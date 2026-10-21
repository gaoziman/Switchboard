import Foundation
import Testing
@testable import Screens

/// 会话库只显示手动添加的文件夹（design/folder-library.md）
@Suite struct FolderLibraryTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func session(_ path: String, host: String = Host.localID, daysAgo: Double = 0, parent: String? = nil, id: String = UUID().uuidString) -> Session {
        Session(id: id, cli: .claude, hostID: host, projectPath: path, title: "t",
                lastActivity: now.addingTimeInterval(-daysAgo * 86_400), messageCount: 1, parentSessionID: parent)
    }

    // MARK: Claude 目录名

    @Test func claudeDirectoryNameReplacesEveryNonAlphanumeric() {
        #expect(FolderLibrary.claudeDirectoryName(for: "/Volumes/Sam990/ProjectDock/vibe-coding") == "-Volumes-Sam990-ProjectDock-vibe-coding")
        #expect(FolderLibrary.claudeDirectoryName(for: "/private/tmp") == "-private-tmp")
        #expect(FolderLibrary.claudeDirectoryName(for: "/") == "-")
        #expect(FolderLibrary.claudeDirectoryName(for: "/a/b.c_d e") == "-a-b-c-d-e")
        // 和 Claude Code 一样按 UTF-16 单元换：一个汉字一个 -
        #expect(FolderLibrary.claudeDirectoryName(for: "/a/中文") == "-a---")
    }

    // MARK: 只留添加过的文件夹（精确匹配，子文件夹不算）

    @Test func keepsOnlySessionsInAddedFoldersExactly() {
        let a = session("/code/app"), sub = session("/code/app/sub"), other = session("/code/other")
        let remote = session("/code/app", host: "devbox")
        let kept = FolderLibrary.sessions([a, sub, other, remote], in: ["local:/code/app"])
        #expect(kept.map(\.id) == [a.id])
    }

    // MARK: 候选索引

    @Test func indexGroupsTopLevelSessionsByFolder() {
        let list = [session("/code/app", daysAgo: 3), session("/code/app", daysAgo: 1),
                    session("/code/app", daysAgo: 0, parent: "x"),          // 子代理不计数
                    session("/code/web", daysAgo: 9)]
        let index = FolderLibrary.index(list, exists: { _ in true })
        #expect(index.map(\.path) == ["/code/app", "/code/web"])            // 最近活动在前
        #expect(index[0].sessionCount == 2)
        #expect(index[0].lastActivity == now.addingTimeInterval(-86_400))
        #expect(index[0].id == "local:/code/app")
    }

    // MARK: 升级时默认勾哪些

    @Test func defaultPicksRecentPinnedAndOpen() {
        let index = FolderLibrary.index([session("/code/recent", daysAgo: 2), session("/code/old", daysAgo: 40),
                                         session("/code/pinned", daysAgo: 90), session("/code/open", daysAgo: 60),
                                         session("/private/tmp/x", daysAgo: 0), session("/", daysAgo: 0),
                                         session("/code/gone", daysAgo: 1)],
                                        exists: { $0 != "/code/gone" })
        let picks = FolderLibrary.defaultPicks(index, pinned: ["local:/code/pinned"], openTabs: ["local:/code/open"], now: now)
        #expect(picks == ["local:/code/recent", "local:/code/open", "local:/code/pinned"])   // 最近活动在前
    }

    @Test func scratchFolders() {
        for p in ["/", NSHomeDirectory(), "/tmp", "/tmp/a", "/private/tmp/b", "/private/var/folders/68/x/T/y", "/var/folders/z",
                  // 隐藏目录里的（工具自己的工作区，比如 ~/.tds/workspaces/<uuid>）
                  NSHomeDirectory() + "/.tds", NSHomeDirectory() + "/.tds/workspaces/01a13b40-33cf"] {
            #expect(FolderLibrary.isScratch(p), "\(p)")
        }
        for p in ["/code/app", NSHomeDirectory() + "/code", "/tmpfoo", "/code/v1.2"] {
            #expect(!FolderLibrary.isScratch(p), "\(p)")
        }
    }

    // MARK: 后台发现没添加的文件夹里有会话在跑

    @Test func runningOutsideLibrary() {
        let running = [("s1", "/code/app"), ("s2", "/code/new"), ("s3", "/code/new"), ("s4", "/code/ignored")]
        let found = FolderLibrary.runningOutside(running, folders: ["local:/code/app"], dismissed: ["local:/code/ignored"])
        #expect(found.count == 1)
        #expect(found.first?.path == "/code/new")
        #expect(found.first?.count == 2)
    }
}

