#if os(macOS)
import AppKit
import SwiftTerm

/// Switchboard 的终端视图：在 SwiftTerm 的基础上补 Mac 习惯
/// - ⌘V 贴图：剪贴板只有图片时，给 Claude Code / Codex 发 Ctrl-V，让它们自己从剪贴板读图（和在 CLI 里按 Ctrl-V 一样）
/// - 拖文件进来：输入转义好的路径（和 Terminal.app 一样）
/// - ⌘-click 链接 / 文件：网址开浏览器；文件按设置用系统默认 app 或编辑器打开，相对路径按标签的项目目录解析
/// - 行编辑键位见 `TerminalKeys`
final class SBTerminalView: LocalProcessTerminalView, EngineTerminalView {
    var tabID: UUID?
    let cli: CLIKind?
    let directory: String
    let isRemote: Bool
    /// terminalDelegate 是 weak，代理要自己留着
    private var clipboardGuard: ClipboardGuard?

    init(frame: NSRect, cli: CLIKind?, directory: String, isRemote: Bool) {
        self.cli = cli
        self.directory = directory
        self.isRemote = isRemote
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
        let guardian = ClipboardGuard(view: self)
        clipboardGuard = guardian
        terminalDelegate = guardian
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func sendBytes(_ bytes: [UInt8]) {
        send(source: self, data: bytes[...])
    }

    // MARK: EngineTerminalView

    var isProcessRunning: Bool { process?.running == true }
    var terminalBackground: NSColor { nativeBackgroundColor }

    func start(_ launch: TerminalLaunch) {
        startProcess(executable: launch.executable, args: launch.arguments,
                     environment: ShellEnvironment.shared.processEnvironment(extra: launch.environment),
                     execName: nil, currentDirectory: launch.directory)
    }

    func terminateProcess() { process?.terminate() }

    func apply(_ s: TerminalStyle) {
        nativeBackgroundColor = NSColor(hex: s.colors.background)
        nativeForegroundColor = NSColor(hex: s.colors.foreground)
        installColors(s.colors.ansi.map { hex in
            SwiftTerm.Color(red: UInt16((hex >> 16) & 0xFF) * 257, green: UInt16((hex >> 8) & 0xFF) * 257, blue: UInt16(hex & 0xFF) * 257)
        })
        caretColor = NSColor(hex: s.colors.foreground).withAlphaComponent(0.8)
        selectedTextBackgroundColor = NSColor(hex: s.colors.foreground).withAlphaComponent(0.25)
        font = s.font
        optionAsMetaKey = true
        getTerminal().setCursorStyle(.steadyBar)
    }

    // MARK: ⌘V

    override func paste(_ sender: Any) {
        if pasteImageIfNeeded() { return }   // 只有图片：发 Ctrl-V，CLI 自己读剪贴板里的图
        super.paste(sender)
    }

    // MARK: 拖文件

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) ? .copy : []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        return typeDroppedFiles(urls)
    }

    // MARK: ⌘-click

    override func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {
        LinkOpener.open(link, relativeTo: directory, remote: isRemote)
    }
}

/// 终端里的程序用 OSC 52 读剪贴板：SwiftTerm 默认不问就把系统剪贴板交出去（主机上的程序也能读到本机剪贴板里的密码）。
/// clipboardRead 在 SwiftTerm 里不能 override，只能在 terminalDelegate 前面挡一层：读一律拒绝，其余原样转给终端视图。
/// 写剪贴板（CLI 的「复制」）照常放行；Ghostty 引擎默认也是拒绝读
private final class ClipboardGuard: TerminalViewDelegate {
    private weak var view: LocalProcessTerminalView?

    init(view: LocalProcessTerminalView) { self.view = view }

    func clipboardRead(source: TerminalView) -> Data? { nil }

