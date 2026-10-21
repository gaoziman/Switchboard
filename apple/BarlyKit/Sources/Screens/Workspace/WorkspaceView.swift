import SwiftUI
import BarlyKit
#if os(macOS)
import AppKit
#endif

/// 工作区窗口：会话库侧栏 | 标签栏 + 终端 / 预览。自绘外壳，栏与栏之间一根发丝线
public struct WorkspaceView: View {
    @Bindable var store: WorkspaceStore
    @State private var sidebarShown = true
    @State private var newSession: NewSessionDraft?
    @AppStorage("showSubagents") private var showSubagents = false
    var onNewSession: (() -> Void)?
    @Environment(\.barly) private var t

    public init(store: WorkspaceStore, onNewSession: (() -> Void)? = nil) {
        self.store = store
        self.onNewSession = onNewSession
    }

    /// ⌘N / +：默认用当前标签或预览的项目和 CLI
    private func beginNewSession() { beginNewSession(folder: nil) }

    private func beginNewSession(folder: String?) {
        if let onNewSession { onNewSession(); return }
        var draft = NewSessionDraft()
        if let tab = store.selectedTab {
            draft.folder = tab.projectPath
            draft.hostID = tab.hostID
            if case .session(_, let cli) = tab.kind { draft.target = .cli(cli) }
        } else if let s = store.previewedSession {
            draft.folder = s.projectPath
            draft.hostID = s.hostID
            draft.target = .cli(s.cli)
        }
        // 项目菜单传来的是「主机:路径」
        if let folder, let colon = folder.firstIndex(of: ":") {
            draft.hostID = String(folder[..<colon])
            draft.folder = String(folder[folder.index(after: colon)...])
        }
        if case .cli(let cli) = draft.target { draft.savedCommand = store.savedCommand(for: cli) }
        let home = NSHomeDirectory()
        if draft.hostID == Host.localID, draft.folder.hasPrefix(home) { draft.folder = "~" + draft.folder.dropFirst(home.count) }
        newSession = draft
    }

    private var recentFolders: [String] {
        var seen = Set<String>()
        return store.sessions.sorted { $0.lastActivity > $1.lastActivity }.map(\.projectPath)
            .filter { $0 != "/" && seen.insert($0).inserted }.prefix(4).map { $0 }
    }

