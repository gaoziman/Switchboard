import Foundation
import Testing
@testable import Screens

/// SB_REAL=1：把 OpenCode / omp 的报状态扩展写到 Application Support，打印启动参数
@Suite("真实数据 · 报状态扩展", .enabled(if: ProcessInfo.processInfo.environment["SB_REAL"] == "1"))
struct RealReportTests {
    @Test func writeExtensions() {
        for cli in [CLIKind.opencode, .omp] {
            let a = LiveReporting.launchAdditions(for: cli)
            print("SB", cli.rawValue, a?.arguments ?? [], a?.environment ?? [:])
        }
    }
}
