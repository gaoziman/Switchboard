import Darwin
import Foundation
import SwiftTerm

/// 回收我们起的子进程（tmux 客户端、ssh）。SwiftTerm 1.20 的 `LocalProcess.terminate()` 发完 SIGTERM 就把子进程监听取消了，
/// 而 waitpid 只在那个监听的回调里调：关标签、关窗口、取消 Connect… 都会留下僵尸，app 退出前一直占着进程表
enum ChildReaper {
    /// 代替 `process.terminate()`
    static func terminate(_ process: LocalProcess) {
        let pid = process.shellPid
        process.terminate()
        reap(pid)
    }

    /// 在后台等它退出并回收；killAfter 秒还没退就补 SIGKILL。
    /// 只在 waitpid 说它还是我们没回收的子进程时才发信号：已经回收过的 pid 可能被别的进程复用了
    static func reap(_ pid: pid_t, killAfter: TimeInterval = 3) {
        guard pid > 0 else { return }
        let deadline = Date().addingTimeInterval(killAfter)
        var killed = false
        func poll() {
            var status: Int32 = 0
            let r = waitpid(pid, &status, WNOHANG)
            guard r == 0 else { return }               // 回收了（r == pid），或者不是 / 不再是我们的子进程（-1）
            if !killed, Date() >= deadline { kill(pid, SIGKILL); killed = true }
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.1, execute: poll)
        }
        DispatchQueue.global(qos: .utility).async(execute: poll)
    }
}