    func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) { view?.sizeChanged(source: source, newCols: newCols, newRows: newRows) }
    func setTerminalTitle(source: TerminalView, title: String) { view?.setTerminalTitle(source: source, title: title) }
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) { view?.hostCurrentDirectoryUpdate(source: source, directory: directory) }
    func send(source: TerminalView, data: ArraySlice<UInt8>) { view?.send(source: source, data: data) }
    func scrolled(source: TerminalView, position: Double) { view?.scrolled(source: source, position: position) }
    func requestOpenLink(source: TerminalView, link: String, params: [String: String]) { view?.requestOpenLink(source: source, link: link, params: params) }
    func bell(source: TerminalView) { view?.bell(source: source) }
    func clipboardCopy(source: TerminalView, content: Data) { view?.clipboardCopy(source: source, content: content) }
    func iTermContent(source: TerminalView, content: ArraySlice<UInt8>) { view?.iTermContent(source: source, content: content) }
    func rangeChanged(source: TerminalView, startY: Int, endY: Int) { view?.rangeChanged(source: source, startY: startY, endY: endY) }
}

/// 行编辑键位：把 Mac 文本框的习惯翻译成 CLI 和 shell 认得的按键。焦点在终端上时才生效
@MainActor
enum TerminalKeys {
    private static var monitor: Any?

    static func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let view = event.window?.firstResponder as? any EngineTerminalView,
                  let bytes = bytes(for: event, cli: view.cli) else { return event }
            view.sendBytes(bytes)
            return nil
        }
    }

    /// nil = 不拦，交给 SwiftTerm
    static func bytes(for event: NSEvent, cli: CLIKind?) -> [UInt8]? {
        let flags = event.modifierFlags.intersection([.command, .option, .shift, .control])
        switch (event.keyCode, flags) {
        case (36, [.shift]) where cli != nil: return [0x0a]            // ⇧Return：换行不发送（Ctrl-J）
        case (123, [.command]): return [0x01]                          // ⌘←：行首（Ctrl-A）
        case (124, [.command]): return [0x05]                          // ⌘→：行尾（Ctrl-E）
        case (51, [.command]): return [0x15]                           // ⌘⌫：删到行首（Ctrl-U）
        case (123, [.option]): return [0x1b, 0x62]                     // ⌥←：上一个词（Esc b）
        case (124, [.option]): return [0x1b, 0x66]                     // ⌥→：下一个词（Esc f）
        case (51, [.option]): return [0x1b, 0x7f]                      // ⌥⌫：删一个词（Esc Del）
        case (6, [.command]) where cli != .codex: return [0x1f]        // ⌘Z：撤销（Ctrl-_；Codex 不支持）
        default: return nil
        }
    }
}

/// ⌘-click 打开（终端里的链接、预览里的 Markdown 链接）：网址开浏览器；文件按「设置 · 通用 · ⌘-点按终端里的文件」
@MainActor
enum LinkOpener {
    enum Target: Equatable {
        case web(URL)
        case reveal(String)              // 会运行东西的：只在访达里显示
        case file(String, line: Int?)
        case refuse
    }

    /// 链接可能来自别人的仓库或提示注入：只放行网址；别的协议（系统设置、第三方 app 的自定义协议）不交给系统，
    /// 只当路径解析（`main.swift:42` 在 URL 看来协议是 main.swift），这台 Mac 上没这个文件就不打开
    static func target(for link: String, relativeTo directory: String, remote: Bool) -> Target {
        if let url = URL(string: link), let scheme = url.scheme?.lowercased(), ["http", "https", "mailto", "ftp"].contains(scheme) {
            return .web(url)
        }
        // 主机上的路径在这台 Mac 上打不开
        guard !remote, let (path, line) = resolve(link, directory: directory) else { return .refuse }
        return revealsInsteadOfOpening(path) ? .reveal(path) : .file(path, line: line)
    }

