import Foundation
import Observation

/// 所有窗口共用的数据：会话库、主机、对话缓存、本地标记、远程状态。
/// 真实运行时每个窗口的 WorkspaceStore 都指向同一个 `shared`，刷新一次所有窗口一起变；截图和单测各用各的
@MainActor
@Observable
public final class WorkspaceData {
    public var hosts: [Host]
    public var projects: [Project]
    public var sessions: [Session] { didSet { cachedIndex = nil } }
    public var loadState: LoadState
    public var transcripts: [String: [TranscriptEntry]]
    public var transcriptBudgets: [String: Int] = [:]
    public var installedCLIs: [CLIKind] = CLIKind.allCases
    public var library = LibraryState()
    public var remoteSnapshots: [String: RemoteSessions.Snapshot] = [:]
    public var signInConfigs: [String: SignInConfig] = [:]
    /// 每台主机上发现过会话的文件夹（候选索引，按需算：添加列表、空状态推荐、升级挑选）
    public var folderCandidates: [String: [FolderLibrary.Candidate]] = [:]
    /// 升级到「手动添加文件夹」：不为空时弹一次挑选
    public var migrationCandidates: [FolderLibrary.Candidate]?
    /// 升级挑选的默认勾选
    public var migrationPicks: [String] = []
    /// 库外有会话在跑的文件夹（侧栏底部提示）
    public var outsideRunning: [FolderLibrary.Outside] = []
    @ObservationIgnored private var cachedIndex: SessionIndex?
    /// 会话按项目、按 ID 分好：侧栏每次重画、轮询每秒都要查，会话列表变了才重算一次
    var sessionIndex: SessionIndex {
        _ = sessions   // 让读索引的视图也跟着会话变（索引本身不被观察）
        if let cachedIndex { return cachedIndex }
        let index = SessionIndex(sessions)
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
    /// 问过的 SSH 主机家目录（主机文件夹里的 ~ 靠它展开）
    @ObservationIgnored var remoteHomes: [String: String] = [:]
    /// 正在读会话库：别的窗口这时再要刷新就跳过
    @ObservationIgnored var isRefreshing = false

    public init(hosts: [Host], projects: [Project], sessions: [Session], transcripts: [String: [TranscriptEntry]] = [:],
                loadState: LoadState = .loaded) {
        self.hosts = hosts
        self.projects = projects
        self.sessions = sessions
        self.transcripts = transcripts
        self.loadState = loadState
    }

    public static let shared = WorkspaceData(hosts: [Host(id: Host.localID, kind: .local, displayName: L("这台 Mac"))],
                                             projects: [], sessions: [], loadState: .loading)
}

/// 会话列表的查询索引（WorkspaceData.sessionIndex）
struct SessionIndex {
    /// 会话 ID → 在 sessions 里的位置（同 ID 取第一个，和 first(where:) 一样）
    let positions: [String: Int]
    /// 项目 ID → 会话（含子代理、归档，保持原顺序）
    let byProject: [String: [Session]]
    /// 父会话 ID → 子代理
    let children: [String: [Session]]
    let lastActivity: [String: Date]
    /// 组内最急的状态
    let activity: [String: Activity]
    /// 不算子代理和归档
    let count: [String: Int]

    init(_ sessions: [Session]) {
        var positions: [String: Int] = [:], byProject: [String: [Session]] = [:], children: [String: [Session]] = [:]
        var lastActivity: [String: Date] = [:], activity: [String: Activity] = [:], count: [String: Int] = [:]
        for (i, s) in sessions.enumerated() {
            if positions[s.id] == nil { positions[s.id] = i }
            let p = s.projectID
            byProject[p, default: []].append(s)
            if let parent = s.parentSessionID { children[parent, default: []].append(s) }
            if s.lastActivity > lastActivity[p] ?? .distantPast { lastActivity[p] = s.lastActivity }
            if let a = activity[p] { if s.activity.urgency > a.urgency { activity[p] = s.activity } } else { activity[p] = s.activity }
            if s.parentSessionID == nil, !s.isArchived { count[p, default: 0] += 1 }
        }
        (self.positions, self.byProject, self.children) = (positions, byProject, children)
        (self.lastActivity, self.activity, self.count) = (lastActivity, activity, count)
    }
}
