import Foundation
import Testing
@testable import Screens

/// 侧栏和轮询查会话走按项目 / 按 ID 分好的索引：结果要和逐个过滤一样，会话一变就跟着变
@MainActor
@Suite struct SessionIndexTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func store() -> WorkspaceStore {
        func s(_ id: String, _ path: String, _ age: TimeInterval, parent: String? = nil, archived: Bool = false) -> Session {
            Session(id: id, cli: .claude, hostID: Host.localID, projectPath: path, title: id, lastActivity: now.addingTimeInterval(-age),
                    messageCount: 1, parentSessionID: parent, isArchived: archived)
        }
        return WorkspaceStore(hosts: [MockData.local],
                              projects: [Project(hostID: Host.localID, path: "/a"), Project(hostID: Host.localID, path: "/b")],
                              sessions: [s("a1", "/a", 100), s("a2", "/a", 10), s("a3", "/a", 5, parent: "a2"),
                                         s("a4", "/a", 1, archived: true), s("b1", "/b", 50)],
                              activity: ["a2": .working, "b1": .waitingForAnswer])
    }

    @Test func perProjectFigures() throws {
        let st = store()
        let a = try #require(st.projects.first { $0.path == "/a" })
        let b = try #require(st.projects.first { $0.path == "/b" })
        #expect(st.lastActivity(of: a) == now.addingTimeInterval(-1))       // 归档、子代理也算最近活动（和原来一样）
        #expect(st.sessionCount(of: a) == 2)                                // 不算子代理和归档
        #expect(st.activity(of: a) == .working)
        #expect(st.activity(of: b) == .waitingForAnswer)
        #expect(st.sessions(in: a).map(\.id) == ["a2", "a1"])
        #expect(st.subagents(of: try #require(st.session("a2"))).map(\.id) == ["a3"])
        #expect(st.projects(on: Host.localID).map(\.path) == ["/a", "/b"])
        #expect(st.session("nope") == nil)
    }

    @Test func followsChanges() throws {
        let st = store()
        let a = try #require(st.projects.first { $0.path == "/a" })
        let b = try #require(st.projects.first { $0.path == "/b" })
        _ = st.activity(of: a)                                              // 先建好索引
        st.data.activity["a2"] = nil                                        // 状态变了，项目的灯跟着变
        #expect(st.activity(of: a) == .notRunning)
        st.sessions.append(Session(id: "b2", cli: .codex, hostID: Host.localID, projectPath: "/b", title: "b2", lastActivity: now,
                                   messageCount: 1))
        #expect(st.session("b2")?.cli == .codex)
        #expect(st.sessionCount(of: b) == 2)
        #expect(st.projects(on: Host.localID).map(\.path) == ["/b", "/a"])   // b 现在最近
        st.sessions.removeAll { $0.id == "a1" }
        #expect(st.session("a1") == nil)
        #expect(st.sessions(in: a).map(\.id) == ["a2"])
    }
}
