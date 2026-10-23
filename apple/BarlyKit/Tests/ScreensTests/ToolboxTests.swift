import Foundation
import Testing
@testable import Screens

/// 找 tmux 和 CLI 可执行文件走 Toolbox：真实运行查这台机器，截图、单测默认「CLI 都装了、没有 tmux」，
/// 结果不再取决于跑测试的机器装了什么（CI 上没有 tmux 也没有 claude，开标签的测试原来都会失败）
@MainActor
@Suite("找可执行文件")
struct ToolboxTests {
    private let nothing = Toolbox(tmux: { nil }, which: { _ in nil })
    private let tmuxOnly = Toolbox(tmux: { "/x/tmux" }, which: { _ in nil })

    @Test("有 tmux 就包一层 tmux；没有 tmux 就直接跑 CLI；都没有就开不了")
    func launchUsesToolbox() {
        let id = UUID()
        let wrapped = TerminalLaunch.cli(tabID: id, command: ["claude"], directory: "/p", tmuxName: "t", tools: tmuxOnly)
        #expect(wrapped?.executable == "/x/tmux" && wrapped?.tmuxName == "t")
        let direct = TerminalLaunch.cli(tabID: id, command: ["claude", "-r"], directory: "/p", tmuxName: "t", tools: .pretendInstalled)
        #expect(direct?.executable == "/usr/local/bin/claude" && direct?.arguments == ["-r"] && direct?.tmuxName == nil)
        #expect(TerminalLaunch.cli(tabID: id, command: ["claude"], directory: "/p", tmuxName: "t", tools: nothing) == nil)
    }

    @Test("单测、截图用的 store 不看这台机器：默认当 CLI 都装了，接着跑会开出标签")
    func storeDefaultIsIndependentOfMachine() {
        let session = Session(id: "s1", cli: .claude, hostID: Host.localID, projectPath: "/p", title: "s1", lastActivity: .now, messageCount: 1)
        let st = WorkspaceStore(hosts: [MockData.local], projects: [Project(hostID: Host.localID, path: "/p")], sessions: [session])
        st.resume(st.session("s1")!)
        #expect(st.selectedTab.flatMap { st.session(for: $0) }?.id == "s1")
    }

    @Test("机器上什么都没装：接着跑开不出标签（真实运行的行为）")
    func nothingInstalledOpensNothing() {
        let session = Session(id: "s1", cli: .claude, hostID: Host.localID, projectPath: "/p", title: "s1", lastActivity: .now, messageCount: 1)
        let data = WorkspaceData(hosts: [MockData.local], projects: [Project(hostID: Host.localID, path: "/p")], sessions: [session], tools: nothing)
        let st = WorkspaceStore(data: data)
        st.resume(st.session("s1")!)
        #expect(st.allTabs.isEmpty)
    }
}
