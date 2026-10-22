import Foundation
import Testing
@testable import Screens

/// 会话库自己记的三样（置顶 / 改名 / 归档、SSH 主机、上次开着的标签）：存下来，下次启动读回来。
/// 用内存存储走一遍真实的保存 / 恢复路径（原来 isLive = false 时一律不存，这些路径测不到）
@MainActor
@Suite("存盘与恢复")
struct PersistenceTests {
    private let devbox = Screens.Host(id: "devbox", kind: .ssh(target: "devbox"), displayName: "devbox", connection: .disconnected)

    private func store(_ persistence: WorkspacePersistence, hosts extra: [Screens.Host] = []) -> WorkspaceStore {
        let sessions = ["s1", "s2"].map {
            Session(id: $0, cli: .claude, hostID: Host.localID, projectPath: "/p", title: $0, lastActivity: .now, messageCount: 1)
        }
        return WorkspaceStore(hosts: [MockData.local] + extra, projects: [Project(hostID: Host.localID, path: "/p")],
                              sessions: sessions, persistence: persistence)
    }

    @Test("置顶、改名：下次启动还在")
    func libraryRoundTrip() {
        let p = WorkspacePersistence.memory()
        let first = store(p)
        first.togglePin(first.session("s2")!)
        first.rename(first.session("s1")!, to: "改过名")
        let next = store(p)
        next.data.loadSavedState()
        #expect(next.library.pinnedSessions == ["s2"])
        #expect(next.library.names["s1"] == "改过名")
    }

    @Test("SSH 主机和它的定期重新登录设置：下次启动还在")
    func hostsRoundTrip() {
        let p = WorkspacePersistence.memory()
        let first = store(p, hosts: [devbox])
        first.setSignIn(SignInConfig(command: "kinit me", hours: 8), for: "devbox")
        let next = store(p)
        next.data.loadSavedState()
        #expect(next.hosts.map(\.id) == [Host.localID, "devbox"])
        #expect(next.hosts.last?.connection == .disconnected)
        #expect(next.signInConfigs["devbox"]?.command == "kinit me")
    }

    @Test("开着的标签：下次启动接着打开，选中的还选中")
    func tabsRoundTrip() {
        let p = WorkspacePersistence.memory()
        let first = store(p)
        first.resume(first.session("s1")!)
        first.resume(first.session("s2")!)
        first.selection = .tab(first.tab(for: first.session("s1")!)!.id)
        first.saveTabs()
        let next = store(p)
        next.restoreTabs()
        #expect(Set(next.allTabs.compactMap { next.session(for: $0)?.id }) == ["s1", "s2"])
        #expect(next.selectedTab.flatMap { next.session(for: $0) }?.id == "s1")
    }

    @Test("磁盘存储：文件名和格式和原来一样（老版本的数据直接能读）")
    func diskFormat() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("sb-persist-\(UUID())")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try Data(#"{"pinnedSessions":["s2"]}"#.utf8).write(to: dir.appendingPathComponent("library.json"))
        try Data(#"[{"alias":"devbox","installed":["claude"]}]"#.utf8).write(to: dir.appendingPathComponent("hosts.json"))
        let st = store(.disk(dir))
        st.data.loadSavedState()
        #expect(st.library.pinnedSessions == ["s2"])
        #expect(st.hosts.last?.installedCLIs == [.claude])
        st.togglePin(st.session("s1")!)
        let saved = try JSONDecoder().decode(LibraryState.self, from: Data(contentsOf: dir.appendingPathComponent("library.json")))
        #expect(saved.pinnedSessions == ["s2", "s1"])
    }

    @Test("library.json 坏了：先改名留着，用空状态，不把它盖掉")
    func corruptLibraryIsBackedUp() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("sb-persist-\(UUID())")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        try Data("{ not json".utf8).write(to: dir.appendingPathComponent("library.json"))
        #expect(WorkspacePersistence.disk(dir).loadLibrary() == LibraryState())
        let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        #expect(files.contains { $0.hasPrefix("library.json.bak") } && !files.contains("library.json"))
    }

    @Test("截图、单测用的 store 默认存在内存里，不碰你的真实数据")
    func defaultIsMemory() {
        let st = WorkspaceStore(hosts: [MockData.local], projects: [], sessions: [])
        #expect(!st.data.persistence.isDisk)
    }
}
