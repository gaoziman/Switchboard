import Foundation
import Testing
@testable import Screens

/// 全文索引：正在跑的会话文件一直在变，不能每次搜索都把它重新解析一遍
@Suite struct MessageIndexFreshnessTests {
    private func sessionFile() throws -> (Session, URL, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("sb-index-\(UUID())")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("s.jsonl")
        let line = #"{"type":"user","message":{"role":"user","content":"hello needle"},"timestamp":"2026-10-20T10:00:00Z"}"#
        try (line + "\n").write(to: file, atomically: true, encoding: .utf8)
        let s = Session(id: "idx-\(UUID())", cli: .claude, hostID: Host.localID, projectPath: "/p", title: "t", lastActivity: .now,
                        messageCount: 1, sourcePath: file.path)
        return (s, file, dir)
    }

    private func append(_ file: URL, _ text: String) throws {
        let h = try FileHandle(forWritingTo: file)
        try h.seekToEnd()
        try h.write(contentsOf: Data((#"{"type":"user","message":{"role":"user","content":"\#(text)"},"timestamp":"2026-10-20T10:01:00Z"}"# + "\n").utf8))
        try h.close()
    }

    @Test func recentlyIndexedSessionIsNotReparsedOnEverySearch() async throws {
        let (s, file, dir) = try sessionFile()
        defer { try? FileManager.default.removeItem(at: dir) }
        let index = MessageIndex(directory: dir.appendingPathComponent("cache"))
        #expect(await index.update([s], progress: { _, _ in }) == 1)
        #expect(await index.search("needle", in: [s])[s.id] != nil)
        try append(file, "brand new words")
        // 刚建过（30 秒内）：文件变了也先不重读
        #expect(await index.update([s], progress: { _, _ in }) == 0)
        // 过了这个时间就重读，新内容搜得到
        #expect(await index.update([s], freshFor: 0, progress: { _, _ in }) == 1)
        #expect(await index.search("brand new", in: [s])[s.id] != nil)
    }
}
