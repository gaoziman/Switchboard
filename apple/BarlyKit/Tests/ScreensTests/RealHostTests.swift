import Foundation
import Testing
@testable import Screens

/// 连一台真实主机（SB_HOST=别名 时才跑）：解析 → 试连 → 镜像 → 读镜像
@Suite("真实主机", .enabled(if: ProcessInfo.processInfo.environment["SB_HOST"] != nil))
struct RealHostTests {
    @Test func probeAndMirror() async {
        let alias = ProcessInfo.processInfo.environment["SB_HOST"]!
        print("SB 解析", SSH.resolve(alias)?.summary ?? "nil")
        let t = Date()
        let probe = await SSH.probe(alias)
        print("SB 试连", probe, String(format: "%.1fs", Date().timeIntervalSince(t)))
        guard case .ok = probe else { return }
        let t2 = Date()
        let error = await SSH.mirror(alias) { d, n in print("SB 镜像进度 \(d)/\(n)") }
        print("SB 镜像", error ?? "ok", String(format: "%.1fs", Date().timeIntervalSince(t2)))
        let sessions = await SessionDiscovery.runRemote(alias)
        print("SB 远程会话", Dictionary(grouping: sessions, by: \.cli).mapValues(\.count), "项目",
              Set(sessions.map(\.projectPath)).count)
        if let s = sessions.max(by: { $0.lastActivity < $1.lastActivity }) {
            print("SB 最近", s.cli.rawValue, s.title.prefix(40), s.projectPath, s.model ?? "-")
            print("SB 预览条数", TranscriptLoader.load(s).count)
        }
    }
}

@Suite("真实主机 · 状态", .enabled(if: ProcessInfo.processInfo.environment["SB_HOST"] != nil))
struct RealRemoteStatusTests {
    @Test func snapshot() {
        let alias = ProcessInfo.processInfo.environment["SB_HOST"]!
        let t = Date()
        let snap = RemoteSessions.snapshot(alias)
        print("SB 主机状态", snap.map { "claude=\($0.claude) tmux=\($0.tmux)" } ?? "nil（ssh 失败）", String(format: "%.2fs", Date().timeIntervalSince(t)))
    }
}
