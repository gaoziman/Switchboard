import Foundation

/// 会话库里的文件夹：添加、移除、升级挑选、候选索引、库外在跑的提示（design/folder-library.md）
@MainActor
public extension WorkspaceStore {
    /// 某台主机上添加过的文件夹路径
    func folderPaths(on hostID: String) -> Set<String> { data.folderPaths(on: hostID) }

    func isInLibrary(_ projectID: ProjectID) -> Bool { library.folders.contains(projectID.raw) }

    /// 某台主机上添加过的文件夹的项目 ID（library.json 里存的是字符串）
    func folderIDs(on hostID: String) -> Set<ProjectID> { Set(library.folders.compactMap(ProjectID.init(raw:)).filter { $0.host == hostID }) }

    /// 加一个文件夹进会话库（本机路径规范化；已经在了就只展开）。加完读一次它的会话
    func addFolder(_ path: String, on hostID: String = Host.localID, refreshNow: Bool = true) {
        let p = hostID == Host.localID ? ((path as NSString).expandingTildeInPath as NSString).standardizingPath : path
        guard p.hasPrefix("/") else { return }
        let id = ProjectID(host: hostID, path: p)
        expandedProjectIDs.insert(id)
        guard !isInLibrary(id) else { return }
        updateLibrary { s in
            s.folders.append(id.raw)
            s.dismissedFolders.remove(id.raw)
        }
        outsideRunning.removeAll { $0.id == id }
        guard isLive, refreshNow else { return }
        Task { await data.refresh(.folders(hostID)) }
    }

    /// 主机上的文件夹：`~/x` 先问主机家目录换成绝对路径（会话文件里记的是绝对路径），问不到就不加
    func addRemoteFolder(_ path: String, on alias: String, refreshNow: Bool = true) async {
        var p = path.trimmingCharacters(in: .whitespaces)
        if SSH.needsHome(p) {
            if data.remoteHomes[alias] == nil, isLive {
                data.remoteHomes[alias] = await SSH.offPool { SSH.home(alias) }
            }
            guard let home = data.remoteHomes[alias] else { return }
            p = SSH.expandingHome(p, home: home)
        }
        addFolder(p, on: alias, refreshNow: refreshNow)
    }

    /// 从会话库拿掉：只是不显示，会话文件一个不动；置顶、重命名、归档的记录留着，以后加回来还在
    func removeFolder(_ project: Project) {
        updateLibrary { s in s.folders.removeAll { $0 == project.id.raw } }
        projects.removeAll { $0.id == project.id }
        let open = openTabSessionIDs
        sessions.removeAll { $0.projectID == project.id && !open.contains($0.id) }
        expandedProjectIDs.remove(project.id)
        if case .preview(let id)? = selection, session(id)?.projectID == project.id || session(id) == nil { selection = nil }
    }

    // MARK: 升级挑选

    /// 挑完了（全都不要 = 空数组）
    func finishMigration(picked: [ProjectID]) {
        updateLibrary { $0.finishFolderMigration(picked: picked.map(\.raw)) }
        data.migrationCandidates = nil
        if let first = picked.first { expandedProjectIDs.insert(first) }
        // 启动时挑选还没做完，那次恢复标签时会话库是空的，什么都没接回来：挑完再恢复一次
        if isLive { Task { await data.refresh(); restoreTabs() } }
    }

    var migrationCandidates: [FolderLibrary.Candidate]? { data.migrationCandidates }
    var migrationPicks: [ProjectID] { data.migrationPicks }

    // MARK: 候选索引（按需）

    func folderCandidates(on hostID: String) -> [FolderLibrary.Candidate] { data.folderCandidates[hostID] ?? [] }

    /// 读过一次了（哪怕一个都没有）：添加面板不再显示「正在读取」
    func folderCandidatesLoaded(on hostID: String) -> Bool { data.folderCandidates[hostID] != nil }

    /// 本机：全量扫一遍（走摘要缓存，第二次起很快）；SSH 主机：读本机镜像
    func loadFolderCandidates(on hostID: String) async {
        let sessions: [Session]
        let reader = data.reader
        if hostID == Host.localID {
            sessions = await Task.detached(priority: .utility) { await reader.local(nil).sessions }.value
        } else {
            sessions = await reader.mirror(hostID)
        }
        let local = hostID == Host.localID
        data.folderCandidates[hostID] = FolderLibrary.index(sessions) { local ? FileManager.default.fileExists(atPath: $0) : true }
    }

    // MARK: 库外在跑

    var outsideRunning: [FolderLibrary.Outside] {
        get { data.outsideRunning }
        set { data.outsideRunning = newValue }
    }

    /// 本机 Claude 报的「在跑的会话 + 工作目录」里，文件夹不在库里、也没被忽略的
    func checkOutsideRunning() {
        guard library.foldersMigrated else { return }
        let running = ActivityMonitor.claudeRunning().map { ($0.sessionID, ($0.cwd as NSString).standardizingPath) }
        let found = FolderLibrary.runningOutside(running, folders: library.folderIDs, dismissed: library.dismissedFolderIDs)
        if found != outsideRunning { outsideRunning = found }
    }

    /// 「忽略」：这个文件夹以后不再提示
    func dismissOutside(_ outside: FolderLibrary.Outside) {
        updateLibrary { s in s.dismissedFolders.insert(outside.id.raw) }
        outsideRunning.removeAll { $0.id == outside.id }
    }
}
