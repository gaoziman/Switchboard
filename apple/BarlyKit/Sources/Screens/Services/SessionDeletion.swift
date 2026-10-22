import Foundation

/// 删除会话（对照 JustSessions 的做法）：
/// - Claude Code：会话文件和旁边的子代理目录移到废纸篓
/// - omp：会话文件移到废纸篓
/// - Codex：`codex delete <id>`（永久删除，Codex 自己清理索引）
/// - OpenCode：`opencode session delete <id>`（永久删除，连子代理会话一起）
public enum SessionDeletion {
    public enum Failure: LocalizedError {
        case noFile
        case command(String)

        public var errorDescription: String? {
            switch self {
            case .noFile: L("找不到这个会话的文件。")
            case .command(let output): output.isEmpty ? L("删除命令失败。") : output
            }
        }
    }

    /// 真正动手的部分：移到废纸篓、跑 CLI 的删除命令；Claude / omp 的会话文件只许在各自的会话目录里（单测换成假的）
    struct Backend {
        var trash: (URL) throws -> Void
        var run: (CLIKind, [String]) throws -> Void
        var roots: [CLIKind: URL]

        static var live: Backend {
            Backend(trash: { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }, run: runCommand,
                    roots: [.claude: ActivityMonitor.claudeRoot.appendingPathComponent("projects"), .omp: OmpSource().root])
        }
    }

    /// 在后台线程跑；成功返回 nil，失败返回原因
    public static func delete(_ session: Session) -> String? { delete(session, using: .live) }

    static func delete(_ session: Session, using backend: Backend) -> String? {
        if session.hostID != Host.localID { return RemoteSessions.delete(session) }
        do {
            switch session.cli {
            case .claude:
                let file = try localFile(session, backend)
                try trash(file, backend)
                let sidecar = file.deletingPathExtension()       // <session id>/subagents
                if FileManager.default.fileExists(atPath: sidecar.path) { try trash(sidecar, backend) }
            case .omp:
                try trash(localFile(session, backend), backend)
            case .codex:
                try backend.run(.codex, ["delete", session.id])
            case .opencode:
                try backend.run(.opencode, ["session", "delete", session.id])
            }
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// 会话文件：得是 .jsonl，规范化（去掉 ..）之后还在这个 CLI 自己的会话目录里，否则不删
    private static func localFile(_ session: Session, _ backend: Backend) throws -> URL {
        guard let path = session.sourcePath, let root = backend.roots[session.cli] else { throw Failure.noFile }
        let file = URL(fileURLWithPath: path).standardizedFileURL
        guard file.pathExtension == "jsonl", file.path.hasPrefix(root.standardizedFileURL.path + "/") else { throw Failure.noFile }
        return file
    }

    /// Codex / OpenCode、以及所有 SSH 主机上的会话是永久删除，确认框里要说清楚
    public static func isPermanent(_ session: Session) -> Bool {
        session.hostID != Host.localID || session.cli == .codex || session.cli == .opencode
    }

    private static func trash(_ url: URL, _ backend: Backend) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }   // 已经没了 = 删掉了
        try backend.trash(url)
    }

    private static func runCommand(_ cli: CLIKind, _ args: [String]) throws {
        guard let exe = ShellEnvironment.shared.which(cli.executable) else { throw Failure.command(L("找不到 \(cli.executable)。")) }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: exe)
        p.arguments = args
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = ShellEnvironment.shared.pathString
        p.environment = env
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        p.standardInput = FileHandle.nullDevice
        try p.run()
        let deadline = Date().addingTimeInterval(30)
        while p.isRunning && Date() < deadline { usleep(50_000) }
        if p.isRunning { p.terminate(); throw Failure.command(L("删除命令 30 秒没有结束。")) }
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard p.terminationStatus == 0 else { throw Failure.command(String(output.suffix(300))) }
    }
}

@MainActor
public extension WorkspaceStore {
    /// 删一批会话：在跑的先关标签、结束 tmux，再逐个删；进度显示在侧栏底部
    func delete(_ targets: [Session]) async -> [String: String] {
        await deleteSessions(targets, using: .live)
    }

    internal func deleteSessions(_ targets: [Session], using backend: SessionDeletion.Backend) async -> [String: String] {
        deletion = DeletionProgress(done: 0, total: targets.count)
        var failures: [String: String] = [:]
        for (i, s) in targets.enumerated() {
            if deletion?.cancelling == true { break }
            if let tab = tab(for: s) { close(tab, keepRunning: false) } else { endTmux(of: s) }
            if let error = await SSH.offPool({ SessionDeletion.delete(s, using: backend) }) {
                failures[s.id] = error
            } else {
                sessions.removeAll { $0.id == s.id }
                if case .preview(s.id)? = selection { selection = nil }
                transcripts[s.id] = nil
            }
            deletion?.done = i + 1
            deletion?.failed = failures.count
        }
        deletion = nil
        // OpenCode 的库、Codex 的索引都变了：重新读一次（截图、单测里不读磁盘）
        if isLive { await data.refresh() }
        return failures
    }
}
