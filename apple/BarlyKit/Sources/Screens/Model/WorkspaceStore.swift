import Foundation
import Observation

public enum LoadState: Equatable, Sendable {
    case loading
    case loaded
    case failed(String)
}

/// 侧栏的两个视图：会话库 / 本窗口打开的标签
public enum SidebarMode: String, CaseIterable, Identifiable, Sendable {
    case projects, openTabs
    public var id: String { rawValue }
}

/// 侧栏过滤（过滤菜单）
public enum SessionFilter: Hashable, Sendable {
    case all
    case recent7Days
    case cli(CLIKind)
    case running
    case waitingForYou
}

/// 主区显示什么：某个终端标签，或某个会话的预览
public enum MainSelection: Hashable, Sendable {
    case tab(UUID)
    case preview(sessionID: String)
}

/// 一个工作区窗口的全部界面状态。视图只读它、调它的方法，不自己持有业务数据。
@MainActor
@Observable
public final class WorkspaceStore {
    /// 所有窗口共用的那份数据（见 WorkspaceData）；下面这些属性都转给它
    public let data: WorkspaceData
    public var hosts: [Host] {
        get { data.hosts }
        set { data.hosts = newValue }
    }
    public var projects: [Project] {
        get { data.projects }
        set { data.projects = newValue }
    }
    public var sessions: [Session] {
        get { data.sessions }
        set { data.sessions = newValue }
    }
    public var loadState: LoadState {
        get { data.loadState }
        set { data.loadState = newValue }
    }
    public var transcripts: [String: [TranscriptEntry]] {
        get { data.transcripts }
        set { data.transcripts = newValue }
    }
    public var tabGroups: [TabGroup]