/// library.json：新字段、旧文件兼容、坏文件不覆盖
@Suite struct LibraryFileTests {
    func tempFile(_ text: String?) -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("sb-lib-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("library.json")
        if let text { try? Data(text.utf8).write(to: url) }
        return url
    }

    @Test func oldFileWithoutFolderFieldsStillLoads() {
        let url = tempFile(#"{"pinnedProjects":["local:/a"],"addedProjects":["/b"]}"#)
        let s = LibraryState.load(from: url)
        #expect(s.pinnedProjects == ["local:/a"])
        #expect(s.addedProjects == ["/b"])
        #expect(s.folders.isEmpty)
        #expect(!s.foldersMigrated)
        #expect(s.dismissedFolders.isEmpty)
    }

    @Test func corruptFileIsBackedUpNotOverwritten() throws {
        let url = tempFile("{ not json")
        let s = LibraryState.load(from: url)
        #expect(s == LibraryState())
        let siblings = try FileManager.default.contentsOfDirectory(atPath: url.deletingLastPathComponent().path)
        #expect(siblings.contains { $0.hasPrefix("library.json.bak") })
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func missingFileIsEmpty() {
        #expect(LibraryState.load(from: tempFile(nil)) == LibraryState())
    }

    @Test func migrationFoldsOldAddedProjects() {
        var s = LibraryState()
        s.addedProjects = ["/b"]
        s.finishFolderMigration(picked: ["local:/a"])
        #expect(s.folders == ["local:/a", "local:/b"])
        #expect(s.foldersMigrated)
        #expect(s.addedProjects.isEmpty)
    }
}

/// 只读添加过的文件夹：Claude 直接定位目录，其他来源按 cwd 过滤
@Suite struct ScopedDiscoveryTests {
    func claudeRoot(_ cwds: [String: String]) -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("sb-claude-\(UUID().uuidString)")
        for (id, cwd) in cwds {
            let dir = root.appendingPathComponent("projects").appendingPathComponent(FolderLibrary.claudeDirectoryName(for: cwd))
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let line = #"{"type":"user","cwd":"\#(cwd)","timestamp":"2026-10-20T10:00:00Z","message":{"role":"user","content":"hi \#(id)"}}"#
            try? Data((line + "\n").utf8).write(to: dir.appendingPathComponent("\(id).jsonl"))
        }
        return root
    }

    @Test func claudeReadsOnlyAddedFolders() {
        let root = claudeRoot(["a1": "/code/app", "a2": "/code/app", "b1": "/code/other", "c1": "/code/app/sub"])
        let source = ClaudeSource(mirror: root, hostID: Host.localID)
        #expect(Set(source.discover(in: ["/code/app"]).map(\.id)) == ["a1", "a2"])
        #expect(Set(source.discover(in: nil).map(\.id)) == ["a1", "a2", "b1", "c1"])
        #expect(source.discover(in: []).isEmpty)
    }

    @Test func claudeDirectoryNameCollisionStillFiltersByCwd() {
        // /code/a-b 和 /code/a.b 编码后同名，同一个目录：按 cwd 再过滤一次
        let root = claudeRoot(["x": "/code/a-b"])
        let dir = root.appendingPathComponent("projects").appendingPathComponent(FolderLibrary.claudeDirectoryName(for: "/code/a.b"))
        let line = #"{"type":"user","cwd":"/code/a.b","timestamp":"2026-10-20T10:00:00Z","message":{"role":"user","content":"hi"}}"#
        try? Data((line + "\n").utf8).write(to: dir.appendingPathComponent("y.jsonl"))
        let source = ClaudeSource(mirror: root, hostID: Host.localID)
        #expect(source.discover(in: ["/code/a.b"]).map(\.id) == ["y"])
    }
}

/// store 上的添加 / 移除 / 升级挑选 / 忽略（fixture store：不写盘）
@MainActor @Suite struct FolderStoreTests {
    func session(_ path: String, _ id: String) -> Session {
        Session(id: id, cli: .claude, hostID: Host.localID, projectPath: path, title: id, lastActivity: .now, messageCount: 1)
    }

