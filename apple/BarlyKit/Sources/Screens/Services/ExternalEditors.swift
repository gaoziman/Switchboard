import Foundation
#if os(macOS)
import AppKit
#endif

/// 「打开项目于」：本机装了的编辑器和终端（按固定顺序，编辑器在前、终端在后）
public enum ExternalEditors {
    public struct App: Identifiable, Hashable, Sendable {
        public var id: String { bundleID }
        public let bundleID: String
        public let name: String
        public let url: URL
    }

    /// 认得的 app：bundle ID → 显示名
    static let known: [(String, String)] = [
        ("com.microsoft.VSCode", "Visual Studio Code"),
        ("com.todesktop.230313mzl4w4u92", "Cursor"),
        ("dev.zed.Zed", "Zed"),
        ("com.exafunction.windsurf", "Windsurf"),
        ("com.apple.dt.Xcode", "Xcode"),
        ("com.sublimetext.4", "Sublime Text"),
        ("com.panic.Nova", "Nova"),
        ("com.jetbrains.intellij", "IntelliJ IDEA"),
        ("com.jetbrains.intellij.ce", "IntelliJ IDEA CE"),
        ("com.jetbrains.WebStorm", "WebStorm"),
        ("com.apple.Terminal", "终端"),
        ("com.googlecode.iterm2", "iTerm"),
        ("com.mitchellh.ghostty", "Ghostty"),
        ("dev.warp.Warp-Stable", "Warp"),
    ]

    /// lookup：bundle ID → app 的位置（真实运行用 NSWorkspace，单测注入）
    static func installed(lookup: (String) -> URL?) -> [App] {
        known.compactMap { id, name in lookup(id).map { App(bundleID: id, name: name, url: $0) } }
    }

    #if os(macOS)
    /// 本机装了的（菜单打开时现查，装了新编辑器不用重启）
    @MainActor public static var installed: [App] {
        installed { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) }
    }

    /// app 图标画成一张 16×16 的位图（NSWorkspace 给的是多尺寸图标，菜单里不一定按 16pt 用）
    @MainActor public static func icon(_ app: App) -> NSImage {
        let source = NSWorkspace.shared.icon(forFile: app.url.path)
        let size = NSSize(width: 16, height: 16)
        return NSImage(size: size, flipped: false) { rect in
            source.draw(in: rect)
            return true
        }
    }

    @MainActor public static func open(_ folder: String, with app: App) {
        NSWorkspace.shared.open([URL(fileURLWithPath: folder)], withApplicationAt: app.url, configuration: NSWorkspace.OpenConfiguration())
    }
    #endif
}