    public var sidebarMode = SidebarMode.projects
    public var searchText = ""
    public var isSearching = false
    public var filter = SessionFilter.all
    public var showsArchived = false
    public var expandedProjectIDs: Set<String> = []
    /// 收起的主机（记在 UserDefaults）
    public var collapsedHostIDs: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "collapsedHosts") ?? []) {
        didSet { if isLive { UserDefaults.standard.set(Array(collapsedHostIDs), forKey: "collapsedHosts") } }
    }
    public var selection: MainSelection? {
        didSet {
            guard oldValue != selection, let oldValue, !navigatingHistory else { return }
            backStack.append(oldValue)
            if backStack.count > 50 { backStack.removeFirst() }
            forwardStack.removeAll()
        }
    }
    /// 每个项目默认列出的会话数，「再显示 20 个」按项目累加
    public var visibleLimits: [String: Int] = [:]
    /// 分屏：左右两个标签；right 为 nil = 右边还在「选一个标签」
    public var split: SplitState?
    /// 侧栏「已打开」视图里多选的标签（⌘-click / ⇧-click）
    public var openTabSelection: Set<UUID> = []
    /// 铃铛列表是否展开
    public var isBellOpen = false
    /// 终端上方的横条：CLI 退出 / 出错 / 断线重连
    public var tabBanners: [UUID: TerminalBanner] = [:]
    /// 批量删除进度（侧栏底部）
    public var deletion: DeletionProgress?
    /// 侧栏底部的小贴士（每次打开随机一条）
    public var tip: String?
    /// 首启引导第几步（nil = 不在引导中）
    public var tourStep: Int?

    // 真实运行（mock / 截图时都是空的）
    /// 每个终端标签要启动的进程；没有 = 原型里的假终端
    public var launches: [UUID: TerminalLaunch] = [:]
    /// 正在问「关闭这个标签？」的标签
    public var closingTab: TerminalTab?
    /// 本机装了的 CLI
    public var installedCLIs: [CLIKind] {
        get { data.installedCLIs }
        set { data.installedCLIs = newValue }
    }
    /// 是真实数据（会写标签记录、会刷新）
    public var isLive = false
    /// 每个标签最近的终端标题（Codex 在这里报状态）
    public var terminalTitles: [UUID: String] = [:]
    /// 置顶、重命名、归档、启动命令（本地，不改 CLI 文件）
    public var library: LibraryState {
        get { data.library }
        set { data.library = newValue }
    }
    /// 正在重命名的会话（弹输入框）
    public var renaming: Session?
    /// 等确认删除的会话
    public var pendingDelete: [Session] = []
    /// 删除确认通过后要归档的项目（「归档项目并删除所有会话」）
    public var pendingArchiveProject: String?
    /// 正在重命名的项目（弹输入框）
    public var renamingProject: Project?
    /// 上一次删除失败的（会话 ID → 原因）
    public var deleteFailures: [String: String] = [:]
    /// 预览读了文件尾部多少字节
    public var transcriptBudgets: [String: Int] {
        get { data.transcriptBudgets }
        set { data.transcriptBudgets = newValue }
    }
    /// 消息全文搜索的命中：会话 ID → 命中那一句
    public var messageHits: [String: String] = [:]
    /// 建索引进度（已读, 总数）；nil = 没在建
    public var indexProgress: (done: Int, total: Int)?
    @ObservationIgnored var searchTask: Task<Void, Never>?
    /// 侧栏多选的会话（⌘-click / ⇧-click）；空 = 没在多选
    public var selectedSessionIDs: Set<String> = []
    /// ⇧-click 的起点
    public var selectionAnchor: String?
    /// 侧栏键盘导航停在哪一行（会话行就是在预览的那个）
    public var libraryCursor: LibraryRow?
    /// 展开了子代理的会话
    public var expandedSubagentParents: Set<String> = []
    /// 后退 / 前进历史（像浏览器）
    public var backStack: [MainSelection] = []
    public var forwardStack: [MainSelection] = []
    @ObservationIgnored var navigatingHistory = false
    /// 每台 SSH 主机最近一次读到的状态（每 5 秒）
    public var remoteSnapshots: [String: RemoteSessions.Snapshot] {
        get { data.remoteSnapshots }
        set { data.remoteSnapshots = newValue }
    }
    /// 正在 Connect… 登录的主机（弹登录对话框）
    public var connectingHost: String?
    /// 每台主机的定期重新登录设置
    public var signInConfigs: [String: SignInConfig] {
        get { data.signInConfigs }
        set { data.signInConfigs = newValue }
    }
    /// 打开中的主机工具对话框
    public var hostSheet: HostSheet?
    /// 远程标签断线后自动重连了几次、上次重连的时间
    public var reconnectAttempts: [UUID: Int] = [:]
    @ObservationIgnored var lastRelaunch: [UUID: Date] = [:]
    /// 这个工作区所在的窗口（NSWindow；别的窗口要把它叫到前面时用）
    @ObservationIgnored public weak var hostWindow: AnyObject?
    /// 新建的会话标签还没认到真实会话：标签 → (CLI, 目录, 开始时间)
    public var pendingClaims: [UUID: PendingClaim] = [:]

    public static let defaultVisibleLimit = 10

    public init(hosts: [Host], projects: [Project], sessions: [Session], tabGroups: [TabGroup] = [],
                transcripts: [String: [TranscriptEntry]] = [:], loadState: LoadState = .loaded) {
        data = WorkspaceData(hosts: hosts, projects: projects, sessions: sessions, transcripts: transcripts, loadState: loadState)
        self.tabGroups = tabGroups
    }

    /// 新窗口：接到已有的那份共用数据上
    public init(data: WorkspaceData) {
        self.data = data
        tabGroups = []
    }

    // MARK: 会话库

    public var trimmedQuery: String { searchText.trimmingCharacters(in: .whitespaces) }

    /// 搜索、Running、Waiting 时全列不截断，项目自动展开
    public var isFiltering: Bool {
        !trimmedQuery.isEmpty || filter == .running || filter == .waitingForYou
    }

    /// 某台主机下列出的项目：置顶在前，其余按最近活动
    public func projects(on hostID: String) -> [Project] {
        let candidates = projects.filter { $0.hostID == hostID && (showsArchived || !$0.isArchived) }
        let matched = isFiltering ? candidates.filter { !sessions(in: $0).isEmpty } : candidates
        let latest = data.sessionIndex.lastActivity
        return matched.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            if lhs.isPinned, let a = library.pinnedProjects.firstIndex(of: lhs.id), let b = library.pinnedProjects.firstIndex(of: rhs.id) { return a < b }
            return latest[lhs.id] ?? .distantPast > latest[rhs.id] ?? .distantPast
        }
    }

    /// 项目下列出的会话（已过滤、已排序，未截断）
    public func sessions(in project: Project) -> [Session] {
        let query = trimmedQuery
        let projectHit = !query.isEmpty && (project.name.localizedStandardContains(query) || project.path.localizedStandardContains(query))
        return (data.sessionIndex.byProject[project.id] ?? [])
            .filter { $0.parentSessionID == nil }
            .filter { showsArchived || !$0.isArchived }
            .filter(passesFilter)
            .filter { query.isEmpty || projectHit || $0.displayTitle.localizedStandardContains(query) || $0.id.localizedStandardContains(query)
                || messageHits[$0.id] != nil }
            .sorted { lhs, rhs in
                if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
                if lhs.isPinned, let a = library.pinnedSessions.firstIndex(of: lhs.id), let b = library.pinnedSessions.firstIndex(of: rhs.id) { return a < b }
                return lhs.lastActivity > rhs.lastActivity
            }
    }

    /// 展开的项目实际显示的会话
    public func visibleSessions(in project: Project) -> (shown: [Session], hidden: Int) {
        let all = sessions(in: project)
        if isFiltering { return (all, 0) }
        let limit = visibleLimits[project.id] ?? Self.defaultVisibleLimit
        return (Array(all.prefix(limit)), max(0, all.count - limit))
    }

    public func isExpanded(_ project: Project) -> Bool {
        isFiltering || expandedProjectIDs.contains(project.id)
    }

    public func showMore(in project: Project) {
        visibleLimits[project.id] = (visibleLimits[project.id] ?? Self.defaultVisibleLimit) + 20
    }

    public func toggleExpanded(_ project: Project) {
        if expandedProjectIDs.contains(project.id) {
            expandedProjectIDs.remove(project.id)
            visibleLimits[project.id] = nil
        } else {
            expandedProjectIDs.insert(project.id)
        }
    }

    public func lastActivity(of project: Project) -> Date {
        data.sessionIndex.lastActivity[project.id] ?? .distantPast
    }

    /// 项目行右侧的状态：组内最急的运行中会话
    public func activity(of project: Project) -> Activity {
        data.sessionIndex.activity[project.id] ?? .notRunning
    }

    public func sessionCount(of project: Project) -> Int {
        data.sessionIndex.count[project.id] ?? 0
    }

    public var hasAnySession: Bool { !sessions.isEmpty }

    public var hasSearchResults: Bool { hosts.contains { !projects(on: $0.id).isEmpty } }

    public var waitingSessions: [Session] {
        sessions.filter(\.activity.isWaitingForUser).sorted { $0.lastActivity > $1.lastActivity }
    }

    public var openTabCount: Int { tabGroups.reduce(0) { $0 + $1.tabs.count } }

    private func passesFilter(_ session: Session) -> Bool {
        switch filter {
        case .all: true
        case .recent7Days: session.lastActivity > Date.now.addingTimeInterval(-7 * 86_400)
        case .cli(let cli): session.cli == cli
        case .running: session.activity.isRunning
        case .waitingForYou: session.activity.isWaitingForUser
        }
    }

    // MARK: 选择与标签

    public var selectedTab: TerminalTab? {
        guard case .tab(let id)? = selection else { return nil }
        return tabGroups.lazy.flatMap(\.tabs).first { $0.id == id }
    }

    public var previewedSession: Session? {
        guard case .preview(let id)? = selection else { return nil }
        return session(id)
    }

    public func session(_ id: String) -> Session? { data.sessionIndex.positions[id].map { sessions[$0] } }

    public func project(for session: Session) -> Project? { projects.first { $0.id == session.projectID } }

    public func host(_ id: String) -> Host? { hosts.first { $0.id == id } }

    /// 会话是否已经开在某个标签里
    public func tab(for session: Session) -> TerminalTab? {
        tabGroups.lazy.flatMap(\.tabs).first {
            if case .session(let id, _) = $0.kind { id == session.id } else { false }
        }
    }

    public func session(for tab: TerminalTab) -> Session? {
        if case .session(let id, _) = tab.kind { session(id) } else { nil }
    }

    public func isSelected(_ session: Session) -> Bool {
        switch selection {
        case .preview(let id): id == session.id
        case .tab: selectedTab.map { tab(for: session)?.id == $0.id } ?? false
        case nil: false
        }
    }

    /// 单击会话：已在标签里跑就切到标签，否则预览
    public func select(_ session: Session) {
        selection = tab(for: session).map { .tab($0.id) } ?? .preview(sessionID: session.id)
    }

    public func toggleCollapsed(_ group: TabGroup) {
        guard let index = tabGroups.firstIndex(where: { $0.id == group.id }) else { return }
        tabGroups[index].isCollapsed.toggle()
    }

    public func group(for tab: TerminalTab) -> TabGroup? {
        tabGroups.first { $0.tabs.contains { $0.id == tab.id } }
    }

    public func retry() { loadState = .loaded }

    // MARK: 分屏

    public var allTabs: [TerminalTab] { tabGroups.flatMap(\.tabs) }

    public func tab(_ id: UUID) -> TerminalTab? { allTabs.first { $0.id == id } }

    /// 当前选中标签所在的分屏（没有就 nil）
    public var activeSplit: SplitState? {
        guard let split, let selected = selectedTab?.id, split.contains(selected) else { return nil }
        return split
    }

    /// 「选一个标签」列表：本窗口里不在分屏里的其他标签，最近用过的在前
    public var splitCandidates: [TerminalTab] {
        guard let split else { return [] }
        return allTabs.filter { !split.contains($0.id) }
    }

    /// ⌘⌥N：当前标签放左边，右边先列出可选标签
    public func startSplit() {
        guard let selected = selectedTab, split == nil else { return }
        split = SplitState(left: selected.id, right: nil)
    }

    public func fillSplit(with tab: TerminalTab) {
        guard var s = split else { return }
        s.right = tab.id
        split = s
        selection = .tab(tab.id)
    }

    /// 双击分隔条：左右互换
    public func swapSplit() {
        guard var s = split, let r = s.right else { return }
        s.right = s.left
        s.left = r
        s.ratio = 1 - s.ratio
        split = s
    }

    /// 关掉分屏的一边：另一边全宽显示（两个标签都还开着）
    public func closeSplitSide(_ id: UUID) {
        guard let s = split else { return }
        let other = s.left == id ? s.right : s.left
        split = nil
        if let other { selection = .tab(other) }
    }

    public func setActivity(_ activity: Activity, forTab id: UUID) {
        for g in tabGroups.indices {
            if let i = tabGroups[g].tabs.firstIndex(where: { $0.id == id }) {
                tabGroups[g].tabs[i].activity = activity
                if case .session(let sid, _) = tabGroups[g].tabs[i].kind, let k = sessions.firstIndex(where: { $0.id == sid }) {
                    sessions[k].activity = activity
                }
            }
        }
    }

    // MARK: 已打开视图多选

    public func toggleOpenTabSelection(_ id: UUID) {
        if openTabSelection.contains(id) { openTabSelection.remove(id) } else { openTabSelection.insert(id) }
    }
}

