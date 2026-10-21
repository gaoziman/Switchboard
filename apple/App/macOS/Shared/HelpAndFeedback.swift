import SwiftUI
import AppKit
import ApplicationServices
@preconcurrency import UserNotifications
import Screens

/// 「帮助」菜单：使用说明（跟界面语言）、快捷键、反馈 / 报告问题（GitHub 表单，版本预填）、更新说明、源代码
struct HelpCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .help) {
            Button("Switchboard 使用说明") { open(AppLinks.guide()) }
            Button("快捷键") { open(AppLinks.guide(.shortcuts)) }
            Button("SSH 主机连不上…") { open(AppLinks.guide(.troubleshooting)) }
            Divider()
            Button("发送反馈…") { open(FeedbackLinks.feedback()) }
            Button("报告问题…") { open(FeedbackLinks.bugReport()) }
            Divider()
            Button("更新说明") { open(AppLinks.releases) }
            Button("在 GitHub 上查看源代码") { open(AppLinks.repository) }
        }
    }

    private func open(_ url: URL) { NSWorkspace.shared.open(url) }
}

// MARK: - 权限

/// 设置「权限」页的真实状态。只读状态，不触发任何授权弹窗；从系统设置回来（app 重新激活）时重查
@MainActor
@Observable
final class PermissionStatus {
    enum State { case granted, notGranted, unknown }

    var notifications = State.unknown
    var fullDiskAccess = State.unknown
    var accessibility = State.unknown

    func refresh() {
        accessibility = AXIsProcessTrusted() ? .granted : .notGranted
        // 能读 TCC 数据库 = 有完全磁盘访问（读不出内容也没关系，只看能不能打开）
        let tcc = "/Library/Application Support/com.apple.TCC/TCC.db"
        fullDiskAccess = FileManager.default.isReadableFile(atPath: tcc) && (try? FileHandle(forReadingFrom: URL(fileURLWithPath: tcc)).close()) != nil ? .granted : .notGranted
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral: notifications = .granted
            case .denied: notifications = .notGranted
            default: notifications = .unknown     // 还没问过：第一次真有通知要发时才会问
            }
        }
    }

    enum Pane: String {
        case notifications, fullDisk = "Privacy_AllFiles", accessibility = "Privacy_Accessibility", localNetwork = "Privacy_LocalNetwork"
    }

    static func openSettings(_ pane: Pane) {
        let url = pane == .notifications
            ? "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(Bundle.main.bundleIdentifier ?? "")"
            : "x-apple.systempreferences:com.apple.preference.security?\(pane.rawValue)"
        if let u = URL(string: url) { NSWorkspace.shared.open(u) }
    }
}

// MARK: - 崩溃报告

/// 启动时：上次启动之后崩过，就问一次要不要报告（GitHub 表单预填摘要；报告文件可以在访达里找到拖进去）
@MainActor
enum CrashReportOffer {
    private static var checked = false

    static func checkOnce() {
        guard !checked else { return }
        checked = true
        let args = CommandLine.arguments
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
              !args.contains(where: { $0.hasPrefix("--sb-") || $0.hasPrefix("--barly") }) else { return }
        Task {
            guard let report = await CrashReportCheck.newReportSinceLastLaunch() else { return }
            show(report)
        }
    }

    static func show(_ report: FoundCrashReport) {
        let alert = NSAlert()
        alert.messageText = L("Switchboard 上次意外退出了")
        alert.informativeText = L("可以把这次崩溃报告给开发者。会打开 GitHub 的问题表单，版本和崩溃摘要已经填好，不含你的文件路径；你可以补一句当时在做什么。")
            + "\n\n" + (report.summary.exception ?? "")
        alert.addButton(withTitle: L("在 GitHub 上报告…"))
        alert.addButton(withTitle: L("不用了"))
        alert.addButton(withTitle: L("在访达中显示报告"))
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            NSWorkspace.shared.open(CrashReportLinks.gitHubIssue(report.summary, fileName: report.file.lastPathComponent))
            NSWorkspace.shared.activateFileViewerSelecting([report.file])
        case .alertThirdButtonReturn:
            NSWorkspace.shared.activateFileViewerSelecting([report.file])
        default:
            break
        }
    }
}
