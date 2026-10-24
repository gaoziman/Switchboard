import Foundation
import Testing
@testable import Screens

/// 终端区右键菜单：文字操作永远在；会话的标签多出会话操作；还在 tmux 里跑的才有「结束会话」
@MainActor
@Suite("终端右键菜单")
struct TerminalMenuTests {
    private func session(_ cli: CLIKind = .claude, host: String = Host.localID, file: String? = "/s/a.jsonl") -> Session {
        Session(id: "a", cli: cli, hostID: host, projectPath: "/p", title: "a", lastActivity: .now, messageCount: 1, sourcePath: file)
    }

    @Test("本机 Claude 会话、在 tmux 里跑、没分屏：全套")
    func localSession() {
        #expect(TerminalMenu.sections(session: session(), runsInTmux: true, canSplit: true) == [
            [.copy, .paste, .selectAll],
            [.rename, .aiRename],
            [.copyConversation, .export([.markdown, .plainText, .original]), .copySessionID, .revealSessionFile],
            [.split],
            [.closeTab, .endSession, .deleteSession],
        ])
    }

    @Test("普通终端：只有文字操作和关标签")
    func plainTerminal() {
        #expect(TerminalMenu.sections(session: nil, runsInTmux: false, canSplit: false) == [
            [.copy, .paste, .selectAll],
            [.closeTab],
        ])
    }

    @Test("标签栏：同一份菜单去掉文字操作；CLI 退出后（有横幅）没有「结束会话」；分屏中不再给分屏")
    func tabBar() {
        let s = session()
        let tab = TerminalTab(kind: .session(id: s.id, cli: .claude), projectPath: "/p", title: "a", activity: .idle)
        let store = WorkspaceStore(hosts: [MockData.local], projects: [Project(hostID: Host.localID, path: "/p")], sessions: [s],
                                   tabGroups: [TabGroup(projectID: ProjectID(host: Host.localID, path: "/p"), name: "p", tint: 0, tabs: [tab])])
        store.launches[tab.id] = TerminalLaunch(tabID: tab.id, executable: "/tmux", arguments: [], directory: "/p", tmuxName: "claude-a")

        let live = TerminalMenu.sections(for: tab, in: store, text: false)
        #expect(live.first == [.rename, .aiRename])
        #expect(live.last == [.closeTab, .endSession, .deleteSession])

        store.tabBanners[tab.id] = .exited(code: 0)
        store.split = SplitState(left: tab.id, right: nil)
        let exited = TerminalMenu.sections(for: tab, in: store, text: false)
        #expect(exited.last == [.closeTab, .deleteSession])
        #expect(!exited.joined().contains(.split))
    }

    @Test("主机上的会话：没有本机文件可显示；OpenCode 没有原始文件可导出")
    func remoteAndOpenCode() {
        let remote = TerminalMenu.sections(session: session(host: "devbox"), runsInTmux: true, canSplit: false)
        #expect(!remote.joined().contains(.revealSessionFile))
        #expect(remote.joined().contains(.export([.markdown, .plainText, .original])))

        let opencode = TerminalMenu.sections(session: session(.opencode, file: nil), runsInTmux: false, canSplit: false)
        #expect(opencode.joined().contains(.export([.markdown, .plainText])))
        #expect(!opencode.joined().contains(.revealSessionFile))
        #expect(opencode.last == [.closeTab, .deleteSession])     // CLI 已经不在 tmux 里：没有「结束会话」
    }
}
