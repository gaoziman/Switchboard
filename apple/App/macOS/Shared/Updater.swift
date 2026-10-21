import Foundation
import Observation
import Sparkle

/// 自动更新（Sparkle）：appcast 在 GitHub Releases（Info.plist 的 SUFeedURL），每个版本用 EdDSA 签名（SUPublicEDKey）。
/// 默认每天在后台查一次；有新版弹 Sparkle 自己的更新窗口。发版见 scripts/release.sh
@MainActor
@Observable
final class AppUpdater {
    static let shared = AppUpdater()

    @ObservationIgnored private let controller: SPUStandardUpdaterController?
    @ObservationIgnored private let delegate = UpdaterDelegate()

    private init() {
        // 跑单测、截图的时候不启动
        let env = ProcessInfo.processInfo.environment
        let quiet = env["XCTestConfigurationFilePath"] != nil || CommandLine.arguments.contains { $0.hasPrefix("--sb-") || $0.hasPrefix("--barly") }
        controller = quiet ? nil : SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: delegate, userDriverDelegate: nil)
        automaticallyChecks = controller?.updater.automaticallyChecksForUpdates ?? false
    }

    var automaticallyChecks: Bool {
        didSet { controller?.updater.automaticallyChecksForUpdates = automaticallyChecks }
    }

    var canCheck: Bool { controller?.updater.canCheckForUpdates ?? false }

    var lastCheck: Date? { controller?.updater.lastUpdateCheckDate }

    func checkForUpdates() { controller?.checkForUpdates(nil) }

    static var versionString: String {
        let info = Bundle.main.infoDictionary ?? [:]
        return "\(info["CFBundleShortVersionString"] as? String ?? "?") (\(info["CFBundleVersion"] as? String ?? "?"))"
    }
}

/// 只给本地测更新流程用：`defaults write design.barly.switchboard.mac SBFeedURLOverride http://127.0.0.1:8765/appcast.xml`。
/// 换地址不影响安全：装之前照样核对 EdDSA 签名
final class UpdaterDelegate: NSObject, SPUUpdaterDelegate {
    func feedURLString(for updater: SPUUpdater) -> String? {
        UserDefaults.standard.string(forKey: "SBFeedURLOverride")
    }
}
