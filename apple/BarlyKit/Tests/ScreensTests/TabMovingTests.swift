import Foundation
import Testing
@testable import Screens

@MainActor @Suite struct TabMovingTests {
    func tab(_ path: String, _ title: String) -> TerminalTab {
        TerminalTab(kind: .plainTerminal, projectPath: path, title: title, activity: .idle)
    }

    func store(_ tabs: [TerminalTab]) -> WorkspaceStore {
        let groups = Dictionary(grouping: tabs, by: \.projectID).map { TabGroup(projectID: $0.key, name: $0.key, tint: 0, tabs: $0.value) }
            .sorted { $0.projectID < $1.projectID }
        let s = WorkspaceStore(hosts: [MockData.local], projects: [], sessions: [], tabGroups: groups)
        s.selection = tabs.first.map { .tab($0.id) }
        return s
    }

    @Test func reorderWithinGroupOnly() {
        let a = tab("/p", "a"), b = tab("/p", "b"), c = tab("/p", "c"), other = tab("/q", "x")
        let s = store([a, b, c, other])
        s.moveTab(c.id, before: a.id)
        #expect(s.tabGroups.first { $0.projectID == a.projectID }?.tabs.map(\.title) == ["c", "a", "b"])
        s.moveTab(c.id, before: nil)
        #expect(s.tabGroups.first { $0.projectID == a.projectID }?.tabs.map(\.title) == ["a", "b", "c"])
        // 不能拖进别的项目的组
        s.moveTab(other.id, before: a.id)
        #expect(s.tabGroups.first { $0.projectID == a.projectID }?.tabs.count == 3)
    }

    @Test func moveBetweenWindowsKeepsState() {
        let a = tab("/p", "a"), b = tab("/p", "b")
        let left = store([a, b]), right = store([tab("/q", "y")])
        left.tabBanners[a.id] = .exited(code: 0)
        left.terminalTitles[a.id] = "⠋ working"
        left.moveTab(a.id, to: right)
        #expect(left.allTabs.map(\.title) == ["b"])
        #expect(left.selection == .tab(b.id))          // 选中的被搬走，选旁边那个
        #expect(right.allTabs.map(\.title).sorted() == ["a", "y"])
        #expect(right.selection == .tab(a.id))
        #expect(right.tabBanners[a.id] != nil && left.tabBanners[a.id] == nil)
        #expect(right.terminalTitles[a.id] == "⠋ working")
    }

    @Test func lastTabLeavesEmptyWindowAndSplitClears() {
        let a = tab("/p", "a"), b = tab("/p", "b")
        let s = store([a, b])
        s.split = SplitState(left: a.id, right: b.id)
        let t = s.detachTab(b.id)
        #expect(t?.tab.id == b.id && s.split == nil)
        _ = s.detachTab(a.id)
        #expect(s.allTabs.isEmpty && s.selection == nil)
    }

    @Test func tearOffWaitsForNewWindow() {
        let a = tab("/p", "a")
        let s = store([a])
        #expect(s.moveTabToNewWindow(a.id))
        #expect(WorkspaceWindows.pendingTransfer?.tab.id == a.id)
        let fresh = WorkspaceStore(hosts: [MockData.local], projects: [], sessions: [])
        if let t = WorkspaceWindows.pendingTransfer { WorkspaceWindows.pendingTransfer = nil; fresh.attachTab(t) }
        #expect(fresh.allTabs.map(\.id) == [a.id] && fresh.selection == .tab(a.id))
    }
}
