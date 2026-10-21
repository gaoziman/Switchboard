import Foundation

/// SSH 主机上的会话：删除、读状态。都走 Connect… / 后台共用的那条连接（SSH.options）
public enum RemoteSessions {
    // MARK: 删除

    /// 本机镜像里的路径 → 主机上相对家目录的路径（只认 .claude/projects 下面的 .jsonl）
    static func remoteRelativePath(_ session: Session) -> String? {
        guard let local = session.sourcePath else { return nil }
        let root = SSH.cacheDirectory(session.hostID).appendingPathComponent("claude/projects").path + "/"
        guard local.hasPrefix(root) else { return nil }
        let rel = String(local.dropFirst(root.count))
        // 只允许「项目目录/会话.jsonl」两段，不许 .. 和绝对路径
        let parts = rel.split(separator: "/")
        guard parts.count == 2, rel.hasSuffix(".jsonl"), !rel.contains(".."), !rel.hasPrefix("/") else { return nil }
        return ".claude/projects/" + rel
    }

    /// 在后台线程跑；nil = 删掉了，否则是原因。主机上没有废纸篓：永久删除
    public static func delete(_ session: Session) -> String? {
        let alias = session.hostID
        let script: String
        switch session.cli {
        case .claude:
            guard let rel = remoteRelativePath(session) else { return L("找不到这个会话在主机上的路径。") }
            let file = Tmux.shellQuote(rel)
            let sidecar = Tmux.shellQuote(String(rel.dropLast(6)))   // 去掉 .jsonl = 子代理目录
            // 符号链接不删（可能指到别处）
            script = "cd \"$HOME\" && [ ! -L \(file) ] && [ ! -L \(sidecar) ] && rm -f -- \(file) && rm -rf -- \(sidecar)"
        case .codex:
            script = "exec \"${SHELL:-/bin/sh}\" -lc \(Tmux.shellQuote("codex delete \(Tmux.shellQuote(session.id))"))"
        case .opencode, .omp:
            return L("主机上的 \(session.cli.title) 会话还不能在这里删。")
        }
        guard let r = SSH.run(["/usr/bin/ssh"] + SSH.options(alias) + [alias, script], timeout: 60) else {
            return L("主机一分钟没有响应（网络、VPN 或主机睡眠）。")
        }
        guard r.status == 0 else {
            let err = r.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if err.contains("Permission denied") { return L("要先在主机标题上点「连接…」登录。") }
            return err.isEmpty ? L("主机上的删除命令失败（退出码 \(r.status)）。") : String(err.suffix(300))
        }
        // 本机镜像里的那份也删掉，不用等下次刷新
        if let path = session.sourcePath { try? FileManager.default.removeItem(atPath: path) }
        return nil
    }

    // MARK: 状态

    public struct Snapshot: Sendable {
        /// Claude 会话 ID → 状态（主机上活着的 claude 进程报的）
        public var claude: [String: Activity] = [:]
        /// 主机上 Switchboard 起的 tmux 会话名
        public var tmux: Set<String> = []
    }

    /// 一次 ssh 拿到两样：活着的 claude 进程的状态文件、tmux 会话列表
    static let statusScript = #"""
        for f in "$HOME"/.claude/sessions/*.json; do
          [ -f "$f" ] || continue
          pid=$(basename "$f" .json)
          kill -0 "$pid" 2>/dev/null && { printf '@claude '; tr -d '\n' < "$f"; echo; }
        done
        command -v tmux >/dev/null 2>&1 && tmux list-sessions -F '@tmux #{session_name}' 2>/dev/null
        true
        """#

    public static func snapshot(_ alias: String) -> Snapshot? {
        guard let r = SSH.run(["/usr/bin/ssh"] + SSH.options(alias) + [alias, statusScript], timeout: 15), r.status == 0 else { return nil }
        return parse(r.stdout)
    }

    static func parse(_ out: String) -> Snapshot {
        var snap = Snapshot()
        for line in out.split(separator: "\n") {
            if line.hasPrefix("@claude "), let r = JSONLines.object(Data(line.dropFirst(8).utf8)),
               let id = r["sessionId"] as? String, let a = ActivityMonitor.claudeActivity(status: r["status"] as? String) {
                snap.claude[id] = a
            } else if line.hasPrefix("@tmux ") {
                snap.tmux.insert(String(line.dropFirst(6)))
            }
        }
        return snap
    }
}
