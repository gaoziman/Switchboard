import Foundation
import Testing
@testable import Screens

/// 侧栏用键盘走：↑ ↓ 移动（停在会话上就预览）、→ 展开 / 进去、← 收起 / 回到上一层、Return 打开
@MainActor
@Suite("侧栏键盘导航")
struct LibraryKeyboardTests {
    /// /a 展开着（a1 a2，a1 有个子代理 a1-sub），/b 收着（b1）
    private func store() -> WorkspaceStore {
        func s(_ id: String, _ path: String, _ minutes: Double, parent: String? = nil) -> Session {
            Session(id: id, cli: .claude, hostID: Host.localID, projectPath: path, title: id,
                    lastActivity: Date.now.addingTimeInterval(-minutes * 60), messageCount: 1, parentSessionID: parent)
        }
        let st = WorkspaceStore(hosts: [MockData.local],
                                projects: [Project(hostID: Host.localID, path: "/a"), Project(hostID: Host.localID, path: "/b")],
                                sessions: [s("a1", "/a", 1), s("a2", "/a", 2), s("a1-sub", "/a", 3, parent: "a1"), s("b1", "/b", 10)])
        st.expandedProjectIDs = ["local:/a"]
        return st
    }

    @Test("可见行和侧栏画出来的一样：项目、展开项目的会话、展开的子代理")
    func rowsMirrorSidebar() {
        let st = store()
        #expect(st.libraryRows(showingSubagents: true) == [.project("local:/a"), .session("a1"), .session("a2"), .project("local:/b")])
        st.expandedSubagentParents = ["a1"]
        #expect(st.libraryRows(showingSubagents: true) == [.project("local:/a"), .session("a1"), .session("a1-sub"), .session("a2"), .project("local:/b")])
        #expect(st.libraryRows(showingSubagents: false) == [.project("local:/a"), .session("a1"), .session("a2"), .project("local:/b")])
        // 主机折叠了就只剩主机下面什么都没有；搜索时折叠不算（侧栏照样列出来）
        st.collapsedHostIDs = [Host.localID]
        #expect(st.libraryRows(showingSubagents: true).isEmpty)
    }

    @Test("↓ ↑ 一行行走，停在会话上就预览；到头不动")
    func upDown() {
        let st = store()
        #expect(st.libraryKey(.down, showingSubagents: false))        // 没有光标：从第一行开始
        #expect(st.libraryCursor == .project("local:/a"))
        st.libraryKey(.down, showingSubagents: false)
        #expect(st.libraryCursor == .session("a1") && st.previewedSession?.id == "a1")
        st.libraryKey(.down, showingSubagents: false)
        st.libraryKey(.down, showingSubagents: false)
        #expect(st.libraryCursor == .project("local:/b"))
        st.libraryKey(.down, showingSubagents: false)
        #expect(st.libraryCursor == .project("local:/b"))
        st.libraryKey(.up, showingSubagents: false)
        #expect(st.previewedSession?.id == "a2")
    }

    @Test("从正在预览的会话接着走")
    func startsFromPreview() {
        let st = store()
        st.select(st.session("a2")!)
        st.libraryKey(.up, showingSubagents: false)
        #expect(st.previewedSession?.id == "a1")
    }

    @Test("→ 展开收着的项目，展开着的进到第一个会话；← 从会话回到项目，再按收起")
    func leftRight() {
        let st = store()
        st.libraryCursor = .project("local:/b")
        st.libraryKey(.right, showingSubagents: false)
        #expect(st.expandedProjectIDs.contains("local:/b"))
        st.libraryKey(.right, showingSubagents: false)
        #expect(st.libraryCursor == .session("b1"))
        st.libraryKey(.left, showingSubagents: false)
        #expect(st.libraryCursor == .project("local:/b"))
        st.libraryKey(.left, showingSubagents: false)
        #expect(!st.expandedProjectIDs.contains("local:/b"))
    }

    @Test("→ 展开子代理，← 从子代理回到父会话")
    func subagents() {
        let st = store()
        st.libraryCursor = .session("a1")
        st.libraryKey(.right, showingSubagents: true)
        #expect(st.expandedSubagentParents.contains("a1"))
        st.libraryKey(.down, showingSubagents: true)
        #expect(st.libraryCursor == .session("a1-sub"))
        st.libraryKey(.left, showingSubagents: true)
        #expect(st.libraryCursor == .session("a1"))
    }

    @Test("Return：项目展开 / 收起，会话接着跑（开标签）")
    func open() {
        let st = store()
        st.libraryCursor = .project("local:/b")
        st.libraryKey(.open, showingSubagents: false)
        #expect(st.expandedProjectIDs.contains("local:/b"))
        st.libraryCursor = .session("a1")
        st.libraryKey(.open, showingSubagents: false)
        #expect(st.selectedTab.flatMap { st.session(for: $0) }?.id == "a1")
    }

    @Test("⇧-click 选区间也按画出来的行走：搜索时折叠的主机照样算")
    func shiftRangeWhileFiltering() {
        let st = store()
        st.collapsedHostIDs = [Host.localID]
        st.searchText = "a1"
        #expect(st.visibleSessionOrder.map(\.id).contains("a1"))
    }
}
