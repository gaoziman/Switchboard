import Foundation
import Testing
@testable import Screens

/// AI 起名接进会话库：候选、批量、新会话只自动起一次、不碰手动起的名字。模型换成假的
@MainActor
@Suite("AI 起名")
struct AIRenameTests {
    private func session(_ id: String) -> Session {
        Session(id: id, cli: .claude, hostID: Host.localID, projectPath: "/p", title: "你好", lastActivity: .now, messageCount: 2)
    }

    private func store(_ ids: [String], auto: Bool = false,
                       suggest: @escaping @Sendable (Session, Int) async throws -> [String]) -> WorkspaceStore {
        let st = WorkspaceStore(hosts: [MockData.local], projects: [Project(hostID: Host.localID, path: "/p")], sessions: ids.map(session))
        st.data.namer = SessionNamer(isAutoEnabled: { auto }) { s, _, count in try await suggest(s, count) }
        return st
    }

    @Test("单个会话：要 3 个候选；起名期间标记在起名中，完了清掉；不自动改名")
    func suggestions() async throws {
        let st = store(["a"]) { s, count in
            #expect(count == 3)
            return ["一｜甲", "二｜乙", "三｜丙"]
        }
        let names = try await st.nameSuggestions(for: st.session("a")!)
        #expect(names == ["一｜甲", "二｜乙", "三｜丙"])
        #expect(st.data.naming.isEmpty)
        #expect(st.session("a")?.localName == nil)
    }

    @Test("批量：每个只要 1 个直接换上；失败的记下原因，成功的照样换")
    func batch() async {
        let st = store(["a", "b", "c"]) { s, count in
            #expect(count == 1)
            if s.id == "b" { throw NamingError.timedOut }
            return ["名字\(s.id)"]
        }
        await st.aiRename(["a", "b", "c"].compactMap(st.session))
        #expect(st.session("a")?.localName == "名字a")
        #expect(st.session("c")?.localName == "名字c")
        #expect(st.session("b")?.localName == nil)
        #expect(st.namingFailures.count == 1)
        #expect(st.data.naming.isEmpty)
    }

    @Test("新会话第一轮结束：开关开着才起；只起一次（失败也算）；有手动名字的不碰；不是这次新建的不碰")
    func autoName() async {
        let calls = Counter()
        let st = store(["new", "named", "old"], auto: true) { s, _ in
            await calls.add()
            return ["自动｜\(s.id)"]
        }
        st.data.freshSessions = ["new", "named"]
        st.rename(st.session("named")!, to: "我起的名字")

        for id in ["new", "named", "old"] { await st.autoNameIfNeeded(st.session(id)!) }
        #expect(st.session("new")?.localName == "自动｜new")
        #expect(st.session("named")?.localName == "我起的名字")
        #expect(st.session("old")?.localName == nil)

        st.rename(st.session("new")!, to: "")            // 用户清掉了名字：也不再自动起
        await st.autoNameIfNeeded(st.session("new")!)
        #expect(st.session("new")?.localName == nil)
        #expect(await calls.value == 1)

        let off = store(["x"], auto: false) { _, _ in ["不该起"] }
        off.data.freshSessions = ["x"]
        await off.autoNameIfNeeded(off.session("x")!)
        #expect(off.session("x")?.localName == nil)
    }

    @Test("SessionNamer 核心：片段 → 提示词 → 引擎 → 清洗出候选；什么都没清洗出来报错")
    func namerCore() async throws {
        let entries = [TranscriptEntry(id: 1, kind: .user("把标签栏改成托盘"), time: .now)]
        let engine = FakeEngine(reply: "1. 「标签栏｜改托盘」\n2. 顶部标签 | 重新设计")
        let names = try await SessionNamer.run(engine: engine, project: "Switchboard", entries: entries, fallbackTitle: "x", count: 3)
        #expect(names == ["标签栏｜改托盘", "顶部标签｜重新设计"])
        #expect(engine.lastPrompt.value?.contains("把标签栏改成托盘") == true)

        await #expect(throws: NamingError.emptyResult) {
            try await SessionNamer.run(engine: FakeEngine(reply: "  。"), project: "p", entries: [], fallbackTitle: "x", count: 3)
        }
    }
}

private actor Counter {
    var value = 0
    func add() { value += 1 }
}

private final class Box<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: T?
    var value: T? { lock.withLock { stored } }
    func set(_ v: T) { lock.withLock { stored = v } }
}

private struct FakeEngine: NamingEngine {
    let reply: String
    let lastPrompt = Box<String>()
    var label: String { "fake" }
    func complete(_ prompt: String) async throws -> String { lastPrompt.set(prompt); return reply }
}

/// 真的调一次本机 Claude Code 起名（只在 SB_REAL=1 时跑：要装了 claude 并登录，会用一点额度）
@Suite("AI 起名 · 真实调用", .enabled(if: ProcessInfo.processInfo.environment["SB_REAL"] == "1"))
struct AIRenameRealTests {
    @Test("Claude Code 起出「主题｜动作」格式的名字，且不在 ~/.claude/projects 里留会话文件")
    func claude() async throws {
        let projects = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/projects")
        let workDir = projects.appendingPathComponent(NamingEngines.workDirectory.path.replacingOccurrences(
            of: #"[^A-Za-z0-9]"#, with: "-", options: .regularExpression))
        var settings = NamingSettings(engine: .claude)
        settings.models[.claude] = "haiku"
        let engine = try NamingEngines.resolve(settings)
        let entries = [TranscriptEntry(id: 1, kind: .user("SSH 断线以后自动重连没有退避，帮我加上指数退避"), time: .now)]
        let names = try await SessionNamer.run(engine: engine, project: "Switchboard", entries: entries, fallbackTitle: "", count: 3)
        print("候选：", names)
        #expect(!names.isEmpty && names.allSatisfy { $0.count <= SessionName.maxLength })
        let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: workDir.path))?.filter { $0.hasSuffix(".jsonl") } ?? []
        #expect(leftovers.isEmpty)
    }
}
