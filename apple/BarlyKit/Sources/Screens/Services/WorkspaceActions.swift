import Foundation

/// 工作区的真实动作：刷新会话库、恢复 / 分叉 / 新建、关标签、CLI 退出、标签记录。
/// 截图用的 fixture 不走这里（isLive = false）
@MainActor
public extension WorkspaceStore {
    /// 正常启动：先空着显示加载，后台读四个 CLI，读完恢复上次的标签
    static func live() -> WorkspaceStore {
        // 第一个窗口读会话库、恢复上次的标签；之后开的窗口接到同一份数据上，标签从空开始
        let first = WorkspaceWindows.live.isEmpty
        let store = WorkspaceStore(data: .shared)
        store.isLive = true
        WorkspaceWindows.register(store)
        if let transfer = WorkspaceWindows.pendingTransfer {
            WorkspaceWindows.pendingTransfer = nil
            store.attachTab(transfer)
        }
        if first {
            // 先读会话库状态，再做任何会改它的事（以前等第一次扫描完才读，期间的改动会把文件整个盖掉）
            store.library = LibraryState.load()
            store.loadHosts()
            Task {
                await store.refresh(restoringTabs: true)
                await store.refreshHosts()
            }
        }
        return store
    }

    func refresh(restoringTabs: Bool = false) async {
        guard !data.isRefreshing else { return }
        data.isRefreshing = true
        defer { data.isRefreshing = false }
        // 启动恢复标签：上次开着的文件夹自动加回库里（升级挑选时默认勾上）
        let savedTabs = restoringTabs && isLive ? Self.savedTabFolders() : []
        if library.foldersMigrated, savedTabs.contains(where: { !isInLibrary($0) }) {
            updateLibrary { s in for id in savedTabs.sorted() where !s.folders.contains(id) { s.folders.append(id) } }
        }
        // 只读会话库里的本机文件夹；还没升级挑选过：全量读一次，给挑选窗口用
        var result: SessionDiscovery.Result
        if library.foldersMigrated || !isLive {
            let folders = isLive ? folderPaths(on: Host.localID) : nil
            result = await Task.detached(priority: .userInitiated) { await SessionDiscovery.run(folders: folders) }.value
        } else {
            result = await Task.detached(priority: .userInitiated) { await SessionDiscovery.run(folders: nil) }.value
            let index = FolderLibrary.index(result.sessions) { FileManager.default.fileExists(atPath: $0) }
            data.folderCandidates[Host.localID] = index
            prepareMigration(index: index, openTabs: savedTabs)
            result.sessions = FolderLibrary.sessions(result.sessions, in: Set(library.folders))
            result.projects = SessionDiscovery.projects(for: result.sessions)
        }
        let previous = Dictionary(sessions.map { ($0.id, $0.activity) }, uniquingKeysWith: { a, _ in a })
        // 只替换本机的；SSH 主机的会话由 refreshHost 管
        sessions = result.sessions.map { s in
            var s = s
            s.activity = previous[s.id] ?? .notRunning   // 刷新不打断状态灯
            return s
        } + sessions.filter { $0.hostID != Host.localID }
        projects = result.projects + projects.filter { $0.hostID != Host.localID }
        applyLibraryState()
        installedCLIs = result.installed
        if hosts.first?.installedCLIs != result.installed { hosts[0].installedCLIs = result.installed }
        if expandedProjectIDs.isEmpty, let recent = projects(on: Host.localID).first {
            expandedProjectIDs.insert(recent.id)
        }
        loadState = .loaded
        if restoringTabs { restoreTabs() }
        // 数据是共用的：每个窗口认领自己的新会话标签、标出自己在跑的
        for store in isLive ? WorkspaceWindows.live : [self] {
            store.claimNewSessions()
            store.markRunning()
        }
        if CommandLine.arguments.contains("--sb-selftest") { selfTest() }
        // 自检：启动就搜一个词（--sb-search tmux）
        if let i = CommandLine.arguments.firstIndex(of: "--sb-search"), i + 1 < CommandLine.arguments.count {
            isSearching = true
            searchText = CommandLine.arguments[i + 1]
            searchMessages()
        }
        // 自检：发一条模拟的「跑完一轮」通知（--sb-notify-test），点它会打开那个会话
        if CommandLine.arguments.contains("--sb-notify-test"),
           let s = sessions.filter({ $0.cli == .claude }).max(by: { $0.lastActivity < $1.lastActivity }) {
            NotificationService.shared.post(ActivityChange(kind: .turnFinished, sessionID: s.id), title: s.displayTitle,
                                            project: project(for: s)?.name ?? "", cli: s.cli)
        }
        // 自检：预览指定 CLI 最近的一个会话（--sb-preview codex）
        if let i = CommandLine.arguments.firstIndex(of: "--sb-preview"), i + 1 < CommandLine.arguments.count,
           let cli = CLIKind(rawValue: CommandLine.arguments[i + 1]),
           let s = sessions.filter({ $0.cli == cli && $0.parentSessionID == nil }).max(by: { $0.lastActivity < $1.lastActivity }) {
            expandedProjectIDs.insert(s.projectID)
            select(s)
        }
    }