/// 主机右键菜单打开的对话框
public enum HostSheet: Identifiable, Equatable, Sendable {
    case portForward(String)
    case check(String)
    case signInSettings(String)
    case signIn(String)
    /// 从主机上发现的项目里挑文件夹加进会话库
    case addFolder(String)

    public var id: String {
        switch self {
        case .portForward(let h): "pf-\(h)"
        case .check(let h): "check-\(h)"
        case .signInSettings(let h): "sis-\(h)"
        case .addFolder(let h): "add-\(h)"
        case .signIn(let h): "si-\(h)"
        }
    }
}

/// 新会话标签等着认领 CLI 写出来的那个会话
public struct PendingClaim: Equatable, Sendable {
    public let cli: CLIKind
    public let folder: String
    public let startedAt: Date
    public var hostID: String = Host.localID
}

/// 终端结束 / 断线时盖在终端上方的横条
public enum TerminalBanner: Equatable, Sendable {
    /// CLI 正常退出
    case exited(code: Int32)
    /// 启动后很快出错退出（start command 写错、找不到命令）
    case failed(code: Int32, hint: String)
    /// SSH 断了，tmux 里的 CLI 还在跑，正在自动重连
    case reconnecting(attempt: Int, nextIn: Int)
}

/// 批量删除进度
public struct DeletionProgress: Equatable, Sendable {
    public var done: Int
    public var total: Int
    public var failed: Int
    public var cancelling: Bool

    public init(done: Int, total: Int, failed: Int = 0, cancelling: Bool = false) {
        self.done = done
        self.total = total
        self.failed = failed
        self.cancelling = cancelling
    }

    public var fraction: Double { total == 0 ? 0 : Double(done) / Double(total) }
}

/// 分屏状态：两个标签并排，比例可拖，双击分隔条左右互换
public struct SplitState: Equatable, Sendable {
    public var left: UUID
    public var right: UUID?
    public var ratio: Double = 0.5

    public init(left: UUID, right: UUID?, ratio: Double = 0.5) {
        self.left = left
        self.right = right
        self.ratio = ratio
    }

    public func contains(_ id: UUID) -> Bool { left == id || right == id }
}
