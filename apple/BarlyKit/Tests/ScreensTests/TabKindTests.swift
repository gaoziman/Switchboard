import Foundation
import Testing
@testable import Screens

/// 标签是什么：认到了会话 / CLI 开着但还没对上会话文件（新建、分叉）/ 普通终端
@MainActor
@Suite("标签类型")
struct TabKindTests {
    @Test("还没对上会话的 CLI 标签：知道是哪个 CLI，没有会话 ID")
    func pendingHasCLIButNoSession() {
        #expect(TerminalTab.Kind.pending(cli: .codex).cli == .codex)
        #expect(TerminalTab.Kind.pending(cli: .codex).sessionID == nil)
        #expect(TerminalTab.Kind.session(id: "s1", cli: .claude).sessionID == "s1")
        #expect(TerminalTab.Kind.plainTerminal.cli == nil)
    }

    @Test("标签记录只记认到了会话的（新建、分叉的下次启动接不回来）")
    func pendingTabsNotSaved() {
        let session = Session(id: "s1", cli: .claude, hostID: Host.localID, projectPath: "/p", title: "s1", lastActivity: .now, messageCount: 1)
        let tabs = [TerminalTab(kind: .session(id: "s1", cli: .claude), projectPath: "/p", title: "a", activity: .idle),
                    TerminalTab(kind: .pending(cli: .codex), projectPath: "/p", title: "新的 Codex 会话", activity: .working),
                    TerminalTab(kind: .plainTerminal, projectPath: "/p", title: "zsh", activity: .idle)]
        let p = WorkspacePersistence.memory()
        let st = WorkspaceStore(hosts: [MockData.local], projects: [Project(hostID: Host.localID, path: "/p")], sessions: [session],
                                tabGroups: [TabGroup(projectID: "local:/p", name: "p", tint: 0, tabs: tabs)], persistence: p)
        st.saveTabs()
        #expect(p.loadTabs().map(\.sessionID) == ["s1"])
    }
}