    /// 自检（只在 `--sb-selftest` 启动时）：用 tmux 开一个跑无害命令的标签，验证 SwiftTerm + 打包的 tmux + 配置
    private func selfTest() {
        let tabID = UUID()
        let script = L("echo 'Switchboard 自检'; echo; tmux -V; echo \"tmux: $(tmux display -p '#{socket_path}')\"; ") +
            "echo \"status=$(tmux show -gv status) prefix=$(tmux show -gv prefix) mouse=$(tmux show -gv mouse)\"; " +
            "echo \"TERM=$TERM  PATH 里有 claude: $(command -v claude)\"; echo; printf '\\033[38;5;208m256 色\\033[0m  \\033[1m粗体\\033[0m  中文对齐测试｜'; echo; sleep 600"
        guard let launch = TerminalLaunch.cli(tabID: tabID, command: ["/bin/sh", "-c", script], directory: NSHomeDirectory(),
                                              tmuxName: "selftest") else { return }
        addTab(TerminalTab(id: tabID, kind: .session(id: "new-selftest", cli: .claude), projectPath: NSHomeDirectory(),
                           title: L("Switchboard 自检"), activity: .working), launch: launch)
    }

    // MARK: 恢复 / 分叉 / 新建

    /// 双击会话或点「接着跑」：已经开着就切过去，否则在它的项目组里开一个标签
    func resume(_ session: Session) {
        if isLive, let (other, tab) = WorkspaceWindows.tabOwner(of: session), other !== self {
            other.selection = .tab(tab.id)
            other.bringWindowToFront()
            return
        }
        if let tab = tab(for: session) {
            selection = .tab(tab.id)
            if tabBanners[tab.id] != nil { relaunch(tab, session: session) }
            return
        }
        open(session: session, arguments: session.cli.resumeArguments(session.id), tmuxName: Tmux.name(for: session.cli, sessionID: session.id))
    }

    /// 分叉：新开一个标签，CLI 会写出一个新会话（刷新后出现在侧栏）
    func branch(_ session: Session) {
        guard let args = session.cli.branchArguments(session.id) else { return }
        open(session: session, arguments: args, tmuxName: Tmux.name(for: session.cli, sessionID: "fork-\(UUID().uuidString.prefix(8))"),
             title: L("分叉：\(session.displayTitle)"), linkSession: false)
    }

