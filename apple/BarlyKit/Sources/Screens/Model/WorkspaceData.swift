import Foundation
import Observation

/// 所有窗口共用的数据：会话库、主机、对话缓存、本地标记、远程状态。
/// 真实运行时每个窗口的 WorkspaceStore 都指向同一个 `shared`，刷新一次所有窗口一起变；截图和单测各用各的
@MainActor
@Observable
public final class WorkspaceData {
    public var hosts: [Host]
    /// 从 CLI 文件读出来的会话和项目，不带本地标记；对外读写都走 sessions / projects
    private var storedSessions: [Session] { didSet { marked = nil; cachedIndex = nil } }
    private var storedProjects: [Project] { didSet { marked = nil } }
    /// 读出来的 + 会话库里的置顶、归档、改名合在一起（会话库里加了但还没有会话的文件夹也列出来）。
    /// 标记只在 library 里存一份：刷新换了会话列表、改了会话库都不用另外去盖（以前每次刷新完都要记得 applyLibraryState）
    public var sessions: [Session] {
        get { marks.sessions }
        set { storedSessions = newValue }
    }
    public var projects: [Project] {
        get { marks.projects }
        set { storedProjects = newValue }
    }
    @ObservationIgnored private var marked: (sessions: [Session], projects: [Project])?
    private var marks: (sessions: [Session], projects: [Project]) {
        _ = (storedSessions, storedProjects, library)   // 让读它的视图跟着这三样变（缓存本身不被观察）
        if let marked { return marked }
        let m = Self.applying(library, sessions: storedSessions, projects: storedProjects)
        marked = m
        return m
    }
    /// 每个会话现在在干什么（状态灯）：只存这一份，不挂在 Session 值上，刷新换会话列表时不用搬。没有 = 没在跑
    public var activity: [String: Activity] = [:] { didSet { cachedIndex = nil } }
    public var loadState: LoadState
    public var transcripts: [String: [TranscriptEntry]]
    public var transcriptBudgets: [String: Int] = [:]
    public var installedCLIs: [CLIKind] = CLIKind.allCases
    public var library = LibraryState() { didSet { marked = nil; cachedIndex = nil } }
    public var remoteSnapshots: [String: RemoteSessions.Snapshot] = [:]
    public var signInConfigs: [String: SignInConfig] = [:]
    /// 每台主机上发现过会话的文件夹（候选索引，按需算：添加列表、空状态推荐、升级挑选）
    public var folderCandidates: [String: [FolderLibrary.Candidate]] = [:]
    /// 升级到「手动添加文件夹」：不为空时弹一次挑选
    public var migrationCandidates: [FolderLibrary.Candidate]?
    /// 升级挑选的默认勾选
    public var migrationPicks: [ProjectID] = []
    /// 库外有会话在跑的文件夹（侧栏底部提示）
    public var outsideRunning: [FolderLibrary.Outside] = []
    /// 正在 AI 起名的会话（行里转圈）
    public var naming: Set<String> = []
    /// 起名用的模型（截图和单测里是没有可用模型的假的）
    @ObservationIgnored var namer: SessionNamer = .unavailable
    /// 这次运行里在 Switchboard 新建、已经认领到的会话：「新会话自动起名」只给它们起
    @ObservationIgnored var freshSessions: Set<String> = []
    @ObservationIgnored private var cachedIndex: SessionIndex?
    /// 会话按项目、按 ID 分好：侧栏每次重画、轮询每秒都要查，会话列表变了才重算一次
    var sessionIndex: SessionIndex {
        _ = (sessions, activity)   // 让读索引的视图也跟着会话和状态变（索引本身不被观察）
        if let cachedIndex { return cachedIndex }
        let index = SessionIndex(sessions, activity: activity)
        cachedIndex = index
        return index
    }
    /// 预览缓存的对话读的时候文件是什么样（变了重读）、最近看过的顺序（超过上限丢最久没看的）
    @ObservationIgnored var transcriptStamps: [String: TranscriptLoader.FileStamp] = [:]
    @ObservationIgnored var transcriptOrder: [String] = []
    /// 状态轮询最近一次在后台读到的（所有窗口共用）
    @ObservationIgnored var activityInputs = ActivityInputs()
    @ObservationIgnored var isGatheringActivity = false
    /// 主机上正在做的活（「poll:别名」「refresh:别名」）、状态连续问不到的次数
    @ObservationIgnored var hostJobs: Set<String> = []
    @ObservationIgnored var snapshotFailures: [String: Int] = [:]
    /// 连续问不到的主机下次什么时候再问（退避）
    @ObservationIgnored var nextPollAt: [String: Date] = [:]
    /// 上次开着、还没恢复的主机标签（那台主机的会话读进来后恢复）
    @ObservationIgnored var pendingRemoteTabs: [WorkspaceStore.TabRecord] = []
    /// 问过的 SSH 主机家目录（主机文件夹里的 ~ 靠它展开）
    @ObservationIgnored var remoteHomes: [String: String] = [:]
    // 刷新编排（Services/LibraryRefresh.swift）：合并本机读、等补读的调用方、开着的窗口
    @ObservationIgnored var localReading = false
    @ObservationIgnored var localRequested = 0
    @ObservationIgnored var localCompleted = 0
    @ObservationIgnored var localWaiters: [(generation: Int, continuation: CheckedContinuation<Void, Never>)] = []
    @ObservationIgnored var restorePending = false
    @ObservationIgnored var savedStateLoaded = false
    @ObservationIgnored var windowRefs: [WindowRef] = []
    final class WindowRef { weak var store: WorkspaceStore?; init(_ s: WorkspaceStore) { store = s } }

