import Foundation
import Testing
@testable import Screens

/// 切到一个标签：侧栏展开它所在的主机和项目、放宽「再显示」让它露出来、滚到那一行
@MainActor
@Suite("切标签时侧栏定位")
struct RevealTabTests {
    private func session(_ id: String, project: String, ago: Double) -> Session {
        Session(id: id, cli: .claude, hostID: Host.localID, projectPath: project, title: id,
                lastActivity: Date(timeIntervalSinceNow: -ago), messageCount: 1)
    }

    private func setup() -> (WorkspaceStore, TerminalTab, TerminalTab) {
        // /b 有 15 个会话，按时间排 old 是最旧的那个（排在第 15，默认只显示 10 个）
        var sessions = (0..<14).map { session("b\($0)", project: "/b", ago: Double($0)) }
        sessions.append(session("old", project: "/b", ago: 1000))
        sessions.append(session("a1", project: "/a", ago: 1))
        let tab = TerminalTab(kind: .session(id: "old", cli: .claude), projectPath: "/b", title: "old", activity: .idle)
        let plain = TerminalTab(kind: .plainTerminal, projectPath: "/a", title: "zsh", activity: .idle)
        let st = WorkspaceStore(hosts: [MockData.local],
                                projects: [Project(hostID: Host.localID, path: "/a"), Project(hostID: Host.localID, path: "/b")],
                                sessions: sessions,
                                tabGroups: [TabGroup(projectID: ProjectID(host: Host.localID, path: "/b"), name: "b", tint: 0, tabs: [tab]),
                                            TabGroup(projectID: ProjectID(host: Host.localID, path: "/a"), name: "a", tint: 1, tabs: [plain])])
        return (st, tab, plain)
    }

    @Test("会话标签：展开项目和主机，露出被「再显示」藏起来的那一行，滚过去；别的项目不收起")
    func revealsSession() {
        let (st, tab, _) = setup()
        let a = ProjectID(host: Host.localID, path: "/a"), b = ProjectID(host: Host.localID, path: "/b")
        st.expandedProjectIDs = [a]
        st.collapsedHostIDs = [Host.localID]

        st.selection = .tab(tab.id)

        #expect(st.expandedProjectIDs == [a, b])
        #expect(!st.collapsedHostIDs.contains(Host.localID))
        let project = st.projects.first { $0.id == b }!
        #expect(st.visibleSessions(in: project).shown.contains { $0.id == "old" })
        #expect(st.revealedRow == .session("old"))
    }

    @Test("没对上会话的标签（普通终端）：展开并滚到它的项目行")
    func revealsProjectForPlainTerminal() {
        let (st, _, plain) = setup()
        st.selection = .tab(plain.id)
        #expect(st.expandedProjectIDs.contains(ProjectID(host: Host.localID, path: "/a")))
        #expect(st.revealedRow == .project(ProjectID(host: Host.localID, path: "/a")))
    }

    @Test("预览会话（从侧栏点的）不动侧栏")
    func previewDoesNotReveal() {
        let (st, _, _) = setup()
        st.selection = .preview(sessionID: "old")
        #expect(st.expandedProjectIDs.isEmpty)
        #expect(st.revealedRow == nil)
    }
}
