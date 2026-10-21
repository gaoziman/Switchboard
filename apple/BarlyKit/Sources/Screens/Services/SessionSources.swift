import Foundation
import SQLite3

/// 一种 CLI 的会话来源：只读它自己的文件，返回会话列表。格式对照 JustSessions（MIT）的适配器
protocol SessionSource: Sendable {
    var cli: CLIKind { get }
    func discover() -> [Session]
}

// MARK: - Claude Code

/// `~/.claude/projects/<编码后的路径>/<session id>.jsonl`（遵守 CLAUDE_CONFIG_DIR）。
/// 开头几行给 cwd 和第一条提示，结尾几行给最近时间、/rename 的标题、/cd 搬过去的目录、最后用的模型
struct ClaudeSource: SessionSource {
    let cli = CLIKind.claude
    let root: URL
    var hostID = Host.localID

    struct Summary: Codable, Sendable {
        var cwd: String?
        var firstPrompt: String?
        var title: String?
        var relocatedCwd: String?
        var latest: Date?
        var model: String?
        var sidechain = false
        var messages = 0
    }

    static let cache = SummaryCache<Summary>(name: "claude-v1")

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        root = URL(fileURLWithPath: environment["CLAUDE_CONFIG_DIR"] ?? NSHomeDirectory() + "/.claude")
    }

    /// SSH 主机：读本机镜像（root 下有 projects/）
    init(mirror root: URL, hostID: String) {
        self.root = root
        self.hostID = hostID
    }

    func discover() -> [Session] {
        let projects = root.appendingPathComponent("projects")
        let fm = FileManager.default
        guard let dirs = try? fm.contentsOfDirectory(at: projects, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return [] }
        var seen = Set<String>()
        var sessions: [Session] = []
        for dir in dirs {
            let files = (try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                                                     options: [.skipsHiddenFiles])) ?? []
            for file in files where file.pathExtension == "jsonl" {
                seen.insert(file.path)
                guard let s = Self.cache.value(for: file, read: Self.summarize), !s.sidechain,
                      let cwd = s.relocatedCwd ?? s.cwd else { continue }
                let sessionID = file.deletingPathExtension().lastPathComponent
                sessions.append(Session(
                    id: sessionID, cli: cli, hostID: hostID, projectPath: cwd,
                    title: SessionTitle.clean(s.title ?? s.firstPrompt), model: s.model,
                    lastActivity: s.latest ?? JSONLines.modificationDate(file), messageCount: s.messages,
                    sourcePath: file.path))
                // 子代理：<会话 id>/subagents/agent-*.jsonl（设置里打开才读）
                if UserDefaults.standard.bool(forKey: "showSubagents") {
                    let sub = dir.appendingPathComponent(sessionID).appendingPathComponent("subagents")
                    for agent in (try? fm.contentsOfDirectory(at: sub, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey])) ?? []
                    where agent.pathExtension == "jsonl" {
                        seen.insert(agent.path)
                        guard let a = Self.cache.value(for: agent, read: Self.summarize) else { continue }
                        // 旁边的 .meta.json 有任务描述（「Git & data evidence」），比第一条提示好认
                        let meta = (try? Data(contentsOf: agent.deletingPathExtension().appendingPathExtension("meta.json"))).flatMap(JSONLines.object)
                        let label = (meta?["description"] as? String) ?? (meta?["name"] as? String)
                        sessions.append(Session(
                            id: agent.deletingPathExtension().lastPathComponent, cli: cli, hostID: hostID, projectPath: a.cwd ?? cwd,
                            title: SessionTitle.clean(label ?? a.title ?? a.firstPrompt), model: a.model,
                            lastActivity: a.latest ?? JSONLines.modificationDate(agent), messageCount: a.messages,
                            parentSessionID: sessionID, sourcePath: agent.path))
                    }
                }
            }
        }
        Self.cache.save(keeping: seen, under: root)
        return sessions
    }

    static func summarize(_ file: URL) -> Summary? {
        var s = Summary()
        for line in JSONLines.leading(file, maxBytes: 4 << 20, maxLines: 40) {
            guard let r = JSONLines.object(line) else { continue }
            s.cwd = s.cwd ?? r["cwd"] as? String
            if r["isSidechain"] as? Bool == true { s.sidechain = true }
            if r["type"] as? String == "custom-title" { s.title = r["customTitle"] as? String }
            if s.firstPrompt == nil { s.firstPrompt = userPrompt(r) }
        }
        for line in JSONLines.trailing(file).reversed() {
            guard let r = JSONLines.object(line) else { continue }
            let type = r["type"] as? String
            if s.latest == nil { s.latest = JSONLines.date(r["timestamp"]) }
            if type == "custom-title", let t = r["customTitle"] as? String { s.title = t }
            if s.relocatedCwd == nil, type == "relocated" { s.relocatedCwd = r["relocatedCwd"] as? String }
            if s.model == nil, type == "assistant",
               let m = (r["message"] as? [String: Any])?["model"] as? String, m != "<synthetic>" { s.model = m }
            if type == "user" || type == "assistant" { s.messages += 1 }
        }
        // 结尾只读了一部分，消息数用文件大小粗估，够显示量级
        if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 256 << 10 {
            s.messages = max(s.messages, size / 6_000)
        }
        return s.cwd == nil && s.relocatedCwd == nil ? nil : s
    }

    /// 用户真正打的字：跳过 isMeta、工具结果、本地命令输出
    static func userPrompt(_ r: [String: Any]) -> String? {
        guard r["type"] as? String == "user", r["isMeta"] as? Bool != true,
              let message = r["message"] as? [String: Any] else { return nil }
        let text: String?
        if let s = message["content"] as? String {
            text = s
        } else if let parts = message["content"] as? [[String: Any]] {
            text = parts.first { $0["type"] as? String == "text" }?["text"] as? String
        } else { text = nil }
        guard let t = text?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty, !t.hasPrefix("<") else { return nil }
        return t
    }
}

