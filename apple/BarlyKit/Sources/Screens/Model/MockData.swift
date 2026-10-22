import Foundation

/// 原型用的假数据：真实感中文、长短参差，覆盖四种 CLI 和全部状态
public enum MockData {
    public static let local = Host(id: Host.localID, kind: .local, displayName: "这台 Mac")
    public static let devbox = Host(id: "devbox", kind: .ssh(target: "devbox"), displayName: "devbox",
                                    installedCLIs: [.claude, .codex])
    public static let gpu = Host(id: "jp-gpu", kind: .ssh(target: "leo@jp-gpu"), displayName: "jp-gpu",
                                 connection: .needsConnect, installedCLIs: [.claude])
    public static let hosts = [local, devbox, gpu]

    static let root = NSHomeDirectory() + "/code"
    public static let relay = "\(root)/relay-gateway"
    public static let notes = "\(root)/notes-site"
    public static let market = "\(root)/secondhand-market"
    public static let shelf = "\(root)/shelf-app"
    public static let imagery = "\(root)/imagery"
    public static let board = "\(root)/agent-board"
    public static let billing = "/home/leo/billing-api"

    public static let projects: [Project] = [
        Project(hostID: Host.localID, path: relay),
        Project(hostID: Host.localID, path: notes),
        Project(hostID: Host.localID, path: market),
        Project(hostID: Host.localID, path: shelf),
        Project(hostID: Host.localID, path: imagery),
        Project(hostID: Host.localID, path: board, folderExists: false),
        Project(hostID: "devbox", path: billing),
        Project(hostID: "devbox", path: "/home/leo/proxy-hub"),
    ]

    public static let focusedProjectID = ProjectID(host: Host.localID, path: relay)
    static let expanded: Set<ProjectID> = [focusedProjectID, ProjectID(host: Host.localID, path: notes), ProjectID(host: "devbox", path: billing)]

    static func ago(_ minutes: Double) -> Date { Date.now.addingTimeInterval(-minutes * 60) }

    static func s(_ id: String, _ cli: CLIKind, _ path: String, _ title: String, _ minutes: Double,
                  model: String? = nil, messages: Int = 40, host: String = Host.localID) -> Session {
        Session(id: id, cli: cli, hostID: host, projectPath: path, title: title, model: model,
                lastActivity: ago(minutes), messageCount: messages)
    }

    /// 截图里的本地标记（置顶在会话库里，不挂在 Session / Project 上）
    static var library: LibraryState {
        var s = LibraryState()
        s.pinnedProjects = [ProjectID(host: Host.localID, path: relay).raw]
        s.pinnedSessions = ["0c93aa51"]
        return s
    }

    /// 截图里各个会话的状态灯（状态不挂在 Session 上，见 WorkspaceData.activity）
    static let sessionActivity: [String: Activity] = [
        "4f1a9c2e": .working,
        "7b20e4d1": .waitingForAnswer,
        "0c93aa51": .doneUnseen,
        "e2d7b630": .idle,
        "b1f0a7c4": .idle,
        "f5e3a1b4": .working,
        "ea1d8f09": .working,
        "long0": .waitingForAnswer,
    ]

