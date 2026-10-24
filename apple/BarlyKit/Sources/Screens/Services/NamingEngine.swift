import Foundation
#if os(macOS)
import Security
#endif

/// 给会话起名用哪个模型（设置 · AI 起名）。自动：本机装了 Claude Code 用它（快），其次 Codex，再其次填好 Key 的 API
public enum NamingEngineKind: String, CaseIterable, Identifiable, Sendable {
    case auto, claude, codex, openAI, anthropic

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .auto: L("自动")
        case .claude: "Claude Code"
        case .codex: "Codex"
        case .openAI: L("OpenAI 兼容")
        case .anthropic: "Anthropic"
        }
    }

    public var usesAPI: Bool { self == .openAI || self == .anthropic }
}

public enum NamingError: Error, Equatable, LocalizedError {
    case noEngine, notInstalled(String), missingKey, missingModel, insecureURL
    case timedOut, failed(String), http(Int, String), badResponse, emptyResult

    public var errorDescription: String? {
        switch self {
        case .noEngine: L("没有可用的模型：装上 Claude Code 或 Codex，或在「设置 · AI 起名」里填 API Key。")
        case .notInstalled(let cli): L("没找到 \(cli)：先装上，或在「设置 · AI 起名」里换一个。")
        case .missingKey: L("还没填 API Key（设置 · AI 起名）。")
        case .missingModel: L("还没填模型名（设置 · AI 起名）。")
        case .insecureURL: L("Base URL 要用 https（本机地址除外）。")
        case .timedOut: L("模型太久没回应，稍后再试。")
        case .failed(let message): message.isEmpty ? L("调用失败。") : message
        case .http(let status, let message): "HTTP \(status)" + (message.isEmpty ? "" : "：\(message)")
        case .badResponse: L("看不懂模型返回的内容。")
        case .emptyResult: L("模型没给出能用的名字，再试一次。")
        }
    }
}

/// 一个起名用的模型：给提示词，拿回它的原话（清洗交给 SessionName）
protocol NamingEngine: Sendable {
    var label: String { get }
    func complete(_ prompt: String) async throws -> String
}

// MARK: 设置

/// 「设置 · AI 起名」的值：选择、模型、Base URL 在 UserDefaults；API Key 在钥匙串
public struct NamingSettings: Equatable, Sendable {
    public var engine: NamingEngineKind
    public var models: [NamingEngineKind: String] = [:]
    public var baseURLs: [NamingEngineKind: String] = [:]
    public var keys: [NamingEngineKind: String] = [:]
    /// 新会话第一轮结束时自动起一次名（默认关）
    public var autoName = false

    public init(engine: NamingEngineKind = .auto) { self.engine = engine }

    public func model(_ kind: NamingEngineKind) -> String { (models[kind] ?? "").trimmingCharacters(in: .whitespaces) }
    public func key(_ kind: NamingEngineKind) -> String { (keys[kind] ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }

    static let engineKey = "naming.engine", autoNameKey = "naming.autoName"
    static func modelKey(_ k: NamingEngineKind) -> String { "naming.model.\(k.rawValue)" }
    static func baseURLKey(_ k: NamingEngineKind) -> String { "naming.baseURL.\(k.rawValue)" }

    public static func load(_ defaults: UserDefaults = .standard) -> NamingSettings {
        var s = NamingSettings(engine: defaults.string(forKey: engineKey).flatMap(NamingEngineKind.init(rawValue:)) ?? .auto)
        s.autoName = defaults.bool(forKey: autoNameKey)
        for k in NamingEngineKind.allCases where k != .auto {
            s.models[k] = defaults.string(forKey: modelKey(k))
            if k.usesAPI {
                s.baseURLs[k] = defaults.string(forKey: baseURLKey(k))
                s.keys[k] = NamingKeychain.read(k)
            }
        }
        return s
    }
}

/// API Key 只放钥匙串（不进 UserDefaults、不进日志）
public enum NamingKeychain {
    private static let service = "design.barly.switchboard.naming"