// MARK: - Codex

/// `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl`（遵守 CODEX_HOME）。第一行 session_meta 给 id 和 cwd；
/// 标题优先 session_index.jsonl 的 thread_name，其次第一条用户输入；模型取最后一个 turn_context
struct CodexSource: SessionSource {
    let cli = CLIKind.codex
    let root: URL
    var hostID = Host.localID

    struct Summary: Codable, Sendable {
        var id: String
        var cwd: String
        var parent: String?
        var firstPrompt: String?
        var model: String?
        var messages = 0
    }

    static let cache = SummaryCache<Summary>(name: "codex-v1")
    static let injected = ["# AGENTS.md", "<environment_context>", "<user_instructions>", "<permissions"]

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        root = URL(fileURLWithPath: environment["CODEX_HOME"] ?? NSHomeDirectory() + "/.codex")
    }

    init(mirror root: URL, hostID: String) {
        self.root = root
        self.hostID = hostID
    }

    func discover() -> [Session] {
        let index = threadNames()
        guard let walker = FileManager.default.enumerator(at: root.appendingPathComponent("sessions"),
                                                          includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                                                          options: [.skipsHiddenFiles]) else { return [] }
        var seen = Set<String>()
        var sessions: [Session] = []
        for case let file as URL in walker where file.pathExtension == "jsonl" && file.lastPathComponent.hasPrefix("rollout-") {
            seen.insert(file.path)
            guard let s = Self.cache.value(for: file, read: Self.summarize) else { continue }
            let named = index[s.id]
            sessions.append(Session(
                id: s.id, cli: cli, hostID: hostID, projectPath: s.cwd,
                title: SessionTitle.clean(named?.name ?? s.firstPrompt), model: s.model,
                lastActivity: max(named?.updated ?? .distantPast, JSONLines.modificationDate(file)),
                messageCount: s.messages, parentSessionID: s.parent, sourcePath: file.path))
        }
        Self.cache.save(keeping: seen, under: root)
        return sessions
    }

    private func threadNames() -> [String: (name: String, updated: Date?)] {
        guard let text = try? String(contentsOf: root.appendingPathComponent("session_index.jsonl"), encoding: .utf8) else { return [:] }
        var out: [String: (String, Date?)] = [:]
        for line in text.split(separator: "\n") {
            guard let r = JSONLines.object(Data(line.utf8)), let id = r["id"] as? String,
                  let name = r["thread_name"] as? String else { continue }
            out[id] = (name, JSONLines.date(r["updated_at"]))
        }
        return out
    }

    static func summarize(_ file: URL) -> Summary? {
        guard let head = JSONLines.firstObject(file), head["type"] as? String == "session_meta",
              let payload = head["payload"] as? [String: Any],
              let id = payload["id"] as? String, let cwd = payload["cwd"] as? String else { return nil }
        let spawn = ((payload["source"] as? [String: Any])?["subagent"] as? [String: Any])?["thread_spawn"] as? [String: Any]
        var s = Summary(id: id, cwd: cwd, parent: spawn?["parent_thread_id"] as? String)
        for line in JSONLines.leading(file, maxBytes: 512 << 10, maxLines: 120) {
            guard s.firstPrompt == nil, let r = JSONLines.object(line), r["type"] as? String == "response_item",
                  let p = r["payload"] as? [String: Any], p["type"] as? String == "message", p["role"] as? String == "user",
                  let content = p["content"] as? [[String: Any]] else { continue }
            for part in content where part["type"] as? String == "input_text" {
                guard let t = (part["text"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty,
                      !injected.contains(where: t.hasPrefix) else { continue }
                s.firstPrompt = t
                break
            }
        }
        for line in JSONLines.trailing(file, maxBytes: 1 << 20).reversed() {
            guard let r = JSONLines.object(line) else { continue }
            let p = r["payload"] as? [String: Any]
            if s.model == nil, r["type"] as? String == "turn_context", let m = p?["model"] as? String {
                s.model = [m, p?["effort"] as? String].compactMap { $0 }.joined(separator: " · ")
            }
            if r["type"] as? String == "response_item", p?["type"] as? String == "message" { s.messages += 1 }
        }
        return s
    }
}

// MARK: - omp

/// `~/.omp/agent/sessions/--<编码后的路径>--/<时间>_<id>.jsonl`。Pi 的格式：第一行（可能是 title 行）后面是
/// `{"type":"session","id":…,"cwd":…}` 头；标题取 title 行或第一条用户消息
struct OmpSource: SessionSource {
    let cli = CLIKind.omp
    let root = URL(fileURLWithPath: NSHomeDirectory() + "/.omp/agent/sessions")

    struct Summary: Codable, Sendable {
        var id: String
        var cwd: String
        var title: String?
        var firstPrompt: String?
        var model: String?
        var messages = 0
    }

    static let cache = SummaryCache<Summary>(name: "omp-v1")

    func discover() -> [Session] {
        guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
                                                          options: [.skipsHiddenFiles]) else { return [] }
        var seen = Set<String>()
        var sessions: [Session] = []
        for case let file as URL in walker where file.pathExtension == "jsonl" {
            seen.insert(file.path)
            guard let s = Self.cache.value(for: file, read: Self.summarize) else { continue }
            sessions.append(Session(
                id: s.id, cli: cli, hostID: Host.localID, projectPath: s.cwd,
                title: SessionTitle.clean(s.title ?? s.firstPrompt), model: s.model,
                lastActivity: JSONLines.modificationDate(file), messageCount: s.messages, sourcePath: file.path))
        }
        Self.cache.save(keeping: seen, under: root)
        return sessions
    }

    static func summarize(_ file: URL) -> Summary? {
        var s: Summary?
        var title: String?
        for line in JSONLines.leading(file, maxBytes: 1 << 20, maxLines: 400) {
            guard let r = JSONLines.object(line) else { continue }
            switch r["type"] as? String {
            case "title", "title_change":
                if let t = r["title"] as? String, !t.isEmpty { title = t }
            case "session":
                if let id = r["id"] as? String, let cwd = r["cwd"] as? String { s = Summary(id: id, cwd: cwd) }
            case "model_change":
                s?.model = r["model"] as? String
            case "message":
                guard let m = r["message"] as? [String: Any] else { break }
                s?.messages += 1
                if s?.firstPrompt == nil, m["role"] as? String == "user",
                   let parts = m["content"] as? [[String: Any]],
                   let t = parts.first(where: { $0["type"] as? String == "text" })?["text"] as? String {
                    s?.firstPrompt = t
                }
            default: break
            }
        }
        s?.title = title
        return s
    }
}

