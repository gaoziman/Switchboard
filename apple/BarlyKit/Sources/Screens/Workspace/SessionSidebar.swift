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
    #if os(macOS)
    @Environment(\.openSettings) private var openSettings
    #endif
    @State private var addingHost = false
    /// 会话库列表有键盘焦点：方向键在里面走（点了行就给它焦点）
    @FocusState private var libraryFocused: Bool

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
            .tourAnchor(.library)
            // 从访达拖文件夹进来 = 添加到会话库
            .live { $0.dropDestination(for: URL.self) { urls, _ in
                let folders = urls.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
                for url in folders { store.addProject(url.path) }
                return !folders.isEmpty
            } }
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
        .shellPanel()
        .padding([.leading, .top, .bottom], WorkspaceMetrics.gutter)
        .onExitCommand { store.clearMultiSelection() }
        .sheet(isPresented: $addingHost) {
            AddHostSheet(onCancel: { addingHost = false }, onAdd: { alias, installed in
                addingHost = false
                store.addHost(alias, installed: installed)
            }, onConnect: { alias in
                addingHost = false
                store.addHost(alias, installed: [])
                store.presentation = .connect(host: alias)
            })
        }
        #if os(macOS)
        .sheet(isPresented: store.isPresenting(\.connectingHost)) {
            if let alias = store.presentation?.connectingHost {
                LiveConnectSheet(alias: alias) { ok in
                    store.presentation = nil
                    if ok { store.setDisconnected(alias, false) }
                }
            }
        }
        .sheet(item: store.presented(\.hostSheet)) { sheet in
            switch sheet {
            case .portForward(let alias):
                LivePortForwardSheet(alias: alias) { store.presentation = nil }
            case .check(let alias):
                LiveHostCheckSheet(alias: alias, onFixWithAgent: { report in
                    store.presentation = nil
                    store.fixHostWithAgent(alias, report: report)
                }, onDone: { store.presentation = nil })
            case .signInSettings(let alias):
                SignInSettingsSheet(alias: alias, config: store.signInConfigs[alias]) { config in
                    store.presentation = nil
                    if config != store.signInConfigs[alias] { store.setSignIn(config, for: alias) }
                }
            case .addFolder(let alias):
                FolderPickerSheet(title: L("添加 \(alias) 上的文件夹"),
                                  subtitle: L("勾选要在侧栏里显示的项目；主机上还没有会话的文件夹可以直接填路径。"),
                                  candidates: store.folderCandidates(on: alias), added: store.folderIDs(on: alias),
                                  allowsPath: true, loading: !store.folderCandidatesLoaded(on: alias),
                                  secondaryTitle: L("取消"), onSecondary: { store.presentation = nil }) { picked, path in
                    store.presentation = nil
                    for id in picked { store.addFolder(id.path, on: alias, refreshNow: false) }
                    Task {
                        if let path { await store.addRemoteFolder(path, on: alias, refreshNow: false) }
                        await store.data.refresh(.folders(alias))
                    }
                }
                .task { await store.loadFolderCandidates(on: alias) }
            case .signIn(let alias):
                if let config = store.signInConfigs[alias] {
                    LiveConnectSheet(alias: alias, command: config.command) { ok in
                        store.presentation = nil
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
                .tourAnchor(.newSession)
        }
        .padding(.leading, 16 - WorkspaceMetrics.gutter).padding(.trailing, 6)
        // 面板顶已经让出 gutter：行高再减一个 gutter，图标行的中线和窗口顶的距离不变，和红绿灯对齐
        .frame(height: WorkspaceMetrics.header - WorkspaceMetrics.gutter * 2)
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
        ScrollViewReader { proxy in
        BarlyScroll {
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(store.hosts) { host in
                    // 过滤、排序算一次，下面几处都用这一份
                    let hostProjects = store.projects(on: host.id)
                    let duplicateNames = Set(Dictionary(grouping: hostProjects, by: \.name).filter { $0.value.count > 1 }.keys)
                    let collapsed = store.collapsedHostIDs.contains(host.id) && !store.isFiltering
                    HostHeading(host: host, collapsed: collapsed, count: hostProjects.count,
                                onConnect: { store.presentation = .connect(host: host.id) },
                                onSignIn: { store.presentation = .hostSheet(.signIn(host.id)) }) {
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
                                   focused: libraryFocused && store.libraryCursor == .project(project.id),
                                   activity: store.activity(of: project),
                                   count: store.sessionCount(of: project),
                                   showsParent: duplicateNames.contains(project.name) || ProjectRow.looksGenerated(project.name),
                                   menu: { AnyView(ProjectMenu(store: store, project: project)) },
                                   quickStart: { AnyView(NewSessionItems(store: store, project: project, includesTerminal: true)) }) {
                            store.libraryCursor = .project(project.id)
                            libraryFocused = true
                            store.toggleExpanded(project)
                        }
                        .id(LibraryRow.project(project.id))
                        .contextMenu { ProjectMenu(store: store, project: project) }
                        .live { $0.draggable("project:" + project.id.raw)
                            .dropDestination(for: String.self) { ids, _ in
                                guard project.isPinned, let id = ids.first, id.hasPrefix("project:"),
                                      let dragged = ProjectID(raw: String(id.dropFirst(8))) else { return false }
                                store.movePinnedProject(dragged, before: project.id)
                                return true
                            } }
                        if store.isExpanded(project) {
                            let visible = store.visibleSessions(in: project)
                            ForEach(visible.shown) { session in
                                let children = store.showsSubagents ? store.subagents(of: session) : []
                                SessionRow(session: session,
                                           selected: store.isSelected(session) || store.selectedSessionIDs.contains(session.id),
                                           activity: store.activity(of: session),
                                           naming: store.data.naming.contains(session.id),
                                           snippet: store.messageHits[session.id], query: store.trimmedQuery,
                                           childCount: children.count, childrenExpanded: store.expandedSubagentParents.contains(session.id),
                                           onToggleChildren: { store.toggleSubagents(session) }) {
                                    store.click(session, command: Self.modifier(.command), shift: Self.modifier(.shift))
                                    libraryFocused = true
                                } onOpen: {
                                    store.resume(session)
                                } menu: {
                                    AnyView(sessionMenu(session))
                                }
                                .contextMenu { sessionMenu(session) }
                                .id(LibraryRow.session(session.id))
                                .live { $0.draggable(session.id)
                                    .dropDestination(for: String.self) { ids, _ in
                                        guard session.isPinned, let id = ids.first, store.session(id) != nil else { return false }
                                        store.movePinnedSession(id, before: session.id)
                                        return true
                                    } }
                                if store.expandedSubagentParents.contains(session.id) {
                                    ForEach(children) { child in
                                        SessionRow(session: child, selected: store.isSelected(child), activity: store.activity(of: child),
                                                   naming: store.data.naming.contains(child.id), indent: 18) {
                                            store.select(child)
                                            store.libraryCursor = .session(child.id)
                                            libraryFocused = true
                                        }
                                        .id(LibraryRow.session(child.id))
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
        .onChange(of: store.libraryCursor) { _, row in
            if let row, libraryFocused { proxy.scrollTo(row) }
        }
        }
        // 键盘：↑ ↓ 走、→ 展开 / 进去、← 收起 / 回上一层、Return 打开（WorkspaceStore.libraryKey）
        .modifier(LibraryKeyboard(focused: $libraryFocused) { store.libraryKey($0) })
    }

    // MARK: 底部

    /// 底栏：添加主机 · 设置 ｜ 右边是全部会话的状态计数（等你 · 工作中 · 没看过的完成），点一下打开「等待你的会话」
    private var footer: some View {
        HStack(spacing: 2) {
            HStack(spacing: 2) {
                PaneIcon(symbol: "folder.badge.plus", help: L("添加文件夹…")) { addProjectFolder() }
                PaneIcon(symbol: "server.rack", help: L("添加 SSH 主机…")) { addingHost = true }
            }
            .tourAnchor(.addHost)
            PaneIcon(symbol: "gearshape", help: L("设置（⌘,）")) {
                #if os(macOS)
                openSettings()
                #endif
            }
            Spacer()
            StatusCounts(activities: store.sessions.map(store.activity(of:))) { store.isBellOpen.toggle() }
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
    static func shortLabel(_ a: Activity) -> String {
        switch a {
        case .waitingForAnswer: L("等你")
        case .working: L("在跑")
        default: L("完成")
        }
    }

    /// 列表里各会话的状态（只算还在列表里的，和原来一样）
    let activities: [Activity]
    let action: () -> Void
    @Environment(\.barly) private var t
    @State private var hovered = false

    var body: some View {
        let counts: [(Activity, Int)] = [Activity.waitingForAnswer, .working, .doneUnseen].map { a in
            (a, activities.reduce(0) { $0 + ($1 == a ? 1 : 0) })
        }.filter { $0.1 > 0 }
        Button(action: action) {
            HStack(spacing: 8) {
                if counts.isEmpty {
                    Image(systemName: "bell").font(.system(size: BarlyScale.pt(13))).foregroundStyle(t.text3)
                }
                ForEach(counts, id: \.0) { activity, n in
                    HStack(spacing: 3) {
                        ActivityLamp(activity, size: 6)
                        Text("\(n)").barlyText(.product.caption.monospaced.weight(500), color: t.text)
                        Text(Self.shortLabel(activity)).barlyText(.product.caption, color: t.text3)
                    }
                    .fixedSize()
                }
            }
            .padding(.horizontal, 6)
            .frame(height: BarlyScale.pt(28))
            .background(hovered ? t.shellHover : .clear, in: RoundedRectangle(cornerRadius: WorkspaceMetrics.rowRadius, style: .continuous))
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
        let running = picked.filter { store.activity(of: $0).isRunning }
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
                store.presentation = .confirmDelete(picked)
                store.clearMultiSelection()
            }
            PaneIcon(symbol: "xmark", help: L("取消选择（Esc）")) { store.clearMultiSelection() }
        }
        .padding(.horizontal, 10)
        .frame(height: BarlyScale.pt(44))
        .sidebarCard()
    }
}

/// 外壳尺寸（Mac 主窗口比 Web 紧一档，mac-native.md §3）
public enum WorkspaceMetrics {
    /// 侧栏栏头 / 标签栏高度（和红绿灯同一行）
    // 跟着界面缩放（BarlyScale）
    public static var header: CGFloat { BarlyScale.pt(48) }
    public static var row: CGFloat { BarlyScale.pt(28) }
    public static var tabHeight: CGFloat { BarlyScale.pt(26) }
    /// 标签栏：描边托盘（嵌在上框线里的项目名 + 一行标签），上面留出项目名不贴面板顶边
    public static var tabBar: CGFloat { BarlyScale.pt(50) }
    public static var tabMin: CGFloat { BarlyScale.pt(96) }
    public static var tabMax: CGFloat { BarlyScale.pt(180) }
    /// 终端面板离窗口边、面板之间的距离
    public static var gutter: CGFloat { BarlyScale.pt(8) }
    /// 面板头：标题 · 路径 · CLI
    public static var panelHeader: CGFloat { BarlyScale.pt(34) }
    /// 圆角走身份阶梯（tight）：面板 10、行和标签 6、分段控件的槽 8
    public static let panelRadius: CGFloat = BarlyRadius.lg
    public static let rowRadius: CGFloat = BarlyRadius.sm
    public static let trackRadius: CGFloat = BarlyRadius.md
    /// 托盘里的标签：托盘圆角 8 减去 4pt 内边距，内外圆角同心
    public static let tabRadius: CGFloat = 5
    /// 项目行的文件夹图标宽；会话行的树形引导线对准它的中线。图标跟着界面缩放，引导线也要跟着算
    public static var folderIcon: CGFloat { BarlyScale.pt(16) }
    /// 引导线离行左边的距离：行内边距 8 + 箭头 10 + 间距 6 + 图标一半
    public static var guideX: CGFloat { 24 + folderIcon / 2 }
    /// 会话行内容的起点（引导线右边留一点）
    public static var sessionInset: CGFloat { guideX + 10 }
}

/// 会话库的键盘焦点和方向键。离屏截图画不了焦点视图（整块画成占位），截图时不加
private struct LibraryKeyboard: ViewModifier {
    var focused: FocusState<Bool>.Binding
    let onKey: (LibraryKey) -> Bool
    @Environment(\.barlySnapshot) private var snapshot

    func body(content: Content) -> some View {
        if snapshot {
            content
        } else {
            content
                .focusable()
                .focused(focused)
                .focusEffectDisabled()
                .onKeyPress(keys: [.upArrow, .downArrow, .leftArrow, .rightArrow, .return]) { press in
                    let key: LibraryKey = switch press.key {
                    case .upArrow: .up
                    case .downArrow: .down
                    case .leftArrow: .left
                    case .rightArrow: .right
                    default: .open
                    }
                    return onKey(key) ? .handled : .ignored
                }
        }
    }
}

/// 浮在窗口底上的圆角面板（侧栏、主区）：面板底 + 一圈细边。
/// 离屏截图（barly-snap）里圆角裁剪套着原生滚动视图会画成占位块，截图时只画圆角底不裁剪
private struct ShellPanel: ViewModifier {
    @Environment(\.barly) private var t
    @Environment(\.barlySnapshot) private var snapshot

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: WorkspaceMetrics.panelRadius, style: .continuous)
        Group {
            if snapshot {
                content.background(t.panelBg, in: shape)
            } else {
                content.background(t.panelBg).clipShape(shape)
            }
        }
        .overlay(shape.strokeBorder(t.panelEdge))
    }
}

/// 侧栏底部的提示 / 进度 / 多选条：面板里内缩的一块圆角浅底，不画横贯的分隔线
private struct SidebarCard: ViewModifier {
    @Environment(\.barly) private var t

    func body(content: Content) -> some View {
        content
            .background(t.shellHover, in: RoundedRectangle(cornerRadius: WorkspaceMetrics.trackRadius, style: .continuous))
            .padding(.horizontal, 8).padding(.top, 4)
    }
}

extension View {
    func shellPanel() -> some View { modifier(ShellPanel()) }
    func sidebarCard() -> some View { modifier(SidebarCard()) }
}

/// 外壳两层：窗口底更暗，侧栏和主区是浮在上面的两块面板（面板 = canvas = 终端底色），中间露一道缝
extension BarlyPalette {
    var shellBase: Color { isDark ? canvas.barlyMix(.black, 0.32) : canvas.barlyMix(.black, 0.06) }
    var panelBg: Color { canvas }
    /// 面板一圈细边：深色是一点白光，浅色是普通边线
    var panelEdge: Color { isDark ? Color.white.opacity(0.06) : border }
    /// 面板上的选中块 / 悬停块
    var shellSelected: Color { isDark ? canvas.barlyMix(.white, 0.07) : canvas.barlyMix(.black, 0.05) }
    var shellHover: Color { isDark ? canvas.barlyMix(.white, 0.04) : canvas.barlyMix(.black, 0.03) }
    /// 标签栏选中的标签：浮起的小卡片。深色比面板亮一点，浅色就是白底，靠细边和阴影浮起来
    var tabCard: Color { isDark ? canvas.barlyMix(.white, 0.07) : canvas }
    var tabCardEdge: Color { isDark ? Color.white.opacity(0.07) : Color.black.opacity(0.08) }
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
    @State private var hovered = false

    var body: some View {
        HStack(spacing: 6) {
            // 点标题折叠 / 展开这台主机；箭头只在悬停或已折叠时出现（像访达侧栏的分组）
            Button(action: onToggle) {
                HStack(spacing: 6) {
                    Image(systemName: host.isLocal ? "laptopcomputer" : "server.rack")
                        .font(.system(size: BarlyScale.pt(10)))
                        .foregroundStyle(t.text4)
                    Text(host.isLocal ? L("本机") : host.displayName).barlyText(.product.caption, color: t.text3)
                    if collapsed {
                        Text(verbatim: L("\(count) 个项目")).barlyText(.product.caption, color: t.text4)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: BarlyScale.pt(8), weight: .bold))
                        .foregroundStyle(t.text4)
                        .rotationEffect(.degrees(collapsed ? 0 : 90))
                        .opacity(hovered || collapsed ? 1 : 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovered = $0 }
            .help(collapsed ? L("展开") : L("折叠"))
            .accessibilityValue(collapsed ? L("已折叠") : L("已展开"))
            Spacer()
            switch host.connection {
            case .needsConnect:
                Text("连接…").barlyText(.product.caption.weight(500), color: t.text)
                    .padding(.horizontal, 7).frame(height: BarlyScale.pt(20))
                    .overlay(RoundedRectangle(cornerRadius: BarlyRadius.xs).stroke(t.borderStrong))
                    .contentShape(Rectangle())
                    .tapButton(perform: onConnect)
                    .handCursor()
            case .refreshing(let done, let total):
                Text("\(done)/\(total)").barlyText(.product.caption.monospaced, color: t.text3)
            case .unreachable(let error):
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: BarlyScale.pt(10))).foregroundStyle(t.warning)
                    .help("连不上：\(error)")
            case .disconnected:
                Text("已断开").barlyText(.product.caption, color: t.text4)
            case .needsSignIn:
                Text("登录…").barlyText(.product.caption.weight(500), color: t.accentText)
                    .padding(.horizontal, 7).frame(height: BarlyScale.pt(20))
                    .overlay(RoundedRectangle(cornerRadius: BarlyRadius.xs).stroke(t.borderStrong))
                    .contentShape(Rectangle())
                    .tapButton(perform: onSignIn)
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
    /// 键盘光标停在这一行（会话行停住就是选中，项目行要自己画出来）
    var focused = false
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
                    .font(.system(size: BarlyScale.pt(8), weight: .bold))
                    .foregroundStyle(t.text4)
                    .rotationEffect(.degrees(expanded ? 90 : 0))
                    .frame(width: 10)
                Image(systemName: project.folderExists ? "folder" : "questionmark.folder")
                    .font(.system(size: BarlyScale.pt(12)))
                    .foregroundStyle(project.folderExists ? t.text3 : t.warning)
                    .frame(width: WorkspaceMetrics.folderIcon)
                    .help(project.folderExists ? project.path : L("文件夹已经不在了"))
                VStack(alignment: .leading, spacing: 0) {
                    Text(project.name)
                        .barlyText(.product.small.weight(500), color: t.text)
                        .lineLimit(1).truncationMode(.middle)
                    if showsParent, !parent.isEmpty {
                        Text(parent).barlyText(.product.caption.size(11), color: t.text4).lineLimit(1).truncationMode(.head)
                    }
                }
                .layoutPriority(1)
                if project.isPinned {
                    Image(systemName: "pin.fill").font(.system(size: BarlyScale.pt(7))).foregroundStyle(t.text4)
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
            .background(focused ? t.shellSelected : hovered ? t.shellHover : .clear,
                        in: RoundedRectangle(cornerRadius: WorkspaceMetrics.rowRadius, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(expanded ? L("已展开") : L("已折叠"))
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
    var activity: Activity = .notRunning
    /// 正在 AI 起名：右边转圈
    var naming = false
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
                        .font(.system(size: BarlyScale.pt(7), weight: .bold))
                        .foregroundStyle(t.text4)
                        .rotationEffect(.degrees(childrenExpanded ? 90 : 0))
                        .frame(width: 10, height: 16)
                        .contentShape(Rectangle())
                        .tapButton(L("展开或收起子代理"), perform: onToggleChildren)
                        .help("\(childCount) 个子代理会话")
                        .padding(.leading, -18)
                }
                CLIMark(session.cli, size: 14)
                SessionName.text(session.displayTitle, separator: t.text4)
                    .barlyText(.product.small.weight(selected ? 500 : 400), color: selected ? t.text : t.text2)
                    .lineLimit(1)
                if session.isPinned {
                    Image(systemName: "pin.fill").font(.system(size: BarlyScale.pt(7))).foregroundStyle(t.text4)
                }
                if session.isArchived {
                    Image(systemName: "archivebox").font(.system(size: BarlyScale.pt(9))).foregroundStyle(t.text4)
                }
                Spacer(minLength: 6)
                Group {
                    if naming {
                        ProgressView().controlSize(.mini).help("正在起名…")
                    } else if activity == .notRunning {
                        RelativeAge(session.lastActivity)
                    } else {
                        ActivityLamp(activity)
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
                .font(.system(size: BarlyScale.pt(11), weight: .semibold))
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
            RoundedRectangle(cornerRadius: WorkspaceMetrics.rowRadius, style: .continuous)
                .fill(selected ? t.shellSelected : hovered ? t.shellHover : .clear)
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
        .background(t.shellBase.opacity(t.isDark ? 0.7 : 1), in: RoundedRectangle(cornerRadius: WorkspaceMetrics.trackRadius, style: .continuous))
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
            .background(on ? (t.isDark ? t.canvas.barlyMix(.white, 0.1) : t.canvas) : .clear,
                        in: RoundedRectangle(cornerRadius: WorkspaceMetrics.rowRadius, style: .continuous))
            .shadow(color: .black.opacity(on && !t.isDark ? 0.08 : 0), radius: 1.5, y: 1)
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
            Image(systemName: "magnifyingglass").font(.system(size: BarlyScale.pt(11))).foregroundStyle(t.text3)
            BarlyBareField(placeholder: L("项目、会话、消息"), text: $text, style: .product.small)
            if !text.isEmpty {
                Image(systemName: "xmark.circle.fill").font(.system(size: BarlyScale.pt(11))).foregroundStyle(t.text4)
                    .tapButton(L("清除搜索")) { text = "" }
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
            Image(systemName: symbol).font(.system(size: BarlyScale.pt(16))).foregroundStyle(t.text3)
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
