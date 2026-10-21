import Foundation

// 读 macOS 的崩溃报告（~/Library/Logs/DiagnosticReports/*.ips）。
// 格式解析和摘要的写法改编自 JustSessions（MIT，© Zichao Yang）。

/// 一次崩溃的摘要：版本、异常、崩溃库留下的话、崩溃线程的调用栈。不含 Mac 上的路径等个人信息；整份报告留在磁盘上，需要时附上
public struct CrashReportSummary: Equatable, Sendable {
    public let bundleIdentifier: String
    public let appVersion: String
    public let macOSVersion: String
    public let exception: String?
    public let crashMessages: [String]
    public let crashedThreadQueue: String?
    public let crashedThreadFrames: [String]
    public let lastExceptionFrames: [String]

    static let maxFrames = 16, maxFrameLength = 160, maxMessages = 4, maxMessageLength = 300

    /// 不是崩溃（309）或没有 bundle ID 就是 nil。第一行是报告头 JSON，后面是报告本体 JSON；字段都可选，macOS 改名也只丢那一项
    public init?(reportText: String) {
        let parts = reportText.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        guard let headerLine = parts.first,
              let header = try? JSONDecoder().decode(Header.self, from: Data(headerLine.utf8)),
              header.bugType == "309", let bundle = header.bundleIdentifier, !bundle.isEmpty else { return nil }
        let body = parts.count > 1 ? try? JSONDecoder().decode(Body.self, from: Data(parts[1].utf8)) : nil
        bundleIdentifier = bundle
        appVersion = FeedbackEnvironment.appVersion(short: header.appVersion, build: header.buildVersion)
        macOSVersion = header.macOSVersion.flatMap { $0.isEmpty ? nil : $0 } ?? "macOS (unknown version)"
        exception = body?.exception.flatMap(Self.describe)
        crashMessages = (body?.asi ?? [:]).sorted { $0.key < $1.key }
            .flatMap { lib, messages in messages.map { "\(lib): \($0)" } }
            .prefix(Self.maxMessages).map { Self.shortened($0, Self.maxMessageLength) }
        let images = body?.usedImages ?? []
        let thread = body.flatMap { b in b.faultingThread.flatMap { i in b.threads.flatMap { $0.indices.contains(i) ? $0[i] : nil } } }
        crashedThreadQueue = thread?.queue
        crashedThreadFrames = Self.describe(thread?.frames ?? [], images)
        lastExceptionFrames = Self.describe(body?.lastExceptionBacktrace ?? [], images)
    }

    private static func describe(_ e: Exception) -> String? {
        switch (e.type, e.signal) {
        case let (t?, s?): "\(t) (\(s))"
        case let (t?, nil): t
        case let (nil, s?): s
        default: nil
        }
    }

    /// 源文件只留文件名：构建机上的目录和崩溃无关
    private static func describe(_ frames: [Frame], _ images: [Image]) -> [String] {
        frames.prefix(maxFrames).enumerated().map { i, f in
            let image = f.imageIndex.flatMap { images.indices.contains($0) ? images[$0].name : nil } ?? "???"
            var line = "\(i)  \(image)  " + (f.symbol ?? "0x" + String(f.imageOffset ?? 0, radix: 16))
            if let file = f.sourceFile, let n = f.sourceLine { line += " (\(URL(fileURLWithPath: file).lastPathComponent):\(n))" }
            return shortened(line, maxFrameLength)
        }
    }

    private static func shortened(_ s: String, _ limit: Int) -> String {
        let one = s.split(whereSeparator: \.isNewline).joined(separator: " ")
        return one.count > limit ? one.prefix(limit - 1) + "…" : one
    }

    // MARK: .ips 格式

