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

    /// hours 缺了按 10 读（自动合成的解码不认属性默认值，缺一个字段整个 hosts.json 都读不出来）
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        command = try c.decode(String.self, forKey: .command)
        check = try c.decodeIfPresent(String.self, forKey: .check)
        hours = try c.decodeIfPresent(Double.self, forKey: .hours) ?? 10
        lastSignIn = try c.decodeIfPresent(Date.self, forKey: .lastSignIn)
    }
}

@MainActor
public extension WorkspaceStore {
    /// 设置窗口用：存过的 SSH 主机别名
    static func savedHostAliases() -> [String] {
        WorkspacePersistence.applicationSupport.loadHosts().map(\.alias)
    }

    private func saveHosts() {
        let records = hosts.filter { !$0.isLocal }.map {
            HostRecord(alias: $0.id, installed: $0.installedCLIs.map(\.rawValue), disconnected: $0.connection == .disconnected ? true : nil,
                       signIn: signInConfigs[$0.id])
        }
        data.persistence.saveHosts(records)
    }

    /// 添加：试连通过（或用户点了「仍然添加」）之后调
    func addHost(_ alias: String, installed: [CLIKind]) {
        guard !hosts.contains(where: { $0.id == alias }) else { return }
        hosts.append(Host(id: alias, kind: .ssh(target: alias), displayName: alias,
                          connection: .refreshing(done: 0, total: 3), installedCLIs: installed))
        saveHosts()
        Task { await data.refresh(.host(alias)) }
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
        if !disconnected { Task { await data.refresh(.host(alias)) } }
    }

    /// 远程新会话等认领时隔几秒刷新那台主机：每次刷新都是整机 rsync + OpenCode 快照（6 次以上 ssh），
    /// Codex 要发出第一条消息才写文件，你一直不打字就会一直等：等得越久刷得越慢
    static func claimRefreshInterval(age: TimeInterval) -> Int {
        age < 60 ? 10 : age < 600 ? 30 : 120
    }

    /// 连续问不到 n 次后隔多久再问：10、20、40… 秒，最多 5 分钟
    static func pollBackoff(failures: Int) -> TimeInterval {
        min(300, 10 * pow(2, Double(max(0, failures - 1))))
    }
}