// MARK: - OpenCode

/// `~/.local/share/opencode/opencode.db`（遵守 OPENCODE_DB、XDG_DATA_HOME），只读打开
struct OpenCodeSource: SessionSource {
    let cli = CLIKind.opencode
    let database: URL

    init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        if let db = environment["OPENCODE_DB"], db.hasPrefix("/") {
            database = URL(fileURLWithPath: db)
        } else {
            let data = environment["XDG_DATA_HOME"].flatMap { $0.hasPrefix("/") ? $0 : nil } ?? NSHomeDirectory() + "/.local/share"
            database = URL(fileURLWithPath: data).appendingPathComponent("opencode/opencode.db")
        }
    }

    func discover() -> [Session] {
        guard let db = SQLiteReader(database) else { return [] }
        let counts = Dictionary(db.rows("SELECT session_id, count(*) FROM message GROUP BY session_id").map { ($0[0] ?? "", Int($0[1] ?? "0") ?? 0) },
                                uniquingKeysWith: { a, _ in a })
        let rows = db.rows("SELECT id, directory, title, time_updated, parent_id FROM session WHERE time_archived IS NULL")
            .nonEmpty ?? db.rows("SELECT id, directory, title, time_updated, parent_id FROM session")
        return rows.compactMap { r in
            guard let id = r[0], let dir = r[1], dir.hasPrefix("/") else { return nil }
            let rawTitle = r[2].flatMap { $0.hasPrefix("New session - ") ? nil : $0 }
            return Session(id: id, cli: cli, hostID: Host.localID, projectPath: dir, title: SessionTitle.clean(rawTitle),
                           lastActivity: Date(timeIntervalSince1970: (Double(r[3] ?? "0") ?? 0) / 1000),
                           messageCount: counts[id] ?? 0, parentSessionID: r[4], sourcePath: database.path)
        }
    }
}

/// 只读的 SQLite 小工具：OpenCode 运行时会写库，等锁 1 秒
final class SQLiteReader {
    private var db: OpaquePointer?

    init?(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path),
              sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            if db != nil { sqlite3_close(db) }
            return nil
        }
        sqlite3_busy_timeout(db, 1_000)
    }

    deinit { sqlite3_close(db) }

    func rows(_ sql: String, bind: [String] = []) -> [[String?]] {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(statement) }
        for (i, value) in bind.enumerated() {
            sqlite3_bind_text(statement, Int32(i + 1), value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        var out: [[String?]] = []
        let columns = sqlite3_column_count(statement)
        while sqlite3_step(statement) == SQLITE_ROW {
            out.append((0..<columns).map { c in sqlite3_column_text(statement, c).map { String(cString: $0) } })
        }
        return out
    }
}

private extension Array {
    var nonEmpty: Self? { isEmpty ? nil : self }
}
