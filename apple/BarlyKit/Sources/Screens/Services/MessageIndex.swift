import Foundation

/// 消息全文索引：每个会话把预览里看得到的文字（你的消息、回复、工具摘要）抽出来存一份纯文本，
/// 放在 ~/Library/Caches/design.barly.switchboard/messages/，一个会话一个文件。
/// 第一次搜索时才建；之后只重读改过的会话（按文件修改时间 + 大小）。不上传、不改 CLI 的文件
public actor MessageIndex {
    public static let shared = MessageIndex()

    /// 单个会话文件最多读尾部多少字节（再早的消息不进索引，和预览一致）
    static let maxBytesPerSession = 24 << 20
    /// 单条消息最多收多少字
    static let maxCharsPerEntry = 4_000

    private struct Entry {
        let version: String
        let text: String
        /// 转小写、去重音之后的文字：搜索时直接做普通查找，比每次带选项比较快一个数量级
        let folded: String
        /// 什么时候读进内存的
        let indexedAt = Date()

        init(version: String, text: String) {
            self.version = version
            self.text = text
            folded = MessageIndex.fold(text)
        }
    }

    nonisolated static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }

    private var entries: [String: Entry] = [:]
    private let dir: URL

    init(directory: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("design.barly.switchboard/messages", isDirectory: true)) {
        dir = directory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    /// 让索引跟上这批会话。progress(已完成, 总数)；返回本次重读了几个。
    /// freshFor：这么多秒内读过的会话，文件变了也先不重读——正在跑的会话文件一直在变，
    /// 不然每搜一次都要把它（最多 24 MB）重新解析一遍；新消息最多晚这么久搜得到
    @discardableResult
    public func update(_ sessions: [Session], freshFor: TimeInterval = 30, progress: @Sendable (Int, Int) -> Void) -> Int {
        var reread = 0
        let live = Set(sessions.map(key))
        for (i, s) in sessions.enumerated() {
            if Task.isCancelled { break }
            let k = key(s)
            if let e = entries[k], Date().timeIntervalSince(e.indexedAt) < freshFor {
                if i % 50 == 0 { progress(i + 1, sessions.count) }
                continue
            }
            let v = version(s)
            if entries[k]?.version == v { if i % 50 == 0 { progress(i + 1, sessions.count) }; continue }
            if let cached = readCache(k), cached.version == v {
                entries[k] = cached
            } else {
                let text = Self.extract(s)
                entries[k] = Entry(version: v, text: text)
                writeCache(k, Entry(version: v, text: text))
                reread += 1
            }
            if i % 10 == 0 || i == sessions.count - 1 { progress(i + 1, sessions.count) }
        }
        entries = entries.filter { live.contains($0.key) }
        return reread
    }

    /// 命中的会话 → 命中那一句（前后各留一点上下文）。忽略大小写和重音
    public func search(_ query: String, in sessions: [Session]) -> [String: String] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { return [:] }
        let fq = Self.fold(q)
        var hits: [String: String] = [:]
        for s in sessions {
            guard let entry = entries[key(s)], entry.folded.contains(fq) else { continue }
            // 只对命中的会话再用原文定位，截出那一句
            if let r = entry.text.range(of: q, options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]) {
                hits[s.id] = Self.snippet(entry.text, around: r)
            } else {
                hits[s.id] = String(entry.text.prefix(80))
            }
        }
        return hits
    }

    public var indexedCount: Int { entries.count }

    // MARK: 抽文字

    static func extract(_ session: Session) -> String {
        TranscriptLoader.load(session, maxBytes: maxBytesPerSession).compactMap { e -> String? in
            switch e.kind {
            case .user(let t), .assistant(let t): String(t.prefix(maxCharsPerEntry))
            case .tools(_, let summary): summary
            case .code(_, let code): String(code.prefix(maxCharsPerEntry))
            case .image: nil
            }
        }
        // 去掉 Markdown 的强调和代码符号，片段里只留文字
        .map { $0.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "`", with: "") }
        .joined(separator: "\n")
    }

    /// 命中处所在那一行，太长就截出命中前后
    static func snippet(_ text: String, around r: Range<String.Index>) -> String {
        let lineStart = text[..<r.lowerBound].lastIndex(of: "\n").map { text.index(after: $0) } ?? text.startIndex
        let lineEnd = text[r.upperBound...].firstIndex(of: "\n") ?? text.endIndex
        let before = text[lineStart..<r.lowerBound]
        let after = text[r.upperBound..<lineEnd]
        // 侧栏一行只放得下二十来个字：关键词前面只留几个字，保证关键词看得见
        let head = before.count > 8 ? "…" + String(before.suffix(8)) : String(before)
        let tail = after.count > 60 ? String(after.prefix(60)) + "…" : String(after)
        return (head + String(text[r]) + tail).trimmingCharacters(in: .whitespaces)
    }

    // MARK: 缓存

    /// 缓存文件名带格式版本：抽文字的规则变了就自动重建
    private func key(_ s: Session) -> String { "v2-\(s.cli.rawValue)-\(s.id)" }

    /// 版本：会话文件的修改时间 + 大小；OpenCode 共用一个库，用会话自己的更新时间
    private func version(_ s: Session) -> String {
        if s.cli == .opencode { return "oc-\(Int(s.lastActivity.timeIntervalSince1970))" }
        guard let path = s.sourcePath,
              let v = try? URL(fileURLWithPath: path).resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]) else { return "?" }
        return "\(Int(v.contentModificationDate?.timeIntervalSince1970 ?? 0))-\(v.fileSize ?? 0)"
    }

    private func readCache(_ key: String) -> Entry? {
        guard let data = try? String(contentsOf: dir.appendingPathComponent(key + ".txt"), encoding: .utf8),
              let newline = data.firstIndex(of: "\n") else { return nil }
        return Entry(version: String(data[..<newline]), text: String(data[data.index(after: newline)...]))
    }

    private func writeCache(_ key: String, _ entry: Entry) {
        try? (entry.version + "\n" + entry.text).write(to: dir.appendingPathComponent(key + ".txt"), atomically: true, encoding: .utf8)
    }
}
