import Foundation

/// 支持的 AI 编程 CLI（需求文档「CLI 支持范围」）
public enum CLIKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case claude, codex, opencode, omp

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .claude: "Claude Code"
        case .codex: "Codex"
        case .opencode: "OpenCode"
        case .omp: "omp"
        }
    }

    public var executable: String {
        switch self {
        case .claude: "claude"
        case .codex: "codex"
        case .opencode: "opencode"
        case .omp: "omp"
        }
    }

    /// 行首小标记：两个字母，比图标好认
    public var monogram: String {
        switch self {
        case .claude: "Cl"
        case .codex: "Cx"
        case .opencode: "Oc"
        case .omp: "π"
        }
    }

    /// 没自定义启动命令时用的默认命令（新会话 sheet 的占位）
    public var defaultCommand: String { executable }

    /// 恢复会话时加在命令后面的参数
    public func resumeArguments(_ sessionID: String) -> [String] {
        switch self {
        case .claude: ["--resume", sessionID]
        case .codex: ["resume", sessionID]
        case .opencode: ["--session", sessionID]
        case .omp: ["--resume", sessionID]
        }
    }

    /// 分叉会话的参数；nil = 这个 CLI 没有直接分叉的启动参数（omp 要恢复后在里面用 /fork）
    public func branchArguments(_ sessionID: String) -> [String]? {
        switch self {
        case .claude: ["--resume", sessionID, "--fork-session"]
        case .codex: ["fork", sessionID]
        case .opencode: ["--session", sessionID, "--fork"]
        case .omp: nil
        }
    }
}

/// CLI 正在做什么：侧栏会话行、项目行、标签、铃铛四处同一套指示
public enum Activity: String, Codable, Sendable, CaseIterable {
    /// 没有运行中的 CLI：显示多久前活跃
    case notRunning
    /// 正在干活：一段弧
    case working
    /// 停下来等你回答（权限确认、提问）
    case waitingForAnswer
    /// 回合结束、等下一条提示
    case idle
    /// 回合在你没看的时候结束，直到你看过
    case doneUnseen
    /// 标签还开着但 CLI 已退出
    case ended

    public var isRunning: Bool {
        switch self {
        case .working, .waitingForAnswer, .idle, .doneUnseen: true
        case .notRunning, .ended: false
        }
    }

    /// 「等待你」过滤和铃铛用
    public var isWaitingForUser: Bool { self == .waitingForAnswer || self == .doneUnseen }

    /// 越大越急：折叠的标签组、项目行显示组内最急的那个
    public var urgency: Int {
        switch self {
        case .waitingForAnswer: 5
        case .doneUnseen: 4
        case .working: 3
        case .idle: 2
        case .ended: 1
        case .notRunning: 0
        }
    }

    public var label: String {
        switch self {
        case .notRunning: L("未运行")
        case .working: L("正在工作")
        case .waitingForAnswer: L("等你回答")
        case .idle: L("等下一条提示")
        case .doneUnseen: L("回合已结束，你还没看")
        case .ended: L("已结束")
        }
    }
}

/// 一台机器：这台 Mac 或一个 SSH 主机
public struct Host: Identifiable, Hashable, Sendable {
    public enum Kind: Hashable, Sendable { case local, ssh(target: String) }

    public enum Connection: Hashable, Sendable {
        case connected
        case refreshing(done: Int, total: Int)
        case needsConnect
        case needsSignIn
        case disconnected
        case unreachable(String)
    }

    public let id: String
    public var kind: Kind
    public var displayName: String
    public var connection: Connection
    public var installedCLIs: [CLIKind]

    public static let localID = "local"

    public init(id: String, kind: Kind, displayName: String, connection: Connection = .connected,
                installedCLIs: [CLIKind] = CLIKind.allCases) {
        self.id = id
        self.kind = kind
        self.displayName = displayName
        self.connection = connection
        self.installedCLIs = installedCLIs
    }

    public var isLocal: Bool { kind == .local }
}

/// 一个项目文件夹（某台主机上的绝对路径）
public struct Project: Identifiable, Hashable, Sendable {
    public var id: String { "\(hostID):\(path)" }
    public let hostID: String
    public let path: String
    public var customName: String?
    public var isPinned: Bool
    public var isArchived: Bool
    public var folderExists: Bool

    public init(hostID: String, path: String, customName: String? = nil, isPinned: Bool = false,
                isArchived: Bool = false, folderExists: Bool = true) {
        self.hostID = hostID
        self.path = path
        self.customName = customName
        self.isPinned = isPinned
        self.isArchived = isArchived
        self.folderExists = folderExists
    }

