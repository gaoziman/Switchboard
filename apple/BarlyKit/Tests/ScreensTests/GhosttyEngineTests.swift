#if os(macOS)
import AppKit
import Foundation
import Testing
@testable import Screens

/// Ghostty 引擎真跑一遍：离屏窗口（不显示、不抢焦点）里建视图，伪终端里跑命令，从 Ghostty 自己的屏幕读回文字。
/// 要 GPU 和 libghostty，默认不跑：SB_GHOSTTY=1 swift test --filter GhosttyEngineTests
@MainActor
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["SB_GHOSTTY"] != nil))
struct GhosttyEngineTests {
    /// 异步等：让出主线程，主队列上排着的回调（进程退出、Ghostty 的写回）才能跑
    func spin(until done: () -> Bool, seconds: Double = 8) async -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while !done() && Date() < deadline { try? await Task.sleep(for: .milliseconds(50)) }
        return done()
    }

    @Test func runsCommandAndShowsOutput() async throws {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: -3000, y: -3000, width: 800, height: 500), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let view = GhosttyTerminalView(frame: NSRect(x: 0, y: 0, width: 800, height: 500), cli: nil, directory: NSHomeDirectory(), isRemote: false)
        view.apply(TerminalStyle.current())
        window.contentView = view
        let tabID = UUID()
        view.tabID = tabID
        var exitCode: Int32?
        TerminalRegistry.shared.onExit = { id, code in if id == tabID { exitCode = code } }
        let launch = TerminalLaunch(tabID: tabID, executable: "/bin/sh",
                                    arguments: ["-c", "printf 'hello from ghostty\\n'; printf '\\033[31mred\\033[0m %s cols\\n' \"$(tput cols 2>/dev/null || echo ?)\"; sleep 0.5; exit 7"],
                                    directory: NSHomeDirectory())
        view.start(launch)
        #expect(await spin { view.screenText?.contains("hello from ghostty") == true }, "屏幕：\(view.screenText ?? "nil")")
        #expect(await spin { exitCode != nil })
        #expect(exitCode == 7)
        print("Ghostty 屏幕：\n\(view.screenText ?? "")")
        window.close()
    }

    @Test func typedInputReachesProcess() async throws {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: -3000, y: -3000, width: 800, height: 500), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let view = GhosttyTerminalView(frame: NSRect(x: 0, y: 0, width: 800, height: 500), cli: nil, directory: NSHomeDirectory(), isRemote: false)
        window.contentView = view
        view.start(TerminalLaunch(tabID: UUID(), executable: "/bin/cat", arguments: [], directory: NSHomeDirectory()))
        view.sendText("echo-through-pty\n")
        #expect(await spin { (view.screenText?.components(separatedBy: "echo-through-pty").count ?? 0) >= 3 }, "屏幕：\(view.screenText ?? "nil")")
        view.terminateProcess()
        window.close()
    }
}
#endif
