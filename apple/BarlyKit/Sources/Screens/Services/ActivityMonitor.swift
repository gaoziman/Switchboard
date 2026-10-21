import Foundation

/// 读各 CLI 自己报的状态（对照 JustSessions 的 Activity 模块，MIT）：
/// - Claude Code：`~/.claude/sessions/<pid>.json` 的 `status`（busy / waiting / idle / shell）
/// - Codex：终端标题里的 run-state（启动时加 `tui.terminal_title`），读不到就看会话文件最后一个回合事件
/// - OpenCode / omp：要注入扩展，暂时只有「在跑」
public enum ActivityMonitor {
    /// 让 Codex 把状态写进终端标题：Ready / Working / Action Required
    public static let codexTitleArguments = ["-c", #"tui.terminal_title=["activity","run-state","thread-id"]"#]

    /// 所有活着的 claude 进程报的状态：会话 ID → 状态
    public static func claudeStatuses(root: URL = URL(fileURLWithPath: ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"]
        ?? NSHomeDirectory() + "/.claude")) -> [String: Activity] {
        let dir = root.appendingPathComponent("sessions")
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return [:] }
        var out: [String: Activity] = [:]
        for name in files where name.hasSuffix(".json") {
            guard let pid = Int32(name.dropLast(5)), kill(pid, 0) == 0 || errno == EPERM,
                  let data = try? Data(contentsOf: dir.appendingPathComponent(name)),
                  let record = JSONLines.object(data),
                  let id = record["sessionId"] as? String,
                  let activity = claudeActivity(status: record["status"] as? String) else { continue }
            out[id] = activity
        }
        return out
    }

    static func claudeActivity(status: String?) -> Activity? {
        switch status {
        case "busy": .working
        case "waiting": .waitingForAnswer
        case "idle", "shell": .idle
        default: nil
        }
    }

    /// Codex 终端标题第一段的 run-state；`Action Required` = 等你批准 / 回答
    public static func codexActivity(title: String) -> Activity? {
        guard let first = title.components(separatedBy: " | ").first?.trimmingCharacters(in: .whitespaces), !first.isEmpty else { return nil }
        if first.hasSuffix("Action Required") { return .waitingForAnswer }
        guard let state = first.split(whereSeparator: \.isWhitespace).last else { return nil }
        if state == "Ready" { return .idle }
        return ["Working", "Thinking", "Waiting", "Starting", "Undoing"].contains(state) ? .working : nil
    }

    /// Codex 会话文件最后一个回合事件：task_started 之后没有 task_complete / turn_aborted = 正在干活
    public static func codexRolloutActivity(_ path: String) -> Activity? {
        let lines = JSONLines.trailing(URL(fileURLWithPath: path), maxBytes: 256 << 10)
        for line in lines.reversed() {
            guard line.range(of: Data(#""type":"task_"#.utf8)) != nil || line.range(of: Data(#""type":"turn_aborted""#.utf8)) != nil,
                  let r = JSONLines.object(line), r["type"] as? String == "event_msg",
                  let type = (r["payload"] as? [String: Any])?["type"] as? String else { continue }
            switch type {
            case "task_started": return .working
            case "task_complete", "turn_aborted": return .idle
            default: continue
            }
        }
        return nil
    }
}

/// 一次状态变化，用来决定发不发通知
public struct ActivityChange: Equatable, Sendable {
    public enum Kind: Sendable { case turnFinished, needsInput }
    public let kind: Kind
    public let sessionID: String
}

@MainActor
public extension WorkspaceStore {
    /// 每秒一次：读状态、标「没看过的完成」、返回需要通知的变化
    @discardableResult
    func pollActivity(appIsActive: Bool) -> [ActivityChange] {
        let codexTitles = terminalTitles
        // 本机 + 各主机的 claude 进程报的状态
        let claude = remoteSnapshots.values.reduce(ActivityMonitor.claudeStatuses()) { $0.merging($1.claude) { a, _ in a } }
        let reported = LiveReporting.statuses()   // OpenCode / omp 扩展报的
        let tmuxRunning = Tmux.runningSessions()
        var changes: [ActivityChange] = []

        // 开着的标签各自是什么状态
        var tabActivity: [UUID: Activity] = [:]
        for tab in allTabs {
            if tabBanners[tab.id] != nil { tabActivity[tab.id] = .ended; continue }
            guard case .session(let id, let cli) = tab.kind else { tabActivity[tab.id] = .idle; continue }
            let reported: Activity? = switch cli {
            case .claude: claude[id]
            case .codex: codexTitles[tab.id].flatMap(ActivityMonitor.codexActivity)
                ?? session(id)?.sourcePath.flatMap(ActivityMonitor.codexRolloutActivity)
            case .opencode, .omp: reported[id]
            }
            tabActivity[tab.id] = reported ?? .idle
        }

        let visibleTabs: Set<UUID> = {
            var ids = Set<UUID>()
            if let t = selectedTab?.id { ids.insert(t) }
            if let s = activeSplit { ids.insert(s.left); if let r = s.right { ids.insert(r) } }
            return appIsActive ? ids : []
        }()

        for i in sessions.indices {
            let s = sessions[i]
            let tab = tab(for: s)
            var next: Activity
            if let tab, let a = tabActivity[tab.id] {
                next = a
            } else if let a = claude[s.id] ?? reported[s.id] {
                next = a                                   // 在别的终端 / tmux 里跑的也算
            } else if s.hostID == Host.localID ? tmuxRunning.contains(Tmux.name(for: s.cli, sessionID: s.id))
                        : remoteSnapshots[s.hostID]?.tmux.contains(Tmux.name(for: s.cli, sessionID: s.id)) == true {
                next = s.cli == .codex ? (s.sourcePath.flatMap(ActivityMonitor.codexRolloutActivity) ?? .idle) : .idle
            } else {
                next = .notRunning
            }
            let previous = s.activity
            let seen = tab.map { visibleTabs.contains($0.id) } ?? false
            // 跑完一轮：之前在干活 / 等你，现在空闲，而你没在看 → 蓝点 + 通知
            if next == .idle, previous == .working || previous == .waitingForAnswer {
                if !seen {
                    next = .doneUnseen
                    changes.append(ActivityChange(kind: .turnFinished, sessionID: s.id))
                }
            } else if next == .idle, previous == .doneUnseen, !seen {
                next = .doneUnseen                         // 没看之前一直亮着
            }
            if next == .waitingForAnswer, previous != .waitingForAnswer, !seen {
                changes.append(ActivityChange(kind: .needsInput, sessionID: s.id))
            }
            if next != previous { sessions[i].activity = next }
        }

        // 标签上的灯跟会话一致
        for g in tabGroups.indices {
            for t in tabGroups[g].tabs.indices {
                let tab = tabGroups[g].tabs[t]
                var a = tabActivity[tab.id] ?? .idle
                if let s = session(for: tab), a == .idle, s.activity == .doneUnseen { a = .doneUnseen }
                if tab.activity != a { tabGroups[g].tabs[t].activity = a }
            }
        }
        return changes
    }

    /// 选中一个标签：它的「没看过的完成」变成已看
    func markSeen(_ tab: TerminalTab) {
        guard let s = session(for: tab), let i = sessions.firstIndex(where: { $0.id == s.id }),
              sessions[i].activity == .doneUnseen else { return }
        sessions[i].activity = .idle
        setActivity(.idle, forTab: tab.id)
    }
}
