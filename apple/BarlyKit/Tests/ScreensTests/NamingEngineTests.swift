import Foundation
import Testing
@testable import Screens

/// 起名引擎：本机 CLI（Claude Code / Codex）和 API（OpenAI 兼容 / Anthropic）。不真的起进程、不联网：进程和网络都换成假的
@Suite("起名引擎")
struct NamingEngineTests {
    // MARK: CLI

    @Test("Claude：不给工具、不留会话文件、不读用户设置（跳过 hook）；默认 haiku")
    func claudeArguments() {
        let args = CLINamingEngine.arguments(cli: .claude, executable: "/bin/claude", model: "", prompt: "P", outputFile: "/o")
        #expect(args == ["/bin/claude", "-p", "--model", "haiku", "--tools", "", "--no-session-persistence",
                         "--setting-sources", "project", "P"])
        #expect(CLINamingEngine.arguments(cli: .claude, executable: "/bin/claude", model: "sonnet", prompt: "P", outputFile: "/o")
                .contains("sonnet"))
    }

    @Test("Codex：ephemeral、只读沙箱、关掉 MCP、最后一条消息写进文件；填了模型才带 -m")
    func codexArguments() {
        let args = CLINamingEngine.arguments(cli: .codex, executable: "/bin/codex", model: "", prompt: "P", outputFile: "/o")
        #expect(args == ["/bin/codex", "exec", "--ephemeral", "--skip-git-repo-check", "-s", "read-only",
                         "-c", "model_reasoning_effort=low", "-c", "mcp_servers={}", "-o", "/o", "P"])
        let withModel = CLINamingEngine.arguments(cli: .codex, executable: "/bin/codex", model: "gpt-mini", prompt: "P", outputFile: "/o")
        #expect(withModel.contains("-m") && withModel.contains("gpt-mini"))
    }

    @Test("CLI 跑完：Claude 读标准输出，Codex 读 -o 文件；在固定的工作目录里跑")
    func cliRuns() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let claude = CLINamingEngine(cli: .claude, executable: "/bin/claude", model: "", workDirectory: dir) { argv, cwd, _ in
            #expect(cwd == dir.path)
            return SSH.Output(status: 0, stdout: "名字｜动作\n", stderr: "")
        }
        #expect(try await claude.complete("P") == "名字｜动作")

        let codex = CLINamingEngine(cli: .codex, executable: "/bin/codex", model: "", workDirectory: dir) { argv, _, _ in
            let out = argv[argv.firstIndex(of: "-o")! + 1]
            try? "Codex 的回答".write(toFile: out, atomically: true, encoding: .utf8)
            return SSH.Output(status: 0, stdout: "一堆日志", stderr: "")
        }
        #expect(try await codex.complete("P") == "Codex 的回答")
    }

    @Test("CLI 失败：超时、退出码非 0（带上 stderr 最后一行）")
    func cliFailures() async {
        let dir = FileManager.default.temporaryDirectory
        let timeout = CLINamingEngine(cli: .claude, executable: "/bin/claude", model: "", workDirectory: dir) { _, _, _ in nil }
        await #expect(throws: NamingError.timedOut) { try await timeout.complete("P") }

        let failed = CLINamingEngine(cli: .claude, executable: "/bin/claude", model: "", workDirectory: dir) { _, _, _ in
            SSH.Output(status: 1, stdout: "", stderr: "debug\nInvalid API key · Please run /login\n")
        }
        await #expect(throws: NamingError.failed("Invalid API key · Please run /login")) { try await failed.complete("P") }
    }

    // MARK: API

    @Test("OpenAI 兼容：Base URL 拼 /chat/completions（尾斜杠不重复）、Bearer、取 choices[0].message.content")
    func openAI() throws {
        let engine = HTTPNamingEngine(flavor: .openAI, baseURL: "https://relay.example.com/v1/", apiKey: "sk-1", model: "m")
        let req = try engine.request("P")
        #expect(req.url?.absoluteString == "https://relay.example.com/v1/chat/completions")
        #expect(req.value(forHTTPHeaderField: "Authorization") == "Bearer sk-1")
        let body = try JSONSerialization.jsonObject(with: req.httpBody!) as! [String: Any]
        #expect(body["model"] as? String == "m")
        #expect(((body["messages"] as! [[String: Any]])[0]["content"] as? String) == "P")
        let reply = #"{"choices":[{"message":{"role":"assistant","content":"主题｜动作"}}]}"#
        #expect(try engine.parse(Data(reply.utf8), status: 200) == "主题｜动作")
    }

    @Test("Anthropic：/v1/messages、x-api-key、版本头、max_tokens；取 content 里的 text")
    func anthropic() throws {
        let engine = HTTPNamingEngine(flavor: .anthropic, baseURL: "", apiKey: "k", model: "")
        let req = try engine.request("P")
        #expect(req.url?.absoluteString == "https://api.anthropic.com/v1/messages")
        #expect(req.value(forHTTPHeaderField: "x-api-key") == "k")
        #expect(req.value(forHTTPHeaderField: "anthropic-version") == "2023-06-01")
        let body = try JSONSerialization.jsonObject(with: req.httpBody!) as! [String: Any]
        #expect(body["model"] as? String == HTTPNamingEngine.defaultAnthropicModel)
        #expect(body["max_tokens"] as? Int != nil)
        let reply = #"{"content":[{"type":"text","text":"一｜二"}]}"#
        #expect(try engine.parse(Data(reply.utf8), status: 200) == "一｜二")
    }

    @Test("API 出错：HTTP 状态码 + 服务返回的错误信息；明文 http 只许本机地址；OpenAI 没填模型要说")
    func apiErrors() throws {
        let engine = HTTPNamingEngine(flavor: .openAI, baseURL: "", apiKey: "k", model: "m")
        #expect(throws: NamingError.http(401, "Incorrect API key")) {
            try engine.parse(Data(#"{"error":{"message":"Incorrect API key"}}"#.utf8), status: 401)
        }
        #expect(throws: NamingError.insecureURL) {
            try HTTPNamingEngine(flavor: .openAI, baseURL: "http://relay.example.com/v1", apiKey: "k", model: "m").request("P")
        }
        #expect(try HTTPNamingEngine(flavor: .openAI, baseURL: "http://127.0.0.1:8080/v1", apiKey: "k", model: "m").request("P").url != nil)
        #expect(throws: NamingError.missingModel) {
            try HTTPNamingEngine(flavor: .openAI, baseURL: "", apiKey: "k", model: " ").request("P")
        }
    }

    // MARK: 选引擎

    @Test("自动：装了 Claude 用 Claude，其次 Codex，再其次填好了 Key 的 API；都没有就报没有可用引擎")
    func resolveAuto() throws {
        let both = Toolbox(tmux: { nil }, which: { "/bin/\($0)" })
        let codexOnly = Toolbox(tmux: { nil }, which: { $0 == "codex" ? "/bin/codex" : nil })
        let none = Toolbox(tmux: { nil }, which: { _ in nil })
        var s = NamingSettings(engine: .auto)
        #expect(try NamingEngines.resolve(s, tools: both).label == "Claude Code")
        #expect(try NamingEngines.resolve(s, tools: codexOnly).label == "Codex")
        #expect(throws: NamingError.noEngine) { try NamingEngines.resolve(s, tools: none) }
        s.keys[.anthropic] = "k"
        #expect(try NamingEngines.resolve(s, tools: none).label == "Anthropic")
        s = NamingSettings(engine: .claude)
        #expect(throws: NamingError.notInstalled("claude")) { try NamingEngines.resolve(s, tools: codexOnly) }
        s = NamingSettings(engine: .openAI)
        #expect(throws: NamingError.missingKey) { try NamingEngines.resolve(s, tools: both) }
    }
}
