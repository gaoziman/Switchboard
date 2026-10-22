import AppKit
import Foundation
import Testing
@testable import Screens

/// 项目 / 会话菜单背后的动作
@MainActor @Suite struct MenuActionsTests {
    func session(_ id: String, _ path: String, parent: String? = nil) -> Session {
        Session(id: id, cli: .claude, hostID: Host.localID, projectPath: path, title: id, lastActivity: .now, messageCount: 1,
                parentSessionID: parent)
    }

    @Test func deletableSkipsRunningAndSubagents() {
        let p = Project(hostID: Host.localID, path: "/p")
        let s = WorkspaceStore(hosts: [MockData.local], projects: [p],
                               sessions: [session("a", "/p"), session("b", "/p"),
                                          session("c", "/p", parent: "a"), session("d", "/q")], activity: ["b": .working])
        #expect(s.deletableSessions(in: p).map(\.id) == ["a"])
        #expect(s.allSessions(in: p).map(\.id).sorted() == ["a", "b"])
    }

    @Test func renameProjectPersistsInLibraryAndClears() {
        let p = Project(hostID: Host.localID, path: "/code/app")
        let s = WorkspaceStore(hosts: [MockData.local], projects: [p], sessions: [])
        s.rename(p, to: "  我的应用 ")
        #expect(s.library.projectNames[p.id.raw] == "我的应用")
        #expect(s.projects.first?.name == "我的应用")
        s.rename(p, to: "")
        #expect(s.library.projectNames[p.id.raw] == nil)
        #expect(s.projects.first?.name == "app")
    }

    @Test func oldLibraryWithoutProjectNamesLoads() throws {
        let s = try JSONDecoder().decode(LibraryState.self, from: Data(#"{"names":{"x":"y"}}"#.utf8))
        #expect(s.projectNames.isEmpty)
    }
}

@Suite struct ExternalEditorTests {
    @Test func listsOnlyInstalledAppsInFixedOrder() {
        let installed: Set<String> = ["com.apple.Terminal", "com.microsoft.VSCode", "dev.zed.Zed"]
        let apps = ExternalEditors.installed { installed.contains($0) ? URL(fileURLWithPath: "/Applications/\($0).app") : nil }
        #expect(apps.map(\.bundleID) == ["com.microsoft.VSCode", "dev.zed.Zed", "com.apple.Terminal"])   // 编辑器在前，终端在后
    }
}

@Suite struct ExportFormatTests {
    @Test func plainTextHasNoMarkdownSyntax() {
        let s = Session(id: "abc", cli: .claude, hostID: Host.localID, projectPath: "/p", title: "修登录", lastActivity: .now, messageCount: 2)
        let text = TranscriptExport.plainText(s, project: nil, entries: [.init(id: 0, kind: .user("怎么修？"), time: .now),
                                                                           .init(id: 1, kind: .assistant("**改** `auth.ts`"), time: .now),
                                                                           .init(id: 2, kind: .code(language: "swift", code: "let a = 1"), time: .now)])
        #expect(!text.contains("# "))
        #expect(!text.contains("```"))
        #expect(text.contains("修登录"))
        #expect(text.contains("你：怎么修？"))
        #expect(text.contains("let a = 1"))
    }
}

@MainActor
@Suite("⌘W 归谁")
struct CloseCommandTargetTests {
    @Test("只有工作区窗口在前面时 ⌘W 才关标签；设置窗口在前面时关设置窗口")
    func workspaceWindowOnly() {
        let store = WorkspaceStore(hosts: [MockData.local], projects: [], sessions: [])
        let workspace = NSWindow(), settings = NSWindow()
        store.hostWindow = workspace
        WorkspaceWindows.register(store)
        defer { WorkspaceWindows.unregister(store) }
        #expect(WorkspaceWindows.isWorkspace(workspace))
        #expect(!WorkspaceWindows.isWorkspace(settings))
    }
}