    /// 新会话 / 普通终端。prompt：作为第一条消息交给 CLI（主机体检「用 agent 修复」）
    func start(_ draft: NewSessionDraft, prompt: String? = nil) {
        // 主动在一个文件夹里开新会话 = 要用它：不在会话库里就加进来（R4）
        if draft.hostID != Host.localID {
            Task { await addRemoteFolder(draft.folder, on: draft.hostID, refreshNow: false) }
            startRemote(draft)
            return
        }
        let folder = (draft.folder as NSString).expandingTildeInPath
        addFolder(folder, refreshNow: false)
        let tabID = UUID()
        let launch: TerminalLaunch?
        let kind: TerminalTab.Kind
        let title: String
        switch draft.target {
        case .terminal:
            launch = TerminalLaunch.shell(tabID: tabID, directory: folder)
            kind = .plainTerminal
            title = ShellEnvironment.shared.shell.split(separator: "/").last.map(String.init) ?? "shell"
        case .cli(let cli):
            if draft.savedCommand != savedCommand(for: cli) { saveCommand(draft.savedCommand, for: cli) }
            let command = CommandLineSplitter.split(draft.effectiveCommand) + Self.extraArguments(cli) + (prompt.map { [$0] } ?? [])
            launch = TerminalLaunch.cli(tabID: tabID, command: command, directory: folder,
                                        tmuxName: Tmux.name(for: cli, sessionID: "new-\(tabID.uuidString.prefix(8))"),
                                        environment: Self.extraEnvironment(cli))
            kind = .session(id: "new-\(tabID.uuidString)", cli: cli)
            title = L("新的 \(cli.title) 会话")
        }
        guard let launch else { return }
        addTab(TerminalTab(id: tabID, kind: kind, hostID: Host.localID, projectPath: folder, title: title, activity: .working),
               launch: launch)
        if case .cli(let cli) = draft.target {
            pendingClaims[tabID] = PendingClaim(cli: cli, folder: folder, startedAt: Date())
        }
    }

    /// 主机体检有问题：在本机开一个 Claude Code 会话，把报告交给它，它用 ssh 去查、去修（每条改动它都会先问你）
    func fixHostWithAgent(_ alias: String, report: String) {
        let prompt = L("""
            下面是 Switchboard 对 SSH 主机「\(alias)」的体检报告。请用 `ssh \(alias) …` 逐条确认问题、找到原因并修好；\
            改动主机上的任何文件或装东西之前先告诉我要做什么。修完再跑一遍报告里「在终端里试」的命令确认。

            \(report)
            """)
        start(NewSessionDraft(target: .cli(.claude), folder: NSHomeDirectory(), savedCommand: savedCommand(for: .claude)), prompt: prompt)
    }

    /// SSH 主机上的新会话 / 终端：路径是主机上的（~ 由主机展开），CLI 用主机的默认命令
    private func startRemote(_ draft: NewSessionDraft) {
        let tabID = UUID()
        let alias = draft.hostID
        let folder = draft.folder.trimmingCharacters(in: .whitespaces)
        let launch: TerminalLaunch
        let kind: TerminalTab.Kind
        let title: String
        switch draft.target {
        case .terminal:
            let (exe, args) = SSH.launch(alias: alias, directory: folder, command: [], tmuxName: nil)
            launch = TerminalLaunch(tabID: tabID, executable: exe, arguments: args, directory: NSHomeDirectory(), tmuxName: nil, remoteHost: alias)
            kind = .plainTerminal
            title = "\(alias) · shell"
        case .cli(let cli):
            let command = [cli.executable] + (cli == .codex ? ActivityMonitor.codexTitleArguments : [])
            launch = .remote(tabID: tabID, alias: alias, command: command, directory: folder,
                             tmuxName: Tmux.name(for: cli, sessionID: "new-\(tabID.uuidString.prefix(8))"))
            kind = .session(id: "new-\(tabID.uuidString)", cli: cli)
            title = L("新的 \(cli.title) 会话")
        }
        addTab(TerminalTab(id: tabID, kind: kind, hostID: alias, projectPath: folder, title: title, activity: .working), launch: launch)
        if case .cli(let cli) = draft.target {
            pendingClaims[tabID] = PendingClaim(cli: cli, folder: folder, startedAt: Date(), hostID: alias)
        }
    }

