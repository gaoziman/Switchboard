import Foundation
import Testing
@testable import Screens

@MainActor
@Suite("会话库补全")
struct LibraryNavigationTests {
    private func store(_ n: Int = 5) -> WorkspaceStore {
        let sessions = (0..<n).map { i in
            Session(id: "s\(i)", cli: .claude, hostID: Host.localID, projectPath: "/p", title: "会话 \(i)",
                    lastActivity: Date.now.addingTimeInterval(Double(-i) * 60), messageCount: 1)
        }
        let s = WorkspaceStore(hosts: [MockData.local], projects: [Project(hostID: Host.localID, path: "/p")], sessions: sessions)
        s.expandedProjectIDs = ["local:/p"]
        return s
    }

    @Test("⌘-click 加减、⇧-click 选区间、普通单击清空")
    func multiSelect() {
        let s = store()
        s.click(s.session("s1")!, command: false, shift: false)
        s.click(s.session("s3")!, command: false, shift: true)
        #expect(s.selectedSessionIDs == ["s1", "s2", "s3"])
        s.click(s.session("s2")!, command: true, shift: false)
        #expect(s.selectedSessionIDs == ["s1", "s3"])
        s.click(s.session("s4")!, command: false, shift: false)
        #expect(s.selectedSessionIDs.isEmpty)
        #expect(s.previewedSession?.id == "s4")
    }

    @Test("后退 / 前进，跳过已经关掉的标签")
    func history() {
        let s = store()
        s.select(s.session("s0")!)
        s.select(s.session("s1")!)
        s.select(s.session("s2")!)
        s.goBack()
        #expect(s.previewedSession?.id == "s1")
        s.goBack()
        #expect(s.previewedSession?.id == "s0")
        s.goForward()
        #expect(s.previewedSession?.id == "s1")
        s.select(s.session("s4")!)          // 新的跳转清掉前进历史
        #expect(!s.canGoForward)
        s.backStack.append(.tab(UUID()))    // 一个已经关掉的标签
        s.goBack()
        #expect(s.previewedSession?.id == "s1")
    }

    @Test("拖动排序置顶；拖没置顶的过来顺便置顶")
    func pinReorder() {
        let s = store()
        s.togglePin(s.session("s0")!)
        s.togglePin(s.session("s1")!)
        s.movePinnedSession("s1", before: "s0")
        #expect(s.library.pinnedSessions == ["s1", "s0"])
        s.movePinnedSession("s3", before: "s0")
        #expect(s.library.pinnedSessions == ["s1", "s3", "s0"])
        #expect(s.session("s3")?.isPinned == true)
    }

    @Test("子代理挂在发起它的会话下面，不单独列出")
    func subagents() {
        let s = store(2)
        s.sessions.append(Session(id: "agent-1", cli: .claude, hostID: Host.localID, projectPath: "/p", title: "子任务",
                                  lastActivity: .now, messageCount: 1, parentSessionID: "s0"))
        #expect(s.subagents(of: s.session("s0")!).map(\.id) == ["agent-1"])
        #expect(!s.sessions(in: s.projects[0]).contains { $0.id == "agent-1" })
        #expect(s.sessionCount(of: s.projects[0]) == 2)
    }

    @Test("导出 Markdown")
    func export() {
        let session = Session(id: "abc", cli: .codex, hostID: Host.localID, projectPath: "/p", title: "修登录", model: "gpt-6.1 · high",
                              lastActivity: .now, messageCount: 2)
        let md = TranscriptExport.markdown(session, project: nil, entries: [
            TranscriptEntry(id: 0, kind: .user("登录页报 500"), time: .now),
            TranscriptEntry(id: 1, kind: .tools([ToolCall(name: "Read", arg: "a"), ToolCall(name: "Bash", arg: "b")]), time: .now),
            TranscriptEntry(id: 2, kind: .assistant("修好了。"), time: .now),
        ])
        #expect(md.hasPrefix("# 修登录"))
        #expect(md.contains("Codex · /p · gpt-6.1 · high · 会话 abc"))
        #expect(md.contains("## 你\n\n登录页报 500"))
        #expect(md.contains("*2 次工具调用：Read a · Bash b*"))
    }

    @Test("旧版本的 library.json 少字段也能读，置顶不会丢")
    func oldLibraryFile() throws {
        let old = #"{"pinnedSessions":["x"],"names":{"x":"名字"},"archivedSessions":[],"archivedProjects":[],"pinnedProjects":[],"commands":{}}"#
        let state = try JSONDecoder().decode(LibraryState.self, from: Data(old.utf8))
        #expect(state.pinnedSessions == ["x"])
        #expect(state.names["x"] == "名字")
        #expect(state.addedProjects.isEmpty)
    }

    @Test("手动加的项目文件夹没有会话也列出")
    func addedProject() {
        let s = store(1)
        s.addProject("/empty/folder")
        #expect(s.projects(on: Host.localID).contains { $0.path == "/empty/folder" })
    }
}