    static func open(_ link: String, relativeTo directory: String, remote: Bool) {
        let path: String, line: Int?
        switch target(for: link, relativeTo: directory, remote: remote) {
        case .web(let url): NSWorkspace.shared.open(url); return
        case .reveal(let p): NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: p)]); return
        case .refuse: NSSound.beep(); return
        case .file(let p, let l): (path, line) = (p, l)
        }
        let url = URL(fileURLWithPath: path)
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        if isDir.boolValue { NSWorkspace.shared.open(url); return }
        switch UserDefaults.standard.string(forKey: "cmdClickFiles") ?? "system" {
        case "vscode": openInEditor("vscode", path: path, line: line)
        case "cursor": openInEditor("cursor", path: path, line: line)
        case "zed": openInEditor("zed", path: path, line: line)
        case "ask": askMenu(path: path, line: line)
        default: NSWorkspace.shared.open(url)
        }
    }

    /// 打开就会运行、安装或跳到别处的类型：在 Mac 上它们不用可执行位也能跑
    private static let runnableExtensions: Set<String> = [
        "terminal", "command", "tool", "webloc", "inetloc", "fileloc", "url", "pkg", "mpkg", "mobileconfig",
        "scpt", "scptd", "applescript", "workflow", "action", "jar", "prefpane", "saver", "dmg",
    ]

    /// ⌘-click 时只在访达里显示、不打开：包（.app、.workflow 这种看着是文件夹的）、可执行文件、上面这些类型
    static func revealsInsteadOfOpening(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else { return false }
        let ext = (path as NSString).pathExtension.lowercased()
        if isDir.boolValue { return NSWorkspace.shared.isFilePackage(atPath: path) || runnableExtensions.contains(ext) || ext == "app" }
        return runnableExtensions.contains(ext) || FileManager.default.isExecutableFile(atPath: path)
    }

    /// 去掉 `:行号(:列)`，相对路径按标签目录解析；文件不存在返回 nil
    static func resolve(_ link: String, directory: String) -> (String, Int?)? {
        var text = link
        var line: Int?
        if let r = text.range(of: #":([0-9]+)(?::[0-9]+)?$"#, options: .regularExpression) {
            line = Int(text[r].dropFirst().split(separator: ":").first ?? "")
            text = String(text[..<r.lowerBound])
        }
        if text.hasPrefix("file://"), let u = URL(string: text) { text = u.path }
        text = (text as NSString).expandingTildeInPath
        if !text.hasPrefix("/") { text = (directory as NSString).appendingPathComponent(text) }
        let path = (text as NSString).standardizingPath
        return FileManager.default.fileExists(atPath: path) ? (path, line) : nil
    }

    /// VS Code 系和 Zed 都认 `<scheme>://file/<路径>:<行>`；编辑器没装就退回系统默认
    static func openInEditor(_ scheme: String, path: String, line: Int?) {
        let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let target = URL(string: "\(scheme)://file\(encoded)\(line.map { ":\($0)" } ?? "")")
        if let target, NSWorkspace.shared.urlForApplication(toOpen: target) != nil {
            NSWorkspace.shared.open(target)
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        }
    }

    private static func askMenu(path: String, line: Int?) {
        let menu = NSMenu()
        let url = URL(fileURLWithPath: path)
        menu.addItem(ClosureMenuItem(L("打开")) { NSWorkspace.shared.open(url) })
        for (name, scheme) in [("Visual Studio Code", "vscode"), ("Cursor", "cursor"), ("Zed", "zed")] {
            if let probe = URL(string: "\(scheme)://file/"), NSWorkspace.shared.urlForApplication(toOpen: probe) != nil {
                menu.addItem(ClosureMenuItem(L("用 \(name) 打开")) { openInEditor(scheme, path: path, line: line) })
            }
        }
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem(L("在访达中显示")) { NSWorkspace.shared.activateFileViewerSelecting([url]) })
        menu.addItem(ClosureMenuItem(L("拷贝路径")) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(path, forType: .string)
        })
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
}

/// 带闭包的菜单项
final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func fire() { handler() }
}
#endif
