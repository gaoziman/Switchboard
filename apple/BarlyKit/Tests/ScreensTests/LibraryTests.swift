import Foundation
import Testing
@testable import Screens

@Suite("启动命令拆分")
struct SplitterTests {
    @Test func plain() { #expect(CommandLineSplitter.split("codex --dangerously-bypass-approvals-and-sandbox") == ["codex", "--dangerously-bypass-approvals-and-sandbox"]) }
    @Test func quotes() { #expect(CommandLineSplitter.split(#"claude --aws-profile "dev team"  --x 'a b'"#) == ["claude", "--aws-profile", "dev team", "--x", "a b"]) }
    @Test func tilde() { #expect(CommandLineSplitter.split("~/.toolbox/bin/claude")[0] == NSHomeDirectory() + "/.toolbox/bin/claude") }
    @Test func emptyQuoted() { #expect(CommandLineSplitter.split(#"x """#) == ["x", ""]) }
}

@MainActor
@Suite("本地会话库状态")
struct LibraryStateTests {
    private func store() -> WorkspaceStore {
        let sessions = (1...4).map { i in
            Session(id: "s\(i)", cli: .claude, hostID: Host.localID, projectPath: "/p", title: "会话 \(i)",
                    lastActivity: Date.now.addingTimeInterval(Double(-i) * 60), messageCount: 1)
        }
        return WorkspaceStore(hosts: [MockData.local], projects: [Project(hostID: Host.localID, path: "/p")], sessions: sessions)
    }

    @Test("几千个会话时合上本地标记不卡；改了会话库马上生效，不用另外去盖")
    func marksAreLiveAndFast() {
        let sessions = (1...3000).map { i in
            Session(id: "s\(i)", cli: .claude, hostID: Host.localID, projectPath: "/p", title: "会话 \(i)", lastActivity: .now, messageCount: 1)
        }
        let s = WorkspaceStore(hosts: [MockData.local], projects: [Project(hostID: Host.localID, path: "/p")], sessions: sessions)
        s.library.pinnedSessions = ["s7"]
        s.library.names = ["s9": "改过名"]
        let start = Date()
        _ = s.sessions
        #expect(Date().timeIntervalSince(start) < 0.5)   // 逐个改的写法要几秒
        #expect(s.session("s7")?.isPinned == true && s.session("s8")?.isPinned == false)
        #expect(s.session("s9")?.localName == "改过名")
    }

    @Test("置顶按置顶的先后排，不按时间")
    func pinOrder() {
        let s = store()
        s.togglePin(s.session("s4")!)
        s.togglePin(s.session("s2")!)
        #expect(s.sessions(in: s.projects[0]).map(\.id) == ["s4", "s2", "s1", "s3"])
        s.togglePin(s.session("s4")!)
        #expect(s.sessions(in: s.projects[0]).map(\.id) == ["s2", "s1", "s3", "s4"])
    }

    @Test("重命名只改显示名，留空恢复")
    func rename() {
        let s = store()
        s.rename(s.session("s1")!, to: "  计费改版  ")
        #expect(s.session("s1")?.displayTitle == "计费改版")
        #expect(s.session("s1")?.title == "会话 1")
        s.rename(s.session("s1")!, to: "")
        #expect(s.session("s1")?.displayTitle == "会话 1")
        #expect(s.library.names.isEmpty)
    }

    @Test("归档后默认不列出，打开显示归档才列")
    func archive() {
        let s = store()
        s.setArchived(["s1", "s3"], true)
        #expect(s.sessions(in: s.projects[0]).map(\.id) == ["s2", "s4"])
        s.showsArchived = true
        #expect(s.sessions(in: s.projects[0]).count == 4)
        s.setArchived(["s1"], false)
        #expect(s.library.archivedSessions == ["s3"])
    }

    @Test("刷新换掉会话列表：置顶、改名照样在（以前要记得刷新完再盖一遍）")
    func marksSurviveRefresh() {
        let s = store()
        s.togglePin(s.session("s3")!)
        s.rename(s.session("s3")!, to: "新名字")
        let fresh = (1...4).map { i in       // 重新读盘：读出来的会话不带任何本地标记
            Session(id: "s\(i)", cli: .claude, hostID: Host.localID, projectPath: "/p", title: "会话 \(i)", lastActivity: .now, messageCount: 1)
        }
        s.replaceSessions(on: Host.localID, with: fresh)
        #expect(s.session("s3")?.isPinned == true)
        #expect(s.session("s3")?.displayTitle == "新名字")
    }

    @Test("按 CLI 保存启动命令")
    func commands() {
        let s = store()
        let command = { (cli: CLIKind) in
            LaunchPlan.command(for: cli, remote: false, savedCommand: s.savedCommand(for: cli), additions: nil, arguments: []).command
        }
        s.saveCommand("codex --x", for: .codex)
        #expect(command(.codex) == ["codex", "--x"] + ActivityMonitor.codexTitleArguments)
        #expect(command(.claude) == ["claude"])
        s.saveCommand(nil, for: .codex)
        #expect(command(.codex) == ["codex"] + ActivityMonitor.codexTitleArguments)
    }
}
