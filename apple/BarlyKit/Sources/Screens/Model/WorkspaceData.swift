import Foundation
import Observation

/// 所有窗口共用的数据：会话库、主机、对话缓存、本地标记、远程状态。
/// 真实运行时每个窗口的 WorkspaceStore 都指向同一个 `shared`，刷新一次所有窗口一起变；截图和单测各用各的
@MainActor
@Observable
public final class WorkspaceData {
    public var hosts: [Host]
    public var projects: [Project]
    public var sessions: [Session]
    public var loadState: LoadState
    public var transcripts: [String: [TranscriptEntry]]
    public var transcriptBudgets: [String: Int] = [:]
    public var installedCLIs: [CLIKind] = CLIKind.allCases
    public var library = LibraryState()
    public var remoteSnapshots: [String: RemoteSessions.Snapshot] = [:]
    public var signInConfigs: [String: SignInConfig] = [:]
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