    public static let sessions: [Session] = [
        s("4f1a9c2e", .claude, relay, "上架 haiku-5-5 并核对两档计费", 0.5, model: "claude-opus-5-5",
          messages: 212),
        s("7b20e4d1", .codex, relay, "渠道优先级回退时日志里缺少上游名", 6, model: "gpt-6.1 · high",
          messages: 58),
        s("0c93aa51", .claude, relay, "首页价格表改成按分组展示", 42, model: "claude-opus-5-5", messages: 96),
        s("e2d7b630", .omp, relay, "压测 /v1/messages 在 200 并发下的 P99", 95, model: "gemini-4-argon",
          messages: 31),
        s("91be0f47", .claude, relay, "注册页加邀请码校验，过期给明确提示", 60 * 20, model: "claude-opus-5-5", messages: 74),
        s("5aa1c8e9", .opencode, relay, "迁移脚本：把旧 tokens 表的分组字段补齐", 60 * 26, messages: 22),
        s("33f0d2b8", .claude, relay, "日志面板加按上游筛选", 60 * 49, messages: 15),
        s("b1f0a7c4", .claude, notes, "笔记站的全文搜索换成 SQLite FTS5", 3, model: "claude-opus-5-5", messages: 64),
        s("c2aa9e10", .codex, notes, "把文章页的目录改成跟随滚动高亮", 60 * 3, model: "gpt-6.1 · medium"),
        s("d3c18f22", .omp, notes, "试一下 gemini-4-argon 的长上下文", 60 * 9),
        s("e4d2c0a3", .claude, notes, "合并重复的标签，并给旧链接做重定向", 60 * 30),
        s("f5e3a1b4", .claude, market, "消息议价改成 WebSocket 推送，断线后补拉未读", 25, model: "claude-opus-5-5",
          messages: 140),
        s("a6f4b2c5", .codex, market, "订单列表分页在最后一页多出一条", 60 * 5),
        s("b7a5c3d6", .claude, shelf, "拖放货架在多显示器下的坐标换算", 60 * 26),
        s("c8b6d4e7", .opencode, imagery, "生图降级链的超时重试", 60 * 50),
        s("d9c7e5f8", .claude, board, "看板拖动排序后状态没回写", 60 * 24 * 6),
        s("ea1d8f09", .claude, billing, "缓存 TTL 覆盖标记位失效的排查", 12, model: "claude-sonnet-5-5", host: "devbox"),
        s("fb2e9a1a", .codex, billing, "运维日志表加 30 天保留策略", 60 * 7, host: "devbox"),
        s("0c3fab2b", .claude, "/home/leo/proxy-hub", "升级到 0.9.7 后的配置迁移", 60 * 24 * 2, host: "devbox"),
    ]

    static let tabGroups: [TabGroup] = [
        TabGroup(projectID: ProjectID(host: Host.localID, path: notes), name: "notes-site", tint: 2, tabs: [
            TerminalTab(kind: .session(id: "b1f0a7c4", cli: .claude), projectPath: notes,
                        title: "笔记站的全文搜索换成 SQLite FTS5", activity: .idle),
            TerminalTab(kind: .plainTerminal, projectPath: notes, title: "zsh", activity: .idle),
        ]),
        TabGroup(projectID: focusedProjectID, name: "relay-gateway", tint: 0, tabs: [
            TerminalTab(kind: .session(id: "4f1a9c2e", cli: .claude), projectPath: relay,
                        title: "上架 haiku-5-5 并核对两档计费", activity: .working),
            TerminalTab(kind: .session(id: "7b20e4d1", cli: .codex), projectPath: relay,
                        title: "渠道优先级回退时日志里缺少上游名", activity: .waitingForAnswer),
            TerminalTab(kind: .session(id: "0c93aa51", cli: .claude), projectPath: relay,
                        title: "首页价格表改成按分组展示", activity: .doneUnseen),
            TerminalTab(kind: .session(id: "e2d7b630", cli: .omp), projectPath: relay,
                        title: "压测 /v1/messages 在 200 并发下的 P99", activity: .idle),
        ]),
        TabGroup(projectID: ProjectID(host: Host.localID, path: market), name: "secondhand-market", tint: 4, tabs: [
            TerminalTab(kind: .session(id: "f5e3a1b4", cli: .claude), projectPath: market,
                        title: "消息议价改成 WebSocket 推送，断线后补拉未读", activity: .working),
        ]),
        TabGroup(projectID: ProjectID(host: "devbox", path: billing), name: "billing-api", tint: 3, tabs: [
            TerminalTab(kind: .session(id: "ea1d8f09", cli: .claude), hostID: "devbox", projectPath: billing,
                        title: "缓存 TTL 覆盖标记位失效的排查", activity: .working),
        ], isCollapsed: true),
    ]

    // MARK: 极端数据（long 状态）

