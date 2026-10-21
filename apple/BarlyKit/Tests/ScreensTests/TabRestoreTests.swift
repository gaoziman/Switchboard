import Foundation
import Testing
@testable import Screens

/// 退出后重开恢复标签：记下标签在哪台主机；主机上的等主机读完再恢复；从库里拿掉的文件夹里开着的标签不断
@MainActor
@Suite struct TabRestoreTests {
    typealias Record = WorkspaceStore.TabRecord

    @Test func oldRecordsWithoutHostAreLocal() throws {
        let old = #"[{"cli":"claude","sessionID":"a","projectPath":"/p","title":"t","tmuxName":"claude-a","selected":true}]"#
        let records = try JSONDecoder().decode([Record].self, from: Data(old.utf8))
        #expect(records.first?.host == Host.localID)
    }

    @Test func remoteTabsAreNotLocalFolders() {
        let records = [Record(cli: "claude", sessionID: "a", projectPath: "/Users/me/p", title: "t", tmuxName: nil, selected: false),
                       Record(cli: "claude", sessionID: "b", projectPath: "/home/leo/x", title: "t", tmuxName: nil, selected: false,
                              hostID: "devbox")]
        #expect(WorkspaceStore.localFolders(of: records) == ["local:/Users/me/p"])
    }

    @Test func pendingRemoteTabsSurviveSaving() {
        let open = [Record(cli: "claude", sessionID: "a", projectPath: "/p", title: "t", tmuxName: nil, selected: true)]
        let pending = [Record(cli: "codex", sessionID: "r", projectPath: "/home/x", title: "t", tmuxName: nil, selected: false, hostID: "devbox"),
                       Record(cli: "claude", sessionID: "a", projectPath: "/p", title: "t", tmuxName: nil, selected: false, hostID: "devbox")]
        // 主机还没连上、还没恢复的远程标签也写回去，下次启动还在；已经开着的不重复
        #expect(WorkspaceStore.records(open: open, pending: pending).map(\.sessionID) == ["a", "r"])
    }

    @Test func sessionsWithOpenTabsSurviveRefresh() {
        let s1 = Session(id: "s1", cli: .claude, hostID: Host.localID, projectPath: "/gone", title: "t", lastActivity: .now, messageCount: 1)
        let s2 = Session(id: "s2", cli: .claude, hostID: Host.localID, projectPath: "/gone", title: "t", lastActivity: .now, messageCount: 1)
        let tab = TerminalTab(kind: .session(id: "s1", cli: .claude), projectPath: "/gone", title: "t", activity: .idle)
        let st = WorkspaceStore(hosts: [MockData.local], projects: [], sessions: [s1, s2],
                                tabGroups: [TabGroup(projectID: "local:/gone", name: "gone", tint: 0, tabs: [tab])])
        // 文件夹从库里拿掉后重新读到的结果里没有它们：开着标签的那个留着（断线重连、接着跑要用），没开的不留
        #expect(st.keepingOpenTabSessions([], on: Host.localID).map(\.id) == ["s1"])
        #expect(st.keepingOpenTabSessions([s1], on: Host.localID).map(\.id) == ["s1"])     // 读到了就不重复
        #expect(st.keepingOpenTabSessions([], on: "devbox").isEmpty)
    }
}
