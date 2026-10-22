import Foundation
import Testing
@testable import Screens

@Suite("启动命令校验")
struct CommandValidationTests {
    @Test("空命令 = 回到默认，不算错")
    func empty() { #expect(NewSessionDraft.commandProblem("   ") == nil) }

    @Test("带参数和引号的正常命令通过")
    func normal() {
        #expect(NewSessionDraft.commandProblem(#"~/.toolbox/bin/claude --aws-profile "dev" --dangerously-skip-permissions"#) == nil)
        #expect(NewSessionDraft.commandProblem("FOO=1 codex --dangerously-bypass-approvals-and-sandbox") == nil)
    }

    @Test("shell 运算符被拦下", arguments: ["codex; echo done", "claude && ls", "claude | tee log", "claude # note", "claude `id`"])
    func operators(_ command: String) { #expect(NewSessionDraft.commandProblem(command) != nil) }

    @Test("引号里的运算符不算")
    func quotedOperator() { #expect(NewSessionDraft.commandProblem(#"claude --append "a;b""#) == nil) }

    @Test("没闭合的引号")
    func unclosed() { #expect(NewSessionDraft.commandProblem(#"claude --name "oops"#) == "引号没有闭合。") }
}

@Suite("开始会话校验")
struct StartProblemTests {
    @Test func needsFolder() { #expect(NewSessionDraft().startProblem(folderExists: true) == "选一个项目文件夹。") }
    @Test func missingFolder() { #expect(NewSessionDraft(folder: "~/x").startProblem(folderExists: false) != nil) }
    @Test func editingBlocksStart() {
        #expect(NewSessionDraft(folder: "~/x", editingCommand: "claude").startProblem(folderExists: true) == "先保存或取消启动命令的修改。")
    }
    @Test func ok() { #expect(NewSessionDraft(folder: "~/x").startProblem(folderExists: true) == nil) }
    @Test func effectiveCommand() {
        #expect(NewSessionDraft(target: .cli(.codex)).effectiveCommand == "codex")
        #expect(NewSessionDraft(target: .cli(.codex), savedCommand: "codex --x").effectiveCommand == "codex --x")
        #expect(NewSessionDraft(target: .terminal).effectiveCommand == "$SHELL -l")
    }
}

@MainActor
@Suite("会话库")
struct LibraryTests {
    private func session(_ id: String, _ path: String, minutes: Double, cli: CLIKind = .claude, title: String? = nil) -> Session {
        Session(id: id, cli: cli, hostID: Host.localID, projectPath: path, title: title ?? "会话 \(id)",
                lastActivity: Date.now.addingTimeInterval(-minutes * 60), messageCount: 1)
    }

    /// 置顶、归档在会话库里（不挂在 Session / Project 上）
    private func store(_ sessions: [Session], projects: [Project]? = nil, activity: [String: Activity] = [:],
                       marks: (inout LibraryState) -> Void = { _ in }) -> WorkspaceStore {
        let s = WorkspaceStore(hosts: [MockData.local],
                               projects: projects ?? [Project(hostID: Host.localID, path: "/a"), Project(hostID: Host.localID, path: "/b")],
                               sessions: sessions, activity: activity)
        s.updateLibrary(marks)
        return s
    }

    @Test("置顶在前，其余按最近活动")
    func ordering() {
        let s = store([session("1", "/a", minutes: 5), session("2", "/a", minutes: 1), session("3", "/a", minutes: 99)]) {
            $0.pinnedSessions = ["3"]
        }
        #expect(s.sessions(in: s.projects[0]).map(\.id) == ["3", "2", "1"])
    }

    @Test("项目按最近活动排，置顶项目在前")
    func projectOrdering() {
        let projects = [Project(hostID: Host.localID, path: "/a"), Project(hostID: Host.localID, path: "/b"),
                        Project(hostID: Host.localID, path: "/c")]
        let s = store([session("1", "/a", minutes: 50), session("2", "/b", minutes: 500), session("3", "/c", minutes: 1)], projects: projects) {
            $0.pinnedProjects = ["local:/b"]
        }
        #expect(s.projects(on: Host.localID).map(\.path) == ["/b", "/c", "/a"])
    }

    @Test("默认只列 10 个，再显示 20 个")
    func truncation() {
        let s = store((0..<35).map { session("\($0)", "/a", minutes: Double($0)) })
        let p = s.projects[0]
        #expect(s.visibleSessions(in: p).shown.count == 10)
        #expect(s.visibleSessions(in: p).hidden == 25)
        s.showMore(in: p)
        #expect(s.visibleSessions(in: p).shown.count == 30)
        s.toggleExpanded(p); s.toggleExpanded(p)   // 收起再展开回到 10
        #expect(s.visibleSessions(in: p).shown.count == 10)
    }

    @Test("搜索时全列、只列匹配的项目")
    func search() {
        let s = store((0..<15).map { session("\($0)", "/a", minutes: Double($0), title: "修 bug \($0)") } + [session("x", "/b", minutes: 1, title: "写文档")])
        s.searchText = "bug"
        #expect(s.visibleSessions(in: s.projects[0]).shown.count == 15)
        #expect(s.projects(on: Host.localID).map(\.path) == ["/a"])
        s.searchText = "kubernetes"
        #expect(!s.hasSearchResults)
    }

    @Test("搜项目名命中时列出它的全部会话")
    func searchProjectName() {
        let s = store([session("1", "/a", minutes: 1), session("2", "/b", minutes: 1)])
        s.searchText = "b"
        #expect(s.projects(on: Host.localID).map(\.path) == ["/b"])
    }

    @Test("过滤：等待你、运行中、单个 CLI、归档")
    func filters() {
        let s = store([session("w", "/a", minutes: 1), session("d", "/a", minutes: 2),
                       session("r", "/a", minutes: 3), session("n", "/a", minutes: 4),
                       session("x", "/a", minutes: 5, cli: .codex), session("z", "/a", minutes: 6)],
                      activity: ["w": .waitingForAnswer, "d": .doneUnseen, "r": .working]) { $0.archivedSessions = ["z"] }
        let p = s.projects[0]
        s.filter = .waitingForYou
        #expect(Set(s.sessions(in: p).map(\.id)) == ["w", "d"])
        s.filter = .running
        #expect(Set(s.sessions(in: p).map(\.id)) == ["w", "d", "r"])
        s.filter = .cli(.codex)
        #expect(s.sessions(in: p).map(\.id) == ["x"])
        s.filter = .all
        #expect(!s.sessions(in: p).contains { $0.id == "z" })
        s.showsArchived = true
        #expect(s.sessions(in: p).contains { $0.id == "z" })
    }

    @Test("项目状态取最急的会话，等你回答最急")
    func urgency() {
        let s = store([session("1", "/a", minutes: 1), session("2", "/a", minutes: 2), session("3", "/a", minutes: 3)],
                      activity: ["1": .idle, "2": .waitingForAnswer, "3": .working])
        #expect(s.activity(of: s.projects[0]) == .waitingForAnswer)
    }

    @Test("单击会话：已开标签就切到标签，否则预览")
    func selectSession() {
        let s = WorkspaceStore.fixture("default")
        let running = s.session("4f1a9c2e")!
        s.select(running)
        #expect(s.selectedTab != nil)
        let idle = s.session("91be0f47")!
        s.select(idle)
        #expect(s.previewedSession?.id == idle.id)
    }

    @Test("分屏：右边候选不含已在分屏里的标签")
    func splitCandidates() {
        let s = WorkspaceStore.fixture("split-choose")
        let split = s.split!
        #expect(!s.splitCandidates.contains { split.contains($0.id) })
        s.fillSplit(with: s.splitCandidates[0])
        #expect(s.split?.right != nil)
    }
}

@Suite("相对时间")
struct RelativeAgeTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    @Test func formats() {
        #expect(RelativeAge.format(now.addingTimeInterval(-20), now: now) == "刚刚")
        #expect(RelativeAge.format(now.addingTimeInterval(-6 * 60), now: now) == "6分")
        #expect(RelativeAge.format(now.addingTimeInterval(-3 * 3600), now: now) == "3时")
        #expect(RelativeAge.format(now.addingTimeInterval(-30 * 3600), now: now) == "昨天")
        #expect(RelativeAge.format(now.addingTimeInterval(-4 * 86400), now: now) == "4天")
    }
}
