import Foundation
import Testing
@testable import Screens

/// 弹窗（重命名、删除确认、主机工具、登录、关闭标签）：同一时刻只有一个，由 store.presentation 说了算
@MainActor
@Suite("弹窗")
struct PresentationTests {
    /// 一台不会真的连上的主机（关闭行为没设 = 要问）
    private let host = "sb-test-\(UUID().uuidString.prefix(8))"

    private func store() -> (WorkspaceStore, TerminalTab, TerminalTab) {
        let a = TerminalTab(kind: .session(id: "r1", cli: .claude), hostID: host, projectPath: "/srv", title: "a", activity: .working)
        let b = TerminalTab(kind: .session(id: "r2", cli: .claude), hostID: host, projectPath: "/srv", title: "b", activity: .working)
        let sessions = ["r1", "r2"].map {
            Session(id: $0, cli: .claude, hostID: host, projectPath: "/srv", title: $0, lastActivity: .now, messageCount: 1)
        }
        let st = WorkspaceStore(hosts: [MockData.local], projects: [], sessions: sessions,
                                tabGroups: [TabGroup(projectID: "\(host):/srv", name: "srv", tint: 0, tabs: [a, b])])
        for t in [a, b] {
            st.launches[t.id] = .remote(tabID: t.id, alias: host, command: ["claude"], directory: "/srv", tmuxName: "claude-\(t.title)")
        }
        return (st, a, b)
    }

    @Test("CLI 还在跑、没设关闭行为：关标签先问；选了以后弹窗收起")
    func closeAsks() {
        let (st, a, _) = store()
        st.requestClose(a)
        #expect(st.presentation == .closeTab(a))
        st.close(a, keepRunning: true)
        #expect(st.presentation == nil)
    }

    @Test("关别的标签（批量删除、移除主机时）不收起不相干的弹窗")
    func closingOtherTabKeepsDialog() {
        let (st, a, b) = store()
        st.presentation = .hostSheet(.check(host))
        st.close(b, keepRunning: true)
        #expect(st.presentation == .hostSheet(.check(host)))
        st.requestClose(a)
        st.close(b, keepRunning: true)                       // 问的是 a，关掉的是 b：还在问 a
        #expect(st.presentation == .closeTab(a))
    }

    @Test("新弹窗顶掉旧的（比如点了「该重新登录了」的通知）")
    func newReplacesOld() {
        let (st, _, _) = store()
        st.presentation = .renameSession(st.session("r1")!)
        st.presentation = .hostSheet(.signIn(host))
        #expect(st.presentation == .hostSheet(.signIn(host)))
        #expect(st.presentation?.renamingSession == nil)
    }
}