    public static func read(_ kind: NamingEngineKind) -> String? {
        #if os(macOS)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                    kSecAttrAccount as String: kind.rawValue, kSecReturnData as String: true]
        var out: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess, let data = out as? Data else { return nil }
        return String(data: data, encoding: .utf8)
        #else
        return nil
        #endif
    }

    /// 空字符串 = 删掉
    public static func write(_ value: String, for kind: NamingEngineKind) {
        #if os(macOS)
        let match: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                    kSecAttrAccount as String: kind.rawValue]
        SecItemDelete(match as CFDictionary)
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var add = match
        add[kSecValueData as String] = Data(trimmed.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
        #endif
    }
}

// MARK: 选引擎

enum NamingEngines {
    /// 本机 CLI 在这个固定目录里跑：Claude 会按工作目录在 ~/.claude/projects 下建一个空文件夹，固定下来就永远只有这一个
    static var workDirectory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("design.barly.switchboard/naming", isDirectory: true)
    }

    static func resolve(_ s: NamingSettings, tools: Toolbox = .live) throws -> any NamingEngine {
        func cli(_ kind: CLIKind, _ name: String) -> CLINamingEngine? {
            tools.which(name).map { CLINamingEngine(cli: kind, executable: $0, model: s.model(kind == .claude ? .claude : .codex),
                                                    workDirectory: workDirectory) }
        }
        func api(_ kind: NamingEngineKind) throws -> HTTPNamingEngine {
            guard !s.key(kind).isEmpty else { throw NamingError.missingKey }
            return HTTPNamingEngine(flavor: kind == .openAI ? .openAI : .anthropic, baseURL: s.baseURLs[kind] ?? "",
                                    apiKey: s.key(kind), model: s.model(kind))
        }
        switch s.engine {
        case .claude: if let e = cli(.claude, "claude") { return e } else { throw NamingError.notInstalled("claude") }
        case .codex: if let e = cli(.codex, "codex") { return e } else { throw NamingError.notInstalled("codex") }
        case .openAI, .anthropic: return try api(s.engine)
        case .auto:
            if let e = cli(.claude, "claude") ?? cli(.codex, "codex") { return e }
            if !s.key(.anthropic).isEmpty { return try api(.anthropic) }
            if !s.key(.openAI).isEmpty, !s.model(.openAI).isEmpty { return try api(.openAI) }
            throw NamingError.noEngine
        }
    }
}

// MARK: 本机 CLI

/// `claude -p` / `codex exec`：不给工具、不留会话文件（不然侧栏会多出一个会话）、在固定目录里跑
struct CLINamingEngine: NamingEngine {
    typealias Runner = @Sendable (_ argv: [String], _ directory: String, _ timeout: TimeInterval) async -> SSH.Output?

    let cli: CLIKind
    let executable: String
    let model: String
    let workDirectory: URL
    var runner: Runner = { argv, dir, timeout in await SSH.offPool { SSH.run(argv, timeout: timeout, directory: dir) } }

    static let timeout: TimeInterval = 60

    var label: String { cli == .claude ? "Claude Code" : "Codex" }

    static func arguments(cli: CLIKind, executable: String, model: String, prompt: String, outputFile: String) -> [String] {
        if cli == .codex {
            return [executable, "exec", "--ephemeral", "--skip-git-repo-check", "-s", "read-only",
                    "-c", "model_reasoning_effort=low", "-c", "mcp_servers={}"]
                + (model.isEmpty ? [] : ["-m", model]) + ["-o", outputFile, prompt]
        }
        // --setting-sources project：不读用户设置，用户配的 hook 不跑；登录态在钥匙串里不受影响（--bare 连钥匙串都不读，不能用）
        return [executable, "-p", "--model", model.isEmpty ? "haiku" : model, "--tools", "", "--no-session-persistence",
                "--setting-sources", "project", prompt]
    }

