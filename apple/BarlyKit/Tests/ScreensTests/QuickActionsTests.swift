import Foundation
import Testing
@testable import Screens

/// 项目行「+」直接开跑、会话菜单「结束会话」
@MainActor @Suite struct QuickActionsTests {
    @Test func quickStartDraftUsesFolderHostAndSavedCommand() {
        let s = WorkspaceStore.fixture("default")
        s.library.commands["codex"] = "codex --full-auto"
        let project = Project(hostID: "devbox", path: "/home/leo/billing-api")
        let draft = s.quickStartDraft(.cli(.codex), in: project)
        #expect(draft.hostID == "devbox")
        #expect(draft.folder == "/home/leo/billing-api")
        #expect(draft.target == .cli(.codex))
        #expect(draft.savedCommand == "codex --full-auto")
        #expect(s.quickStartDraft(.terminal, in: project).savedCommand == nil)
    }

    @Test func quickStartListsOnlyCLIsInstalledOnThatHost() {
        let s = WorkspaceStore.fixture("default")
        let local = Project(hostID: Host.localID, path: "/code/app")
        s.installedCLIs = [.claude, .opencode]
        if let i = s.hosts.firstIndex(where: { $0.isLocal }) { s.hosts[i].installedCLIs = [.claude, .opencode] }
        #expect(s.quickStartCLIs(for: local) == [.claude, .opencode])
        if let i = s.hosts.firstIndex(where: { $0.id == "devbox" }) { s.hosts[i].installedCLIs = [.codex] }
        #expect(s.quickStartCLIs(for: Project(hostID: "devbox", path: "/x")) == [.codex])
    }

    @Test func endSessionClosesItsTabButKeepsTheSession() {
        let s = WorkspaceStore.fixture("default")
        guard let tab = s.allTabs.first(where: { s.session(for: $0) != nil }), let session = s.session(for: tab) else {
            Issue.record("fixture 里没有带会话的标签"); return
        }
        s.endSession(session)
        #expect(s.tab(for: session) == nil)
        #expect(s.session(session.id) != nil)        // 会话还在库里
    }
}
