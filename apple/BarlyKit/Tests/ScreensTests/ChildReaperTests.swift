import Darwin
import Foundation
import Testing
@testable import Screens

@Suite("关标签后回收子进程")
struct ChildReaperTests {
    /// 用 posix_spawn 起（Foundation 的 Process 会自己回收，测不出僵尸）。
    /// 测试进程会屏蔽 / 忽略 SIGTERM，子进程默认继承：恢复成默认处理，和 SwiftTerm fork 出来的一样
    private func spawn(_ script: String) throws -> pid_t {
        var pid: pid_t = 0
        let args = ["/bin/sh", "-c", script]
        var argv = args.map { strdup($0) } + [nil]
        defer { argv.forEach { free($0) } }
        var attr: posix_spawnattr_t?
        posix_spawnattr_init(&attr)
        defer { posix_spawnattr_destroy(&attr) }
        var none = sigset_t(), term = sigset_t()
        sigemptyset(&none)
        sigemptyset(&term)
        sigaddset(&term, SIGTERM)
        posix_spawnattr_setsigmask(&attr, &none)
        posix_spawnattr_setsigdefault(&attr, &term)
        posix_spawnattr_setflags(&attr, Int16(POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF))
        let rc = posix_spawn(&pid, "/bin/sh", nil, &attr, &argv, environ)
        try #require(rc == 0)
        return pid
    }

    /// 还是我们没回收的子进程（活着或僵尸）
    private func stillOurs(_ pid: pid_t) -> Bool { kill(pid, 0) == 0 }

    private func waitReaped(_ pid: pid_t, within seconds: Double) async -> Bool {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if !stillOurs(pid) { return true }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return false
    }

    @Test("SIGTERM 之后子进程被 waitpid 回收，不留僵尸")
    func reapsAfterTerm() async throws {
        let pid = try spawn("sleep 30")
        kill(pid, SIGTERM)
        ChildReaper.reap(pid, killAfter: 5)
        #expect(await waitReaped(pid, within: 2))
    }

    @Test("不理 SIGTERM 的子进程到点补 SIGKILL，再回收")
    func killsStubbornChild() async throws {
        let pid = try spawn("trap '' TERM; while :; do sleep 0.05; done")
        try await Task.sleep(for: .milliseconds(100))   // 等 trap 装好
        kill(pid, SIGTERM)
        ChildReaper.reap(pid, killAfter: 0.3)
        #expect(await waitReaped(pid, within: 3))
    }

    @Test("已经回收过的 pid 不再碰")
    func ignoresGonePid() async throws {
        let pid = try spawn("exit 0")
        var status: Int32 = 0
        waitpid(pid, &status, 0)
        ChildReaper.reap(pid, killAfter: 0)              // 不会对一个可能被复用的 pid 发信号
        ChildReaper.reap(0, killAfter: 0)
        #expect(!stillOurs(pid))
    }
}