    func store() -> WorkspaceStore {
        let s = WorkspaceStore(hosts: [MockData.local], projects: [Project(hostID: Host.localID, path: "/a")],
                               sessions: [session("/a", "a1"), session("/a", "a2")])
        s.library.folders = ["local:/a"]
        s.library.foldersMigrated = true
        return s
    }

    @Test func addFolderListsItEvenWithoutSessions() {
        let s = store()
        s.addFolder("/c/./d/")
        #expect(s.library.folders == ["local:/a", "local:/c/d"])
        #expect(s.projects.contains { $0.id == "local:/c/d" })
        #expect(s.expandedProjectIDs.contains("local:/c/d"))
        s.addFolder("/c/d")                                   // 再加一次不重复
        #expect(s.library.folders.count == 2)
        s.addFolder("relative/path")                          // 不是绝对路径：不加
        #expect(s.library.folders.count == 2)
    }

    @Test func remoteTildeFolderIsStoredAsAbsolutePath() async {
        let s = store()
        s.data.remoteHomes["devbox"] = "/home/leo"
        await s.addRemoteFolder(" ~/proj ", on: "devbox", refreshNow: false)
        #expect(s.library.folders.contains("devbox:/home/leo/proj"))
        await s.addRemoteFolder("/srv/app", on: "devbox", refreshNow: false)
        #expect(s.library.folders.contains("devbox:/srv/app"))
        // 不知道家目录（问不到）：不加，也不存成 ~
        await s.addRemoteFolder("~/x", on: "other", refreshNow: false)
        #expect(!s.library.folders.contains { $0.hasPrefix("other:") })
    }

    @Test func emptyCandidateListStillCountsAsLoaded() {
        let s = store()
        #expect(!s.folderCandidatesLoaded(on: "devbox"))
        s.data.folderCandidates["devbox"] = []                // 主机上一个会话都没有
        #expect(s.folderCandidatesLoaded(on: "devbox"))
    }

    @Test func removeFolderHidesButKeepsLibraryMarks() {
        let s = store()
        s.library.pinnedSessions = ["a1"]
        s.library.names = ["a1": "改过的名字"]
        let project = s.projects[0]
        s.removeFolder(project)
        #expect(s.library.folders.isEmpty)
        #expect(s.projects.isEmpty)
        #expect(s.sessions.isEmpty)
        #expect(s.library.pinnedSessions == ["a1"])           // 记录留着，加回来还在
        #expect(s.library.names["a1"] == "改过的名字")
    }

    @Test func migrationWithNothingFoundFinishesSilently() {
        let s = store()
        s.library.foldersMigrated = false
        s.prepareMigration(index: [], openTabs: [])
        #expect(s.library.foldersMigrated)
        #expect(s.migrationCandidates == nil)
    }

    @Test func migrationPicksThenFinishes() {
        let s = store()
        s.library = LibraryState()
        s.library.pinnedProjects = ["local:/old"]
        let index = FolderLibrary.index([session("/a", "x"), Session(id: "o", cli: .codex, hostID: Host.localID, projectPath: "/old",
                                                                      title: "o", lastActivity: .distantPast, messageCount: 1)],
                                        exists: { _ in true })
        s.prepareMigration(index: index, openTabs: [])
        #expect(s.migrationCandidates?.count == 2)
        #expect(s.migrationPicks == ["local:/a", "local:/old"])
        s.finishMigration(picked: ["local:/old"])
        #expect(s.library.folders == ["local:/old"])
        #expect(s.library.foldersMigrated)
        #expect(s.migrationCandidates == nil)
    }

    @Test func dismissOutsideStopsPrompting() {
        let s = store()
        s.outsideRunning = [FolderLibrary.Outside(path: "/x", count: 1)]
        s.dismissOutside(s.outsideRunning[0])
        #expect(s.outsideRunning.isEmpty)
        #expect(s.library.dismissedFolders == ["local:/x"])
        s.addFolder("/x")                                     // 后来又主动加了：从忽略里拿掉
        #expect(s.library.dismissedFolders.isEmpty)
    }
}