    /// 读会话文件、跑 rsync / ssh：真实运行用磁盘和 ssh，截图、单测用不碰外面的（见 SessionReader / HostLink）
    let reader: SessionReader
    let link: HostLink
    /// 找 tmux 和 CLI：真实运行查这台机器，截图、单测当 CLI 都装了（见 Toolbox）
    let tools: Toolbox

    /// library.json、hosts.json、tabs.json 存在哪：shared 存磁盘，其余（截图、单测）存内存
    public let persistence: WorkspacePersistence

    public init(hosts: [Host], projects: [Project], sessions: [Session], transcripts: [String: [TranscriptEntry]] = [:],
                loadState: LoadState = .loaded, persistence: WorkspacePersistence? = nil, activity: [String: Activity] = [:],
                reader: SessionReader = .empty, link: HostLink = .offline, tools: Toolbox = .pretendInstalled) {
        self.persistence = persistence ?? .memory()
        self.reader = reader
        self.link = link
        self.tools = tools
        self.activity = activity
        self.hosts = hosts
        self.storedProjects = projects
        self.storedSessions = sessions
        self.transcripts = transcripts
        self.loadState = loadState
    }

    /// 合上会话库里的标记。在局部数组上改完：几千个会话也只是一次遍历
    static func applying(_ state: LibraryState, sessions stored: [Session], projects storedProjects: [Project])
        -> (sessions: [Session], projects: [Project]) {
        var projects = storedProjects
        var known = Set(projects.map(\.id))
        for id in state.folders.compactMap(ProjectID.init(raw:)) where !known.contains(id) {   // 按添加顺序
            let local = id.host == Host.localID
            projects.append(Project(hostID: id.host, path: id.path, folderExists: !local || FileManager.default.fileExists(atPath: id.path)))
            known.insert(id)
        }
        let pinnedProjects = Set(state.pinnedProjectIDs), archivedProjects = state.archivedProjectIDs
        for i in projects.indices {
            projects[i].isPinned = pinnedProjects.contains(projects[i].id)
            projects[i].isArchived = archivedProjects.contains(projects[i].id)
            projects[i].customName = state.projectNames[projects[i].id.raw]
        }
        var sessions = stored
        let pinnedSessions = Set(state.pinnedSessions)
        for i in sessions.indices {
            let id = sessions[i].id
            sessions[i].isPinned = pinnedSessions.contains(id)
            sessions[i].isArchived = state.archivedSessions.contains(id)
            sessions[i].localName = state.names[id]
        }
        return (sessions, projects)
    }

    public static let shared: WorkspaceData = {
        let data = WorkspaceData(hosts: [Host(id: Host.localID, kind: .local, displayName: L("这台 Mac"))],
                                 projects: [], sessions: [], loadState: .loading, persistence: .applicationSupport,
                                 reader: .live, link: .live, tools: .live)
        data.namer = .live
        return data
    }()
}

/// 会话列表的查询索引（WorkspaceData.sessionIndex）
struct SessionIndex {
    /// 会话 ID → 在 sessions 里的位置（同 ID 取第一个，和 first(where:) 一样）
    let positions: [String: Int]
    /// 项目 ID → 会话（含子代理、归档，保持原顺序）
    let byProject: [ProjectID: [Session]]
    /// 父会话 ID → 子代理
    let children: [String: [Session]]
    let lastActivity: [ProjectID: Date]
    /// 组内最急的状态
    let activity: [ProjectID: Activity]
    /// 不算子代理和归档
    let count: [ProjectID: Int]

    init(_ sessions: [Session], activity reported: [String: Activity] = [:]) {
        var positions: [String: Int] = [:], byProject: [ProjectID: [Session]] = [:], children: [String: [Session]] = [:]
        var lastActivity: [ProjectID: Date] = [:], activity: [ProjectID: Activity] = [:], count: [ProjectID: Int] = [:]
        for (i, s) in sessions.enumerated() {
            if positions[s.id] == nil { positions[s.id] = i }
            let p = s.projectID
            byProject[p, default: []].append(s)
            if let parent = s.parentSessionID { children[parent, default: []].append(s) }
            if s.lastActivity > lastActivity[p] ?? .distantPast { lastActivity[p] = s.lastActivity }
            let now = reported[s.id] ?? .notRunning
            if let a = activity[p] { if now.urgency > a.urgency { activity[p] = now } } else { activity[p] = now }
            if s.parentSessionID == nil, !s.isArchived { count[p, default: 0] += 1 }
        }
        (self.positions, self.byProject, self.children) = (positions, byProject, children)
        (self.lastActivity, self.activity, self.count) = (lastActivity, activity, count)
    }
}
