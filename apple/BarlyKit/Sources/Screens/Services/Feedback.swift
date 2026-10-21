import Foundation

/// 帮助、反馈都落在 GitHub 仓库：使用说明是 docs/ 里的 Markdown（中英两份，跟界面语言走），
/// 反馈和问题是 .github/ISSUE_TEMPLATE 里的表单，版本号预先填好
public enum AppLinks {
    public static let repository = URL(string: "https://github.com/gaoziman/Switchboard")!
    public static let releases = repository.appendingPathComponent("releases")
    static let newIssue = repository.appendingPathComponent("issues/new")

    /// 使用说明的某一节（docs/guide*.md 里 `<a id="…">` 的锚点）
    public enum GuideSection: String, Sendable {
        case start, library, terminal, status, ssh, sshStartup = "ssh-startup", forwarding, check, signIn = "sign-in"
        case appearance, shortcuts, privacy, troubleshooting
    }

    public static func guide(_ section: GuideSection? = nil, english: Bool = isEnglish) -> URL {
        let file = english ? "guide.en.md" : "guide.md"
        var c = URLComponents(url: repository.appendingPathComponent("blob/main/docs/\(file)"), resolvingAgainstBaseURL: false)!
        c.fragment = section.map { "user-content-\($0.rawValue)" }
        return c.url!
    }

    public static var isEnglish: Bool { Bundle.main.preferredLocalizations.first?.hasPrefix("en") == true }
}

/// 反馈和问题开头带上的版本，方便对上是哪个版本、哪个系统
public struct FeedbackEnvironment: Equatable, Sendable {
    public let appVersion: String
    public let macOSVersion: String

    public static var current: FeedbackEnvironment {
        let info = Bundle.main.infoDictionary ?? [:]
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return FeedbackEnvironment(appVersion: appVersion(short: info["CFBundleShortVersionString"] as? String, build: info["CFBundleVersion"] as? String),
                                   macOSVersion: "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)")
    }

    /// 「0.1.0 (202610201901)」；没有构建号或和版本号一样时只写版本号
    static func appVersion(short: String?, build: String?) -> String {
        let short = short.flatMap { $0.isEmpty ? nil : $0 }, build = build.flatMap { $0.isEmpty ? nil : $0 }
        switch (short, build) {
        case let (s?, b?) where b != s: return "\(s) (\(b))"
        case let (s?, _): return s
        default: return "development build"
        }
    }

    /// 产品名和版本号在各语言里写法一样，不翻译
    public var summary: String { "Switchboard \(appVersion) · macOS \(macOSVersion)" }
}

public enum FeedbackLinks {
    /// 报告问题：bug_report.yml 表单，版本栏预填
    public static func bugReport(_ env: FeedbackEnvironment = .current) -> URL {
        issue(template: "bug_report.yml", [("app-version", env.appVersion), ("macos-version", env.macOSVersion)])
    }

    /// 发送反馈 / 建议：feedback.yml 表单
    public static func feedback(_ env: FeedbackEnvironment = .current) -> URL {
        issue(template: "feedback.yml", [("app-version", env.appVersion), ("macos-version", env.macOSVersion)])
    }

    static func issue(template: String, _ fields: [(String, String)], title: String? = nil) -> URL {
        var c = URLComponents(url: AppLinks.newIssue, resolvingAgainstBaseURL: false)!
        c.queryItems = [URLQueryItem(name: "template", value: template)] + (title.map { [URLQueryItem(name: "title", value: $0)] } ?? [])
            + fields.map { URLQueryItem(name: $0.0, value: $0.1) }
        // URLComponents 不编码查询里的 +，GitHub 会读成空格（C++ 符号里常见）
        c.percentEncodedQuery = c.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        return c.url!
    }
}
