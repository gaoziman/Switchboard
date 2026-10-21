#if os(macOS)
import AppKit

/// 界面语言：跟随系统 / 中文 / English。写进这个 app 自己的 AppleLanguages，重新启动后整个 app（视图、菜单、通知、报错）一起换。
/// 重启不丢东西：标签会重新打开，tmux 里的 CLI 一直在跑
public enum AppLanguage: String, CaseIterable, Sendable {
    case system, zh, en

    public static let defaultsKey = "language"

    /// 启动时这个 app 实际用的语言（Bundle 选定的那一个）
    public static let launched: String = Bundle.main.preferredLocalizations.first ?? "zh-Hans"

    public static var chosen: AppLanguage {
        UserDefaults.standard.string(forKey: defaultsKey).flatMap(AppLanguage.init(rawValue:)) ?? .system
    }

    /// 选了某个语言之后，下次启动会用哪个
    public var resolved: String {
        switch self {
        case .zh: "zh-Hans"
        case .en: "en"
        case .system: Bundle.preferredLocalizations(from: Bundle.main.localizations, forPreferences: Locale.preferredLanguages).first ?? "zh-Hans"
        }
    }

    /// 写进 AppleLanguages（跟随系统 = 删掉，交还给系统设置里的语言顺序）
    public static func apply(_ language: AppLanguage) {
        let defaults = UserDefaults.standard
        defaults.set(language.rawValue, forKey: defaultsKey)
        switch language {
        case .system: defaults.removeObject(forKey: "AppleLanguages")
        case .zh: defaults.set(["zh-Hans"], forKey: "AppleLanguages")
        case .en: defaults.set(["en"], forKey: "AppleLanguages")
        }
    }

    /// 需要重启才能生效
    public static var needsRelaunch: Bool { chosen.resolved != launched }

    /// 等这个进程退出后再打开自己
    @MainActor public static func relaunch() {
        let path = Bundle.main.bundlePath
        let pid = ProcessInfo.processInfo.processIdentifier
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", "while kill -0 \(pid) 2>/dev/null; do sleep 0.1; done; /usr/bin/open \"$0\"", path]
        try? p.run()
        NSApp.terminate(nil)
    }
}
#endif