    static let extremeProjects: [Project] = [
        Project(hostID: Host.localID,
                path: NSHomeDirectory() + "/Library/Mobile Documents/com~apple~CloudDocs/归档/2025 年一个名字非常非常长的客户项目-最终版-v3"),
    ]

    static let extremeSessions: [Session] = [
        s("long0", .claude, relay,
          "把整个计费模块从按次改成按 token 分档，并保证旧账单可以重新计算，同时给运营后台加一个对账导出，导出要能按渠道和分组筛选",
          1, messages: 12_480),
    ] + (1..<40).map { i in
        s("long\(i)", CLIKind.allCases[i % 4], relay, "批量任务 #\(1200 + i)：核对第 \(i) 批上游渠道的模型列表",
          Double(60 * 24 * (i + 3)), messages: 30 + i)
    } + [
        s("long99", .codex, extremeProjects[0].path, "这个项目名很长，用来看侧栏的中间截断", 60 * 24 * 40),
    ]

    static let extremeTabGroups: [TabGroup] = tabGroups + [
        TabGroup(projectID: ProjectID(host: Host.localID, path: shelf), name: "shelf-app", tint: 1,
                 tabs: (0..<9).map { i in
                     TerminalTab(kind: .session(id: "long\(i + 1)", cli: .claude), projectPath: shelf,
                                 title: "一个很长很长的标签标题，用来看标签收窄后的渐隐 \(i)", activity: .idle)
                 }),
    ]

    // MARK: 对话预览

    static let transcript: [TranscriptEntry] = {
        var i = 0
        func e(_ kind: TranscriptEntry.Kind, _ minutes: Double) -> TranscriptEntry {
            defer { i += 1 }
            return TranscriptEntry(id: i, kind: kind, time: ago(minutes))
        }
        return [
            e(.user("首页价格表改成按分组展示：同一个模型在不同分组下价格不一样，现在只显示了默认分组的。"), 70),
            e(.assistant("先看一下价格表现在的数据从哪来。"), 69),
            e(.tools(count: 4, summary: "Read pricing.tsx · Grep groupRatio · Read api/pricing.go · Bash go test ./pricing"), 68),
            e(.assistant("价格表只读了 `model_price`，没有乘分组倍率。分组倍率在 `group_ratio` 表里，前端拿不到。\n\n我准备这样改：\n\n1. `/api/pricing` 返回每个模型在**每个分组**下的价格\n2. 表头加分组切换，默认选当前用户所在分组\n3. 倍率为 1 的分组不单独显示"), 66),
            e(.user("可以，倍率为 1 的也显示，不然用户以为没有这个分组。"), 60),
            e(.tools(count: 6, summary: "Edit api/pricing.go · Edit pricing.tsx · Bash go test ./... · Bash pnpm build"), 55),
            e(.code(language: "go", code: "for _, g := range groups {\n    ratio := groupRatio[g.Name]\n    row.Prices[g.Name] = Price{\n        Input:  base.Input * ratio,\n        Output: base.Output * ratio,\n    }\n}"), 54),
            e(.image(caption: "截图 · 价格表按分组切换后的样子"), 50),
            e(.assistant("改好了。测试全过，本地起服务看了一遍：切到「Claude Max」分组时 haiku-5-5 的价格是官方价 × 2.18，和后台一致。"), 42),
        ]
    }()

    // MARK: 终端假画面（原型阶段代替真实终端；阶段④ 换成 SwiftTerm）

    public enum LineStyle: Sendable { case text, dim, prompt, tool, added, removed, working }

