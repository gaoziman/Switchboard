import Foundation

/// 读 JSONL 会话文件的开头 / 结尾几行，不把几十 MB 的文件整个读进来
enum JSONLines {
    private static let newline = UInt8(ascii: "\n")

    /// 文件开头的行（最多 maxBytes 字节；最后一行没读完就丢掉）
    static func leading(_ url: URL, maxBytes: Int = 256 << 10, maxLines: Int = .max) -> [Data] {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return [] }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: maxBytes), !data.isEmpty else { return [] }
        var lines = data.split(separator: newline, omittingEmptySubsequences: true).map { Data($0) }
        if data.count == maxBytes, data.last != newline, !lines.isEmpty { lines.removeLast() }
        return Array(lines.prefix(maxLines))
    }

    /// 文件结尾的行，旧的在前（最多 maxBytes 字节；第一行可能被截断就丢掉）
    static func trailing(_ url: URL, maxBytes: Int = 256 << 10) -> [Data] {
        guard let handle = try? FileHandle(forReadingFrom: url),
              let size = try? handle.seekToEnd() else { return [] }
        defer { try? handle.close() }
        let start = size > UInt64(maxBytes) ? size - UInt64(maxBytes) : 0
        guard (try? handle.seek(toOffset: start)) != nil,
              let data = try? handle.readToEnd(), !data.isEmpty else { return [] }
        var lines = data.split(separator: newline, omittingEmptySubsequences: true).map { Data($0) }
        if start > 0, !lines.isEmpty { lines.removeFirst() }
        return lines
    }

    /// 和 trailing 交出一样的行，但边读边交：按块读，手里只有一块和当前这一行。
    /// 导出整个会话（最多 256 MB）时，trailing 要先把整块读进来、每行再拷一份，峰值是文件的两倍
    static func trailingLines(_ url: URL, maxBytes: Int, chunkSize: Int = 1 << 20) -> TrailingLines {
        TrailingLines(url: url, maxBytes: maxBytes, chunkSize: chunkSize)
    }

    struct TrailingLines: Sequence {
        let url: URL
        let maxBytes: Int
        let chunkSize: Int

        func makeIterator() -> Reader { Reader(url: url, maxBytes: maxBytes, chunkSize: chunkSize) }

        final class Reader: IteratorProtocol {
            private var handle: FileHandle?
            private let chunkSize: Int
            /// 读进来、还没交出去的字节（最后一行可能还没读完）
            private var pending = Data()
            /// 不是从文件开头读的：第一行可能被截断，丢掉（和 trailing 一样）
            private var dropFirst = false

            init(url: URL, maxBytes: Int, chunkSize: Int) {
                self.chunkSize = Swift.max(1, chunkSize)
                guard let handle = try? FileHandle(forReadingFrom: url), let size = try? handle.seekToEnd() else { return }
                let start = size > UInt64(maxBytes) ? size - UInt64(maxBytes) : 0
                guard (try? handle.seek(toOffset: start)) != nil else { try? handle.close(); return }
                self.handle = handle
                dropFirst = start > 0
            }

            deinit { try? handle?.close() }

            func next() -> Data? {
                while true {
                    if let newline = pending.firstIndex(of: JSONLines.newline) {
                        let line = pending[pending.startIndex..<newline]
                        pending = pending[pending.index(after: newline)...]
                        if let line = take(line) { return line }
                        continue
                    }
                    if let handle, let chunk = try? handle.read(upToCount: chunkSize), !chunk.isEmpty {
                        var joined = Data(pending)
                        joined.append(chunk)
                        pending = joined
                        continue
                    }
                    // 读到头了：剩下的是没有换行结尾的最后一行
                    try? handle?.close()
                    handle = nil
                    let rest = pending
                    pending = Data()
                    return rest.isEmpty ? nil : take(rest)
                }
            }

            /// 空行不算；第一行要丢就丢掉
            private func take(_ line: Data) -> Data? {
                guard !line.isEmpty else { return nil }
                if dropFirst { dropFirst = false; return nil }
                return Data(line)
            }
        }
    }

    /// 第一行（Codex 的 session_meta、Pi / omp 的头）
    static func firstObject(_ url: URL, skippingTypes: Set<String> = []) -> [String: Any]? {
        for line in leading(url, maxBytes: 64 << 10, maxLines: 5) {
            guard let object = object(line) else { continue }
            if let type = object["type"] as? String, skippingTypes.contains(type) { continue }
            return object
        }
        return nil
    }

    /// 解析时产生的临时对象当场放掉：逐行解析几万行时，不然要等整个循环结束才释放（每行的大段工具输出都攒着）
    static func object(_ data: Data) -> [String: Any]? {
        autoreleasepool { (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] }
    }

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let iso = ISO8601DateFormatter()

    static func date(_ value: Any?) -> Date? {
        if let string = value as? String {
            return isoFractional.date(from: string) ?? iso.date(from: string)
        }
        if let number = value as? Double { return Date(timeIntervalSince1970: number > 1e12 ? number / 1000 : number) }
        return nil
    }

    static func modificationDate(_ url: URL) -> Date {
        ((try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate) ?? .distantPast
    }
}

/// 标题清理：去掉换行、命令包装、过长截断
enum SessionTitle {
    static let untitled = L("未命名会话")

    static func clean(_ raw: String?) -> String {
        guard var text = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return untitled }
        if text.hasPrefix("<") { return untitled }        // <command-name>、<local-command-stdout> 这类不是用户写的
        text = text.replacingOccurrences(of: "\n", with: " ")
        while text.contains("  ") { text = text.replacingOccurrences(of: "  ", with: " ") }
        return text.count > 120 ? String(text.prefix(120)) + "…" : text
    }
}

/// 按「路径 + 修改时间 + 大小」缓存每个会话文件的摘要，第二次刷新只读改过的文件。存在 Caches 里
final class SummaryCache<Value: Codable & Sendable>: @unchecked Sendable {
    private struct Entry: Codable {
        let modified: Double
        let size: Int
        let value: Value
    }

    private var entries: [String: Entry]
    private let file: URL
    private let lock = NSLock()
    private var dirty = false

    init(name: String) {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("design.barly.switchboard/summaries", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        file = dir.appendingPathComponent("\(name).json")
        entries = (try? JSONDecoder().decode([String: Entry].self, from: Data(contentsOf: file))) ?? [:]
    }

    /// 文件没变就用缓存，否则调 read 重新读
    func value(for url: URL, read: (URL) -> Value?) -> Value? {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let modified = values?.contentModificationDate?.timeIntervalSince1970 ?? 0
        let size = values?.fileSize ?? 0
        lock.lock()
        if let hit = entries[url.path], hit.modified == modified, hit.size == size {
            lock.unlock()
            return hit.value
        }
        lock.unlock()
        guard let value = read(url) else { return nil }
        lock.lock()
        entries[url.path] = Entry(modified: modified, size: size, value: value)
        dirty = true
        lock.unlock()
        return value
    }

    /// 删掉 root 下已经不存在的文件的缓存（别的目录的不动：本机和各 SSH 主机的镜像共用一个缓存），写盘
    func save(keeping paths: Set<String>, under root: URL) {
        let prefix = root.standardizedFileURL.path + "/"
        lock.lock()
        defer { lock.unlock() }
        let before = entries.count
        entries = entries.filter { !$0.key.hasPrefix(prefix) || paths.contains($0.key) }
        guard dirty || entries.count != before else { return }
        if let data = try? JSONEncoder().encode(entries) { try? data.write(to: file, options: .atomic) }
        dirty = false
    }
}
