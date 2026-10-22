import Foundation

/// 预览时间线顶上那一条：几轮对话 · 几次工具 · 改了几个文件 · 用了多少分钟（只算已经加载的消息）
public struct TranscriptStats: Equatable, Sendable {
    public let rounds: Int
    public let tools: Int
    public let filesChanged: Int
    public let minutes: Int

    /// 算「改了文件」的工具：参数是文件名
    static let editTools: Set<String> = ["Edit", "MultiEdit", "Write", "NotebookEdit", "apply_patch", "edit", "write"]

    public init(_ entries: [TranscriptEntry]) {
        var rounds = 0, tools = 0
        var files = Set<String>()
        for e in entries {
            switch e.kind {
            case .user: rounds += 1
            case .tools(let calls):
                tools += calls.count
                for c in calls where Self.editTools.contains(c.name) && !c.arg.isEmpty { files.insert(c.arg) }
            default: break
            }
        }
        self.rounds = rounds
        self.tools = tools
        self.filesChanged = files.count
        if let first = entries.first?.time, let last = entries.last?.time, last > first {
            minutes = Int((last.timeIntervalSince(first) / 60).rounded())
        } else {
            minutes = 0
        }
    }
}

/// 时间线的过滤：全部 / 只看对话 / 只看工具。你的话总是留着，当分段
public enum TimelineFilter: String, CaseIterable, Sendable {
    case all, conversation, tools

    public var title: String {
        switch self {
        case .all: L("全部")
        case .conversation: L("只看对话")
        case .tools: L("只看工具")
        }
    }

    public func apply(_ entries: [TranscriptEntry]) -> [TranscriptEntry] {
        switch self {
        case .all: entries
        case .conversation: entries.filter { if case .tools = $0.kind { false } else { true } }
        case .tools: entries.filter {
            switch $0.kind {
            case .user, .tools: true
            default: false
            }
        }
        }
    }
}
