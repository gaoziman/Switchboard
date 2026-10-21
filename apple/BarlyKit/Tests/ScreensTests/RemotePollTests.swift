import Foundation
import Testing
@testable import Screens

/// 主机状态轮询：同一台主机不叠着问；连续问不到就别再显示旧状态
@MainActor
@Suite struct RemotePollTests {
    private func store() -> WorkspaceStore {
        WorkspaceStore(hosts: [MockData.local], projects: [], sessions: [])
    }

    @Test func oneJobPerHostAtATime() {
        let st = store()
        #expect(st.beginHostJob(.poll, "devbox"))
        #expect(!st.beginHostJob(.poll, "devbox"))        // 上一次还没回来：这次跳过
        #expect(st.beginHostJob(.refresh, "devbox"))      // 刷新和轮询各管各的
        #expect(st.beginHostJob(.poll, "other"))
        st.endHostJob(.poll, "devbox")
        #expect(st.beginHostJob(.poll, "devbox"))
    }

    @Test func staleSnapshotDroppedAfterRepeatedFailures() {
        let st = store()
        var snap = RemoteSessions.Snapshot()
        snap.claude["c1"] = .working
        st.recordSnapshot(snap, for: "devbox")
        st.recordSnapshot(nil, for: "devbox")
        st.recordSnapshot(nil, for: "devbox")
        #expect(st.remoteSnapshots["devbox"]?.claude["c1"] == .working)   // 偶尔一两次没回来：先留着，灯不闪
        st.recordSnapshot(nil, for: "devbox")
        #expect(st.remoteSnapshots["devbox"] == nil)                      // 连续三次：不再当它还在跑
        st.recordSnapshot(snap, for: "devbox")
        st.recordSnapshot(nil, for: "devbox")
        #expect(st.remoteSnapshots["devbox"] != nil)                      // 成功一次就重新计数
    }

    @Test("主机连续问不到：越隔越久再问（10 秒起翻倍，最多 5 分钟），问到一次恢复每 5 秒")
    func failingHostBacksOff() {
        let st = store()
        let t0 = Date()
        #expect(st.shouldPoll("devbox", now: t0))
        st.recordSnapshot(nil, for: "devbox", now: t0)
        #expect(!st.shouldPoll("devbox", now: t0.addingTimeInterval(9)))
        #expect(st.shouldPoll("devbox", now: t0.addingTimeInterval(10)))
        st.recordSnapshot(nil, for: "devbox", now: t0)
        #expect(!st.shouldPoll("devbox", now: t0.addingTimeInterval(19)))
        #expect(WorkspaceStore.pollBackoff(failures: 3) == 40)
        #expect(WorkspaceStore.pollBackoff(failures: 20) == 300)
        st.recordSnapshot(RemoteSessions.Snapshot(), for: "devbox", now: t0)
        #expect(st.shouldPoll("devbox", now: t0))
    }

    @Test("Mac 唤醒、回到 app：退避清零，马上再问")
    func wakeResetsBackoff() {
        let st = store()
        let t0 = Date()
        for _ in 0..<5 { st.recordSnapshot(nil, for: "devbox", now: t0) }
        #expect(!st.shouldPoll("devbox", now: t0.addingTimeInterval(60)))
        st.retryReconnects()
        #expect(st.shouldPoll("devbox", now: t0))
    }

    @Test("远程新会话等认领：刚开时每 10 秒刷新那台主机，等久了放慢（一直不打字就别一直整机镜像）")
    func claimRefreshSlowsDown() {
        #expect(WorkspaceStore.claimRefreshInterval(age: 5) == 10)
        #expect(WorkspaceStore.claimRefreshInterval(age: 59) == 10)
        #expect(WorkspaceStore.claimRefreshInterval(age: 120) == 30)
        #expect(WorkspaceStore.claimRefreshInterval(age: 3600) == 120)
    }

    @Test func blockingWorkRunsOffTheConcurrencyPool() async {
        let value = await SSH.offPool { 42 }
        #expect(value == 42)
    }
}

@MainActor
@Suite struct RefreshQueueTests {
    @Test("正在刷新时再要刷新：记下补读一次，等读完才返回（不再直接丢掉）")
    func refreshDuringRefreshQueuesAndWaits() async throws {
        let st = WorkspaceStore(hosts: [MockData.local], projects: [], sessions: [])
        st.data.isRefreshing = true                       // 假装别的窗口正在读
        let waiter = Task { await st.refresh() }
        try await Task.sleep(for: .milliseconds(120))
        #expect(st.data.refreshQueued)
        st.data.isRefreshing = false                      // 那次读完了
        await waiter.value                                // 这时才返回
        #expect(st.data.isRefreshing == false)
    }
}
