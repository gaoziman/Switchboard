#if os(macOS)
import AppKit
import SwiftTerm

/// Switchboard 的终端视图：在 SwiftTerm 的基础上补 Mac 习惯
/// - ⌘V 贴图：剪贴板只有图片时，给 Claude Code / Codex 发 Ctrl-V，让它们自己从剪贴板读图（和在 CLI 里按 Ctrl-V 一样）
/// - 拖文件进来：输入转义好的路径（和 Terminal.app 一样）
/// - ⌘-click 链接 / 文件：网址开浏览器；文件按设置用系统默认 app 或编辑器打开，相对路径按标签的项目目录解析
/// - 行编辑键位见 `TerminalKeys`
final class SBTerminalView: LocalProcessTerminalView {
    let cli: CLIKind?
    let directory: String
    let isRemote: Bool

    init(frame: NSRect, cli: CLIKind?, directory: String, isRemote: Bool) {
        self.cli = cli
        self.directory = directory
        self.isRemote = isRemote
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func sendBytes(_ bytes: [UInt8]) {
        send(source: self, data: bytes[...])
    }

    func sendText(_ text: String) {
        sendBytes(Array(text.utf8))
    }

    // MARK: ⌘V

    override func paste(_ sender: Any) {
        let pb = NSPasteboard.general
        let hasText = pb.string(forType: .string) != nil
        let hasImage = pb.canReadObject(forClasses: [NSImage.self], options: nil)
        if !hasText, hasImage, !isRemote, cli == .claude || cli == .codex {
            sendBytes([0x16])   // Ctrl-V：CLI 自己读剪贴板里的图片并附到提示里
            return
        }
        super.paste(sender)
    }

    // MARK: 拖文件

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) ? .copy : []
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self],
                                                               options: [.urlReadingFileURLsOnly: true]) as? [URL],
              !urls.isEmpty else { return false }
        window?.makeFirstResponder(self)
        if isRemote {
            // 主机上没有这些文件，路径输进去也用不了（先复制到主机，下一步做）
            NSSound.beep()
            return false
        }
        sendText(urls.map { Tmux.shellQuote($0.path) }.joined(separator: " ") + " ")
        return true
    }

    // MARK: ⌘-click

    override func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {
        LinkOpener.open(link, relativeTo: directory, remote: isRemote)
    }
}

/// 行编辑键位：把 Mac 文本框的习惯翻译成 CLI 和 shell 认得的按键。焦点在终端上时才生效
@MainActor
enum TerminalKeys {
    private static var monitor: Any?

    static func install() {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let view = event.window?.firstResponder as? SBTerminalView,
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

/// ⌘-click 打开：网址开浏览器；文件按「设置 · 通用 · ⌘-点按终端里的文件」
@MainActor
enum LinkOpener {
    static func open(_ link: String, relativeTo directory: String, remote: Bool) {
        if let url = URL(string: link), let scheme = url.scheme, ["http", "https", "mailto", "ftp"].contains(scheme) {
            NSWorkspace.shared.open(url)
            return
        }
        // 主机上的路径在这台 Mac 上打不开
        guard !remote else { NSSound.beep(); return }
        guard let (path, line) = resolve(link, directory: directory) else { NSSound.beep(); return }
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        let url = URL(fileURLWithPath: path)
        if isDir.boolValue { NSWorkspace.shared.open(url); return }
        // 会执行的东西（脚本、可执行文件）不打开，只在访达里显示
        if FileManager.default.isExecutableFile(atPath: path), url.pathExtension != "app" {
            NSWorkspace.shared.activateFileViewerSelecting([url])
            return
        }
        switch UserDefaults.standard.string(forKey: "cmdClickFiles") ?? "system" {
        case "vscode": openInEditor("vscode", path: path, line: line)
        case "cursor": openInEditor("cursor", path: path, line: line)
        case "zed": openInEditor("zed", path: path, line: line)
        case "ask": askMenu(path: path, line: line)
        default: NSWorkspace.shared.open(url)
        }
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
