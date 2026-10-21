import Foundation
import Testing
@testable import Screens

@Suite struct FeedbackTests {
    static let header = #"{"app_name":"Switchboard","bug_type":"309","bundleID":"design.barly.switchboard.mac","app_version":"0.1.0","build_version":"202610201901","os_version":"macOS 26.1 (25B78)"}"#
    static let body = #"""
        {"exception":{"type":"EXC_BREAKPOINT","signal":"SIGTRAP"},"asi":{"libswiftCore.dylib":["Fatal error: Index out of range"]},"faultingThread":0,
         "threads":[{"queue":"com.apple.main-thread","frames":[{"imageIndex":0,"imageOffset":4096,"symbol":"WorkspaceStore.cycleTab(by:)","sourceFile":"/Users/someone/build/WorkspaceActions.swift","sourceLine":42},{"imageIndex":1,"imageOffset":255}]}],
         "usedImages":[{"name":"Switchboard"},{"name":"SwiftUI"}]}
        """#.replacingOccurrences(of: "\n", with: "")
    static let report = header + "\n" + body

    @Test func parsesCrash() throws {
        let s = try #require(CrashReportSummary(reportText: Self.report))
        #expect(s.bundleIdentifier == "design.barly.switchboard.mac")
        #expect(s.appVersion == "0.1.0 (202610201901)")
        #expect(s.exception == "EXC_BREAKPOINT (SIGTRAP)")
        #expect(s.crashMessages == ["libswiftCore.dylib: Fatal error: Index out of range"])
        #expect(s.crashedThreadQueue == "com.apple.main-thread")
        // 源文件只留文件名，不带构建机路径
        #expect(s.crashedThreadFrames == ["0  Switchboard  WorkspaceStore.cycleTab(by:) (WorkspaceActions.swift:42)", "1  SwiftUI  0xff"])
    }

    @Test func ignoresNonCrashAndBrokenFiles() {
        #expect(CrashReportSummary(reportText: Self.header.replacingOccurrences(of: "\"309\"", with: "\"288\"") + "\n{}") == nil)
        #expect(CrashReportSummary(reportText: "not json") == nil)
        // 报告本体坏了也能出摘要（只有版本）
        let s = CrashReportSummary(reportText: Self.header + "\n{broken")
        #expect(s?.exception == nil && s?.crashedThreadFrames.isEmpty == true)
    }

    @Test func issueLinkPrefillsAndStaysShort() throws {
        let s = try #require(CrashReportSummary(reportText: Self.report))
        let url = CrashReportLinks.gitHubIssue(s, fileName: "Switchboard-2026-10-20-190000.ips")
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let value = { (k: String) in items.first { $0.name == k }?.value }
        #expect(value("template") == "bug_report.yml")
        #expect(value("app-version") == "0.1.0 (202610201901)")
        #expect(value("title") == "Crash: EXC_BREAKPOINT (SIGTRAP) in Switchboard 0.1.0 (202610201901)")
        #expect(value("supporting-details")?.contains("cycleTab") == true)
        #expect(!url.absoluteString.contains("/Users/someone"))
        let long = String(repeating: "x", count: 5_000)
        #expect(CrashReportLinks.details(s, fileName: long + ".ips").count < 5_200)
    }

    @Test func plusSignsAreEncoded() {
        let url = FeedbackLinks.issue(template: "bug_report.yml", [("supporting-details", "operator+")])
        #expect(url.absoluteString.contains("operator%2B"))
    }

    @Test func versionText() {
        #expect(FeedbackEnvironment.appVersion(short: "0.1.0", build: "7") == "0.1.0 (7)")
        #expect(FeedbackEnvironment.appVersion(short: "0.1.0", build: "0.1.0") == "0.1.0")
        #expect(FeedbackEnvironment.appVersion(short: nil, build: "7") == "development build")
    }

    @Test func guideFollowsLanguage() {
        #expect(AppLinks.guide(.ssh, english: true).absoluteString.hasSuffix("docs/guide.en.md#user-content-ssh"))
        #expect(AppLinks.guide(english: false).absoluteString.hasSuffix("docs/guide.md"))
    }

    @Test func findsOnlyNewReportsOfThisApp() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("sb-crash-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let old = dir.appendingPathComponent("Switchboard-old.ips"), new = dir.appendingPathComponent("Switchboard-new.ips")
        let other = dir.appendingPathComponent("Switchboard-other.ips")
        try Self.report.write(to: old, atomically: true, encoding: .utf8)
        try Self.report.write(to: new, atomically: true, encoding: .utf8)
        try Self.report.replacingOccurrences(of: "design.barly.switchboard.mac", with: "com.example.other").write(to: other, atomically: true, encoding: .utf8)
        let t0 = Date(timeIntervalSinceNow: -3600)
        try FileManager.default.setAttributes([.modificationDate: t0.addingTimeInterval(-60)], ofItemAtPath: old.path)
        try FileManager.default.setAttributes([.modificationDate: t0.addingTimeInterval(120)], ofItemAtPath: other.path)
        try FileManager.default.setAttributes([.modificationDate: t0.addingTimeInterval(60)], ofItemAtPath: new.path)
        let finder = CrashReportFinder(directory: dir, bundleIdentifier: "design.barly.switchboard.mac")
        #expect(finder.newestReport(writtenAfter: t0)?.file.lastPathComponent == "Switchboard-new.ips")
        #expect(finder.newestReport(writtenAfter: t0.addingTimeInterval(90)) == nil)
    }

    @Test func eachCrashOfferedOnce() async throws {
        let defaults = try #require(UserDefaults(suiteName: "sb-crash-\(UUID().uuidString)"))
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("sb-crash-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let finder = CrashReportFinder(directory: dir, bundleIdentifier: "design.barly.switchboard.mac")
        let t0 = Date(timeIntervalSinceNow: -100)
        // 第一次运行：不翻旧账
        try Self.report.write(to: dir.appendingPathComponent("Switchboard-a.ips"), atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: t0.addingTimeInterval(-10)], ofItemAtPath: dir.appendingPathComponent("Switchboard-a.ips").path)
        #expect(await CrashReportCheck.newReportSinceLastLaunch(defaults: defaults, finder: finder, now: t0) == nil)
        // 之后崩了一次：下次启动问一次，再下次不问
        let f = dir.appendingPathComponent("Switchboard-b.ips")
        try Self.report.write(to: f, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.modificationDate: t0.addingTimeInterval(10)], ofItemAtPath: f.path)
        #expect(await CrashReportCheck.newReportSinceLastLaunch(defaults: defaults, finder: finder, now: t0.addingTimeInterval(20))?.file.lastPathComponent == f.lastPathComponent)
        #expect(await CrashReportCheck.newReportSinceLastLaunch(defaults: defaults, finder: finder, now: t0.addingTimeInterval(30)) == nil)
    }
}

@MainActor @Suite struct GuidanceTests {
    func store() -> WorkspaceStore { WorkspaceStore(hosts: [MockData.local], projects: [], sessions: []) }
    func defaults() -> UserDefaults { UserDefaults(suiteName: "sb-guide-\(UUID().uuidString)")! }

    @Test func firstLaunchRunsTourOnce() {
        let d = defaults(), s = store()
        s.startGuidance(defaults: d)
        #expect(s.tourStep == 1 && s.tip == nil)
        s.nextTourStep(defaults: d); s.nextTourStep(defaults: d)
        #expect(s.tourStep == 3)
        s.nextTourStep(defaults: d)
        #expect(s.tourStep == nil)
        // 下次打开：不再引导，换成贴士
        let next = store()
        next.startGuidance(defaults: d)
        #expect(next.tourStep == nil && next.tip != nil)
    }

    @Test func skipEndsTourAndTipsCanBeOff() {
        let d = defaults(), s = store()
        s.startGuidance(defaults: d)
        s.finishTour(defaults: d)
        #expect(s.tourStep == nil)
        d.set(false, forKey: "showTips")
        let next = store()
        next.startGuidance(defaults: d)
        #expect(next.tip == nil && next.tourStep == nil)
    }

    @Test func nextTipCycles() {
        let s = store()
        s.tip = Tips.all.last
        s.nextTip()
        #expect(s.tip == Tips.all.first)
        s.nextTip()
        #expect(s.tip == Tips.all[1])
    }
}
