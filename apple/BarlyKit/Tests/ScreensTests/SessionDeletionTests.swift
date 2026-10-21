import Foundation
import Testing
@testable import Screens

/// 删除会话：本机文件进废纸篓（只许在 CLI 自己的会话目录里），Codex / OpenCode 用它们自己的命令
@MainActor
@Suite struct SessionDeletionTests {
    /// 假的「废纸篓」和命令：记下做了什么，文件真的删掉（看效果）
    final class Recorder: @unchecked Sendable {
        var trashed: [String] = []
        var commands: [[String]] = []
        var failCommand: String?
        var failTrash: Set<String> = []
    }

    private func backend(_ r: Recorder, root: URL) -> SessionDeletion.Backend {
        SessionDeletion.Backend(
            trash: { url in
                if r.failTrash.contains(url.lastPathComponent) { throw CocoaError(.fileWriteNoPermission) }
                r.trashed.append(url.lastPathComponent)
                try FileManager.default.removeItem(at: url)
            },
            run: { cli, args in
                r.commands.append([cli.executable] + args)
                if let fail = r.failCommand { throw SessionDeletion.Failure.command(fail) }
            },
            roots: [.claude: root.appendingPathComponent("projects"), .omp: root.appendingPathComponent("omp")])
    }

    private func sandbox() throws -> (URL, () -> Void) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("sb-del-\(UUID())")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("projects/-p/abc/subagents"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("omp/--p--"), withIntermediateDirectories: true)
        try "x".write(to: root.appendingPathComponent("projects/-p/abc.jsonl"), atomically: true, encoding: .utf8)
        try "x".write(to: root.appendingPathComponent("projects/-p/abc/subagents/s.jsonl"), atomically: true, encoding: .utf8)
        try "x".write(to: root.appendingPathComponent("omp/--p--/1_o.jsonl"), atomically: true, encoding: .utf8)
        try "keep".write(to: root.appendingPathComponent("outside.jsonl"), atomically: true, encoding: .utf8)
        return (root, { try? FileManager.default.removeItem(at: root) })
    }

    private func session(_ cli: CLIKind, _ path: String?, id: String = "abc") -> Session {
        Session(id: id, cli: cli, hostID: Host.localID, projectPath: "/p", title: "t", lastActivity: .now, messageCount: 1, sourcePath: path)
    }

    @Test func claudeFileAndSubagentFolderGoToTrash() throws {
        let (root, cleanup) = try sandbox(); defer { cleanup() }
        let r = Recorder()
        let error = SessionDeletion.delete(session(.claude, root.appendingPathComponent("projects/-p/abc.jsonl").path), using: backend(r, root: root))
        #expect(error == nil)
        #expect(r.trashed == ["abc.jsonl", "abc"])
    }

    @Test func alreadyGoneCountsAsDeleted() throws {
        let (root, cleanup) = try sandbox(); defer { cleanup() }
        let r = Recorder()
        #expect(SessionDeletion.delete(session(.claude, root.appendingPathComponent("projects/-p/gone.jsonl").path), using: backend(r, root: root)) == nil)
        #expect(r.trashed.isEmpty)
    }

    @Test("会话目录外面的文件不删（路径不对、.. 跳出去、不是 .jsonl）")
    func refusesFilesOutsideTheCLIsFolder() throws {
        let (root, cleanup) = try sandbox(); defer { cleanup() }
        let r = Recorder()
        for path in [root.appendingPathComponent("outside.jsonl").path,
                     root.appendingPathComponent("projects/-p/../../outside.jsonl").path,
                     root.appendingPathComponent("projects/-p/abc").path,
                     root.appendingPathComponent("omp/--p--/1_o.jsonl").path] {          // omp 的文件不能当 Claude 的删
            #expect(SessionDeletion.delete(session(.claude, path), using: backend(r, root: root)) != nil, "\(path)")
        }
        #expect(r.trashed.isEmpty)
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("outside.jsonl").path))
        #expect(SessionDeletion.delete(session(.claude, nil), using: backend(r, root: root)) != nil)
    }

    @Test func ompFileGoesToTrash() throws {
        let (root, cleanup) = try sandbox(); defer { cleanup() }
        let r = Recorder()
        #expect(SessionDeletion.delete(session(.omp, root.appendingPathComponent("omp/--p--/1_o.jsonl").path), using: backend(r, root: root)) == nil)
        #expect(r.trashed == ["1_o.jsonl"])
    }

    @Test func codexAndOpenCodeUseTheirOwnCommands() throws {
        let (root, cleanup) = try sandbox(); defer { cleanup() }
        let r = Recorder()
        #expect(SessionDeletion.delete(session(.codex, nil, id: "cx-1"), using: backend(r, root: root)) == nil)
        #expect(SessionDeletion.delete(session(.opencode, nil, id: "ses_1"), using: backend(r, root: root)) == nil)
        #expect(r.commands == [["codex", "delete", "cx-1"], ["opencode", "session", "delete", "ses_1"]])
        r.failCommand = "no such session"
        #expect(SessionDeletion.delete(session(.codex, nil, id: "cx-2"), using: backend(r, root: root)) == "no such session")
    }

    @Test("一批里有删不掉的：记下原因，其余照删，删掉的从列表里拿掉")
    func batchKeepsGoingAndReportsFailures() async throws {
        let (root, cleanup) = try sandbox(); defer { cleanup() }
        try "x".write(to: root.appendingPathComponent("projects/-p/def.jsonl"), atomically: true, encoding: .utf8)
        let a = session(.claude, root.appendingPathComponent("projects/-p/abc.jsonl").path, id: "abc")
        let b = session(.claude, root.appendingPathComponent("projects/-p/def.jsonl").path, id: "def")
        let c = session(.codex, nil, id: "cx")
        let st = WorkspaceStore(hosts: [MockData.local], projects: [Project(hostID: Host.localID, path: "/p")], sessions: [a, b, c])
        st.selection = .preview(sessionID: "abc")
        let r = Recorder()
        r.failTrash = ["def.jsonl"]
        let failures = await st.deleteSessions([a, b, c], using: backend(r, root: root))
        #expect(Set(failures.keys) == ["def"])
        #expect(st.sessions.map(\.id) == ["def"])
        #expect(st.selection == nil)
        #expect(st.deletion == nil)
    }

    @Test func permanence() {
        #expect(!SessionDeletion.isPermanent(session(.claude, "/x.jsonl")))
        #expect(SessionDeletion.isPermanent(session(.codex, nil)))
        #expect(SessionDeletion.isPermanent(Session(id: "r", cli: .claude, hostID: "devbox", projectPath: "/p", title: "t", lastActivity: .now, messageCount: 1)))
    }
}
