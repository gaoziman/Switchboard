#if os(macOS)
import AppKit
import SwiftUI
import SwiftTerm
import BarlyKit

/// 每个标签一个终端视图，切标签时不销毁（CLI 继续跑、滚动位置保留）。
/// 进程是 `tmux attach-or-create`；没有 tmux 就直接跑 CLI
@MainActor
public final class TerminalRegistry {
    public static let shared = TerminalRegistry()

    private var views: [UUID: any EngineTerminalView] = [:]
    private var delegates: [UUID: TerminalDelegate] = [:]
    /// CLI 退出时回调（tab id, 退出码）
    public var onExit: ((UUID, Int32) -> Void)?
    /// 终端标题变化（CLI 用 OSC 设的标题，Codex 用它报状态）
    public var onTitle: ((UUID, String) -> Void)?

    /// 标签的终端：第一次要时按当前设置的引擎建好并启动进程，之后每次拿回同一个视图（换窗口、换引擎设置都不重建）
    func view(for launch: TerminalLaunch, palette: BarlyPalette) -> any EngineTerminalView {
        if let existing = views[launch.tabID] { return existing }
        TerminalKeys.install()
        observeSettings()
        let view = TerminalEngine.current.makeView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), launch: launch)
        view.tabID = launch.tabID
        view.apply(TerminalStyle.current())
        if let swiftTerm = view as? SBTerminalView {
            let delegate = TerminalDelegate(tabID: launch.tabID, registry: self)
            swiftTerm.processDelegate = delegate
            delegates[launch.tabID] = delegate
        }
        views[launch.tabID] = view
        view.start(launch)
        return view
    }

    /// 这个标签用的是哪个引擎（设置里说明「之后新开的标签才换」时用）
    public func engine(of tabID: UUID) -> TerminalEngine? {
        views[tabID].map { $0 is GhosttyTerminalView ? .ghostty : .swiftTerm }
    }

    /// 关标签：只断开终端（tmux 里的 CLI 继续跑），或者连 tmux 会话一起结束
    public func close(_ tabID: UUID, endingTmux tmuxName: String?) {
        if let tmuxName { Tmux.kill(tmuxName) }
        if let view = views[tabID] {
            view.terminateProcess()
            view.removeFromSuperview()
        }
        views[tabID] = nil
        delegates[tabID] = nil
    }

    public func isAlive(_ tabID: UUID) -> Bool { views[tabID]?.isProcessRunning == true }

    private var observer: NSObjectProtocol?

    /// 设置一改（配色、字体、字号、主题、明暗），所有开着的终端立刻换
    private func observeSettings() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { TerminalRegistry.shared.restyleAll() }
        }
    }

    private var lastStyleKey = ""

    public func restyleAll() {
        let key = TerminalStyle.current().key
        guard key != lastStyleKey else { return }
        lastStyleKey = key
        let style = TerminalStyle.current()
        for view in views.values {
            view.apply(style)
            view.superview?.layer?.backgroundColor = NSColor(hex: style.colors.background).cgColor
        }
    }

    func exited(_ tabID: UUID, code: Int32) { onExit?(tabID, code) }
    func titled(_ tabID: UUID, _ title: String) { onTitle?(tabID, title) }
}

/// 终端当前该用的配色和字体（从设置算出来）
@MainActor
public struct TerminalStyle {
    public let colors: TerminalColors
    public let font: NSFont

    var key: String { "\(colors.background)-\(colors.foreground)-\(colors.ansi)-\(font.fontName)-\(font.pointSize)" }

    public static let defaultFontSize = 13

    public static func current() -> TerminalStyle {
        let d = UserDefaults.standard
        let theme = AppTheme.current
        let appDark: Bool = switch d.string(forKey: "appearance") ?? "system" {
        case "light": false
        case "dark": true
        default: NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
        let dark: Bool = switch d.string(forKey: "terminalBrightness") ?? "app" {
        case "light": false
        case "dark": true
        default: appDark
        }
        let base = theme.palette(dark: dark) ?? (dark ? BarlyTokens.dark : BarlyTokens.light)
        var colors = TerminalColors.resolve(scheme: d.string(forKey: "terminalScheme") ?? "app", appTheme: theme, dark: dark,
                                            appCanvas: NSColor(base.canvas).hexValue, appText: NSColor(base.text).hexValue)
        let intensity = d.object(forKey: "colorIntensity") as? Double ?? 100
        colors = colors.intensified(intensity / 100)
        let size = CGFloat(d.object(forKey: "terminalFontSize") as? Int ?? defaultFontSize)
        return TerminalStyle(colors: colors, font: font(family: d.string(forKey: "terminalFont") ?? "system", size: size))
    }

    static func font(family: String, size: CGFloat) -> NSFont {
        if family != "system", let f = NSFontManager.shared.font(withFamily: family, traits: [], weight: 5, size: size) { return f }
        return NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
    }

    /// 本机装的等宽字体（设置里列出来）；字宽不等的、中文字体会被排除
    public static func monospacedFamilies() -> [String] {
        NSFontManager.shared.availableFontFamilies.filter { family in
            guard !family.hasPrefix("."), let f = NSFontManager.shared.font(withFamily: family, traits: [], weight: 5, size: 13) else { return false }
            return f.isFixedPitch || family.localizedCaseInsensitiveContains("Mono") || family.localizedCaseInsensitiveContains("Code")
        }
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }

    var hexValue: UInt32 {
        guard let c = usingColorSpace(.sRGB) else { return 0 }
        return (UInt32((c.redComponent * 255).rounded()) << 16) | (UInt32((c.greenComponent * 255).rounded()) << 8) | UInt32((c.blueComponent * 255).rounded())
    }
}

private final class TerminalDelegate: NSObject, LocalProcessTerminalViewDelegate {
    let tabID: UUID
    weak var registry: TerminalRegistry?

    init(tabID: UUID, registry: TerminalRegistry) {
        self.tabID = tabID
        self.registry = registry
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        let id = tabID
        Task { @MainActor [weak registry] in registry?.titled(id, title) }
    }

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        let id = tabID
        let code = ExitStatus.code(fromWaitStatus: exitCode)    // 原始 waitpid 状态 → 退出码（ssh 断线的 255 才认得出来）
        Task { @MainActor [weak registry] in registry?.exited(id, code: code) }
    }
}

/// SwiftUI 里放终端：同一个标签每次拿回同一个视图
public struct TerminalSurface: NSViewRepresentable {
    let launch: TerminalLaunch
    @Environment(\.barly) private var t

    public init(launch: TerminalLaunch) { self.launch = launch }

    public func makeNSView(context: Context) -> NSView {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(t.canvas).cgColor
        attach(to: container)
        return container
    }

    public func updateNSView(_ container: NSView, context: Context) {
        attach(to: container)
    }

    private func attach(to container: NSView) {
        let view = TerminalRegistry.shared.view(for: launch, palette: t)
        container.layer?.backgroundColor = view.terminalBackground.cgColor
        guard view.superview !== container else { return }
        view.removeFromSuperview()
        container.subviews.forEach { $0.removeFromSuperview() }
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            view.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
        ])
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
    }
}
#endif
