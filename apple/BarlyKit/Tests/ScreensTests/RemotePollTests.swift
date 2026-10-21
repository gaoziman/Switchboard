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