    public static let terminalLines: [(LineStyle, String)] = [
        (.tool, "✻ Claude Code v2.1.250"),
        (.dim, "  claude-opus-5-5 · Claude Max · ~/code/relay-gateway"),
        (.text, ""),
        (.prompt, "> 上架 haiku-5-5，价格按官方两档，算一遍扣费对不对"),
        (.text, ""),
        (.text, "● 先看现有的分档表达式怎么写的。"),
        (.text, ""),
        (.tool, "● Bash(ssh devbox 'psql -U root -d relay -c \"select key, \\\"group\\\" from tokens where id = 13\"')"),
        (.dim, "  ⎿  token group: Claude Max"),
        (.dim, "     {\"model\":\"haiku-5-5\",\"usage\":{\"input_tokens\":17,\"output_tokens\":10}}"),
        (.text, ""),
        (.text, "● 手算：(17×0.1 + 10×0.5) ÷ 10⁶ × 2.18 ≈ 7.3，日志里 quota = 7，命中 standard 档。"),
        (.text, ""),
        (.tool, "● Update(docs/pricing.md)"),
        (.dim, "  ⎿  Added 9 lines, removed 1 line"),
        (.removed, "     8 -  updated: 2026-09-22"),
        (.added, "     8 +  updated: 2026-10-20"),
        (.added, "   122 +  haiku-5-5：两档价格照官方原价，>100K 走高档"),
        (.text, ""),
        (.text, "● haiku-5-5 已上架，用管理员 token 发了一次真实请求，扣费对得上。"),
        (.text, "  还没验证：超过 100K 的长提示会不会走高档。"),
        (.text, ""),
        (.working, "✻ Testing the >100K tier… (38s · ↓ 2.1k tokens)"),
        (.text, ""),
        (.prompt, "> "),
        (.dim, "  ⏵⏵ auto mode on (shift+tab to cycle)"),
    ]
}

public extension MockData {
    /// Codex 停下来等你批准一条命令（分屏右边用）
    static let codexLines: [(LineStyle, String)] = [
        (.tool, ">_ OpenAI Codex (v0.160.0)"),
        (.dim, "  model: gpt-6.1 high · directory: ~/code/relay-gateway"),
        (.text, ""),
        (.prompt, "› 渠道优先级回退时，日志里要带上游名"),
        (.text, ""),
        (.text, "• 回退逻辑在 relay/channel/fallback.go，日志只打了渠道 ID。"),
        (.text, "  我会在 retryWithNext() 里把上游名一起写进去，再补一个单测。"),
        (.text, ""),
        (.tool, "• Proposed command"),
        (.dim, "  go test ./relay/channel/... -run TestFallbackLogs -count=1"),
        (.text, ""),
        (.working, "  Allow command?  [y] Yes   [a] Always   [n] No"),
    ]
}

extension MockData {
    /// 本机发现过会话、但还没加进会话库的文件夹（空状态推荐、升级挑选、添加列表用）
    static var folderCandidates: [FolderLibrary.Candidate] {
        FolderLibrary.index(sessions.filter { $0.hostID == Host.localID } + extremeSessions.filter { $0.hostID == Host.localID }) { _ in true }
    }

    /// SSH 主机 devbox 上发现过会话的文件夹
    static var devboxCandidates: [FolderLibrary.Candidate] {
        FolderLibrary.index(sessions.filter { $0.hostID == "devbox" }) { _ in true }
    }
}

