import Foundation

/// 把会话文件读成预览用的对话条目：用户消息、回复、连续的工具调用折成一行、图片占位。
/// 思考过程、系统注入、工具原始输出都不显示。只读文件尾部（默认 4 MB），够看最近几百条；更早的阶段二做分页
public enum TranscriptLoader {
    /// 这个会话文件比 maxBytes 大（只读了尾部）
    public static func isTruncated(_ session: Session, maxBytes: Int) -> Bool {
        guard session.cli != .opencode, let path = session.sourcePath,
              let size = try? URL(fileURLWithPath: path).resourceValues(forKeys: [.fileSizeKey]).fileSize else { return false }
        return size > maxBytes
    }

    public static func load(_ session: Session, maxBytes: Int = 4 << 20) -> [TranscriptEntry] {
        guard let path = session.sourcePath else { return [] }
        let url = URL(fileURLWithPath: path)
        var builder = Builder()
        switch session.cli {
        case .claude: claude(JSONLines.trailing(url, maxBytes: maxBytes), &builder, subagent: session.parentSessionID != nil)
        case .codex: codex(JSONLines.trailing(url, maxBytes: maxBytes), &builder)
        case .omp: omp(JSONLines.trailing(url, maxBytes: maxBytes), &builder)
        case .opencode: opencode(database: url, sessionID: session.id, &builder)
        }
        return builder.finish()
    }

    /// 逐条收集，工具调用先攒着，遇到下一条正文时折成一行
    struct Builder {
        var entries: [TranscriptEntry] = []
        var pendingTools: [String] = []
        var lastTime = Date.distantPast

        mutating func user(_ text: String, _ time: Date?) {
            flushTools()
            let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return }
            append(.user(t), time)
        }

        mutating func assistant(_ text: String, _ time: Date?) {
            flushTools()
            let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty else { return }
            append(.assistant(t), time)
        }

        mutating func tool(_ summary: String, _ time: Date?) {
            pendingTools.append(summary)
            if let time { lastTime = time }
        }

        mutating func image(_ time: Date?) {
            flushTools()
            append(.image(caption: L("图片")), time)
        }

        private mutating func append(_ kind: TranscriptEntry.Kind, _ time: Date?) {
            if let time { lastTime = time }
            entries.append(TranscriptEntry(id: entries.count, kind: kind, time: lastTime))
        }

        private mutating func flushTools() {
            guard !pendingTools.isEmpty else { return }
            let summary = pendingTools.prefix(4).joined(separator: " · ") + (pendingTools.count > 4 ? " …" : "")
            entries.append(TranscriptEntry(id: entries.count, kind: .tools(count: pendingTools.count, summary: summary), time: lastTime))
            pendingTools = []
        }

