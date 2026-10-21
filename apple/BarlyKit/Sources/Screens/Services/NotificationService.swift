import Foundation
@preconcurrency import UserNotifications

/// 系统通知：CLI 跑完一轮、停下来等你。点通知 → 打开那个会话（它的标签，或重新接上 tmux）。
/// 第一次真有东西要通知时才请求权限；开关在设置「通用 · 通知」，横幅 / 声音 / 勿扰跟随系统设置
@MainActor
public final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    public static let shared = NotificationService()
    private var asked = false

    /// 点了通知（会话 ID）
    public var onOpen: ((String) -> Void)?
    /// 点了「该重新登录了」（主机别名）
    public var onSignIn: ((String) -> Void)?

    public func install() {
        UNUserNotificationCenter.current().delegate = self
    }

    public func post(_ change: ActivityChange, title: String, project: String, cli: CLIKind) {
        let defaults = UserDefaults.standard
        switch change.kind {
        case .turnFinished: guard defaults.object(forKey: "notifyTurnDone") as? Bool ?? true else { return }
        case .needsInput: guard defaults.object(forKey: "notifyNeedsInput") as? Bool ?? true else { return }
        }
        let content = UNMutableNotificationContent()
        content.title = change.kind == .needsInput ? L("\(cli.title) 在等你回答") : L("\(cli.title) 跑完了一轮")
        content.subtitle = project
        content.body = title
        content.sound = .default
        content.threadIdentifier = change.sessionID
        content.userInfo = ["sessionID": change.sessionID]
        let request = UNNotificationRequest(identifier: "\(change.sessionID)-\(change.kind)", content: content, trigger: nil)
        let firstTime = !asked
        asked = true
        Task {
            let center = UNUserNotificationCenter.current()
            if firstTime {
                guard (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) == true else { return }
            }
            try? await center.add(request)
        }
    }

    /// 主机的重新登录到期了
    public func postSignInDue(_ alias: String) {
        let content = UNMutableNotificationContent()
        content.title = L("\(alias) 该重新登录了")
        content.body = L("点这里输入重新登录命令要的东西，主机上的会话才能继续刷新。")
        content.sound = .default
        content.userInfo = ["host": alias]
        let request = UNNotificationRequest(identifier: "signin-\(alias)", content: content, trigger: nil)
        let firstTime = !asked
        asked = true
        Task {
            let center = UNUserNotificationCenter.current()
            if firstTime {
                guard (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) == true else { return }
            }
            try? await center.add(request)
        }
    }

    /// 你看过这个会话了：把它之前的通知收掉
    public func clear(sessionID: String) {
        let ids = ["\(sessionID)-turnFinished", "\(sessionID)-needsInput"]
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
    }

    nonisolated public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                                   withCompletionHandler completionHandler: @escaping () -> Void) {
        let info = response.notification.request.content.userInfo
        let id = info["sessionID"] as? String, host = info["host"] as? String
        Task { @MainActor in
            if let id { self.onOpen?(id) }
            if let host { self.onSignIn?(host) }
            completionHandler()
        }
    }

    /// app 在前台时也显示横幅（看不到那个标签时才会发）
    nonisolated public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                                   withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
