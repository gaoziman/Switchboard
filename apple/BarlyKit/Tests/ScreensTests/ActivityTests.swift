import Foundation
import Testing
@testable import Screens

@Suite("状态解析")
struct ActivityParsingTests {
    @Test func claudeStatus() {
        #expect(ActivityMonitor.claudeActivity(status: "busy") == .working)
        #expect(ActivityMonitor.claudeActivity(status: "waiting") == .waitingForAnswer)
        #expect(ActivityMonitor.claudeActivity(status: "idle") == .idle)
        #expect(ActivityMonitor.claudeActivity(status: "shell") == .idle)
        #expect(ActivityMonitor.claudeActivity(status: "something-new") == nil)
    }

    @Test("Codex 终端标题", arguments: [
        ("⠋ Working | relay-gateway | 019a1b2c-3d4e-5f60-7182-93a4b5c6d7e8", Activity.working),
        ("Ready | relay-gateway | 019a1b2c-3d4e…", .idle),
        ("[ ! ] Action Required | relay-gateway", .waitingForAnswer),
        ("[ . ] Action Required | relay-gateway", .waitingForAnswer),
        ("● ⠙ Thinking | x", .working),
    ])
    func codexTitle(_ title: String, _ expected: Activity) {
        #expect(ActivityMonitor.codexActivity(title: title) == expected)
    }

    @Test func codexTitleUnknown() {
        #expect(ActivityMonitor.codexActivity(title: "zsh") == nil)
        #expect(ActivityMonitor.codexActivity(title: "") == nil)
    }

    @Test("Codex 会话文件里的回合事件")
    func codexRollout() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("rollout-test-\(UUID()).jsonl")
        defer { try? FileManager.default.removeItem(at: url) }
        let started = #"{"timestamp":"2026-10-20T10:00:00Z","type":"event_msg","payload":{"type":"task_started"}}"#
        let output = #"{"type":"response_item","payload":{"type":"function_call_output","output":"\"type\":\"task_complete\""}}"#
        try (started + "\n" + output + "\n").write(to: url, atomically: true, encoding: .utf8)
        #expect(ActivityMonitor.codexRolloutActivity(url.path) == .working)   // 输出里提到 task_complete 不算
        let done = #"{"type":"event_msg","payload":{"type":"task_complete"}}"#
        try (started + "\n" + output + "\n" + done + "\n").write(to: url, atomically: true, encoding: .utf8)
        #expect(ActivityMonitor.codexRolloutActivity(url.path) == .idle)
    }
}

@MainActor
@Suite("没看过的完成")
struct UnseenTurnTests {
    /// 一个开着标签、tmux 不在跑的 OpenCode 会话（OpenCode 不报状态 → 标签开着就是空闲）
    private func store(selected: Bool) -> (WorkspaceStore, TerminalTab, TerminalTab) {
        let s1 = Session(id: "oc-1", cli: .opencode, hostID: Host.localID, projectPath: "/p", title: "a", lastActivity: .now, messageCount: 1,
                         activity: .working)
        let s2 = Session(id: "oc-2", cli: .opencode, hostID: Host.localID, projectPath: "/p", title: "b", lastActivity: .now, messageCount: 1)
        let t1 = TerminalTab(kind: .session(id: "oc-1", cli: .opencode), projectPath: "/p", title: "a", activity: .working)
        let t2 = TerminalTab(kind: .session(id: "oc-2", cli: .opencode), projectPath: "/p", title: "b", activity: .idle)
        let store = WorkspaceStore(hosts: [MockData.local], projects: [Project(hostID: Host.localID, path: "/p")], sessions: [s1, s2],
                                   tabGroups: [TabGroup(projectID: "\(Host.localID):/p", name: "p", tint: 0, tabs: [t1, t2])])
        store.selection = .tab(selected ? t1.id : t2.id)
        return (store, t1, t2)
    }

    @Test("在看的标签跑完：直接空闲，不通知")
    func seen() {
        let (store, _, _) = store(selected: true)
        #expect(store.pollActivity(appIsActive: true).isEmpty)
        #expect(store.session("oc-1")?.activity == .idle)
    }

    @Test("没在看的标签跑完：蓝点 + 一条通知；之后不重复通知；选中后消失")
    func unseen() {
        let (store, t1, _) = store(selected: false)
        let changes = store.pollActivity(appIsActive: true)
        #expect(changes == [ActivityChange(kind: .turnFinished, sessionID: "oc-1")])
        #expect(store.session("oc-1")?.activity == .doneUnseen)
        #expect(store.tab(t1.id)?.activity == .doneUnseen)
        #expect(store.pollActivity(appIsActive: true).isEmpty)
        #expect(store.session("oc-1")?.activity == .doneUnseen)
        store.selection = .tab(t1.id)
        store.markSeen(t1)
        #expect(store.session("oc-1")?.activity == .idle)
    }

    @Test("app 在后台：就算是选中的标签也算没看")
    func background() {
        let (store, _, _) = store(selected: true)
        #expect(store.pollActivity(appIsActive: false).count == 1)
    }

    @Test("等你回答进铃铛")
    func bell() {
        let (store, _, _) = store(selected: false)
        store.sessions[1].activity = .waitingForAnswer
        #expect(store.waitingSessions.map(\.id) == ["oc-2"])
    }
}

@Suite("全文搜索")
struct MessageIndexTests {
    @Test("片段：命中前后各留一点")
    func snippet() {
        let text = "第一行\n" + String(repeating: "很长的前文", count: 10) + "关键词" + String(repeating: "很长的后文", count: 20) + "\n第三行"
        let r = text.range(of: "关键词")!
        let s = MessageIndex.snippet(text, around: r)
        #expect(s.hasPrefix("…"))
        #expect(s.contains("关键词"))
        #expect(s.hasSuffix("…"))
        #expect(!s.contains("第一行") && !s.contains("第三行"))
    }

    @Test("大小写、全角半角都归一")
    func folding() {
        #expect(MessageIndex.fold("SwiftTerm").contains(MessageIndex.fold("swiftterm")))
        #expect(MessageIndex.fold("ＴＭＵＸ").contains(MessageIndex.fold("tmux")))
        #expect(MessageIndex.fold("Café").contains(MessageIndex.fold("cafe")))
    }
}

@Suite("OpenCode / omp 报状态")
struct LiveReportingTests {
    @Test func activityNames() {
        #expect(LiveReporting.activity("working") == .working)
        #expect(LiveReporting.activity("waiting") == .waitingForAnswer)
        #expect(LiveReporting.activity("idle") == .idle)
        #expect(LiveReporting.activity(nil) == nil)
    }

    @Test("tmux 新会话带上环境变量（-e）")
    func tmuxEnvironment() {
        guard let (_, args) = Tmux.attachOrCreate(name: "x", directory: "/tmp", command: ["omp"], environment: ["B": "2", "A": "1"]) else { return }
        let i = args.firstIndex(of: "-e")!
        #expect(Array(args[i..<(i + 4)]) == ["-e", "A=1", "-e", "B=2"])
        #expect(args.last == "omp")
    }

    @Test("omp 带扩展参数，Claude / Codex 不带")
    func additions() {
        #expect(LiveReporting.launchAdditions(for: .claude) == nil)
        #expect(LiveReporting.launchAdditions(for: .codex) == nil)
    }
}
