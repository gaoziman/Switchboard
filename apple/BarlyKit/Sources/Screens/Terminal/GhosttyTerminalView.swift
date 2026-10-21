#if os(macOS)
import AppKit
import GhosttyTerminal
import SwiftTerm

/// Ghostty 画的终端。进程照样是 SwiftTerm 的 LocalProcess（伪终端由我们管）：进程的输出交给 Ghostty 的内存会话，
/// Ghostty 把你打的字和排出来的行列数交回来。颜色、字体来自共用的 GhosttyStyle 控制器。
/// 输出太快 Ghostty 来不及解析时（超过 4 MB 没解析），读进程的队列先等一等，进程写满伪终端缓冲也就跟着停，和普通终端一样
final class GhosttyTerminalView: AppTerminalView, EngineTerminalView, TerminalSurfaceViewDelegate {
    var tabID: UUID?
    let cli: CLIKind?
    let directory: String
    let isRemote: Bool

    private let session: InMemoryTerminalSession
    private let pump: GhosttyOutputPump
    private let processQueue = DispatchQueue(label: "design.barly.switchboard.ghostty.process")
    private var process: LocalProcess!
    /// Ghostty 最近一次排出来的行列（伪终端的窗口大小跟着它）
    private var viewport: InMemoryTerminalViewport?

    init(frame: NSRect, cli: CLIKind?, directory: String, isRemote: Bool) {
        self.cli = cli
        self.directory = directory
        self.isRemote = isRemote
        // Ghostty 在它自己的线程上回调：转到主线程处理
        let target = WeakTarget()
        session = InMemoryTerminalSession(
            write: { data in DispatchQueue.main.async { MainActor.assumeIsolated { target.view?.process.send(data: Array(data)[...]) } } },
            resize: { viewport in DispatchQueue.main.async { MainActor.assumeIsolated { target.view?.resize(to: viewport) } } }
        )
        pump = GhosttyOutputPump(session: session)
        super.init(frame: frame)
        target.view = self
        pump.view = self
        process = LocalProcess(delegate: pump, dispatchQueue: processQueue)
        delegate = self
        configuration = TerminalSurfaceOptions(backend: .inMemory(session))
        controller = GhosttyStyle.shared.controller
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private final class WeakTarget: @unchecked Sendable { @MainActor weak var view: GhosttyTerminalView? }

    /// Ghostty 当前屏幕上的文字（单测用）
    var screenText: String? { session.readViewportText() }

    // MARK: EngineTerminalView

    var isProcessRunning: Bool { process.running }
    var terminalBackground: NSColor { NSColor(hex: GhosttyStyle.shared.background) }

    func start(_ launch: TerminalLaunch) {
        process.startProcess(executable: launch.executable, args: launch.arguments,
                             environment: ShellEnvironment.shared.processEnvironment(extra: launch.environment),
                             execName: nil, currentDirectory: launch.directory)
    }

    func terminateProcess() {
        pump.stop()
        ChildReaper.terminate(process)
    }

    func sendBytes(_ bytes: [UInt8]) { process.send(data: bytes[...]) }

    func apply(_ style: TerminalStyle) { GhosttyStyle.shared.apply(style) }

    // MARK: 伪终端

    private func resize(to viewport: InMemoryTerminalViewport) {
        self.viewport = viewport
        guard process.running else { return }
        var size = windowSize
        _ = PseudoTerminalHelpers.setWinSize(masterPtyDescriptor: process.childfd, windowSize: &size)
    }

    var windowSize: winsize {
        guard let v = viewport else { return winsize(ws_row: 24, ws_col: 80, ws_xpixel: 0, ws_ypixel: 0) }
        return winsize(ws_row: UInt16(v.rows), ws_col: UInt16(v.columns), ws_xpixel: UInt16(clamping: v.widthPixels), ws_ypixel: UInt16(clamping: v.heightPixels))
    }

    fileprivate func processEnded(_ status: Int32?) {
        let code = ExitStatus.code(fromWaitStatus: status)
        session.finish(exitCode: UInt32(bitPattern: code), runtimeMilliseconds: 0)
        if let tabID { TerminalRegistry.shared.exited(tabID, code: code) }
    }

    // MARK: Mac 习惯

    override func paste(_ sender: Any?) {
        if pasteImageIfNeeded() { return }
        super.paste(sender)
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        sender.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) ? .copy : []
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation { draggingEntered(sender) }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        return typeDroppedFiles(urls)
    }

