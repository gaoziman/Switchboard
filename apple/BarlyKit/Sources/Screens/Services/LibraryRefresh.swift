import Foundation

// MARK: - Port

/// 读会话：本机四个 CLI 的文件、主机在本机的镜像。真实运行用 SessionDiscovery（还会写 ~/Library/Caches 的摘要缓存）；
/// 截图、单测默认 .empty，测刷新编排时换成内存里的假来源
public struct SessionReader: Sendable {
    /// folders：只读这些本机文件夹（会话库里的）；nil = 全读（升级挑选）
    var local: @Sendable (_ folders: Set<String>?) async -> SessionDiscovery.Result
    var mirror: @Sendable (_ alias: String) async -> [Session]

    public static let live = SessionReader(local: { await SessionDiscovery.run(folders: $0) },
                                           mirror: { await SessionDiscovery.runRemote($0) })
    public static let empty = SessionReader(local: { _ in SessionDiscovery.Result(sessions: [], projects: [], installed: [], elapsed: 0) },
                                            mirror: { _ in [] })
}

/// 和 SSH 主机打交道：rsync 镜像它的会话、问它在跑什么。真实运行起 rsync / ssh；截图、单测默认 .offline（谁都连不上）
public struct HostLink: Sendable {
    /// 镜像到本机；nil = 成功，否则是 ssh / rsync 说的原因
    var mirror: @Sendable (_ alias: String, _ progress: @escaping @Sendable (Int, Int) -> Void) async -> String?
    var snapshot: @Sendable (_ alias: String) async -> RemoteSessions.Snapshot?

    public static let live = HostLink(mirror: { await SSH.mirror($0, progress: $1) },
                                      snapshot: { alias in await SSH.offPool { RemoteSessions.snapshot(alias) } })
    public static let offline = HostLink(mirror: { _, _ in "offline" }, snapshot: { _ in nil })
}

/// 找 tmux 和 CLI 的可执行文件。真实运行查这台机器（内置 tmux → PATH）；截图、单测默认 .pretendInstalled：
/// 当 CLI 都装在 /usr/local/bin、没有 tmux，结果不取决于跑测试的机器装了什么
public struct Toolbox: Sendable {
    var tmux: @Sendable () -> String?
    var which: @Sendable (_ name: String) -> String?

    public static let live = Toolbox(tmux: { Tmux.executable }, which: { ShellEnvironment.shared.which($0) })
    public static let pretendInstalled = Toolbox(tmux: { nil }, which: { $0.hasPrefix("/") ? $0 : "/usr/local/bin/\($0)" })
}

/// 刷新什么
public enum RefreshScope: Hashable, Sendable {
    /// 本机会话库（走摘要缓存，很快）
    case local
    /// 这台机器上会话库里的文件夹变了：本机就重读，主机就重读已有的镜像（不连网）
    case folders(String)
    /// rsync 重新镜像这台主机再重读（最长 10 分钟）
    case host(String)
    /// 本机 + 所有没断开的主机
    case everything
}

// MARK: - 刷新编排

@MainActor
public extension WorkspaceData {
    /// 第一个窗口建好后调一次：读存盘的会话库和主机 → 读本机（上次开着的标签恢复到主窗口）→ 镜像所有主机
    func start() async {
        loadSavedState()
        await refreshLocal(restoringTabs: true)
        await refreshHosts()
    }

    /// 读存盘的会话库和主机（连同重新登录设置）。只读一次；要在任何会改它们的操作之前（以前等第一次扫描完才读，
    /// 期间的改动会把文件整个盖掉）
    func loadSavedState() {
        guard !savedStateLoaded else { return }
        savedStateLoaded = true
        library = persistence.loadLibrary()
        let records = persistence.loadHosts()
        for r in records { if let c = r.signIn { signInConfigs[r.alias] = c } }
        for r in records where !hosts.contains(where: { $0.id == r.alias }) {
            hosts.append(Host(id: r.alias, kind: .ssh(target: r.alias), displayName: r.alias,
                              connection: r.disconnected == true ? .disconnected : .refreshing(done: 0, total: 3),
                              installedCLIs: (r.installed ?? []).compactMap(CLIKind.init(rawValue:))))
        }
    }

    /// 返回时：数据是最新的，每个窗口都认领过自己的新会话标签、刷过状态灯，该恢复的标签已经在主窗口恢复。
    /// 本机：正在读时不叠着读，读完补读一次，等补读完才返回（刚删的会话、刚加的文件夹马上看得到）。
    /// 主机：同一台的镜像正在跑就直接返回。不抛错：主机连不上记在 hosts[i].connection，已有的会话列表留着
    func refresh(_ scope: RefreshScope = .local) async {
        switch scope {
        case .local: await refreshLocal(restoringTabs: false)
        case .folders(let host): if host == Host.localID { await refreshLocal(restoringTabs: false) } else { await reloadHost(host) }
        case .host(let alias): await refreshHost(alias)
        case .everything:
            await refreshLocal(restoringTabs: false)
            await refreshHosts()
        }
    }