    public var body: some View {
        HStack(spacing: 0) {
            if sidebarShown {
                SessionSidebar(store: store, onNewSession: beginNewSession)
            }
            VStack(spacing: 0) {
                if !store.tabGroups.isEmpty {
                    TabBar(store: store, sidebarHidden: !sidebarShown, onNewSession: beginNewSession)
                } else {
                    Color.clear.frame(height: WorkspaceMetrics.tabBar)
                }
                main
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.leading, sidebarShown ? 0 : WorkspaceMetrics.gutter)
                    .padding([.trailing, .bottom], WorkspaceMetrics.gutter)
            }
        }
        .background(t.shellBase)
        .overlay(alignment: .bottomLeading) {
            // 从侧栏底栏的状态计数弹上来
            if store.isBellOpen && sidebarShown {
                BellPopover(sessions: store.waitingSessions, projectName: { store.project(for: $0)?.name ?? "" }) { session in
                    store.isBellOpen = false
                    store.resume(session)
                }
                    .padding(.leading, 12)
                    .padding(.bottom, BarlyScale.pt(44) + 4)
            }
        }
        .overlay {
            if let step = store.tourStep {
                TourOverlay(step: step, onNext: { store.nextTourStep() }, onSkip: { store.finishTour() })
            }
        }
        .ignoresSafeArea()
        .modifier(LibraryDialogs(store: store))
        .sheet(item: $store.closingTab) { tab in
            CloseTabDialog(tabTitle: tab.title, hostName: tab.hostID == Host.localID ? L("这台 Mac ") : " \(tab.hostID) ",
                           onEnd: { remember in
                               if remember { WorkspaceStore.setCloseBehavior("end", for: tab.hostID) }
                               store.close(tab, keepRunning: false)
                           },
                           onCancel: { store.closingTab = nil },
                           onKeep: { remember in
                               if remember { WorkspaceStore.setCloseBehavior("keep", for: tab.hostID) }
                               store.close(tab, keepRunning: true)
                           })
        }
        .modifier(FolderMigration(store: store))
        .sheet(isPresented: Binding(get: { newSession != nil }, set: { if !$0 { newSession = nil } })) {
            NewSessionSheet(draft: Binding(get: { newSession ?? NewSessionDraft() }, set: { newSession = $0 }),
                            installed: store.installedCLIs, recentFolders: recentFolders,
                            savedCommandFor: { store.savedCommand(for: $0) },
                            hosts: store.hosts.filter { $0.isLocal || $0.connection == .connected },
                            recentFoldersFor: { host in
                                var seen = Set<String>()
                                return store.sessions.filter { $0.hostID == host }.sorted { $0.lastActivity > $1.lastActivity }
                                    .map(\.projectPath).filter { seen.insert($0).inserted }.prefix(4).map { $0 }
                            },
                            onCancel: { newSession = nil },
                            onStart: {
                                if let draft = newSession { store.start(draft) }
                                newSession = nil
                            })
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchboardNewSession)) { note in
            if isKeyWindow { beginNewSession(folder: note.object as? String) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchboardCloseTab)) { _ in
            if isKeyWindow, let tab = store.selectedTab { store.requestClose(tab) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchboardToggleSidebar)) { _ in
            if isKeyWindow { withAnimation(.smooth(duration: 0.2)) { sidebarShown.toggle() } }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchboardRefresh)) { _ in
            guard isKeyWindow else { return }
            Task {
                await store.refresh()
                await store.refreshHosts()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchboardBack)) { _ in if isKeyWindow { store.goBack() } }
        .onReceive(NotificationCenter.default.publisher(for: .switchboardForward)) { _ in if isKeyWindow { store.goForward() } }
        .onChange(of: showSubagents) { _, _ in Task { await store.refresh() } }
        .onReceive(NotificationCenter.default.publisher(for: .switchboardSplit)) { _ in
            if isKeyWindow { store.startSplit() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchboardUnsplit)) { _ in
            if isKeyWindow { store.split = nil }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchboardSelectTab)) { note in
            if let i = note.object as? Int, isKeyWindow { store.selectTab(at: i) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchboardCycleTab)) { note in
            if let d = note.object as? Int, isKeyWindow { store.cycleTab(d) }
        }
        #if os(macOS)
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)) { _ in store.retryReconnects() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in store.retryReconnects() }
        #endif
        .onAppear(perform: hookRuntime)
        .modifier(WindowLifecycle(store: store))
        .onReceive(NotificationCenter.default.publisher(for: .switchboardReplayTour)) { _ in if isKeyWindow { store.replayTour() } }
        .task(id: store.isLive) { await pollLoop() }
        .onChange(of: store.selection) { _, _ in
            if let tab = store.selectedTab {
                store.markSeen(tab)
                if let s = store.session(for: tab) { NotificationService.shared.clear(sessionID: s.id) }
            }
            store.isBellOpen = false
        }
    }

    /// 多窗口时菜单命令只给当前窗口（设置窗口在前面时，给后面那个主窗口）
    private var isKeyWindow: Bool {
        #if os(macOS)
        guard let window = store.hostWindow as? NSWindow else { return true }
        return window.isKeyWindow || window.isMainWindow
        #else
        return true
        #endif
    }

    /// 终端退出 / 关闭 / 标题、通知点击回到 store（mock 截图时什么都不做）
    private func hookRuntime() {
        guard store.isLive else { return }
        if store.isPrimary { store.startGuidance() }
        #if os(macOS)
        // 这些回调是全局的：按标签找到它所在的窗口，别的窗口打开时也不会被覆盖错
        TerminalRegistry.shared.onExit = { id, code in WorkspaceWindows.owner(ofTab: id)?.processExited(id, code: code) }
        TerminalRegistry.shared.onTitle = { id, title in WorkspaceWindows.owner(ofTab: id)?.terminalTitles[id] = title }
        TerminalRuntime.closer = { id, tmux in TerminalRegistry.shared.close(id, endingTmux: tmux) }
        NotificationService.shared.install()
        NotificationService.shared.onSignIn = { alias in
            guard let primary = WorkspaceWindows.primary else { return }
            primary.bringWindowToFront()
            primary.hostSheet = .signIn(alias)
        }
        NotificationService.shared.onOpen = { id in
            NSApp.activate(ignoringOtherApps: true)
            guard let target = WorkspaceWindows.primary, let s = target.session(id) else { return }
            target.resume(s)      // 标签开在别的窗口时 resume 会把那个窗口叫到前面
        }
        #endif
    }

    /// 每秒读一次各 CLI 的状态，有「跑完一轮 / 等你」就发通知
    private func pollLoop() async {
        guard store.isLive else { return }
        var tick = 0
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            guard store.loadState == .loaded else { continue }
            tick += 1
            // 有新会话标签等着认领时，每 5 秒读一次本机会话库（走缓存，很快）；平时每分钟一次
            // 多窗口时每分钟刷新、主机状态、重新登录只由主窗口做（数据是共用的）
            let primary = store.isPrimary
            if (!store.pendingClaims.isEmpty && tick % 5 == 0) || (primary && tick % 60 == 0) {
                Task { await store.refresh() }
            }
            // SSH 主机：每 5 秒问一次状态；有远程新会话等认领时刷新那台主机（刚开每 10 秒，等久了放慢）
            if primary, tick % 5 == 0 { Task { await store.pollRemoteStatus() } }
            // 会话库外（没添加的文件夹）有 Claude 在跑：每 5 秒看一次，侧栏底部提示
            if primary, tick % 5 == 2 { store.checkOutsideRunning() }
            // 定期重新登录：每 5 分钟查一次，刚到期的发通知
            if primary, tick % 300 == 3, !store.signInConfigs.isEmpty {
                Task { for alias in await store.checkSignIns() { NotificationService.shared.postSignInDue(alias) } }
            }
            for host in Set(store.pendingClaims.values.map(\.hostID)) where host != Host.localID {
                let newest = store.pendingClaims.values.filter { $0.hostID == host }.map(\.startedAt).max() ?? .now
                guard tick % WorkspaceStore.claimRefreshInterval(age: Date().timeIntervalSince(newest)) == 0 else { continue }
                Task { await store.refreshHost(host); store.claimNewSessions() }
            }
            #if os(macOS)
            // 这个窗口在屏幕上（没最小化）、app 在前台，才算「你看得到这个窗口里的标签」
            let window = store.hostWindow as? NSWindow
            let active = NSApp.isActive && (window.map { $0.isVisible && !$0.isMiniaturized } ?? true)
            #else
            let active = true
            #endif
            // 读文件、问 tmux 在后台做；app 在后台时每 3 秒读一次就够（通知晚两秒没关系，省电）
            if active || tick % 3 == 0 { await store.gatherActivity() }
            for change in store.pollActivity(appIsActive: active) {
                guard let s = store.session(change.sessionID) else { continue }
                NotificationService.shared.post(change, title: s.displayTitle, project: store.project(for: s)?.name ?? "", cli: s.cli)
            }
        }
    }

    @ViewBuilder private var main: some View {
        if let split = store.activeSplit {
            SplitPane(store: store, split: split) { tab in AnyView(terminal(for: tab)) }
        } else if let tab = store.selectedTab {
            TerminalPanel {
                VStack(spacing: 0) {
                    PanelHeader(tab: tab, group: store.group(for: tab))
                    if let banner = store.tabBanners[tab.id] {
                        TerminalBannerView(banner: banner, cli: store.session(for: tab)?.cli,
                                           onResume: {
                                               if case .reconnecting = banner { store.reconnectNow(tab.id) }
                                               else if let s = store.session(for: tab) { store.resume(s) }
                                           },
                                           onClose: { store.close(tab, keepRunning: false) })
                    }
                    terminal(for: tab)
                }
            }
        } else if let session = store.previewedSession {
            TerminalPanel {
                PreviewPane(session: session, project: store.project(for: session), host: store.host(session.hostID),
                            entries: store.transcripts[session.id] ?? [],
                            highlight: store.messageHits[session.id] != nil ? store.trimmedQuery : nil,
                            onResume: { store.resume(session) }, onBranch: { store.branch(session) },
                            menu: store.isLive ? { AnyView(SessionMenu(store: store, session: session)) } : nil,
                            hasEarlier: store.hasEarlierTranscript(session.id),
                            onLoadEarlier: { Task { await store.loadTranscript(session.id, earlier: true) } })
                    .id(session.id)
                    // 会话有新动静（刷新后 lastActivity 变了）也重读：文件没变会直接用缓存
                    .task(id: "\(session.id)@\(session.lastActivity.timeIntervalSince1970)") { await store.loadTranscript(session.id) }
            }
        } else {
            TerminalPanel {
                EmptyMain(loadState: store.loadState, hasSessions: store.hasAnySession, onNewSession: beginNewSession)
            }
        }
    }
}