    /// 新会话标签认领 CLI 写出来的会话：同一个 CLI、同一个目录、开始之后才出现、还没被别的标签占用。
    /// Codex 要等你发出第一条消息才有会话文件
    func claimNewSessions() {
        guard !pendingClaims.isEmpty else { return }
        let normalize = { (p: String) in (p as NSString).standardizingPath }
        for (tabID, claim) in pendingClaims {
            guard tab(tabID) != nil else { pendingClaims[tabID] = nil; continue }
            // 主机上输入的 ~/x 不知道主机的家目录在哪：按结尾 /x 对
            let sameFolder: (String) -> Bool = { path in
                if claim.hostID != Host.localID, claim.folder.hasPrefix("~/") {
                    return normalize(path).hasSuffix(String(normalize(claim.folder).dropFirst(1)))
                }
                return normalize(path) == normalize(claim.folder)
            }
            let candidates = sessions.filter {
                $0.hostID == claim.hostID && $0.cli == claim.cli && $0.parentSessionID == nil
                    && sameFolder($0.projectPath)
                    && $0.lastActivity >= claim.startedAt.addingTimeInterval(-5)
                    && tab(for: $0) == nil
            }
            guard let found = candidates.max(by: { $0.lastActivity < $1.lastActivity }) else { continue }
            pendingClaims[tabID] = nil
            for g in tabGroups.indices {
                if let t = tabGroups[g].tabs.firstIndex(where: { $0.id == tabID }) {
                    tabGroups[g].tabs[t].kind = .session(id: found.id, cli: found.cli)
                    tabGroups[g].tabs[t].title = found.displayTitle
                }
            }
            // tmux 会话也改成这个会话的名字：关标签后点会话能接回同一个（主机上的不改：它在主机的 tmux 里）
            if claim.hostID == Host.localID, let old = launches[tabID]?.tmuxName {
                let new = Tmux.name(for: found.cli, sessionID: found.id)
                Tmux.run(["rename-session", "-t", old, new])
                launches[tabID]?.tmuxName = new
            }
            expandedProjectIDs.insert(found.projectID)
        }
        saveTabs()
    }

    func open(session: Session, arguments: [String], tmuxName: String, title: String? = nil, linkSession: Bool = true) {
        let tabID = UUID()
        let launch: TerminalLaunch
        if session.hostID != Host.localID {
            // 主机上的启动命令先用默认（按主机保存命令下一步做）
            let command = [session.cli.executable] + (session.cli == .codex ? ActivityMonitor.codexTitleArguments : []) + arguments
            launch = .remote(tabID: tabID, alias: session.hostID, command: command, directory: session.projectPath, tmuxName: tmuxName)
        } else {
            let command = launchCommand(session.cli) + Self.extraArguments(session.cli) + arguments
            guard let local = TerminalLaunch.cli(tabID: tabID, command: command, directory: session.projectPath, tmuxName: tmuxName,
                                                 environment: Self.extraEnvironment(session.cli)) else { return }
            launch = local
        }
        let kind: TerminalTab.Kind = linkSession ? .session(id: session.id, cli: session.cli) : .session(id: "fork-\(tabID)", cli: session.cli)
        addTab(TerminalTab(id: tabID, kind: kind, hostID: session.hostID, projectPath: session.projectPath,
                           title: title ?? session.displayTitle, activity: .working), launch: launch)
    }

    private func relaunch(_ tab: TerminalTab, session: Session) {
        lastRelaunch[tab.id] = Date()
        TerminalRuntime.close(tab.id, endingTmux: nil)
        tabBanners[tab.id] = nil
        let name = Tmux.name(for: session.cli, sessionID: session.id)
        if session.hostID != Host.localID {
            var remote = TerminalLaunch.remote(tabID: tab.id, alias: session.hostID,
                                               command: [session.cli.executable] + (session.cli == .codex ? ActivityMonitor.codexTitleArguments : []) + session.cli.resumeArguments(session.id),
                                               directory: session.projectPath, tmuxName: name)
            remote.cli = session.cli
            remote.projectPath = session.projectPath
            launches[tab.id] = remote
            setActivity(.working, forTab: tab.id)
            return
        }
        guard let launch = TerminalLaunch.cli(tabID: tab.id, command: launchCommand(session.cli) + Self.extraArguments(session.cli) + session.cli.resumeArguments(session.id),
                                              directory: session.projectPath, tmuxName: name,
                                              environment: Self.extraEnvironment(session.cli)) else { return }
        var relaunched = launch
        relaunched.cli = session.cli
        relaunched.projectPath = session.projectPath
        launches[tab.id] = relaunched
        setActivity(.working, forTab: tab.id)
    }

