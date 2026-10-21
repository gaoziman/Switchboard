import Foundation

/// SSH 主机：存盘、添加、刷新（rsync 镜像 → 读镜像）、移除
/// 定期重新登录（kinit 之类）：命令、可选的检查命令（退出码 0 = 还有效）、没有检查命令时的间隔
public struct SignInConfig: Codable, Equatable, Sendable {
    public var command: String
    public var check: String?
    public var hours: Double = 10
    public var lastSignIn: Date?

    public init(command: String, check: String? = nil, hours: Double = 10, lastSignIn: Date? = nil) {
        self.command = command
        self.check = check
        self.hours = hours
        self.lastSignIn = lastSignIn
    }
}

@MainActor
public extension WorkspaceStore {
    private static var hostsFile: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Switchboard", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("hosts.json")
    }

    private struct HostRecord: Codable {
        let alias: String
        var installed: [String]?
        var disconnected: Bool?
        var signIn: SignInConfig?
    }

    /// 设置窗口用：存过的 SSH 主机别名
    static func savedHostAliases() -> [String] {
        guard let data = try? Data(contentsOf: hostsFile),
              let records = try? JSONDecoder().decode([HostRecord].self, from: data) else { return [] }
        return records.map(\.alias)
    }

    /// 启动时：本机 + 存过的 SSH 主机（连同重新登录设置）
    func loadHosts() {
        guard let data = try? Data(contentsOf: Self.hostsFile),
              let records = try? JSONDecoder().decode([HostRecord].self, from: data) else { return }
        for r in records { if let c = r.signIn { signInConfigs[r.alias] = c } }
        for r in records where !hosts.contains(where: { $0.id == r.alias }) {
            hosts.append(Host(id: r.alias, kind: .ssh(target: r.alias), displayName: r.alias,
                              connection: r.disconnected == true ? .disconnected : .refreshing(done: 0, total: 3),
                              installedCLIs: (r.installed ?? []).compactMap(CLIKind.init(rawValue:))))
        }
    }

    private func saveHosts() {
        guard isLive else { return }
        let records = hosts.filter { !$0.isLocal }.map {
            HostRecord(alias: $0.id, installed: $0.installedCLIs.map(\.rawValue), disconnected: $0.connection == .disconnected ? true : nil,
                       signIn: signInConfigs[$0.id])
        }
        if let data = try? JSONEncoder().encode(records) { try? data.write(to: Self.hostsFile, options: .atomic) }
    }

    /// 添加：试连通过（或用户点了「仍然添加」）之后调
    func addHost(_ alias: String, installed: [CLIKind]) {
        guard !hosts.contains(where: { $0.id == alias }) else { return }
        hosts.append(Host(id: alias, kind: .ssh(target: alias), displayName: alias,
                          connection: .refreshing(done: 0, total: 3), installedCLIs: installed))
        saveHosts()
        Task { await refreshHost(alias) }
    }

    // MARK: 定期重新登录

    func setSignIn(_ config: SignInConfig?, for alias: String) {
        signInConfigs[alias] = config
        saveHosts()
        Task { await checkSignIns() }
    }

    func signedIn(_ alias: String) {
        signInConfigs[alias]?.lastSignIn = Date()
        saveHosts()
        if let i = hosts.firstIndex(where: { $0.id == alias }), hosts[i].connection == .needsSignIn { hosts[i].connection = .connected }
    }

    /// 每 5 分钟：有检查命令就跑它（退出码不是 0 = 过期了），没有就按间隔算。到期的主机标「需要重新登录」
    @discardableResult
    func checkSignIns() async -> [String] {
        var due: [String] = []
        for (alias, config) in signInConfigs {
            guard let i = hosts.firstIndex(where: { $0.id == alias }), hosts[i].connection == .connected || hosts[i].connection == .needsSignIn else { continue }
            var expired: Bool
            if let check = config.check, !check.isEmpty {
                let script = #"exec "${SHELL:-/bin/sh}" -lc "# + Tmux.shellQuote(check)
                let r = await SSH.offPool { SSH.run(["/usr/bin/ssh"] + SSH.options(alias) + [alias, script], timeout: 20) }
                expired = r.map { $0.status != 0 } ?? false
            } else {
                expired = config.lastSignIn.map { Date().timeIntervalSince($0) > config.hours * 3600 } ?? true
            }
            if let j = hosts.firstIndex(where: { $0.id == alias }) {
                if expired, hosts[j].connection != .needsSignIn { due.append(alias) }
                hosts[j].connection = expired ? .needsSignIn : (hosts[j].connection == .needsSignIn ? .connected : hosts[j].connection)
            }
        }
        return due
    }

    func removeHost(_ alias: String) {
        PortForwardManager.shared.stopAll(host: alias)
        for tab in allTabs where tab.hostID == alias { close(tab, keepRunning: true) }
        hosts.removeAll { $0.id == alias }
        remoteSnapshots[alias] = nil
        sessions.removeAll { $0.hostID == alias }
        projects.removeAll { $0.hostID == alias }
        try? FileManager.default.removeItem(at: SSH.cacheDirectory(alias))
        saveHosts()
    }

    func setDisconnected(_ alias: String, _ disconnected: Bool) {
        guard let i = hosts.firstIndex(where: { $0.id == alias }) else { return }
        hosts[i].connection = disconnected ? .disconnected : .refreshing(done: 0, total: 3)
        if disconnected { PortForwardManager.shared.stopAll(host: alias) }
        saveHosts()
        if !disconnected { Task { await refreshHost(alias) } }
    }

    /// 每 5 秒：问每台连着的主机「哪些 claude 在干什么、tmux 里有什么」（没断开、上次没失败的才问）
    /// 一台主机上一次还没问完（网络慢、主机卡住）就跳过它，不叠着起 ssh
    func pollRemoteStatus() async {
        for host in hosts where !host.isLocal && host.connection == .connected {
            let alias = host.id
            guard beginHostJob(.poll, alias) else { continue }
            let snap = await SSH.offPool { RemoteSessions.snapshot(alias) }
            endHostJob(.poll, alias)
            recordSnapshot(snap, for: alias)
        }
    }

    enum HostJob { case poll, refresh }

    /// 这台主机这种活没在做就记上、返回 true；在做就返回 false（调用方跳过）
    func beginHostJob(_ job: HostJob, _ alias: String) -> Bool {
        let key = "\(job):\(alias)"
        return data.hostJobs.insert(key).inserted
    }

    func endHostJob(_ job: HostJob, _ alias: String) {
        data.hostJobs.remove("\(job):\(alias)")
    }

    /// 问不到（nil）先留着上次的：偶尔一次超时灯不闪；连续 3 次问不到就清掉，别一直显示主机掉线前的状态
    func recordSnapshot(_ snap: RemoteSessions.Snapshot?, for alias: String) {
        if let snap {
            remoteSnapshots[alias] = snap
            data.snapshotFailures[alias] = nil
            return
        }
        let failures = (data.snapshotFailures[alias] ?? 0) + 1
        data.snapshotFailures[alias] = failures
        if failures >= 3 { remoteSnapshots[alias] = nil }
    }

    /// 所有没断开的 SSH 主机一起刷新
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
        let store = self
        let error = await SSH.mirror(alias) { done, total in
            Task { @MainActor in
                if let j = store.hosts.firstIndex(where: { $0.id == alias }), case .refreshing = store.hosts[j].connection {
                    store.hosts[j].connection = .refreshing(done: done, total: total)
                }
            }
        }
        guard let j = hosts.firstIndex(where: { $0.id == alias }) else { return }
        if let error {
            hosts[j].connection = error.contains("Permission denied") || error.contains("Host key verification")
                ? .needsConnect : .unreachable(error)
        } else {
            hosts[j].connection = .connected
        }
        await reloadHostSessions(alias)
    }

    /// 从本机镜像重读一台主机：全部会话记成候选（添加列表用），只把会话库里的文件夹放进侧栏
    func reloadHostSessions(_ alias: String) async {
        let all = await SessionDiscovery.runRemote(alias)
        data.folderCandidates[alias] = FolderLibrary.index(all) { _ in true }
        let remote = FolderLibrary.sessions(all, in: Set(library.folders))
        let previous = Dictionary(sessions.filter { $0.hostID == alias }.map { ($0.id, $0.activity) }, uniquingKeysWith: { a, _ in a })
        let fresh = keepingOpenTabSessions(remote.map { s in var s = s; s.activity = previous[s.id] ?? .notRunning; return s }, on: alias)
        sessions.removeAll { $0.hostID == alias }
        sessions += fresh
        projects.removeAll { $0.hostID == alias }
        projects += SessionDiscovery.projects(for: remote)
        applyLibraryState()
        if let recent = projects(on: alias).first, !expandedProjectIDs.contains(where: { $0.hasPrefix(alias + ":") }) {
            expandedProjectIDs.insert(recent.id)
        }
        restoreRemoteTabs(on: alias)
        markRunning()
    }
}
