import Foundation
import Testing
@testable import Screens

@MainActor @Suite struct MoveToFolderTests {
    func session(_ cli: CLIKind, host: String = Host.localID, path: String = "/code/a") -> Session {
        Session(id: "mv-\(UUID().uuidString)", cli: cli, hostID: host, projectPath: path, title: "t", lastActivity: .now, messageCount: 1)
    }

    @Test func onlyOtherExistingFoldersOnSameHost() {
        let s = session(.claude)
        let store = WorkspaceStore(hosts: [MockData.local], projects: [
            Project(hostID: Host.localID, path: "/code/a"),
            Project(hostID: Host.localID, path: "/code/b"),
            Project(hostID: Host.localID, path: "/code/gone", folderExists: false),
            Project(hostID: "devbox", path: "/code/c"),
        ], sessions: [s])
        #expect(store.moveDestinations(for: s).map(\.path) == ["/code/b"])
    }

    @Test func onlyClaudeAndNotWhileRunning() {
        let claude = session(.claude), codex = session(.codex)
        let store = WorkspaceStore(hosts: [MockData.local], projects: [], sessions: [claude, codex])
        #expect(!store.canMove(codex))
        // 主机上的会话：主机的 tmux 里在跑就不行
        let remote = session(.claude, host: "devbox")
        store.remoteSnapshots["devbox"] = RemoteSessions.Snapshot(claude: [:], tmux: [Tmux.name(for: .claude, sessionID: remote.id)])
        #expect(!store.canMove(remote))
        store.remoteSnapshots["devbox"] = RemoteSessions.Snapshot()
        #expect(store.canMove(remote))
    }
}