    private func addTab(_ tab: TerminalTab, launch: TerminalLaunch) {
        var launch = launch
        if case .session(_, let cli) = tab.kind { launch.cli = cli }
        launch.projectPath = tab.projectPath
        launches[tab.id] = launch
        let projectID = tab.projectID
        if let i = tabGroups.firstIndex(where: { $0.projectID == projectID }) {
            tabGroups[i].tabs.append(tab)
            tabGroups[i].isCollapsed = false
        } else {
            let name = (tab.projectPath as NSString).lastPathComponent
            tabGroups.append(TabGroup(projectID: projectID, name: name.isEmpty ? "/" : name, tint: Self.tint(for: projectID, avoiding: Set(tabGroups.map(\.tint))), tabs: [tab]))
        }
        selection = .tab(tab.id)
        markRunning()
        saveTabs()
    }

    /// 这个 CLI 在这台主机上的启动命令：保存过的（拆成参数，支持引号）或默认可执行文件
    func launchCommand(_ cli: CLIKind) -> [String] {
        savedCommand(for: cli).map(CommandLineSplitter.split) ?? [cli.executable]
    }

    /// 启动 CLI 时 Switchboard 自己加的参数：Codex 把状态写进终端标题，omp 加载报状态的扩展
    static func extraArguments(_ cli: CLIKind) -> [String] {
        if cli == .codex { return ActivityMonitor.codexTitleArguments }
        return LiveReporting.launchAdditions(for: cli)?.arguments ?? []
    }

    /// 启动 CLI 时 Switchboard 自己加的环境变量：OpenCode / omp 的报告目录、OpenCode 的插件配置
    static func extraEnvironment(_ cli: CLIKind) -> [String: String] {
        LiveReporting.launchAdditions(for: cli)?.environment ?? [:]
    }

    /// 组色有几种（见 BarlyPalette.groupColor）
    nonisolated static let tintCount = 5

    /// 组色：按项目路径稳定分配（FNV-1a），从这个颜色往后找第一个没被已打开的组占用的；全占满就用哈希本身
    nonisolated static func tint(for key: String, avoiding used: Set<Int>) -> Int {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in key.utf8 { hash ^= UInt64(byte); hash &*= 0x100_0000_01b3 }
        let start = Int(hash % UInt64(tintCount))
        return (0..<tintCount).map { (start + $0) % tintCount }.first { !used.contains($0) } ?? start
    }

    // MARK: 断线重连

    /// 每次等多久（秒）：先快后慢，加起来约 15 分钟后放弃，之后只能手动「立即重连」
    static let reconnectDelays = [2, 5, 10, 20, 30, 60, 60, 120, 120, 180, 300]