public extension WorkspaceStore {
    /// 截图用的固定状态。名字和屏幕清单的状态列一一对应。
    static func fixture(_ state: String) -> WorkspaceStore {
        let store: WorkspaceStore
        switch state {
        case "empty":
            store = WorkspaceStore(hosts: [MockData.local], projects: [], sessions: [])
        case "folders-empty":
            // 会话库里还没有本机文件夹：空状态 + 最近有会话的文件夹推荐
            store = WorkspaceStore(hosts: [MockData.local], projects: [], sessions: [])
            store.data.folderCandidates[Host.localID] = MockData.folderCandidates
        case "loading":
            store = WorkspaceStore(hosts: [MockData.local], projects: [], sessions: [], loadState: .loading)
        case "error":
            store = WorkspaceStore(hosts: [MockData.local], projects: [], sessions: [],
                                   loadState: .failed("读不到 ~/.claude/projects：Switchboard 没有这个文件夹的访问权限。"))
        case "long":
            store = WorkspaceStore(hosts: MockData.hosts, projects: MockData.projects + MockData.extremeProjects,
                                   sessions: MockData.sessions + MockData.extremeSessions,
                                   tabGroups: MockData.extremeTabGroups, activity: MockData.sessionActivity)
        default:
            store = WorkspaceStore(hosts: MockData.hosts, projects: MockData.projects, sessions: MockData.sessions,
                                   tabGroups: MockData.tabGroups, transcripts: ["0c93aa51": MockData.transcript],
                                   activity: MockData.sessionActivity)
        }
        store.library = MockData.library
        store.expandedProjectIDs = MockData.expanded
        switch state {
        case "search-empty":
            store.isSearching = true
            store.searchText = "kubernetes 灰度"
        case "preview":
            store.selection = .preview(sessionID: "0c93aa51")
        case "preview-missing":
            store.selection = .preview(sessionID: "d9c7e5f8")
        case "split", "split-choose":
            let relayTabs = store.tabGroups.first { $0.projectID == MockData.focusedProjectID }!.tabs
            store.selection = .tab(relayTabs[0].id)
            store.split = SplitState(left: relayTabs[0].id, right: state == "split" ? relayTabs[1].id : nil, ratio: 0.52)
        case "open-tabs", "open-tabs-select":
            store.sidebarMode = .openTabs
            let tabs = store.allTabs
            store.selection = .tab(tabs[2].id)
            if state == "open-tabs-select" { store.openTabSelection = [tabs[1].id, tabs[3].id, tabs[5].id] }
        case "ended", "failed", "reconnecting", "deleting":
            let tabs = store.allTabs
            let tab = state == "reconnecting" ? tabs.first { $0.hostID == "devbox" }! : tabs[2]
            store.selection = .tab(tab.id)
            switch state {
            case "ended":
                store.tabBanners[tab.id] = .exited(code: 0)
                store.setActivity(.ended, forTab: tab.id)
            case "failed":
                store.tabBanners[tab.id] = .failed(code: 127, hint: "zsh: command not found: claudee")
                store.setActivity(.ended, forTab: tab.id)
            case "reconnecting":
                store.tabBanners[tab.id] = .reconnecting(attempt: 3, nextIn: 12)
                if let i = store.tabGroups.firstIndex(where: { $0.projectID == ProjectID(host: "devbox", path: MockData.billing) }) {
                    store.tabGroups[i].isCollapsed = false
                }
            default: store.deletion = DeletionProgress(done: 37, total: 140)
            }
        case "outside-running":
            store.outsideRunning = [FolderLibrary.Outside(path: NSHomeDirectory() + "/code/agent-lab", count: 2)]
            if let tab = store.tabGroups.first(where: { $0.projectID == MockData.focusedProjectID })?.tabs.first {
                store.selection = .tab(tab.id)
            }
        case "tip":
            store.tip = "把标签拖到终端区的左右边缘，就能和当前标签并排分屏。"
            if let tab = store.tabGroups.first(where: { $0.projectID == MockData.focusedProjectID })?.tabs.first {
                store.selection = .tab(tab.id)
            }
        case "tour1", "tour2", "tour3":
            store.tourStep = Int(state.suffix(1))
            store.selection = nil
            store.tabGroups = []
        case "bell":
            if let tab = store.tabGroups.first(where: { $0.projectID == MockData.focusedProjectID })?.tabs.first {
                store.selection = .tab(tab.id)
            }
            store.isBellOpen = true
        case "long":
            store.expandedProjectIDs.insert(ProjectID(host: Host.localID, path: MockData.extremeProjects[0].path))
            if let tab = store.tabGroups.last?.tabs.first { store.selection = .tab(tab.id) }
        default:
            if let tab = store.tabGroups.first(where: { $0.projectID == MockData.focusedProjectID })?.tabs.first {
                store.selection = .tab(tab.id)
            }
        }
        if ["empty", "loading", "error", "folders-empty"].contains(state) { store.selection = nil }
        return store
    }
}