    struct Header: Decodable {
        let bugType: String?, bundleIdentifier: String?, appVersion: String?, buildVersion: String?, macOSVersion: String?
        enum CodingKeys: String, CodingKey {
            case bugType = "bug_type", bundleIdentifier = "bundleID", appVersion = "app_version", buildVersion = "build_version", macOSVersion = "os_version"
        }
    }
    struct Body: Decodable {
        let exception: Exception?, asi: [String: [String]]?, faultingThread: Int?, threads: [Thread]?, usedImages: [Image]?, lastExceptionBacktrace: [Frame]?
    }
    struct Exception: Decodable { let type: String?, signal: String? }
    struct Thread: Decodable { let queue: String?, frames: [Frame]? }
    struct Frame: Decodable { let imageIndex: Int?, imageOffset: Int?, symbol: String?, sourceFile: String?, sourceLine: Int? }
    struct Image: Decodable { let name: String? }
}

public struct FoundCrashReport: Sendable {
    public let file: URL
    public let summary: CrashReportSummary
}

/// 找上次检查之后这个 app 的最新一份崩溃报告
public struct CrashReportFinder: Sendable {
    public var directory: URL
    public var bundleIdentifier: String

    public init(directory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/DiagnosticReports"),
                bundleIdentifier: String = Bundle.main.bundleIdentifier ?? "") {
        self.directory = directory
        self.bundleIdentifier = bundleIdentifier
    }

    public func newestReport(writtenAfter date: Date) -> FoundCrashReport? {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        let candidates = files
            .filter { $0.pathExtension == "ips" && $0.lastPathComponent.hasPrefix("Switchboard") }
            .compactMap { url -> (URL, Date)? in
                guard let d = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate, d > date else { return nil }
                return (url, d)
            }
            .sorted { $0.1 > $1.1 }
        for (url, _) in candidates {
            guard let text = try? String(contentsOf: url, encoding: .utf8), let s = CrashReportSummary(reportText: text),
                  s.bundleIdentifier == bundleIdentifier else { continue }
            return FoundCrashReport(file: url, summary: s)
        }
        return nil
    }
}

public enum CrashReportLinks {
    /// 链接要在 GitHub 接受的长度以内：详情截到这么长，后面的栈帧先丢；整份报告可以作为附件拖进去
    static let maxDetails = 2_500

    /// 报告问题表单，崩溃摘要预填。文字保持英文：给维护者看的，和崩溃报告本身一样
    public static func gitHubIssue(_ summary: CrashReportSummary, fileName: String) -> URL {
        FeedbackLinks.issue(template: "bug_report.yml", [
            ("app-version", summary.appVersion),
            ("macos-version", summary.macOSVersion),
            ("actual-behavior", "Switchboard quit unexpectedly."),
            ("supporting-details", details(summary, fileName: fileName)),
        ], title: "Crash: \(summary.exception ?? "unknown exception") in Switchboard \(summary.appVersion)")
    }

    static func details(_ s: CrashReportSummary, fileName: String) -> String {
        var lines = ["Exception: \(s.exception ?? "unknown")"] + s.crashMessages
        if !s.lastExceptionFrames.isEmpty { lines += ["", "Last exception backtrace:"] + s.lastExceptionFrames }
        if !s.crashedThreadFrames.isEmpty { lines += ["", "Crashed thread\(s.crashedThreadQueue.map { " (\($0))" } ?? ""):"] + s.crashedThreadFrames }
        let heading = "Crash report \(fileName), in ~/Library/Logs/DiagnosticReports"
        func text(_ l: [String]) -> String { "\(heading)\n\n```\n\(l.joined(separator: "\n"))\n```" }
        var cut = false
        while lines.count > 1, text(lines + (cut ? ["…"] : [])).count > maxDetails { lines.removeLast(); cut = true }
        return text(lines + (cut ? ["…"] : []))
    }
}

/// 启动时：上次启动之后有崩溃，就问一次要不要报告。先记下这次的时间再读文件，每份崩溃只问一次
public enum CrashReportCheck {
    static let lastCheckKey = "crashReportsLastCheck"

    public static func newReportSinceLastLaunch(defaults: UserDefaults = .standard, finder: CrashReportFinder = CrashReportFinder(),
                                                now: Date = .now) async -> FoundCrashReport? {
        // 第一次运行不翻旧账
        let last = defaults.object(forKey: lastCheckKey) as? Date ?? now
        defaults.set(now, forKey: lastCheckKey)
        return await Task.detached(priority: .utility) { finder.newestReport(writtenAfter: last) }.value
    }
}
