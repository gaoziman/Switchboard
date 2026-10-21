import Foundation
import Testing
@testable import Screens

@MainActor
@Suite("Connect… 解析 ssh 的提问")
struct SSHConnectTests {
    private func feed(_ c: SSHConnect, _ s: String) { c.received(Array(s.utf8)[...]) }

    @Test func password() {
        let c = SSHConnect(alias: "h")
        feed(c, "Authorized users only.\r\n(leo@h) Password:")
        #expect(c.phase == .asking(question: "(leo@h) Password:", secret: true))
        #expect(c.transcript == "Authorized users only.")
    }

    @Test("分几次到的输出也认")
    func chunked() {
        let c = SSHConnect(alias: "h")
        feed(c, "Duo two-factor login for leo\nEnter a passcode")
        #expect(c.phase == .starting)
        feed(c, " or select one of the following options:")
        if case .asking(_, let secret) = c.phase { #expect(secret) } else { Issue.record("没认出提问") }   // passcode 按密文输入
    }

    @Test func otp() {
        let c = SSHConnect(alias: "h")
        feed(c, "Verification code:")
        #expect(c.phase == .asking(question: "Verification code:", secret: true))
    }

    @Test func hostKey() {
        let c = SSHConnect(alias: "h")
        feed(c, "The authenticity of host 'h (1.2.3.4)' can't be established.\nED25519 key fingerprint is SHA256:abc.\nAre you sure you want to continue connecting (yes/no/[fingerprint])?")
        if case .hostKey = c.phase {} else { Issue.record("没认出主机指纹提问") }
        #expect(c.transcript.contains("SHA256:abc"))
    }

    @Test("同一个问题又问一次 = 上次没通过")
    func rejected() {
        let c = SSHConnect(alias: "h")
        feed(c, "Password:")
        #expect(!c.rejected)
        feed(c, "\nPassword:")
        #expect(c.rejected)
    }

    @Test func outcome() {
        let ok = SSHConnect(alias: "h")
        ok.terminated(0)
        #expect(ok.phase == .connected)
        let bad = SSHConnect(alias: "h")
        feed(bad, "Permission denied (publickey).\n")
        bad.terminated(255)
        if case .failed(let why) = bad.phase { #expect(why.contains("Permission denied")) } else { Issue.record("应该失败") }
    }
}

@MainActor
@Suite("真实主机 · Connect…", .enabled(if: ProcessInfo.processInfo.environment["SB_HOST"] != nil))
struct RealConnectTests {
    @Test func connectAndReuse() async throws {
        let alias = ProcessInfo.processInfo.environment["SB_HOST"]!
        let c = SSHConnect(alias: alias)
        var done: Bool?
        c.onFinish = { done = $0 }
        c.start()
        for _ in 0..<200 where done == nil { try await Task.sleep(for: .milliseconds(100)) }
        print("SB Connect 结果", c.phase, "transcript:", c.transcript)
        let check = SSH.run(["/usr/bin/ssh", "-O", "check", "-o", "ControlPath=\(SSH.controlPath)", alias], timeout: 10)
        print("SB 共享连接", check?.status == 0 ? "在" : "不在", check?.stderr.trimmingCharacters(in: .whitespacesAndNewlines) ?? "")
        let reuse = Date()
        let probe = await SSH.probe(alias)
        print("SB 复用连接试连", probe, String(format: "%.2fs", Date().timeIntervalSince(reuse)))
        _ = SSH.run(["/usr/bin/ssh", "-O", "exit", "-o", "ControlPath=\(SSH.controlPath)", alias], timeout: 10)
    }
}

@MainActor
@Suite("断线重连")
struct ReconnectTests {
    private func store() -> (WorkspaceStore, TerminalTab) {
        let tab = TerminalTab(kind: .session(id: "r1", cli: .claude), hostID: "devbox", projectPath: "/srv", title: "远程", activity: .idle)
        let s = WorkspaceStore(hosts: [MockData.local], projects: [], sessions: [
            Session(id: "r1", cli: .claude, hostID: "devbox", projectPath: "/srv", title: "远程", lastActivity: .now, messageCount: 1)
        ], tabGroups: [TabGroup(projectID: "devbox:/srv", name: "srv", tint: 0, tabs: [tab])])
        s.launches[tab.id] = TerminalLaunch.remote(tabID: tab.id, alias: "devbox", command: ["claude"], directory: "/srv", tmuxName: "claude-r1")
        return (s, tab)
    }

    @Test("ssh 掉线（255）→ 第 1 次重连，2 秒后")
    func firstDrop() {
        let (s, tab) = store()
        s.processExited(tab.id, code: 255)
        #expect(s.tabBanners[tab.id] == .reconnecting(attempt: 1, nextIn: 2))
        #expect(s.reconnectAttempts[tab.id] == 1)
    }

    @Test("每次掉线越等越久，试完所有档位就停")
    func backoff() {
        let (s, tab) = store()
        for _ in WorkspaceStore.reconnectDelays { s.scheduleReconnect(tab.id) }
        #expect(s.tabBanners[tab.id] == .reconnecting(attempt: WorkspaceStore.reconnectDelays.count, nextIn: WorkspaceStore.reconnectDelays.last!))
        s.scheduleReconnect(tab.id)
        #expect(s.tabBanners[tab.id] == .reconnecting(attempt: 0, nextIn: 0))   // 自动重连停了
    }

    @Test("连上一分钟以后才断：从第 1 次重新数")
    func resetAfterLongConnection() {
        let (s, tab) = store()
        s.reconnectAttempts[tab.id] = 5
        s.lastRelaunch[tab.id] = Date().addingTimeInterval(-300)
        s.scheduleReconnect(tab.id)
        #expect(s.reconnectAttempts[tab.id] == 1)
    }

    @Test("CLI 正常退出（0）不重连")
    func normalExit() {
        let (s, tab) = store()
        s.processExited(tab.id, code: 0)
        #expect(s.tabBanners[tab.id] == .exited(code: 0))
    }
}
