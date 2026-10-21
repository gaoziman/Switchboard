import Foundation
import Testing
@testable import Screens

/// 读这台 Mac 上的真实会话（只在 SB_REAL=1 时跑，CI 和别人的机器上跳过）
@Suite("真实数据", .enabled(if: ProcessInfo.processInfo.environment["SB_REAL"] == "1"))
struct RealDataTests {
    @Test func discoverAndPreview() async {
        let result = await SessionDiscovery.run()
        let byCLI = Dictionary(grouping: result.sessions, by: \.cli).mapValues(\.count)
        print("SB 会话", byCLI.map { "\($0.key.rawValue)=\($0.value)" }.sorted(), "项目", result.projects.count,
              "耗时", String(format: "%.2fs", result.elapsed), "已装", result.installed.map(\.rawValue))
        #expect(!result.sessions.isEmpty)
        for cli in CLIKind.allCases {
            guard let s = result.sessions.filter({ $0.cli == cli && $0.parentSessionID == nil }).max(by: { $0.lastActivity < $1.lastActivity }) else { continue }
            let entries = TranscriptLoader.load(s)
            let kinds = Dictionary(grouping: entries) { e -> String in
                switch e.kind { case .user: "user"; case .assistant: "assistant"; case .tools: "tools"; case .code: "code"; case .image: "image" }
            }.mapValues(\.count)
            print("SB", cli.rawValue, "|", s.title.prefix(40), "|", s.projectPath, "|", s.model ?? "-", "|", kinds.sorted { $0.key < $1.key })
        }
        let again = await SessionDiscovery.run()
        print("SB 第二次（走缓存）耗时", String(format: "%.2fs", again.elapsed))
    }
}

@Suite("真实数据 · 全文搜索", .enabled(if: ProcessInfo.processInfo.environment["SB_REAL"] == "1"))
struct RealSearchTests {
    @Test func indexAndSearch() async {
        let sessions = await SessionDiscovery.run().sessions.filter { $0.parentSessionID == nil }
        let start = Date()
        let reread = await MessageIndex.shared.update(sessions) { _, _ in }
        print("SB 建索引", sessions.count, "个会话，重读", reread, "个，用时", String(format: "%.1fs", Date().timeIntervalSince(start)))
        for q in ["tmux", "灰度", "SwiftTerm", "计费"] {
            let t = Date()
            let hits = await MessageIndex.shared.search(q, in: sessions)
            print("SB 搜「\(q)」", hits.count, "个命中", String(format: "%.0fms", Date().timeIntervalSince(t) * 1000), "|", hits.values.first?.prefix(60) ?? "")
        }
        let t2 = Date()
        let again = await MessageIndex.shared.update(sessions) { _, _ in }
        print("SB 第二次更新重读", again, "个，用时", String(format: "%.2fs", Date().timeIntervalSince(t2)))
    }
}
