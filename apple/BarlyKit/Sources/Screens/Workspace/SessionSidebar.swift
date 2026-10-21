import SwiftUI
import BarlyKit
#if os(macOS)
import AppKit
#endif

/// 会话库侧栏：栏头（红绿灯 · 搜索 / 铃铛 / 新会话）→ 项目 | 已打开 + 过滤 → 主机 → 项目 → 会话 → 添加主机 / 设置
public struct SessionSidebar: View {
    @Bindable var store: WorkspaceStore
    var onNewSession: () -> Void
    @Environment(\.barly) private var t
    @State private var addingHost = false

    public static var width: CGFloat { BarlyScale.pt(288) }

    public init(store: WorkspaceStore, onNewSession: @escaping () -> Void = {}) {
        self.store = store
        self.onNewSession = onNewSession
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            modeBar
            if store.isSearching {
                SidebarSearchField(text: $store.searchText)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                    .onChange(of: store.searchText) { _, _ in store.searchMessages() }
                if let p = store.indexProgress {
                    HStack(spacing: 8) {
                        ActivityLamp(.working, size: 6)
                        Text(verbatim: L("第一次搜索，正在建索引 \(p.done) / \(p.total)")).barlyText(.product.caption, color: t.text3).lineLimit(1)
                    }
                    .padding(.horizontal, 14).padding(.bottom, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Group {
                if store.sidebarMode == .openTabs {
                    OpenTabsList(store: store)
                } else {
                    content
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            // 从访达拖文件夹进来 = 添加到会话库
            .dropDestination(for: URL.self) { urls, _ in
                let folders = urls.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
                for url in folders { store.addProject(url.path) }
                return !folders.isEmpty
            }
            if store.selectedSessionIDs.count > 1 {
                MultiSelectBar(store: store)
            } else if let deletion = store.deletion {
                DeletionBar(progress: deletion) { store.deletion?.cancelling = true }
            } else if let outside = store.outsideRunning.first {
                OutsideRunningBar(outside: outside, onAdd: { store.addFolder(outside.path) }, onDismiss: { store.dismissOutside(outside) })
            } else if let tip = store.tip {
                TipCard(text: tip, onClose: { store.tip = nil }, onNext: { store.nextTip() })
            }
            footer
        }
        .frame(width: Self.width)
        .background(t.shellBase)
        .clipped()
        .onExitCommand { store.clearMultiSelection() }
        .sheet(isPresented: $addingHost) {
            AddHostSheet(onCancel: { addingHost = false }, onAdd: { alias, installed in
                addingHost = false
                store.addHost(alias, installed: installed)
            }, onConnect: { alias in
                addingHost = false
                store.addHost(alias, installed: [])
                store.connectingHost = alias
            })
        }
        #if os(macOS)
        .sheet(isPresented: Binding(get: { store.connectingHost != nil }, set: { if !$0 { store.connectingHost = nil } })) {
            if let alias = store.connectingHost {
                LiveConnectSheet(alias: alias) { ok in
                    store.connectingHost = nil
                    if ok { store.setDisconnected(alias, false) }
                }
            }
        }
        .sheet(item: $store.hostSheet) { sheet in
            switch sheet {
            case .portForward(let alias):
                LivePortForwardSheet(alias: alias) { store.hostSheet = nil }
            case .check(let alias):
                LiveHostCheckSheet(alias: alias, onFixWithAgent: { report in
                    store.hostSheet = nil
                    store.fixHostWithAgent(alias, report: report)
                }, onDone: { store.hostSheet = nil })
            case .signInSettings(let alias):
                SignInSettingsSheet(alias: alias, config: store.signInConfigs[alias]) { config in
                    store.hostSheet = nil
                    if config != store.signInConfigs[alias] { store.setSignIn(config, for: alias) }
                }
            case .addFolder(let alias):
                FolderPickerSheet(title: L("添加 \(alias) 上的文件夹"),
                                  subtitle: L("勾选要在侧栏里显示的项目；主机上还没有会话的文件夹可以直接填路径。"),
                                  candidates: store.folderCandidates(on: alias), added: store.folderIDs(on: alias),
                                  allowsPath: true, loading: !store.folderCandidatesLoaded(on: alias),
                                  secondaryTitle: L("取消"), onSecondary: { store.hostSheet = nil }) { picked, path in
                    store.hostSheet = nil
                    for id in picked { store.addFolder(String(id.dropFirst(alias.count + 1)), on: alias, refreshNow: false) }
                    Task {
                        if let path { await store.addRemoteFolder(path, on: alias, refreshNow: false) }
                        await store.reloadHostSessions(alias)
                    }
                }
                .task { await store.loadFolderCandidates(on: alias) }
            case .signIn(let alias):
                if let config = store.signInConfigs[alias] {
                    LiveConnectSheet(alias: alias, command: config.command) { ok in
                        store.hostSheet = nil
                        if ok { store.signedIn(alias) }
                    }
                }
            }
        }
        #endif
    }

    // MARK: 顶部

    private var header: some View {
        HStack(spacing: 2) {
            TrafficLights()
            PaneIcon(symbol: "chevron.left", help: L("后退（⌘[）")) { store.goBack() }
                .opacity(store.canGoBack ? 1 : 0.35)
            PaneIcon(symbol: "chevron.right", help: L("前进（⌘]）")) { store.goForward() }
                .opacity(store.canGoForward ? 1 : 0.35)
            Spacer()
            PaneIcon(symbol: "magnifyingglass", help: L("搜索项目、会话和消息（⌘F）")) { store.isSearching.toggle() }
            PaneIcon(symbol: "plus", help: L("新会话（⌘N）"), action: onNewSession)
        }
        .padding(.leading, 16).padding(.trailing, 8)
        .frame(height: WorkspaceMetrics.header)
    }

    private var modeBar: some View {
        HStack(spacing: 6) {
            ModeSwitch(selection: $store.sidebarMode, openTabs: store.openTabCount)
            FilterMenu(store: store)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
    }

    // MARK: 列表

    @ViewBuilder private var content: some View {
        switch store.loadState {
        case .loading:
            LoadingRows()
        case .failed(let message):
            SidebarMessage(symbol: "exclamationmark.triangle", title: L("读不到会话"), detail: message) {
                BarlyButton(L("重试"), icon: "arrow.clockwise", variant: .outline, size: .sm) { store.retry() }
            }
        case .loaded where store.isFiltering && !store.hasSearchResults:
            SidebarMessage(symbol: "magnifyingglass", title: L("没有匹配「\(store.trimmedQuery)」的会话"),
                           detail: L("搜索会查项目名、路径、会话标题和会话 ID。消息全文第一次搜索要先建索引。")) {
                BarlyButton(L("清除搜索"), variant: .ghost, size: .sm) { store.searchText = "" }
            }
        case .loaded:
            library
        }
    }

    private var library: some View {
        BarlyScroll {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(store.hosts) { host in
                    // 过滤、排序算一次，下面几处都用这一份
                    let hostProjects = store.projects(on: host.id)
                    let duplicateNames = Set(Dictionary(grouping: hostProjects, by: \.name).filter { $0.value.count > 1 }.keys)
                    let collapsed = store.collapsedHostIDs.contains(host.id) && !store.isFiltering
                    HostHeading(host: host, collapsed: collapsed, count: hostProjects.count,
                                onConnect: { store.connectingHost = host.id },
                                onSignIn: { store.hostSheet = .signIn(host.id) }) {
                        if store.collapsedHostIDs.contains(host.id) { store.collapsedHostIDs.remove(host.id) } else { store.collapsedHostIDs.insert(host.id) }
                    }
                    .contextMenu {
                        if host.isLocal {
                            Button("添加文件夹…") { addProjectFolder() }
                        } else {
                            HostMenu(store: store, host: host)
                        }
                    }
                    if !collapsed, hostProjects.isEmpty, !store.isFiltering {
                        if host.isLocal {
                            FolderEmptyState(store: store, onAdd: addProjectFolder)
                        } else {
                            HostEmptyNote(host: host)
                        }
                    }
                    ForEach(collapsed ? [] : hostProjects) { project in
                        ProjectRow(project: project,
                                   expanded: store.isExpanded(project),
                                   activity: store.activity(of: project),
                                   count: store.sessionCount(of: project),
                                   showsParent: duplicateNames.contains(project.name) || ProjectRow.looksGenerated(project.name),
                                   menu: { AnyView(ProjectMenu(store: store, project: project)) },
                                   quickStart: { AnyView(NewSessionItems(store: store, project: project, includesTerminal: true)) }) {
                            store.toggleExpanded(project)
                        }
                        .contextMenu { ProjectMenu(store: store, project: project) }
                        .draggable("project:" + project.id)
                        .dropDestination(for: String.self) { ids, _ in
                            guard project.isPinned, let id = ids.first, id.hasPrefix("project:") else { return false }
                            store.movePinnedProject(String(id.dropFirst(8)), before: project.id)
                            return true
                        }
                        if store.isExpanded(project) {
                            let visible = store.visibleSessions(in: project)
                            ForEach(visible.shown) { session in
                                let children = store.showsSubagents ? store.subagents(of: session) : []
                                SessionRow(session: session,
                                           selected: store.isSelected(session) || store.selectedSessionIDs.contains(session.id),
                                           snippet: store.messageHits[session.id], query: store.trimmedQuery,
                                           childCount: children.count, childrenExpanded: store.expandedSubagentParents.contains(session.id),
                                           onToggleChildren: { store.toggleSubagents(session) }) {
                                    store.click(session, command: Self.modifier(.command), shift: Self.modifier(.shift))
                                } onOpen: {
                                    store.resume(session)
                                } menu: {
                                    AnyView(sessionMenu(session))
                                }
                                .contextMenu { sessionMenu(session) }
                                .draggable(session.id)
                                .dropDestination(for: String.self) { ids, _ in
                                    guard session.isPinned, let id = ids.first, store.session(id) != nil else { return false }
                                    store.movePinnedSession(id, before: session.id)
                                    return true
                                }
                                if store.expandedSubagentParents.contains(session.id) {
                                    ForEach(children) { child in
                                        SessionRow(session: child, selected: store.isSelected(child), indent: 18) {
                                            store.select(child)
                                        }
                                    }
                                }
                            }
                            if visible.hidden > 0 {
                                Button { store.showMore(in: project) } label: {
                                    Text("再显示 \(min(20, visible.hidden)) 个")
                                        .barlyText(.product.caption, color: t.text3)
                                        .padding(.leading, WorkspaceMetrics.sessionInset)
                                        .frame(maxWidth: .infinity, minHeight: BarlyScale.pt(24), alignment: .leading)
                                        .background { TreeRowBackground() }
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .handCursor()
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
        }
    }

    // MARK: 底部

    /// 底栏：添加主机 · 设置 ｜ 右边是全部会话的状态计数（等你 · 工作中 · 没看过的完成），点一下打开「等待你的会话」
    private var footer: some View {
        HStack(spacing: 2) {
            PaneIcon(symbol: "folder.badge.plus", help: L("添加文件夹…")) { addProjectFolder() }
            PaneIcon(symbol: "server.rack", help: L("添加 SSH 主机…")) { addingHost = true }
            PaneIcon(symbol: "gearshape", help: L("设置（⌘,）"))
            Spacer()
            StatusCounts(sessions: store.sessions) { store.isBellOpen.toggle() }
        }
        .padding(.horizontal, 8)
        .frame(height: BarlyScale.pt(44))
    }
}

extension SessionSidebar {
    /// 会话的右键菜单（悬停「…」也用它）：多选时是批量菜单
    @ViewBuilder func sessionMenu(_ session: Session) -> some View {
        if store.selectedSessionIDs.count > 1, store.selectedSessionIDs.contains(session.id) {
            MultiSessionMenu(store: store)
        } else {
            SessionMenu(store: store, session: session)
        }
    }

    /// 选一个文件夹加成项目（还没有会话也列出来，可以从它的「新会话…」开始）
    func addProjectFolder() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = L("添加")
        if panel.runModal() == .OK, let url = panel.url { store.addProject(url.path) }
        #endif
    }

    /// 当前点击带没带 ⌘ / ⇧
    static func modifier(_ flag: NSEvent.ModifierFlags) -> Bool {
        #if os(macOS)
        NSEvent.modifierFlags.contains(flag)
        #else
        false
        #endif
    }
}

/// 底栏右边的状态计数：只列有的那几种，全是 0 时只留一个安静的铃铛
private struct StatusCounts: View {
    let sessions: [Session]
    let action: () -> Void
    @Environment(\.barly) private var t
    @State private var hovered = false

    var body: some View {
        let counts: [(Activity, Int)] = [Activity.waitingForAnswer, .working, .doneUnseen].map { a in
            (a, sessions.reduce(0) { $0 + ($1.activity == a ? 1 : 0) })
        }.filter { $0.1 > 0 }
        Button(action: action) {
            HStack(spacing: 10) {
                if counts.isEmpty {
                    Image(systemName: "bell").font(.system(size: 13)).foregroundStyle(t.text3)
                }
                ForEach(counts, id: \.0) { activity, n in
                    HStack(spacing: 4) {
                        ActivityLamp(activity, size: 7)
                        Text("\(n)").barlyText(.product.caption.monospaced.weight(500),
                                               color: activity == .waitingForAnswer ? t.accentText : t.text2)
                    }
                }
            }
            .padding(.horizontal, 8)
            .frame(height: BarlyScale.pt(28))
            .background(hovered ? t.fill2 : .clear, in: RoundedRectangle(cornerRadius: WorkspaceMetrics.rowRadius))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .handCursor()
        .help(L("等待你的会话"))
    }
}

/// 多选时侧栏底部：已选几个 · 归档 · 删除 · 结束运行 · 取消
private struct MultiSelectBar: View {
    let store: WorkspaceStore
    @Environment(\.barly) private var t

    var body: some View {
        let picked = store.multiSelection
        let running = picked.filter { $0.activity.isRunning }
        HStack(spacing: 6) {
            Text(verbatim: L("已选 \(picked.count) 个")).barlyText(.product.small, color: t.text2)
            Spacer()
            if !running.isEmpty {
                BarlyButton(L("结束 \(running.count) 个"), variant: .ghost, size: .sm) {
                    for s in running { store.endSession(s) }
                }
            }
            BarlyButton(L("归档"), variant: .ghost, size: .sm) {
                store.setArchived(picked.map(\.id), true)
                store.clearMultiSelection()
            }
            BarlyButton(L("删除…"), variant: .outline, size: .sm) {
                store.pendingDelete = picked
                store.clearMultiSelection()
            }
            PaneIcon(symbol: "xmark", help: L("取消选择（Esc）")) { store.clearMultiSelection() }
        }
        .padding(.horizontal, 10)
        .frame(height: BarlyScale.pt(44))
        .background(t.fill1)
        .overlay(alignment: .top) { Hairline() }
    }
}

/// 外壳尺寸（Mac 主窗口比 Web 紧一档，mac-native.md §3）
public enum WorkspaceMetrics {
    /// 侧栏栏头 / 标签栏高度（和红绿灯同一行）
    // 跟着界面缩放（BarlyScale）
    public static var header: CGFloat { BarlyScale.pt(48) }
    public static var row: CGFloat { BarlyScale.pt(28) }
    public static var tabHeight: CGFloat { BarlyScale.pt(26) }
    /// 标签栏：上面组头一行 + 下面标签一行，比侧栏栏头高一点，组头不贴窗口顶边
    public static var tabBar: CGFloat { BarlyScale.pt(52) }
    /// 标签栏组头（项目名 + 横线）那一行
    public static var groupHeader: CGFloat { BarlyScale.pt(16) }
    public static var tabMin: CGFloat { BarlyScale.pt(96) }
    public static var tabMax: CGFloat { BarlyScale.pt(180) }
    /// 终端面板离窗口边、面板之间的距离
    public static var gutter: CGFloat { BarlyScale.pt(8) }
    /// 面板头：标题 · 路径 · CLI
    public static var panelHeader: CGFloat { BarlyScale.pt(34) }
    /// 面板 8、行和标签 6（审美底线的圆角阶梯）
    public static let panelRadius: CGFloat = 8
    public static let rowRadius: CGFloat = 6
    /// 项目行的文件夹图标宽；会话行的树形引导线对准它的中线
    public static let folderIcon: CGFloat = 16
    /// 引导线离行左边的距离：行内边距 8 + 箭头 10 + 间距 6 + 图标一半 8
    public static let guideX: CGFloat = 32
    /// 会话行内容的起点（引导线右边留一点）
    public static let sessionInset: CGFloat = 42
}

/// 外壳的两层底：窗口底（侧栏、标签栏）更暗，终端面板浮在上面。浅色时底是浅灰、面板是白
extension BarlyPalette {
    var shellBase: Color { isDark ? bg : fill1 }
    var panelBg: Color { canvas }
    /// 底上的选中块：深色抬一级，浅色用白
    var shellSelected: Color { isDark ? fill2 : canvas }
}

// MARK: - 行

/// SSH 主机下面一个会话都没有时说清楚：还在拉、真没有、还是连不上
private struct HostEmptyNote: View {
    let host: Host
    @Environment(\.barly) private var t

    private var text: String {
        switch host.connection {
        case .refreshing: return L("正在从主机拉取会话…")
        case .needsConnect: return L("这台主机要密码或验证码，后台刷新登不上。")
        case .unreachable: return L("连不上，右键可以重试或断开。")
        case .disconnected: return L("已断开，不会自动访问。")
        case .needsSignIn: return L("重新登录到期了：点标题上的「登录…」。")
        case .connected:
            return host.installedCLIs.isEmpty
                ? L("主机上没有找到 Claude Code、Codex，也没有它们的会话。")
                : L("还没有添加这台主机上的文件夹：右键主机名 →「添加文件夹…」。")
        }
    }

    var body: some View {
        Text(text).barlyText(.product.caption, color: t.text4)
            .padding(.leading, 26).padding(.trailing, 8).padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HostHeading: View {
    let host: Host
    var collapsed = false
    var count = 0
    var onConnect: () -> Void = {}
    var onSignIn: () -> Void = {}
    var onToggle: () -> Void = {}
    @Environment(\.barly) private var t

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: host.isLocal ? "laptopcomputer" : "server.rack")
                .font(.system(size: 10))
                .foregroundStyle(t.text4)
            MonoLabel(host.isLocal ? "THIS MAC" : host.displayName, color: t.text3)
            if collapsed {
                Text(verbatim: L("\(count) 个项目")).barlyText(.product.caption, color: t.text4)
            }
            Spacer()
            switch host.connection {
            case .needsConnect:
                Text("连接…").barlyText(.product.caption.weight(500), color: t.text)
                    .padding(.horizontal, 7).frame(height: BarlyScale.pt(20))
                    .overlay(RoundedRectangle(cornerRadius: BarlyRadius.xs).stroke(t.borderStrong))
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onConnect)
                    .handCursor()
            case .refreshing(let done, let total):
                Text("\(done)/\(total)").barlyText(.product.caption.monospaced, color: t.text3)
            case .unreachable(let error):
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 10)).foregroundStyle(t.warning)
                    .help("连不上：\(error)")
            case .disconnected:
                MonoLabel("OFFLINE", color: t.text4)
            case .needsSignIn:
                Text("登录…").barlyText(.product.caption.weight(500), color: t.accentText)
                    .padding(.horizontal, 7).frame(height: BarlyScale.pt(20))
                    .overlay(RoundedRectangle(cornerRadius: BarlyRadius.xs).stroke(t.borderStrong))
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onSignIn)
                    .handCursor()
                    .help("这台主机的重新登录到期了")
            case .connected:
                EmptyView()
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 14).padding(.bottom, 4)
    }
}

private struct ProjectRow: View {
    let project: Project
    let expanded: Bool
    let activity: Activity
    let count: Int
    /// 名字分不清时（同一台主机上重名、或者是 UUID 这类看不出是什么的）在下面写上一级路径
    var showsParent = false
    /// 悬停时右边换成「…」（项目菜单）和「+」（快速新建）
    var menu: (() -> AnyView)? = nil
    var quickStart: (() -> AnyView)? = nil
    let action: () -> Void
    @Environment(\.barly) private var t
    @State private var hovered = false

    private var showsActions: Bool { hovered && menu != nil }

    /// 上一级目录的最后两段：「Sam990/ProjectDock」
    private var parent: String {
        let dir = (project.shortPath as NSString).deletingLastPathComponent
        return dir.split(separator: "/").suffix(2).joined(separator: "/")
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(t.text4)
                    .rotationEffect(.degrees(expanded ? 90 : 0))
                    .frame(width: 10)
                Image(systemName: project.folderExists ? "folder" : "questionmark.folder")
                    .font(.system(size: 12))
                    .foregroundStyle(project.folderExists ? t.text3 : t.warning)
                    .frame(width: WorkspaceMetrics.folderIcon)
                    .help(project.folderExists ? project.path : L("文件夹已经不在了"))
                VStack(alignment: .leading, spacing: 0) {
                    Text(project.name)
                        .barlyText(.product.small.weight(600), color: t.text)
                        .lineLimit(1).truncationMode(.middle)
                    if showsParent, !parent.isEmpty {
                        Text(parent).barlyText(.product.caption.size(11), color: t.text4).lineLimit(1).truncationMode(.head)
                    }
                }
                .layoutPriority(1)
                if project.isPinned {
                    Image(systemName: "pin.fill").font(.system(size: 7)).foregroundStyle(t.text4)
                }
                Spacer(minLength: 6)
                ActivityLamp(activity, size: 6)
                // 会话数靠右成一列；悬停时让位给「… +」
                Text("\(count)").barlyText(.product.caption.monospaced, color: t.text4)
                    .frame(minWidth: 22, alignment: .trailing)
                    .opacity(showsActions ? 0 : 1)
                    .frame(width: showsActions ? RowAction.size * 2 + 2 : nil, alignment: .trailing)
            }
            .padding(.horizontal, 8)
            .frame(minHeight: WorkspaceMetrics.row)
            .padding(.vertical, showsParent ? 3 : 0)
            .background(hovered ? t.fill1 : .clear, in: RoundedRectangle(cornerRadius: WorkspaceMetrics.rowRadius))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .trailing) {
            if showsActions, let menu, let quickStart {
                HStack(spacing: 2) {
                    RowAction(symbol: "ellipsis", help: L("更多"), content: menu)
                    RowAction(symbol: "plus", help: L("新会话"), content: quickStart)
                }
                .padding(.trailing, 6)
            }
        }
        .onHover { hovered = $0 }
        .handCursor()
        .help(project.path)
    }

    /// 只有十六进制和横线、又很长：多半是工具生成的 UUID 目录
    static func looksGenerated(_ name: String) -> Bool {
        name.count >= 16 && name.allSatisfy { $0.isHexDigit || $0 == "-" }
    }
}

struct SessionRow: View {
    let session: Session
    let selected: Bool
    /// 消息全文搜索命中的那一句，显示在标题下面
    var snippet: String? = nil
    var query = ""
    /// 子代理：几个、展开没有、点箭头
    var childCount = 0
    var childrenExpanded = false
    var onToggleChildren: () -> Void = {}
    /// 子代理行再往里缩
    var indent: CGFloat = 0
    let action: () -> Void
    /// 双击：在原目录里接着跑
    var onOpen: () -> Void = {}
    /// 悬停时右边换成「…」，点开就是右键菜单
    var menu: (() -> AnyView)? = nil
    @Environment(\.barly) private var t
    @State private var hovered = false

    /// 片段里的关键词用正文色 + 中粗，其余次要色
    private func highlighted(_ snippet: String) -> AttributedString {
        var out = AttributedString(snippet)
        if !query.isEmpty, let r = out.range(of: query, options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]) {
            out[r].foregroundColor = t.text
            out[r].font = .system(size: 12, weight: .semibold)
        }
        return out
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if childCount > 0 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(t.text4)
                        .rotationEffect(.degrees(childrenExpanded ? 90 : 0))
                        .frame(width: 10, height: 16)
                        .contentShape(Rectangle())
                        .onTapGesture(perform: onToggleChildren)
                        .help("\(childCount) 个子代理会话")
                        .padding(.leading, -18)
                }
                CLIMark(session.cli, size: 14)
                Text(session.displayTitle)
                    .barlyText(.product.small.weight(selected ? 500 : 400), color: selected ? t.text : t.text2)
                    .lineLimit(1)
                if session.isPinned {
                    Image(systemName: "pin.fill").font(.system(size: 7)).foregroundStyle(t.text4)
                }
                if session.isArchived {
                    Image(systemName: "archivebox").font(.system(size: 9)).foregroundStyle(t.text4)
                }
                Spacer(minLength: 6)
                Group {
                    if session.activity == .notRunning {
                        RelativeAge(session.lastActivity)
                    } else {
                        ActivityLamp(session.activity)
                    }
                }
                .opacity(hovered && menu != nil ? 0 : 1)
            }
            .padding(.leading, WorkspaceMetrics.sessionInset + indent).padding(.trailing, 8)
            .frame(height: WorkspaceMetrics.row)
            .overlay(alignment: .bottomLeading) {
                if let snippet {
                    Text(highlighted(snippet)).barlyText(.product.caption, color: t.text3).lineLimit(1)
                        .padding(.leading, WorkspaceMetrics.sessionInset + indent + 22).padding(.trailing, 8)
                        .offset(y: 14)
                }
            }
            .padding(.bottom, snippet == nil ? 0 : 16)
            .background { TreeRowBackground(selected: selected, hovered: hovered) }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .trailing) {
            if hovered, let menu {
                RowAction(symbol: "ellipsis", help: L("更多"), content: menu)
                    .padding(.trailing, 6)
            }
        }
        .simultaneousGesture(TapGesture(count: 2).onEnded { onOpen() })
        .onHover { hovered = $0 }
        .handCursor()
        .help("\(session.displayTitle)\n单击预览，双击接着跑")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// 行尾悬停出现的小按钮，点开是一个菜单（项目的「…」「+」）
struct RowAction: View {
    static let size: CGFloat = 22
    let symbol: String
    let help: String
    let content: () -> AnyView
    @Environment(\.barly) private var t
    @State private var hovered = false

    var body: some View {
        Menu { content() } label: {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(hovered ? t.text : t.text2)
                .frame(width: Self.size, height: 20)
                .background(hovered ? t.fill2 : .clear, in: RoundedRectangle(cornerRadius: 5))
                .contentShape(Rectangle())
        }
        .menuStyle(.button).buttonStyle(.plain).menuIndicator(.hidden).fixedSize()
        .onHover { hovered = $0 }
        .handCursor()
        .help(help)
    }
}

/// 会话行的底：左边一根树形引导线（对准项目的文件夹图标，相邻行连成一条），选中时这一段变成强调色短条；
/// 浅底从引导线右边开始，树的线条始终露在外面
struct TreeRowBackground: View {
    var selected = false
    var hovered = false
    @Environment(\.barly) private var t

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: WorkspaceMetrics.rowRadius)
                .fill(selected ? t.shellSelected : hovered ? t.fill1 : .clear)
                .padding(.leading, WorkspaceMetrics.guideX + 5)
            Rectangle().fill(t.hairline)
                .frame(width: 1)
                .padding(.vertical, -1)
                .padding(.leading, WorkspaceMetrics.guideX)
            if selected {
                RoundedRectangle(cornerRadius: 1.5).fill(t.accent)
                    .frame(width: 3, height: 16)
                    .padding(.leading, WorkspaceMetrics.guideX - 1)
            }
        }
    }
}