extension WorkspaceView {
    @ViewBuilder func terminal(for tab: TerminalTab) -> some View {
        #if os(macOS)
        if let launch = store.launches[tab.id] {
            TerminalSurface(launch: launch).id(launch.tabID.uuidString + launch.arguments.joined())
        } else {
            TerminalPane(tab: tab, banner: store.tabBanners[tab.id])
        }
        #else
        TerminalPane(tab: tab, banner: store.tabBanners[tab.id])
        #endif
    }
}

public extension Notification.Name {
    static let switchboardNewSession = Notification.Name("switchboard.newSession")
    static let switchboardCloseTab = Notification.Name("switchboard.closeTab")
    static let switchboardToggleSidebar = Notification.Name("switchboard.toggleSidebar")
    static let switchboardRefresh = Notification.Name("switchboard.refresh")
    /// object: Int（从 0 数，-1 = 最后一个）
    static let switchboardSelectTab = Notification.Name("switchboard.selectTab")
    /// object: Int（+1 / -1）
    static let switchboardCycleTab = Notification.Name("switchboard.cycleTab")
    static let switchboardSplit = Notification.Name("switchboard.split")
    static let switchboardBack = Notification.Name("switchboard.back")
    static let switchboardForward = Notification.Name("switchboard.forward")
    /// object: NSFindPanelAction 的 rawValue（1 打开 / 2 下一个 / 3 上一个）
    static let switchboardFindInPreview = Notification.Name("switchboard.findInPreview")
    static let switchboardUnsplit = Notification.Name("switchboard.unsplit")
}