    // MARK: TerminalSurfaceViewDelegate

    func terminalDidChangeTitle(_ title: String) {
        if let tabID { TerminalRegistry.shared.titled(tabID, title) }
    }

    func terminalDidRequestOpenURL(_ url: String, kind: TerminalOpenURLKind) {
        LinkOpener.open(url, relativeTo: directory, remote: isRemote)
    }

    func terminalDidRingBell() { NSSound.beep() }
}

/// LocalProcess 在后台队列上回调这里：输出直接交给 Ghostty 的会话（它线程安全、从不阻塞），
/// 没解析的超过高水位就在这条队列上等，等降到低水位再读
private final class GhosttyOutputPump: LocalProcessDelegate, @unchecked Sendable {
    static let highWater = 4 << 20, lowWater = 1 << 20

    private let session: InMemoryTerminalSession
    private let room = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var stopped = false
    @MainActor weak var view: GhosttyTerminalView?

    init(session: InMemoryTerminalSession) {
        self.session = session
        session.setOutputBacklogHandler(highWater: Self.highWater, lowWater: Self.lowWater) { [weak self] backlogged in
            if !backlogged { self?.room.signal() }
        }
    }

    func stop() {
        lock.withLock { stopped = true }
        room.signal()
    }

    func dataReceived(slice: ArraySlice<UInt8>) {
        while session.pendingOutputByteCount >= Self.highWater, !lock.withLock({ stopped }) {
            _ = room.wait(timeout: .now() + .milliseconds(100))
        }
        session.receive(Data(slice))
    }

    func processTerminated(_ source: LocalProcess, exitCode: Int32?) {
        DispatchQueue.main.async { MainActor.assumeIsolated { self.view?.processEnded(exitCode) } }
    }

    func getWindowSize() -> winsize {
        // LocalProcess 只在 startProcess 里问，startProcess 在主线程调
        MainActor.assumeIsolated { view?.windowSize ?? winsize(ws_row: 24, ws_col: 80, ws_xpixel: 0, ws_ypixel: 0) }
    }
}

/// 所有 Ghostty 终端共用一个控制器：配色、字体变了重新配置一次，开着的终端一起换
@MainActor
final class GhosttyStyle {
    static let shared = GhosttyStyle()

    /// 键位全清：⌘T、⌘W、⌘1–9 这些交给 app 的菜单；复制 / 粘贴 / 全选走编辑菜单（视图的 copy: / paste: / selectAll:）
    private static let base = TerminalConfiguration { b in
        b.withCustom("keybind", "clear")
        b.withWindowPaddingX(0)
        b.withWindowPaddingY(0)
        b.withCursorStyle(.bar)
        b.withCursorStyleBlink(false)
        b.withCustom("macos-option-as-alt", "true")
        b.withCustom("confirm-close-surface", "false")
        b.withCustom("shell-integration", "none")
    }

    private(set) var background: UInt32 = 0x131313
    private var themeKey = ""
    lazy var controller: TerminalController = {
        let style = TerminalStyle.current()
        background = style.colors.background
        themeKey = style.key
        return TerminalController(configuration: Self.base, theme: Self.theme(style))
    }()

    func apply(_ style: TerminalStyle) {
        guard style.key != themeKey else { return }
        themeKey = style.key
        background = style.colors.background
        _ = controller.setTheme(Self.theme(style))
    }

    /// 我们的配色放在主题里（主题在配置之后渲染，盖过库自带的默认配色）；浅色、深色同一套，明暗由设置算好
    static func theme(_ style: TerminalStyle) -> TerminalTheme {
        let c = style.colors
        func hex(_ v: UInt32) -> String { String(format: "#%06X", v & 0xFFFFFF) }
        let config = TerminalConfiguration { b in
            b.withBackground(hex(c.background))
            b.withForeground(hex(c.foreground))
            b.withCursorColor(hex(c.foreground))
            b.withSelectionBackground(hex(ThemeColors.mix(c.background, c.foreground, 0.25)))
            for (i, v) in c.ansi.prefix(16).enumerated() { b.withPalette(i, color: hex(v)) }
            b.withFontSize(Float(style.font.pointSize))
            // 系统等宽字体是隐藏字族，Ghostty 按名字找不到：这时用 Ghostty 自带的默认字体
            if let family = style.font.familyName, !family.hasPrefix(".") { b.withFontFamily(family) }
        }
        return TerminalTheme(light: config, dark: config)
    }
}
#endif
