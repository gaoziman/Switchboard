import Foundation
import Testing
@testable import Screens

/// Codex 的 rollout 文件：CLI 升级改了格式，会话列表和预览会悄悄变空，这里用一份固定的样例盯着
@Suite("Codex 会话解析")
struct CodexParsingTests {
    private static let rollout = [
        #"{"timestamp":"2026-10-20T10:00:00.000Z","type":"session_meta","payload":{"id":"0199-main","cwd":"/Users/me/proj","cli_version":"0.50.0","source":"cli"}}"#,
        #"{"timestamp":"2026-10-20T10:00:01.000Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"<environment_context>\n  <cwd>/Users/me/proj</cwd>\n</environment_context>"}]}}"#,
        #"{"timestamp":"2026-10-20T10:00:02.000Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"把登录页的按钮改成蓝色"}]}}"#,
        #"{"timestamp":"2026-10-20T10:00:03.000Z","type":"turn_context","payload":{"cwd":"/Users/me/proj","model":"gpt-5-codex","effort":"high"}}"#,
        #"{"timestamp":"2026-10-20T10:00:04.000Z","type":"response_item","payload":{"type":"function_call","name":"shell","arguments":"{\"command\":[\"bash\",\"-lc\",\"rg login\"]}","call_id":"c1"}}"#,
        #"{"timestamp":"2026-10-20T10:00:05.000Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"改好了。"}]}}"#,
    ]

    private func write(_ lines: [String]) throws -> (URL, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("sb-codex-\(UUID())")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("rollout-2026-10-20T10-00-00-0199-main.jsonl")
        try (lines.joined(separator: "\n") + "\n").write(to: file, atomically: true, encoding: .utf8)
        return (file, dir)
    }

    @Test("会话列表：ID、目录、第一条你打的话（跳过 CLI 注入的环境说明）、模型和档位、消息数")
    func summary() throws {
        let (file, dir) = try write(Self.rollout)
        defer { try? FileManager.default.removeItem(at: dir) }
        let s = try #require(CodexSource.summarize(file))
        #expect(s.id == "0199-main")
        #expect(s.cwd == "/Users/me/proj")
        #expect(s.firstPrompt == "把登录页的按钮改成蓝色")
        #expect(s.model == "gpt-5-codex · high")
        #expect(s.messages == 3)
        #expect(s.parent == nil)
    }

    @Test("子代理：记下父会话")
    func subagentParent() throws {
        var lines = Self.rollout
        lines[0] = #"{"timestamp":"2026-10-20T10:00:00.000Z","type":"session_meta","payload":{"id":"0199-child","cwd":"/Users/me/proj","source":{"subagent":{"thread_spawn":{"parent_thread_id":"0199-main"}}}}}"#
        let (file, dir) = try write(lines)
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(CodexSource.summarize(file)?.parent == "0199-main")
    }

    @Test("第一行不是 session_meta：不当成会话")
    func notARollout() throws {
        let (file, dir) = try write(Array(Self.rollout.dropFirst()))
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(CodexSource.summarize(file) == nil)
    }

    @Test("预览：你的话、工具调用折成一行、回复；环境说明不显示")
    func transcript() throws {
        let (file, dir) = try write(Self.rollout)
        defer { try? FileManager.default.removeItem(at: dir) }
        let session = Session(id: "0199-main", cli: .codex, hostID: Host.localID, projectPath: "/Users/me/proj", title: "t",
                              lastActivity: .now, messageCount: 3, sourcePath: file.path)
        let kinds = TranscriptLoader.load(session).map(\.kind)
        try #require(kinds.count == 3)
        #expect(kinds[0] == .user("把登录页的按钮改成蓝色"))
        guard case .tools(let count, _) = kinds[1] else { Issue.record("第二条应该是工具调用：\(kinds[1])"); return }
        #expect(count == 1)
        #expect(kinds[2] == .assistant("改好了。"))
    }
}