/// 主区没有选中任何东西：一句话 + 两个快捷键提示，首次使用时给「新会话」
private struct EmptyMain: View {
    let loadState: LoadState
    let hasSessions: Bool
    private var loading: Bool { loadState == .loading }
    private var failed: Bool { if case .failed = loadState { true } else { false } }
    let onNewSession: () -> Void
    @Environment(\.barly) private var t

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            MonoLabel(loading ? "SCANNING SESSIONS" : failed ? "LIBRARY UNAVAILABLE" : "NO TAB OPEN", color: t.text4)
            Text(loading ? "正在读取各 CLI 的会话…" : failed ? "会话库没读出来" : hasSessions ? "选一个会话" : "从一个新会话开始")
                .barlyText(.product.pageTitle, color: t.text)
            if !loading {
                VStack(alignment: .leading, spacing: 8) {
                    hint(["⌘", "N"], L("在项目文件夹里启动 Claude Code、Codex、OpenCode 或 omp"))
                    hint([L("单击")], L("不启动 CLI，先读对话"))
                    hint([L("双击")], L("在原目录里接着跑"))
                }
                if !hasSessions && !failed {
                    BarlyButton(L("新会话"), icon: "plus", variant: .primary, size: .md, action: onNewSession)
                        .padding(.top, 6)
                }
            }
        }
        .frame(maxWidth: 420, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(t.canvas)
    }

    private func hint(_ keys: [String], _ text: String) -> some View {
        HStack(spacing: 10) {
            KeyCombo(keys).frame(width: 44, alignment: .leading)
            Text(text).barlyText(.product.small, color: t.text3)
        }
    }
}

/// 记下所在的窗口；窗口关掉时从多窗口登记里拿掉。
/// 认窗口真的关了，不认 onDisappear：改界面缩放时内容整个重建（.id）也会触发 onDisappear
private struct WindowLifecycle: ViewModifier {
    let store: WorkspaceStore

    func body(content: Content) -> some View {
        #if os(macOS)
        content
            .background(WindowReader { if let window = $0 { store.hostWindow = window } })
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { note in
                if let window = note.object as? NSWindow, window === store.hostWindow { store.windowClosed() }
            }
        #else
        content
        #endif
    }
}

#if os(macOS)
/// 拿到 SwiftUI 视图所在的 NSWindow
struct WindowReader: NSViewRepresentable {
    let onWindow: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = ReaderView()
        view.onWindow = onWindow
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class ReaderView: NSView {
        var onWindow: ((NSWindow?) -> Void)?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onWindow?(window)
        }
    }
}
#endif