    public var name: String { customName ?? (path as NSString).lastPathComponent }

    /// 显示用的路径：家目录换成 ~
    public var shortPath: String {
        let home = NSHomeDirectory()
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }
}

/// CLI 的一次会话（只读 CLI 自己的文件，置顶、重命名这类本地状态另存）
public struct Session: Identifiable, Hashable, Sendable {
    public let id: String
    public let cli: CLIKind
    public let hostID: String
    public let projectPath: String
    public var title: String
    public var localName: String?
    public var model: String?
    public var lastActivity: Date
    public var messageCount: Int
    public var parentSessionID: String?
    public var isPinned: Bool
    public var isArchived: Bool
    public var activity: Activity
    /// 会话文件（OpenCode 是它的数据库）；mock 数据为 nil
    public var sourcePath: String?

    public init(id: String, cli: CLIKind, hostID: String, projectPath: String, title: String,
                localName: String? = nil, model: String? = nil, lastActivity: Date, messageCount: Int,
                parentSessionID: String? = nil, isPinned: Bool = false, isArchived: Bool = false,
                activity: Activity = .notRunning, sourcePath: String? = nil) {
        self.id = id
        self.cli = cli
        self.hostID = hostID
        self.projectPath = projectPath
        self.title = title
        self.localName = localName
        self.model = model
        self.lastActivity = lastActivity
        self.messageCount = messageCount
        self.parentSessionID = parentSessionID
        self.isPinned = isPinned
        self.isArchived = isArchived
        self.activity = activity
        self.sourcePath = sourcePath
    }

    public var displayTitle: String { localName ?? title }
    public var projectID: String { "\(hostID):\(projectPath)" }
}

/// 窗口里的一个终端标签
public struct TerminalTab: Identifiable, Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case session(id: String, cli: CLIKind)
        /// CLI 开着，但还没对上会话文件：新建的（等认领，见 pendingClaims）、分叉出来的（刷新后作为新会话出现在侧栏）
        case pending(cli: CLIKind)
        case plainTerminal

        public var cli: CLIKind? {
            switch self {
            case .session(_, let cli), .pending(let cli): cli
            case .plainTerminal: nil
            }
        }

        public var sessionID: String? { if case .session(let id, _) = self { id } else { nil } }
    }

    public let id: UUID
    public var kind: Kind
    public var hostID: String
    public var projectPath: String
    public var title: String
    public var activity: Activity

    public init(id: UUID = UUID(), kind: Kind, hostID: String = Host.localID, projectPath: String,
                title: String, activity: Activity) {
        self.id = id
        self.kind = kind
        self.hostID = hostID
        self.projectPath = projectPath
        self.title = title
        self.activity = activity
    }

    public var projectID: String { "\(hostID):\(projectPath)" }
    public var isPlainTerminal: Bool { kind == .plainTerminal }
}

/// 标签栏里按项目分的一组（类 Chrome 标签组）
public struct TabGroup: Identifiable, Hashable, Sendable {
    public var id: String { projectID }
    public let projectID: String
    public let name: String
    /// 组色序号（按项目稳定分配）
    public let tint: Int
    public var tabs: [TerminalTab]
    public var isCollapsed: Bool

    public init(projectID: String, name: String, tint: Int, tabs: [TerminalTab], isCollapsed: Bool = false) {
        self.projectID = projectID
        self.name = name
        self.tint = tint
        self.tabs = tabs
        self.isCollapsed = isCollapsed
    }

    /// 组内最急的状态：折叠时显示在组标签上
    public var mostUrgent: Activity {
        tabs.map(\.activity).max { $0.urgency < $1.urgency } ?? .notRunning
    }
}

/// 对话预览里的一条（只读，从 CLI 会话文件解析）
public struct TranscriptEntry: Identifiable, Hashable, Sendable {
    public enum Kind: Hashable, Sendable {
        case user(String)
        case assistant(String)
        /// 一串连续的工具调用折叠成一行
        case tools(count: Int, summary: String)
        case code(language: String, code: String)
        case image(caption: String)
    }

    public let id: Int
    public let kind: Kind
    public let time: Date

    public init(id: Int, kind: Kind, time: Date) {
        self.id = id
        self.kind = kind
        self.time = time
    }

    /// 查找用的文字
    public var searchableText: String {
        switch kind {
        case .user(let t), .assistant(let t): t
        case .tools(_, let s): s
        case .code(_, let c): c
        case .image(let c): c
        }
    }
}