/// 「项目 | 已打开 N」：Segmented 的侧栏版（槽 + 浅一级滑块，高 28）
private struct ModeSwitch: View {
    @Binding var selection: SidebarMode
    let openTabs: Int
    @Environment(\.barly) private var t

    var body: some View {
        HStack(spacing: 2) {
            segment(.projects, L("项目"))
            segment(.openTabs, L("已打开"), count: openTabs)
        }
        .padding(2)
        .background(t.isDark ? t.fill1 : t.fill2, in: RoundedRectangle(cornerRadius: WorkspaceMetrics.rowRadius))
    }

    private func segment(_ mode: SidebarMode, _ title: String, count: Int? = nil) -> some View {
        let on = selection == mode
        return Button { selection = mode } label: {
            HStack(spacing: 5) {
                Text(title).barlyText(.product.small.weight(on ? 500 : 400), color: on ? t.text : t.text3)
                if let count, count > 0 {
                    Text("\(count)").barlyText(.product.caption.monospaced, color: on ? t.text2 : t.text4)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: BarlyScale.pt(24))
            .background(on ? (t.isDark ? t.fill3 : t.canvas) : .clear, in: RoundedRectangle(cornerRadius: WorkspaceMetrics.rowRadius - 2))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .handCursor()
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

private struct SidebarSearchField: View {
    @Binding var text: String
    @Environment(\.barly) private var t

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundStyle(t.text3)
            BarlyBareField(placeholder: L("项目、会话、消息"), text: $text, style: .product.small)
            if !text.isEmpty {
                Image(systemName: "xmark.circle.fill").font(.system(size: 11)).foregroundStyle(t.text4)
                    .onTapGesture { text = "" }
                    .handCursor()
            }
        }
        .padding(.horizontal, 8)
        .frame(height: BarlyScale.pt(28))
        .background(t.fieldBg, in: RoundedRectangle(cornerRadius: BarlyRadius.sm))
        .overlay(RoundedRectangle(cornerRadius: BarlyRadius.sm).stroke(t.borderStrong))
    }
}

/// 侧栏里的空 / 错 / 无结果：图标 + 一句标题 + 说明 + 一个出路
private struct SidebarMessage<Action: View>: View {
    let symbol: String
    let title: String
    let detail: String
    @ViewBuilder var action: Action
    @Environment(\.barly) private var t

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol).font(.system(size: 16)).foregroundStyle(t.text3)
            Text(title).barlyText(.product.small.weight(500), color: t.text)
            Text(detail).barlyText(.product.caption, color: t.text3)
                .fixedSize(horizontal: false, vertical: true)
            action.padding(.top, 4)
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct LoadingRows: View {
    @Environment(\.barly) private var t

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<14, id: \.self) { i in
                let isProject = i % 5 == 0
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2).fill(t.fill2).frame(width: isProject ? 12 : 16, height: isProject ? 10 : 16)
                    RoundedRectangle(cornerRadius: 2).fill(t.fill2)
                        .frame(width: CGFloat([150, 190, 120, 170, 140][i % 5]), height: 9)
                    Spacer()
                }
                .padding(.leading, isProject ? 26 : 34)
                .frame(height: WorkspaceMetrics.row)
            }
        }
        .padding(.top, 10)
    }
}
