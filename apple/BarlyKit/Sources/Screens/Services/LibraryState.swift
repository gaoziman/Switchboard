import Foundation

/// Switchboard 自己的会话库状态：置顶顺序、本地重命名、归档、按 CLI 保存的启动命令。
/// 不改 CLI 的任何文件，存在 library.json（WorkspacePersistence）
public struct LibraryState: Codable, Equatable, Sendable {
    /// 置顶的项目 ID，按置顶顺序
    public var pinnedProjects: [String] = []
    /// 置顶的会话 ID，按置顶顺序
    public var pinnedSessions: [String] = []
    /// 会话 ID → 本地名字
    public var names: [String: String] = [:]
    /// 项目 ID → 本地名字（重命名项目；只改 Switchboard 里的显示）
    public var projectNames: [String: String] = [:]
    public var archivedSessions: Set<String> = []
    public var archivedProjects: Set<String> = []
    /// CLI → 保存过的启动命令
    public var commands: [String: String] = [:]
    /// 旧版本手动加的本机文件夹（路径）。升级挑选时并进 folders，之后不再用
    public var addedProjects: [String] = []
    /// 会话库里的文件夹：项目 ID「主机:路径」，按添加顺序。侧栏只显示这些（design/folder-library.md）
    public var folders: [String] = []
    /// 升级到「手动添加文件夹」后挑过一次了（没挑过：启动时弹挑选）
    public var foldersMigrated = false
    /// 库外有会话在跑时点过「忽略」的文件夹（项目 ID），不再提示
    public var dismissedFolders: Set<String> = []

    public init() {}

    /// 升级挑选完成：挑中的 + 旧版本手动加的，去重保序
    mutating func finishFolderMigration(picked: [String]) {
        for id in picked + addedProjects.map({ "\(Host.localID):\($0)" }) where !folders.contains(id) { folders.append(id) }
        addedProjects = []
        foldersMigrated = true
    }

    /// 旧版本存的文件少字段也能读
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pinnedProjects = try c.decodeIfPresent([String].self, forKey: .pinnedProjects) ?? []
        pinnedSessions = try c.decodeIfPresent([String].self, forKey: .pinnedSessions) ?? []
        names = try c.decodeIfPresent([String: String].self, forKey: .names) ?? [:]
        projectNames = try c.decodeIfPresent([String: String].self, forKey: .projectNames) ?? [:]
        archivedSessions = try c.decodeIfPresent(Set<String>.self, forKey: .archivedSessions) ?? []
        archivedProjects = try c.decodeIfPresent(Set<String>.self, forKey: .archivedProjects) ?? []
        commands = try c.decodeIfPresent([String: String].self, forKey: .commands) ?? [:]
        addedProjects = try c.decodeIfPresent([String].self, forKey: .addedProjects) ?? []
        folders = try c.decodeIfPresent([String].self, forKey: .folders) ?? []
        foldersMigrated = try c.decodeIfPresent(Bool.self, forKey: .foldersMigrated) ?? false
        dismissedFolders = try c.decodeIfPresent(Set<String>.self, forKey: .dismissedFolders) ?? []
    }
}

@MainActor
public extension WorkspaceStore {
    /// 把本地状态盖到刚读出来的会话和项目上。在局部数组上改完一次写回：`sessions` 是转到 data 的计算属性，`sessions[i].x = v` 每次都整组拷贝、发一次变更通知
    func applyLibraryState() {
        let state = library
        var projects = self.projects
        var known = Set(projects.map(\.id))
        // 会话库里的文件夹还没有会话也列出来
        for id in state.folders where !known.contains(id) {
            guard let colon = id.firstIndex(of: ":") else { continue }
            let host = String(id[..<colon]), path = String(id[id.index(after: colon)...])
            let local = host == Host.localID
            projects.append(Project(hostID: host, path: path, folderExists: !local || FileManager.default.fileExists(atPath: path)))
            known.insert(id)
        }
        let pinnedProjects = Set(state.pinnedProjects)
        for i in projects.indices {
            projects[i].isPinned = pinnedProjects.contains(projects[i].id)
            projects[i].isArchived = state.archivedProjects.contains(projects[i].id)
            projects[i].customName = state.projectNames[projects[i].id]
        }
        var sessions = self.sessions
        let pinnedSessions = Set(state.pinnedSessions)
        for i in sessions.indices {
            let id = sessions[i].id
            sessions[i].isPinned = pinnedSessions.contains(id)
            sessions[i].isArchived = state.archivedSessions.contains(id)
            sessions[i].localName = state.names[id]
        }
        if projects != self.projects { self.projects = projects }
        if sessions != self.sessions { self.sessions = sessions }
    }

    func updateLibrary(_ change: (inout LibraryState) -> Void) {
        change(&library)
        data.persistence.saveLibrary(library)
        applyLibraryState()
    }

    func togglePin(_ session: Session) {
        updateLibrary { s in
            if let i = s.pinnedSessions.firstIndex(of: session.id) { s.pinnedSessions.remove(at: i) } else { s.pinnedSessions.append(session.id) }
        }
    }

    func togglePin(_ project: Project) {
        updateLibrary { s in
            if let i = s.pinnedProjects.firstIndex(of: project.id) { s.pinnedProjects.remove(at: i) } else { s.pinnedProjects.append(project.id) }
        }
    }

    /// 空名字 = 恢复 CLI 自己的标题
    func rename(_ session: Session, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updateLibrary { s in s.names[session.id] = trimmed.isEmpty || trimmed == session.title ? nil : trimmed }
        for g in tabGroups.indices {
            for t in tabGroups[g].tabs.indices where tabGroups[g].tabs[t].kind == .session(id: session.id, cli: session.cli) {
                tabGroups[g].tabs[t].title = trimmed.isEmpty ? session.title : trimmed
            }
        }
    }

    func setArchived(_ sessionIDs: [String], _ archived: Bool) {
        updateLibrary { s in
            for id in sessionIDs { if archived { s.archivedSessions.insert(id) } else { s.archivedSessions.remove(id) } }
        }
        if archived, case .preview(let id)? = selection, sessionIDs.contains(id), !showsArchived { selection = nil }
    }

    func setArchived(_ project: Project, _ archived: Bool) {
        updateLibrary { s in
            if archived { s.archivedProjects.insert(project.id) } else { s.archivedProjects.remove(project.id) }
        }
    }

    /// 手动加一个本机文件夹（访达里选的、拖进来的）
    func addProject(_ path: String) { addFolder(path) }

    /// 保存过的启动命令（nil = 默认）
    func savedCommand(for cli: CLIKind) -> String? { library.commands[cli.rawValue] }

    func saveCommand(_ command: String?, for cli: CLIKind) {
        updateLibrary { s in s.commands[cli.rawValue] = command }
    }
}
