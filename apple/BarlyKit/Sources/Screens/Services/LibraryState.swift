import Foundation

/// Switchboard 自己的会话库状态：置顶顺序、本地重命名、归档、按 CLI 保存的启动命令。
/// 不改 CLI 的任何文件，存在 ~/Library/Application Support/Switchboard/library.json
public struct LibraryState: Codable, Equatable, Sendable {
    /// 置顶的项目 ID，按置顶顺序
    public var pinnedProjects: [String] = []
    /// 置顶的会话 ID，按置顶顺序
    public var pinnedSessions: [String] = []
    /// 会话 ID → 本地名字
    public var names: [String: String] = [:]
    public var archivedSessions: Set<String> = []
    public var archivedProjects: Set<String> = []
    /// CLI → 保存过的启动命令
    public var commands: [String: String] = [:]
    /// 手动加的项目文件夹（还没有会话也列出来）
    public var addedProjects: [String] = []

    public init() {}

    /// 旧版本存的文件少字段也能读
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pinnedProjects = try c.decodeIfPresent([String].self, forKey: .pinnedProjects) ?? []
        pinnedSessions = try c.decodeIfPresent([String].self, forKey: .pinnedSessions) ?? []
        names = try c.decodeIfPresent([String: String].self, forKey: .names) ?? [:]
        archivedSessions = try c.decodeIfPresent(Set<String>.self, forKey: .archivedSessions) ?? []
        archivedProjects = try c.decodeIfPresent(Set<String>.self, forKey: .archivedProjects) ?? []
        commands = try c.decodeIfPresent([String: String].self, forKey: .commands) ?? [:]
        addedProjects = try c.decodeIfPresent([String].self, forKey: .addedProjects) ?? []
    }

    static var file: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Switchboard", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("library.json")
    }

    public static func load() -> LibraryState {
        (try? JSONDecoder().decode(LibraryState.self, from: Data(contentsOf: file))) ?? LibraryState()
    }

    public func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(self) { try? data.write(to: Self.file, options: .atomic) }
    }
}

@MainActor
public extension WorkspaceStore {
    /// 把本地状态盖到刚读出来的会话和项目上
    func applyLibraryState() {
        let state = library
        for path in state.addedProjects where !projects.contains(where: { $0.hostID == Host.localID && $0.path == path }) {
            projects.append(Project(hostID: Host.localID, path: path, folderExists: FileManager.default.fileExists(atPath: path)))
        }
        for i in projects.indices {
            projects[i].isPinned = state.pinnedProjects.contains(projects[i].id)
            projects[i].isArchived = state.archivedProjects.contains(projects[i].id)
        }
        for i in sessions.indices {
            let id = sessions[i].id
            sessions[i].isPinned = state.pinnedSessions.contains(id)
            sessions[i].isArchived = state.archivedSessions.contains(id)
            sessions[i].localName = state.names[id]
        }
    }

    private func updateLibrary(_ change: (inout LibraryState) -> Void) {
        change(&library)
        if isLive { library.save() }
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

    /// 手动加一个项目文件夹
    func addProject(_ path: String) {
        let p = (path as NSString).standardizingPath
        updateLibrary { s in if !s.addedProjects.contains(p) { s.addedProjects.append(p) } }
        expandedProjectIDs.insert("\(Host.localID):\(p)")
    }

    /// 保存过的启动命令（nil = 默认）
    func savedCommand(for cli: CLIKind) -> String? { library.commands[cli.rawValue] }

    func saveCommand(_ command: String?, for cli: CLIKind) {
        updateLibrary { s in s.commands[cli.rawValue] = command }
    }
}