    /// 每台连着的主机问一次在跑什么；同一台上一次还没问完就跳过，问不到的越隔越久再问
    func pollHosts(now: Date = Date()) async {
        for host in hosts where !host.isLocal && host.connection == .connected {
            let alias = host.id
            guard shouldPoll(alias, now: now), beginHostJob(.poll, alias) else { continue }
            let snap = await link.snapshot(alias)
            endHostJob(.poll, alias)
            recordSnapshot(snap, for: alias, now: now)
        }
    }

    // MARK: 窗口

    /// 开着的窗口，按打开先后；第一个是主窗口（展开项目、恢复标签、自检参数由它做）
    var windows: [WorkspaceStore] {
        windowRefs.removeAll { $0.store == nil }
        return windowRefs.compactMap(\.store)
    }

    var primaryWindow: WorkspaceStore? { windows.first }

    func attach(_ store: WorkspaceStore) {
        guard !windowRefs.contains(where: { $0.store === store }) else { return }
        windowRefs.append(WindowRef(store))
    }

    func detach(_ store: WorkspaceStore) { windowRefs.removeAll { $0.store == nil || $0.store === store } }

    /// 所有窗口里开着标签的会话
    var openTabSessionIDs: Set<String> { Set(windows.flatMap(\.allTabs).compactMap(\.kind.sessionID)) }

    // MARK: 会话库

    func updateLibrary(_ change: (inout LibraryState) -> Void) {
        change(&library)
        persistence.saveLibrary(library)
    }

    /// 换掉一台主机的会话（刷新读完时）：状态按会话 ID 存，还在的不用搬；不在了的状态清掉（和原来一样：消失再出现的从「没在跑」算起）
    func replaceSessions(on hostID: String, with fresh: [Session]) {
        let gone = Set(sessions.filter { $0.hostID == hostID }.map(\.id)).subtracting(fresh.map(\.id))
        sessions = sessions.filter { $0.hostID != hostID } + fresh
        if !gone.isEmpty { activity = activity.filter { !gone.contains($0.key) } }
    }

    /// 某台主机上添加过的文件夹路径
    func folderPaths(on hostID: String) -> Set<String> {
        Set(library.folders.compactMap(ProjectID.init(raw:)).filter { $0.host == hostID }.map(\.path))
    }

    // MARK: 主机任务、轮询退避

    enum HostJob { case poll, refresh }

    /// 这台主机这种活没在做就记上、返回 true；在做就返回 false（调用方跳过）
    func beginHostJob(_ job: HostJob, _ alias: String) -> Bool { hostJobs.insert("\(job):\(alias)").inserted }

    func endHostJob(_ job: HostJob, _ alias: String) { hostJobs.remove("\(job):\(alias)") }

    /// 问不到（nil）先留着上次的：偶尔一次超时灯不闪；连续 3 次问不到就清掉，别一直显示主机掉线前的状态。
    /// 问不到还要退避：主机关机、VPN 断了的时候别每 5 秒起一次 ssh（每次最长 15 秒）
    func recordSnapshot(_ snap: RemoteSessions.Snapshot?, for alias: String, now: Date = Date()) {
        if let snap {
            remoteSnapshots[alias] = snap
            snapshotFailures[alias] = nil
            nextPollAt[alias] = nil
            return
        }
        let failures = (snapshotFailures[alias] ?? 0) + 1
        snapshotFailures[alias] = failures
        nextPollAt[alias] = now.addingTimeInterval(WorkspaceStore.pollBackoff(failures: failures))
        if failures >= 3 { remoteSnapshots[alias] = nil }
    }

    func shouldPoll(_ alias: String, now: Date = Date()) -> Bool { (nextPollAt[alias] ?? .distantPast) <= now }
}

// MARK: - 实现

@MainActor
extension WorkspaceData {
    /// 合并：每次请求记一个序号；在读的时候来的请求（序号比这次读开始时的大）等下一次读完。几个同时来的并成一次补读
    func refreshLocal(restoringTabs: Bool) async {
        localRequested += 1
        let mine = localRequested
        if restoringTabs { restorePending = true }
        if localReading {
            await withCheckedContinuation { localWaiters.append((mine, $0)) }
            return
        }
        localReading = true
        while localCompleted < localRequested {
            let target = localRequested
            let restoring = restorePending
            restorePending = false
            await readLocalOnce(restoringTabs: restoring)
            localCompleted = target
            let ready = localWaiters.filter { $0.generation <= target }
            localWaiters.removeAll { $0.generation <= target }
            ready.forEach { $0.continuation.resume() }
        }
        localReading = false
    }

