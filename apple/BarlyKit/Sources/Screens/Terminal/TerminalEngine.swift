#if os(macOS)
import AppKit

/// 终端引擎：SwiftTerm（默认，纯 Swift）或 Ghostty（GPU 渲染，用 libghostty）。
/// 进程都由我们用 SwiftTerm 的 LocalProcess 在伪终端里起，引擎只管画和收键盘。换引擎只影响之后新开的标签
public enum TerminalEngine: String, CaseIterable, Sendable {
    case swiftTerm, ghostty

    public static let defaultsKey = "terminalEngine"

    public static var current: TerminalEngine {
        UserDefaults.standard.string(forKey: defaultsKey).flatMap(TerminalEngine.init(rawValue:)) ?? .swiftTerm
    }

    public var title: String {
        switch self {
        case .swiftTerm: "SwiftTerm"
        case .ghostty: "Ghostty"
        }
    }

    @MainActor
    func makeView(frame: NSRect, launch: TerminalLaunch) -> any EngineTerminalView {
        let directory = launch.projectPath ?? launch.directory
        switch self {
        case .swiftTerm: return SBTerminalView(frame: frame, cli: launch.cli, directory: directory, isRemote: launch.remoteHost != nil)
        case .ghostty: return GhosttyTerminalView(frame: frame, cli: launch.cli, directory: directory, isRemote: launch.remoteHost != nil)
        }
    }
}

/// SwiftTerm 的 LocalProcess 交上来的是 waitpid 的原始状态（exit 7 → 1792），不是退出码。
/// 换成退出码；被信号结束的按 shell 的习惯记 128 + 信号
enum ExitStatus {
    static func code(fromWaitStatus status: Int32?) -> Int32 {
        guard let s = status else { return 0 }
        let signal = s & 0x7F
        if signal == 0 { return (s >> 8) & 0xFF }        // 正常退出
        if signal == 0x7F { return 0 }                   // 停止（不是退出）
        return 128 + signal
    }
}

/// 两个引擎的终端视图都要做到的事（注册表、样式、键位、拖文件、⌘-click 都只认这个）
@MainActor
protocol EngineTerminalView: NSView {
    var tabID: UUID? { get set }
    var cli: CLIKind? { get }
    var isRemote: Bool { get }
    var isProcessRunning: Bool { get }
    /// 终端底色：外面那圈边距也涂成它
    var terminalBackground: NSColor { get }
    func start(_ launch: TerminalLaunch)
    func terminateProcess()
    /// 直接发给 CLI 的字节（行编辑键位、⌘V 贴图的 Ctrl-V）
    func sendBytes(_ bytes: [UInt8])
    func apply(_ style: TerminalStyle)
}

extension EngineTerminalView {
    func sendText(_ text: String) { sendBytes(Array(text.utf8)) }

    /// 拖文件进来：本机输入转义好的路径；主机上没有这些文件，响一声
    func typeDroppedFiles(_ urls: [URL]) -> Bool {
        guard !urls.isEmpty else { return false }
        window?.makeFirstResponder(self)
        if isRemote { NSSound.beep(); return false }
        sendText(urls.map { Tmux.shellQuote($0.path) }.joined(separator: " ") + " ")
        return true
    }

    /// ⌘V 时剪贴板只有图片：给 Claude Code / Codex 发 Ctrl-V，让它们自己读剪贴板里的图。返回 true = 已处理
    func pasteImageIfNeeded() -> Bool {
        let pb = NSPasteboard.general
        guard pb.string(forType: .string) == nil, pb.canReadObject(forClasses: [NSImage.self], options: nil),
              !isRemote, cli == .claude || cli == .codex else { return false }
        sendBytes([0x16])
        return true
    }
}
#endif
