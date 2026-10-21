import AppKit
import Foundation
import Testing
@testable import Screens

@MainActor
@Suite("终端键位")
struct TerminalKeyTests {
    private func key(_ code: UInt16, _ flags: NSEvent.ModifierFlags, _ chars: String = "") -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0, context: nil,
                         characters: chars, charactersIgnoringModifiers: chars, isARepeat: false, keyCode: code)!
    }

    @Test func mappings() {
        #expect(TerminalKeys.bytes(for: key(36, .shift, "\r"), cli: .claude) == [0x0a])
        #expect(TerminalKeys.bytes(for: key(36, .shift, "\r"), cli: nil) == nil)          // 普通终端不改 ⇧Return
        #expect(TerminalKeys.bytes(for: key(123, .command), cli: .claude) == [0x01])
        #expect(TerminalKeys.bytes(for: key(124, .command), cli: nil) == [0x05])
        #expect(TerminalKeys.bytes(for: key(51, .command), cli: .codex) == [0x15])
        #expect(TerminalKeys.bytes(for: key(123, .option), cli: .claude) == [0x1b, 0x62])
        #expect(TerminalKeys.bytes(for: key(51, .option), cli: .claude) == [0x1b, 0x7f])
        #expect(TerminalKeys.bytes(for: key(6, .command, "z"), cli: .claude) == [0x1f])
        #expect(TerminalKeys.bytes(for: key(6, .command, "z"), cli: .codex) == nil)       // Codex 不支持撤销
        #expect(TerminalKeys.bytes(for: key(36, [], "\r"), cli: .claude) == nil)          // 普通回车交给终端
        #expect(TerminalKeys.bytes(for: key(123, [.command, .shift]), cli: .claude) == nil) // ⇧⌘← 选择，不拦
    }
}

@MainActor
@Suite("⌘-click 路径")
struct LinkTests {
    @Test func resolve() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("sb-link-\(UUID())")
        try FileManager.default.createDirectory(at: dir.appendingPathComponent("Sources"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("Sources/main.swift")
        try "x".write(to: file, atomically: true, encoding: .utf8)
        let base = (dir.path as NSString).standardizingPath
        #expect(LinkOpener.resolve("Sources/main.swift:42", directory: dir.path)?.0 == base + "/Sources/main.swift")
        #expect(LinkOpener.resolve("Sources/main.swift:42", directory: dir.path)?.1 == 42)
        #expect(LinkOpener.resolve("Sources/main.swift:42:7", directory: dir.path)?.1 == 42)
        #expect(LinkOpener.resolve(file.path, directory: "/")?.1 == nil)
        #expect(LinkOpener.resolve("nope.swift", directory: dir.path) == nil)
    }
}

@MainActor
@Suite("切标签 · 认领 · 关闭偏好")
struct TabNavigationTests {
    private func store() -> WorkspaceStore {
        let tabs = (0..<3).map { TerminalTab(kind: .plainTerminal, projectPath: "/p", title: "t\($0)", activity: .idle) }
        let s = WorkspaceStore(hosts: [MockData.local], projects: [], sessions: [],
                               tabGroups: [TabGroup(projectID: "local:/p", name: "p", tint: 0, tabs: tabs, isCollapsed: true)])
        return s
    }

    @Test func numbered() {
        let s = store()
        s.selectTab(at: 1)
        #expect(s.selectedTab?.title == "t1")
        #expect(s.tabGroups[0].isCollapsed == false)       // 选到折叠组里的标签会展开
        s.selectTab(at: -1)
        #expect(s.selectedTab?.title == "t2")
        s.selectTab(at: 7)                                 // 没有第 8 个：不动
        #expect(s.selectedTab?.title == "t2")
    }

    @Test func cycle() {
        let s = store()
        s.cycleTab(1)
        #expect(s.selectedTab?.title == "t0")              // 预览里按下一个 → 第一个
        s.cycleTab(-1)
        #expect(s.selectedTab?.title == "t2")              // 回绕
        s.cycleTab(1)
        #expect(s.selectedTab?.title == "t0")
    }

    @Test("新会话标签认领目录里之后出现的同类会话")
    func claim() {
        let tab = TerminalTab(kind: .session(id: "new-x", cli: .claude), projectPath: "/work/app", title: "新的 Claude Code 会话", activity: .working)
        let start = Date()
        let s = WorkspaceStore(hosts: [MockData.local], projects: [], sessions: [
            Session(id: "old", cli: .claude, hostID: Host.localID, projectPath: "/work/app", title: "旧的", lastActivity: start.addingTimeInterval(-3600), messageCount: 1),
            Session(id: "other", cli: .codex, hostID: Host.localID, projectPath: "/work/app", title: "别的 CLI", lastActivity: start.addingTimeInterval(10), messageCount: 1),
            Session(id: "fresh", cli: .claude, hostID: Host.localID, projectPath: "/work/app/", title: "修登录页", lastActivity: start.addingTimeInterval(8), messageCount: 2),
        ], tabGroups: [TabGroup(projectID: "local:/work/app", name: "app", tint: 0, tabs: [tab])])
        s.pendingClaims[tab.id] = PendingClaim(cli: .claude, folder: "/work/app", startedAt: start)
        s.claimNewSessions()
        #expect(s.tab(tab.id)?.kind == .session(id: "fresh", cli: .claude))
        #expect(s.tab(tab.id)?.title == "修登录页")
        #expect(s.pendingClaims.isEmpty)
    }

    @Test("关闭偏好按主机记")
    func closePreference() {
        let host = "test-host-\(UUID().uuidString.prefix(6))"
        #expect(WorkspaceStore.closeBehavior(for: host) == "ask")
        WorkspaceStore.setCloseBehavior("keep", for: host)
        #expect(WorkspaceStore.closeBehavior(for: host) == "keep")
        UserDefaults.standard.removeObject(forKey: "closeBehavior.\(host)")
    }
}
