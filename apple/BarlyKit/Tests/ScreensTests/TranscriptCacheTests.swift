import Foundation
import Testing
@testable import Screens

/// 预览的对话缓存：有上限、文件变了重读、「加载更早」有封顶
@MainActor
@Suite struct TranscriptCacheTests {
    private func store(_ count: Int) -> WorkspaceStore {
        let sessions = (0..<count).map {
            Session(id: "s\($0)", cli: .claude, hostID: Host.localID, projectPath: "/p", title: "t", lastActivity: .now, messageCount: 1)
        }
        return WorkspaceStore(hosts: [MockData.local], projects: [Project(hostID: Host.localID, path: "/p")], sessions: sessions)
    }

    @Test func keepsOnlyRecentlyViewedTranscripts() {
        let limit = WorkspaceStore.transcriptCacheLimit
        let st = store(limit + 3)
        for i in 0..<(limit + 3) {
            st.transcripts["s\(i)"] = []
            st.transcriptBudgets["s\(i)"] = 4 << 20
            st.touchTranscript("s\(i)")
        }
        #expect(st.transcripts.count == limit)
        #expect(st.transcripts["s0"] == nil && st.transcriptBudgets["s0"] == nil)   // 最久没看的先丢
        #expect(st.transcripts["s\(limit + 2)"] != nil)
        st.touchTranscript("s3")                                                     // 再看一次：排到最新
        st.transcripts["new"] = []
        st.touchTranscript("new")
        #expect(st.transcripts["s3"] != nil)
        #expect(st.transcripts["s4"] == nil)
    }

    @Test func loadEarlierStopsAtCap() {
        #expect(WorkspaceStore.nextTranscriptBudget(4 << 20) == 16 << 20)
        #expect(WorkspaceStore.nextTranscriptBudget(16 << 20) == 64 << 20)
        #expect(WorkspaceStore.nextTranscriptBudget(64 << 20) == nil)               // 不再翻到 256 MB
    }

    @Test func fileStampChangesWhenFileGrows() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("stamp-\(UUID()).jsonl")
        defer { try? FileManager.default.removeItem(at: url) }
        try "a\n".write(to: url, atomically: true, encoding: .utf8)
        let s = Session(id: "x", cli: .claude, hostID: Host.localID, projectPath: "/p", title: "t", lastActivity: .now, messageCount: 1,
                        sourcePath: url.path)
        let first = try #require(TranscriptLoader.stamp(s))
        #expect(TranscriptLoader.stamp(s) == first)
        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("b\n".utf8))
        try handle.close()
        #expect(TranscriptLoader.stamp(s) != first)
    }
}