    func scheduleReconnect(_ tabID: UUID) {
        // 连上之后跑了一分钟以上才断的，算新的一次掉线，从头开始数
        if let last = lastRelaunch[tabID], Date().timeIntervalSince(last) > 60 { reconnectAttempts[tabID] = 0 }
        let attempt = (reconnectAttempts[tabID] ?? 0) + 1
        reconnectAttempts[tabID] = attempt
        guard attempt <= Self.reconnectDelays.count else {
            tabBanners[tabID] = .reconnecting(attempt: 0, nextIn: 0)   // 放弃自动：只剩「立即重连」
            return
        }
        let delay = Self.reconnectDelays[attempt - 1]
        tabBanners[tabID] = .reconnecting(attempt: attempt, nextIn: delay)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            self?.reconnectNow(tabID, onlyIfAttempt: attempt)
        }
    }

    /// 立刻重连（按钮、Mac 唤醒、回到 app 时）；onlyIfAttempt：定时器到点时确认中间没被别的重连抢先
    func reconnectNow(_ tabID: UUID, onlyIfAttempt: Int? = nil) {
        guard let tab = tab(tabID), case .reconnecting? = tabBanners[tabID], let session = session(for: tab) else { return }
        if let onlyIfAttempt, reconnectAttempts[tabID] != onlyIfAttempt { return }
        relaunch(tab, session: session)
    }

    /// Mac 唤醒、回到 app：所有在等重连的标签马上试一次
    func retryReconnects() {
        for (id, banner) in tabBanners { if case .reconnecting = banner { reconnectNow(id) } }
    }

    // MARK: 切标签

    /// ⌘1–⌘8 选第几个（从 0 数），⌘9 = -1 选最后一个；折叠的组会展开
    func selectTab(at index: Int) {
        let tabs = allTabs
        guard !tabs.isEmpty else { return }
        let i = index < 0 ? tabs.count - 1 : index
        guard i < tabs.count else { return }
        show(tabs[i])
    }

    /// ⌘⇧] / Ctrl+Tab = +1，⌘⇧[ / Ctrl+Shift+Tab = -1，到头回绕；在预览里时从第一个 / 最后一个开始
    func cycleTab(_ delta: Int) {
        let tabs = allTabs
        guard !tabs.isEmpty else { return }
        guard let current = selectedTab, let i = tabs.firstIndex(where: { $0.id == current.id }) else {
            show(delta > 0 ? tabs[0] : tabs[tabs.count - 1])
            return
        }
        show(tabs[(i + delta + tabs.count) % tabs.count])
    }

    private func show(_ tab: TerminalTab) {
        if let g = tabGroups.firstIndex(where: { $0.tabs.contains { $0.id == tab.id } }) { tabGroups[g].isCollapsed = false }
        selection = .tab(tab.id)
    }

    // MARK: 关标签

    /// 关闭会话标签的默认做法（按主机记）："ask" / "keep" / "end"
    static func closeBehavior(for hostID: String) -> String {
        UserDefaults.standard.string(forKey: "closeBehavior.\(hostID)") ?? "ask"
    }

    static func setCloseBehavior(_ value: String, for hostID: String) {
        UserDefaults.standard.set(value, forKey: "closeBehavior.\(hostID)")
    }

    /// ⌘W / 点 ×：CLI 在 tmux 里还在跑就按这台主机的设置（没设就问）；已结束、普通终端直接关
    func requestClose(_ tab: TerminalTab) {
        guard let launch = launches[tab.id], launch.tmuxName != nil, tabBanners[tab.id] == nil else {
            close(tab, keepRunning: false)
            return
        }
        switch Self.closeBehavior(for: tab.hostID) {
        case "keep": close(tab, keepRunning: true)
        case "end": close(tab, keepRunning: false)
        default: closingTab = tab
        }
    }

    /// keepRunning = 只关标签，CLI 继续在 tmux 里跑；否则连 tmux 会话一起结束
    func close(_ tab: TerminalTab, keepRunning: Bool) {
        let launch = launches[tab.id]
        let tmuxName = launch?.tmuxName
        if let alias = launch?.remoteHost {
            // 远程：本机只断开 ssh；结束会话要到主机上结束它的 tmux
            TerminalRuntime.close(tab.id, endingTmux: nil)
            if !keepRunning, let tmuxName {
                Task.detached {
                    _ = SSH.run(["/usr/bin/ssh"] + SSH.options(alias) + [alias, "tmux kill-session -t \(Tmux.shellQuote(tmuxName))"], timeout: 20)
                }
            }
        } else {
            TerminalRuntime.close(tab.id, endingTmux: keepRunning ? nil : tmuxName)
        }
        launches[tab.id] = nil
        tabBanners[tab.id] = nil
        closingTab = nil
        let ordered = allTabs
        let index = ordered.firstIndex { $0.id == tab.id }
        for g in tabGroups.indices { tabGroups[g].tabs.removeAll { $0.id == tab.id } }
        tabGroups.removeAll { $0.tabs.isEmpty }
        if split?.contains(tab.id) == true { split = nil }
        if case .tab(tab.id)? = selection {
            let rest = allTabs
            if let index, !rest.isEmpty { selection = .tab(rest[min(index, rest.count - 1)].id) }
            else if let session = session(for: tab) { selection = .preview(sessionID: session.id) }
            else { selection = nil }
        }
        markRunning()
        saveTabs()
    }

    /// CLI 退出：标签不关，留着它打印的内容，上面加一条横条
    func processExited(_ tabID: UUID, code: Int32) {
        guard tab(tabID) != nil else { return }
        // tmux 里 CLI 还活着、只是终端断开了（比如 tmux server 被别处结束）就不报
        if launches[tabID]?.remoteHost == nil, let name = launches[tabID]?.tmuxName, Tmux.isRunning(name) { return }
        // ssh 掉线（255）：CLI 多半还在主机的 tmux 里，自动重连
        if launches[tabID]?.remoteHost != nil, code == 255 {
            setActivity(.ended, forTab: tabID)
            scheduleReconnect(tabID)
            return
        }
        tabBanners[tabID] = code == 0 ? .exited(code: 0) : .failed(code: code, hint: L("退出码 \(code)"))
        setActivity(.ended, forTab: tabID)
        saveTabs()
    }

    // MARK: 状态

    /// 立刻刷一次状态（开 / 关标签之后）
    func markRunning() {
        _ = pollActivity(appIsActive: true)
    }

    // MARK: 预览

    /// 预览：先读文件最后 4 MB；「加载更早的消息」每次翻 4 倍
    func loadTranscript(_ sessionID: String, earlier: Bool = false) async {
        guard isLive, let session = session(sessionID) else { return }
        if !earlier, transcripts[sessionID] != nil { return }
        let budget = earlier ? (transcriptBudgets[sessionID] ?? 4 << 20) * 4 : 4 << 20
        let entries = await Task.detached(priority: .userInitiated) { TranscriptLoader.load(session, maxBytes: budget) }.value
        transcriptBudgets[sessionID] = budget
        transcripts[sessionID] = entries
    }

    func hasEarlierTranscript(_ sessionID: String) -> Bool {
        guard isLive, let session = session(sessionID) else { return false }
        return TranscriptLoader.isTruncated(session, maxBytes: transcriptBudgets[sessionID] ?? 4 << 20)
    }

    // MARK: 标签记录（退出后重开时恢复）

    internal struct TabRecord: Codable {
        let cli: String?
        let sessionID: String?
        let projectPath: String
        let title: String
        let tmuxName: String?
        let selected: Bool
    }

    internal static var tabsFile: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Switchboard", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("tabs.json")
    }

    func saveTabs() {
        guard isLive else { return }
        // 所有窗口的标签记在一起，下次启动都恢复到第一个窗口
        let records = WorkspaceWindows.live.flatMap { store in
            store.allTabs.compactMap { tab -> TabRecord? in
                guard case .session(let id, let cli) = tab.kind, !id.hasPrefix("new-"), !id.hasPrefix("fork-") else { return nil }
                return TabRecord(cli: cli.rawValue, sessionID: id, projectPath: tab.projectPath, title: tab.title,
                                 tmuxName: store.launches[tab.id]?.tmuxName, selected: store === self && selectedTab?.id == tab.id)
            }
        }
        if let data = try? JSONEncoder().encode(records) { try? data.write(to: Self.tabsFile, options: .atomic) }
    }

    internal func restoreTabs() {
        guard UserDefaults.standard.object(forKey: "restoreTabs") as? Bool ?? true,
              let data = try? Data(contentsOf: Self.tabsFile),
              let records = try? JSONDecoder().decode([TabRecord].self, from: data) else { return }
        var selected: UUID?
        for r in records {
            guard let id = r.sessionID, let s = session(id), tab(for: s) == nil else { continue }
            resume(s)
            if r.selected { selected = selectedTab?.id }
        }
        if let selected { selection = .tab(selected) }
    }
}

/// 关终端的入口，store 不直接依赖 AppKit
@MainActor
public enum TerminalRuntime {
    public static var closer: ((UUID, String?) -> Void)?
    static func close(_ tabID: UUID, endingTmux: String?) {
        if let closer { closer(tabID, endingTmux) } else if let endingTmux { Tmux.kill(endingTmux) }
    }
}