        mutating func finish() -> [TranscriptEntry] {
            flushTools()
            return entries
        }
    }

    /// 工具调用的一行摘要：工具名 + 最有用的那个参数（命令、文件名、搜索词）
    static func toolSummary(_ name: String, _ input: [String: Any]?) -> String {
        let keys = ["command", "file_path", "path", "pattern", "query", "url", "description", "cmd"]
        let arg = keys.lazy.compactMap { input?[$0] as? String }.first
            ?? (input?["command"] as? [String])?.joined(separator: " ")
        guard var a = arg?.replacingOccurrences(of: "\n", with: " ") else { return name }
        if a.hasPrefix("/") { a = (a as NSString).lastPathComponent }
        return "\(name) \(a.count > 48 ? String(a.prefix(48)) + "…" : a)"
    }

    // MARK: Claude Code

    /// subagent = 子代理自己的记录：每一行都标着 isSidechain，不能过滤
    static func claude(_ lines: [Data], _ b: inout Builder, subagent: Bool = false) {
        for line in lines {
            guard let r = JSONLines.object(line), subagent || r["isSidechain"] as? Bool != true, r["isMeta"] as? Bool != true,
                  let message = r["message"] as? [String: Any] else { continue }
            let time = JSONLines.date(r["timestamp"])
            switch r["type"] as? String {
            case "user":
                if let text = message["content"] as? String {
                    if !text.hasPrefix("<") { b.user(text, time) }
                } else if let parts = message["content"] as? [[String: Any]] {
                    for p in parts {
                        switch p["type"] as? String {
                        case "text": if let t = p["text"] as? String, !t.hasPrefix("<") { b.user(t, time) }
                        case "image": b.image(time)
                        default: break   // tool_result 不显示
                        }
                    }
                }
            case "assistant":
                for p in message["content"] as? [[String: Any]] ?? [] {
                    switch p["type"] as? String {
                    case "text": b.assistant(p["text"] as? String ?? "", time)
                    case "tool_use": b.tool(toolSummary(p["name"] as? String ?? "Tool", p["input"] as? [String: Any]), time)
                    default: break   // thinking 不显示
                    }
                }
            default: break
            }
        }
    }

    // MARK: Codex

    static func codex(_ lines: [Data], _ b: inout Builder) {
        for line in lines {
            guard let r = JSONLines.object(line), r["type"] as? String == "response_item",
                  let p = r["payload"] as? [String: Any] else { continue }
            let time = JSONLines.date(r["timestamp"])
            switch p["type"] as? String {
            case "message":
                let role = p["role"] as? String
                for part in p["content"] as? [[String: Any]] ?? [] {
                    guard let text = part["text"] as? String else {
                        if part["type"] as? String == "input_image" { b.image(time) }
                        continue
                    }
                    if role == "user" {
                        if !CodexSource.injected.contains(where: text.hasPrefix) { b.user(text, time) }
                    } else if role == "assistant" {
                        b.assistant(text, time)
                    }
                }
            case "function_call", "custom_tool_call", "local_shell_call":
                let args = (p["arguments"] as? String).flatMap { JSONLines.object(Data($0.utf8)) }
                    ?? (p["action"] as? [String: Any])
                b.tool(toolSummary(p["name"] as? String ?? "shell", args), time)
            default: break
            }
        }
    }

    // MARK: omp（Pi 格式）

    static func omp(_ lines: [Data], _ b: inout Builder) {
        for line in lines {
            guard let r = JSONLines.object(line), r["type"] as? String == "message",
                  let m = r["message"] as? [String: Any] else { continue }
            let time = JSONLines.date(r["timestamp"])
            let parts = m["content"] as? [[String: Any]] ?? []
            switch m["role"] as? String {
            case "user":
                for p in parts {
                    if p["type"] as? String == "text" { b.user(p["text"] as? String ?? "", time) }
                    if p["type"] as? String == "image" { b.image(time) }
                }
            case "assistant":
                for p in parts {
                    switch p["type"] as? String {
                    case "text": b.assistant(p["text"] as? String ?? "", time)
                    case "toolCall": b.tool(toolSummary(p["name"] as? String ?? "tool", p["arguments"] as? [String: Any]), time)
                    default: break
                    }
                }
            default: break   // toolResult 不显示
            }
        }
    }

    // MARK: OpenCode

    static func opencode(database: URL, sessionID: String, _ b: inout Builder) {
        guard let db = SQLiteReader(database) else { return }
        let rows = db.rows("""
            SELECT json_extract(m.data,'$.role'), json_extract(p.data,'$.type'), json_extract(p.data,'$.text'),
                   json_extract(p.data,'$.tool'), json_extract(p.data,'$.state.input'), p.time_created
            FROM part p JOIN message m ON m.id = p.message_id
            WHERE p.session_id = ? ORDER BY m.time_created, p.id
            """, bind: [sessionID])
        for r in rows.suffix(3000) {
            let time = r[5].flatMap(Double.init).map { Date(timeIntervalSince1970: $0 / 1000) }
            switch r[1] {
            case "text":
                let text = r[2] ?? ""
                if r[0] == "user" { b.user(text, time) } else { b.assistant(text, time) }
            case "tool":
                let input = r[4].flatMap { JSONLines.object(Data($0.utf8)) }
                b.tool(toolSummary(r[3] ?? "tool", input), time)
            case "file":
                b.image(time)
            default: break
            }
        }
    }
}