    private func readLocalOnce(restoringTabs: Bool) async {
        // 启动恢复标签：上次开着的文件夹自动加回库里（升级挑选时默认勾上）
        let savedTabs = restoringTabs ? WorkspaceStore.localFolders(of: persistence.loadTabs()) : []
        if library.foldersMigrated, savedTabs.contains(where: { !library.folders.contains($0.raw) }) {
            updateLibrary { s in for id in savedTabs.sorted() where !s.folders.contains(id.raw) { s.folders.append(id.raw) } }
        }
        // 只读会话库里的本机文件夹；还没升级挑选过：全量读一次，给挑选窗口用
        var result: SessionDiscovery.Result
        if library.foldersMigrated {
            result = await reader.local(folderPaths(on: Host.localID))
        } else {
            result = await reader.local(nil)
            let index = FolderLibrary.index(result.sessions) { FileManager.default.fileExists(atPath: $0) }
            folderCandidates[Host.localID] = index
            prepareMigration(index: index, openTabs: savedTabs)
            result.sessions = FolderLibrary.sessions(result.sessions, in: library.folderIDs)
            result.projects = SessionDiscovery.projects(for: result.sessions)
        }
        // 只替换本机的；SSH 主机的会话由 refreshHost 管。状态灯按会话 ID 存，刷新不打断
        replaceSessions(on: Host.localID, with: keepingOpenTabSessions(result.sessions, on: Host.localID))
        projects = result.projects + projects.filter { $0.hostID != Host.localID }
        installedCLIs = result.installed
        if hosts.first?.installedCLIs != result.installed { hosts[0].installedCLIs = result.installed }
        loadState = .loaded
        if let primary = primaryWindow {
            if primary.expandedProjectIDs.isEmpty, let recent = primary.projects(on: Host.localID).first {
                primary.expandedProjectIDs.insert(recent.id)
            }
            if restoringTabs { primary.restoreTabs() }
        }
        settleWindows()
        primaryWindow?.runLaunchHooks()
    }

    /// 升级后第一次：用全量扫描的结果给出候选和默认勾选（置顶 / 上次开着标签 / 最近 14 天）
    func prepareMigration(index: [FolderLibrary.Candidate], openTabs: Set<ProjectID>) {
        guard !index.isEmpty else {
            updateLibrary { $0.finishFolderMigration(picked: []) }
            return
        }
        migrationPicks = FolderLibrary.defaultPicks(index, pinned: Set(library.pinnedProjectIDs), openTabs: openTabs)
        migrationCandidates = index
    }

    /// 所有没断开的 SSH 主机一起镜像
    func refreshHosts() async {
        await withTaskGroup(of: Void.self) { group in
            for host in hosts where !host.isLocal && host.connection != .disconnected {
                group.addTask { await self.refreshHost(host.id) }
            }
        }
    }

    /// 一台主机：rsync 镜像 → 读镜像 → 替换它名下的会话。失败按原因标状态，已有的列表保留
    func refreshHost(_ alias: String) async {
        guard let i = hosts.firstIndex(where: { $0.id == alias }), hosts[i].connection != .disconnected,
              beginHostJob(.refresh, alias) else { return }   // 上一次镜像还没完（rsync 最长 10 分钟）：不叠着再起一份
        defer { endHostJob(.refresh, alias) }
        hosts[i].connection = .refreshing(done: 0, total: 3)
        let error = await link.mirror(alias) { [weak self] done, total in
            Task { @MainActor in
                guard let self, let j = self.hosts.firstIndex(where: { $0.id == alias }), case .refreshing = self.hosts[j].connection else { return }
                self.hosts[j].connection = .refreshing(done: done, total: total)
            }
        }
        // 镜像途中点了断开（或删了主机）：别把它改回已连接，也别恢复它的远程标签
        guard let j = hosts.firstIndex(where: { $0.id == alias }), hosts[j].connection != .disconnected else { return }
        if let error {
            hosts[j].connection = error.contains("Permission denied") || error.contains("Host key verification")
                ? .needsConnect : .unreachable(error)
        } else {
            hosts[j].connection = .connected
        }
        await reloadHost(alias)
    }

    /// 从本机镜像重读一台主机：全部会话记成候选（添加列表用），只把会话库里的文件夹放进侧栏
    func reloadHost(_ alias: String) async {
        let all = await reader.mirror(alias)
        folderCandidates[alias] = FolderLibrary.index(all) { _ in true }
        let remote = FolderLibrary.sessions(all, in: library.folderIDs)
        replaceSessions(on: alias, with: keepingOpenTabSessions(remote, on: alias))
        projects = projects.filter { $0.hostID != alias } + SessionDiscovery.projects(for: remote)
        if let primary = primaryWindow {
            if let recent = primary.projects(on: alias).first, !primary.expandedProjectIDs.contains(where: { $0.host == alias }) {
                primary.expandedProjectIDs.insert(recent.id)
            }
            primary.restoreRemoteTabs(on: alias)
        }
        settleWindows()
    }

    /// 读完以后每个窗口：认领自己的新会话标签、标出在跑的
    private func settleWindows() {
        for window in windows {
            window.claimNewSessions()
            window.markRunning()
        }
    }

    /// 开着标签的会话：所在文件夹从库里拿掉了也留着，不然断线重连、接着跑都找不到它
    func keepingOpenTabSessions(_ fresh: [Session], on hostID: String) -> [Session] {
        let open = openTabSessionIDs
        let have = Set(fresh.map(\.id))
        return fresh + sessions.filter { $0.hostID == hostID && open.contains($0.id) && !have.contains($0.id) }
    }
}
