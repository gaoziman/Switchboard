import AppKit
import SwiftUI

/// 菜单栏 / 浮动面板形态共用的 AppKit 小工具（这两种形态没有 SwiftUI 主窗口，弹窗和面板由 AppKit 承载）。
@MainActor
enum AppKitSupport {
    /// 「外观」偏好 → NSAppearance。NSPanel / NSPopover 里的 NSHostingView 不认 SwiftUI 的 preferredColorScheme
    /// （Stash 实测：浅色截出来仍是深色），面板 / 货架 / 弹窗每次弹出前都要把外观设在窗口上
    static func appearance() -> NSAppearance? {
        switch UserDefaults.standard.string(forKey: "appearance") ?? "system" {
        case "light": NSAppearance(named: .aqua)
        case "dark": NSAppearance(named: .darkAqua)
        default: nil
        }
    }

    private static var settingsTrigger: NSWindow?
    private static var windows: [String: NSWindow] = [:]
    private static var anchor: NSWindow?

    /// 打开 SwiftUI 的 Settings 场景。`openSettings` 只能在 SwiftUI 视图里拿到，
    /// AppKit 菜单项里没有，所以放一个看不见的小窗口承载一个视图，由它去调。
    static func openSettings() {
        settingsTrigger?.close()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1, height: 1), styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsOpener())
        window.orderFrontRegardless()
        settingsTrigger = window
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 打开（或复用）一个承载 SwiftUI 视图的普通窗口：自绘外壳，隐藏标题栏。
    /// 菜单栏 app 没有 Dock 图标，打开窗口时要 activate，否则窗口会出现在别的 app 后面。
    @discardableResult
    static func showWindow(id: String, title: String, size: CGSize, content: some View) -> NSWindow {
        if let window = windows[id] {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return window
        }
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = title
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: content)
        window.center()
        windows[id] = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return window
    }

    /// 屏幕右上角、菜单栏正下方的透明锚点：菜单栏太挤、状态栏图标被系统藏起来时（刘海屏常见），弹窗挂到这里。
    static func topTrailingAnchor() -> NSView {
        if let view = anchor?.contentView { return view }
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let frame = NSRect(x: screen.visibleFrame.maxX - 420, y: screen.visibleFrame.maxY - 1, width: 24, height: 1)
        let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .statusBar
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.orderFrontRegardless()
        anchor = window
        return window.contentView!
    }
}

private struct SettingsOpener: View {
    @Environment(\.openSettings) private var openSettings
    var body: some View {
        Color.clear.frame(width: 1, height: 1).onAppear { openSettings() }
    }
}