    func complete(_ prompt: String) async throws -> String {
        try? FileManager.default.createDirectory(at: workDirectory, withIntermediateDirectories: true)
        let outFile = FileManager.default.temporaryDirectory.appendingPathComponent("sb-naming-\(UUID().uuidString).txt").path
        defer { try? FileManager.default.removeItem(atPath: outFile) }
        let argv = Self.arguments(cli: cli, executable: executable, model: model, prompt: prompt, outputFile: outFile)
        guard let r = await runner(argv, workDirectory.path, Self.timeout) else { throw NamingError.timedOut }
        guard r.status == 0 else {
            let last = r.stderr.split(whereSeparator: \.isNewline).last.map(String.init) ?? ""
            throw NamingError.failed(String(last.trimmingCharacters(in: .whitespaces).prefix(200)))
        }
        let text = cli == .codex ? (try? String(contentsOfFile: outFile, encoding: .utf8)) ?? "" : r.stdout
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: API

/// OpenAI 兼容（/chat/completions，Base URL 可换成中转、DeepSeek 等）和 Anthropic（/v1/messages）
struct HTTPNamingEngine: NamingEngine {
    enum Flavor: Sendable { case openAI, anthropic }
    typealias Transport = @Sendable (URLRequest) async throws -> (Data, Int)

    let flavor: Flavor
    let baseURL: String
    let apiKey: String
    let model: String
    var transport: Transport = { request in
        let (data, response) = try await URLSession.shared.data(for: request)
        return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
    }

    static let defaultAnthropicModel = "claude-haiku-5-5"
    static let timeout: TimeInterval = 20

    var label: String { flavor == .openAI ? L("OpenAI 兼容") : "Anthropic" }

    func request(_ prompt: String) throws -> URLRequest {
        let fallback = flavor == .openAI ? "https://api.openai.com/v1" : "https://api.anthropic.com"
        var base = baseURL.trimmingCharacters(in: .whitespaces)
        if base.isEmpty { base = fallback }
        while base.hasSuffix("/") { base.removeLast() }
        let path = flavor == .openAI ? "/chat/completions" : "/v1/messages"
        guard let url = URL(string: base + path), let scheme = url.scheme?.lowercased(), let host = url.host?.lowercased() else {
            throw NamingError.insecureURL
        }
        guard scheme == "https" || (scheme == "http" && ["localhost", "127.0.0.1", "::1"].contains(host)) else { throw NamingError.insecureURL }
        let trimmedModel = model.trimmingCharacters(in: .whitespaces)
        var req = URLRequest(url: url, timeoutInterval: Self.timeout)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any]
        switch flavor {
        case .openAI:
            guard !trimmedModel.isEmpty else { throw NamingError.missingModel }
            req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            body = ["model": trimmedModel, "messages": [["role": "user", "content": prompt]]]
        case .anthropic:
            req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            body = ["model": trimmedModel.isEmpty ? Self.defaultAnthropicModel : trimmedModel, "max_tokens": 300,
                    "messages": [["role": "user", "content": prompt]]]
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        return req
    }

    func parse(_ data: Data, status: Int) throws -> String {
        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard (200..<300).contains(status) else {
            let error = json?["error"] as? [String: Any]
            let message = (error?["message"] as? String) ?? (json?["message"] as? String) ?? ""
            throw NamingError.http(status, String(message.prefix(200)))
        }
        let text: String?
        switch flavor {
        case .openAI:
            text = ((json?["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any])?["content"] as? String
        case .anthropic:
            text = (json?["content"] as? [[String: Any]])?.compactMap { $0["type"] as? String == "text" ? $0["text"] as? String : nil }
                .joined(separator: "\n")
        }
        guard let text else { throw NamingError.badResponse }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func complete(_ prompt: String) async throws -> String {
        let req = try request(prompt)
        let (data, status): (Data, Int)
        do { (data, status) = try await transport(req) } catch let e as URLError where e.code == .timedOut { throw NamingError.timedOut }
        catch { throw NamingError.failed(error.localizedDescription) }
        return try parse(data, status: status)
    }
}
