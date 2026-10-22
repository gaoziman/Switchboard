import Foundation
import Testing
@testable import Screens

/// 状态灯只存一份：会话 ID → 状态（WorkspaceData.activity），不挂在 Session 值上，刷新换会话列表时不用搬
@MainActor
@Suite("状态只存一份")
struct ActivityStoreTests {
    private func session(_ id: String, host: String = Host.localID) -> Session {
        Session(id: id, cli: .claude, hostID: host, projectPath: "/p", title: id, lastActivity: .now, messageCount: 1)
    }

    @Test("刷新换掉一台主机的会话：还在的状态灯不丢，不在了的清掉，别的主机不动")
    func replaceKeepsActivity() {
        let st = WorkspaceStore(hosts: [MockData.local], projects: [], sessions: [session("a"), session("b"), session("r", host: "devbox")],
                                activity: ["a": .working, "b": .waitingForAnswer, "r": .idle])
        st.data.replaceSessions(on: Host.localID, with: [session("a"), session("c")])
        #expect(st.sessions.map(\.id).sorted() == ["a", "c", "r"])
        #expect(st.activity(of: st.session("a")!) == .working)
        #expect(st.activity(of: st.session("c")!) == .notRunning)
        #expect(st.data.activity["b"] == nil)
        #expect(st.activity(of: st.session("r")!) == .idle)
    }

    @Test("项目的灯取组里最急的；改了状态，项目的灯跟着变")
    func projectActivityFollows() {
        let st = WorkspaceStore(hosts: [MockData.local], projects: [Project(hostID: Host.localID, path: "/p")],
                                sessions: [session("a"), session("b")], activity: ["a": .idle])
        #expect(st.activity(of: st.projects[0]) == .idle)
        st.data.activity["b"] = .waitingForAnswer
        #expect(st.activity(of: st.projects[0]) == .waitingForAnswer)
    }
}
