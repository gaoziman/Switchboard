import Foundation

/// 给会话起名：读一小段对话 → 提示词 → 模型 → 清洗成「主题｜动作」的候选。
/// 模型在调用时才按设置选（设置随时会改）；单测换成假的
struct SessionNamer: Sendable {
    /// 「新会话自动起名」开着没有
    var isAutoEnabled: @Sendable () -> Bool
    /// 会话 + 项目名 + 要几个 → 候选
    var suggest: @Sendable (_ session: Session, _ project: String, _ count: Int) async throws -> [String]

    init(isAutoEnabled: @escaping @Sendable () -> Bool,
         suggest: @escaping @Sendable (_ session: Session, _ project: String, _ count: Int) async throws -> [String]) {
        self.isAutoEnabled = isAutoEnabled
        self.suggest = suggest
    }

    static let unavailable = SessionNamer(isAutoEnabled: { false }) { _, _, _ in throw NamingError.noEngine }

    static let live = SessionNamer(isAutoEnabled: { UserDefaults.standard.bool(forKey: NamingSettings.autoNameKey) }) { session, project, count in
        let engine = try NamingEngines.resolve(NamingSettings.load())
        // 只要最后 1 MB：开头几条用户消息不在里面时用会话标题（就是第一句话）补上
        let entries = await Task.detached { TranscriptLoader.load(session, maxBytes: 1 << 20) }.value
        return try await run(engine: engine, project: project, entries: entries, fallbackTitle: session.title, count: count)
    }

    static func run(engine: any NamingEngine, project: String, entries: [TranscriptEntry], fallbackTitle: String,
                    count: Int) async throws -> [String] {
        var entries = entries
        if !entries.contains(where: { if case .user = $0.kind { true } else { false } }) {
            entries.insert(TranscriptEntry(id: -1, kind: .user(fallbackTitle), time: .now), at: 0)
        }
        let prompt = NamingPrompt.prompt(excerpt: NamingPrompt.excerpt(project: project, entries: entries), count: count)
        let names = SessionName.candidates(from: try await engine.complete(prompt), count: count)
        guard !names.isEmpty else { throw NamingError.emptyResult }
        return names
    }
}

@MainActor
public extension WorkspaceStore {
    /// 单个会话：3 个候选，用户挑
    func nameSuggestions(for session: Session) async throws -> [String] {
        data.naming.insert(session.id)
        defer { data.naming.remove(session.id) }
        return try await data.namer.suggest(session, projectName(of: session), 3)
    }

    /// 多选批量：每个要 1 个直接换上，同时最多跑 2 个；没起成的记进 namingFailures（弹一次提示）
    func aiRename(_ sessions: [Session]) async {
        namingFailures = []
        let namer = data.namer
        let jobs = sessions.filter { !data.naming.contains($0.id) }
        for s in jobs { data.naming.insert(s.id) }
        var queue = jobs.map { ($0, projectName(of: $0)) }[...]
        await withTaskGroup(of: (Session, Result<[String], Error>).self) { group in
            func launch() {
                guard let (s, project) = queue.popFirst() else { return }
                group.addTask { (s, await Result { try await namer.suggest(s, project, 1) }) }
            }
            launch(); launch()
            for await (s, result) in group {
                data.naming.remove(s.id)
                switch result {
                case .success(let names): if let name = names.first, let current = session(s.id) { rename(current, to: name) }
                case .failure(let error): namingFailures.append("\(s.displayTitle)：\(error.localizedDescription)")
                }
                launch()
            }
        }
    }

    /// 回合结束时调：这次在 Switchboard 新建的会话、开关开着、没有名字、没自动起过 → 起一次（失败不打扰，也不再试）
    func autoNameIfNeeded(_ session: Session) async {
        guard data.namer.isAutoEnabled(), data.freshSessions.contains(session.id), session.localName == nil,
              !data.library.autoNamed.contains(session.id), !data.naming.contains(session.id) else { return }
        updateLibrary { $0.autoNamed.insert(session.id) }
        data.naming.insert(session.id)
        defer { data.naming.remove(session.id) }
        guard let name = try? await data.namer.suggest(session, projectName(of: session), 1).first else { return }
        // 起名的这几秒里用户自己改过名就不覆盖
        if let current = self.session(session.id), current.localName == nil { rename(current, to: name) }
    }

    private func projectName(of session: Session) -> String {
        project(for: session)?.name ?? (session.projectPath as NSString).lastPathComponent
    }
}

/// 设置页用：本机找到了哪些 CLI、按当前设置试起一次名
public enum NamingCheck {
    public static func installedCLIs() -> [String] {
        [("claude", "Claude Code"), ("codex", "Codex")].compactMap { Toolbox.live.which($0.0) != nil ? $0.1 : nil }
    }

    /// 用一段固定的示例对话试一次：返回用的哪个模型、起出来的名字
    public static func run() async throws -> (engine: String, name: String) {
        let engine = try NamingEngines.resolve(NamingSettings.load())
        let sample = [TranscriptEntry(id: 1, kind: .user("顶部标签栏没选中的标签看不清，帮我重新设计一下，加分组托盘"), time: .now),
                      TranscriptEntry(id: 2, kind: .assistant("已经改成描边托盘，选中的标签是浮起的卡片。"), time: .now)]
        let names = try await SessionNamer.run(engine: engine, project: "Switchboard", entries: sample, fallbackTitle: "", count: 1)
        return (engine.label, names[0])
    }
}
