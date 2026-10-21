import SwiftUI
import BarlyKit
import BarlyExamples
import Screens

/// macOS 入口（--mac-form window）：Dock 图标 + 自绘外壳主窗口（隐藏标题栏、内容到顶），不用系统 NavigationSplitView。
/// 另有 ⌘, 设置窗口（Shared/SettingsView.swift）和菜单命令（Shared/AppCommands.swift）；数据走 Shared/AppStore.swift。
@main
struct BarlyMacApp: App {
    @State private var store = AppStore.live()
    @AppStorage(AppAppearance.defaultsKey) private var appearance = AppAppearance.defaultValue
    init() { BarlyFonts.register(); LiveShot.handle(); _ = AppUpdater.shared }
    var body: some Scene {
        WindowGroup(id: "workspace") {
            MacRoot()
                .environment(store)
                .switchboardTheme()
                .barlyRoot(forceScheme: barlyScheme(appearance))
                .environment(\.barlyTitlebarInset, 22)   // 给红绿灯留位
                .frame(minWidth: 1200, minHeight: 820)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1440, height: 1024)
        .commands { AppCommands(); HelpCommands() }
        // 主题、明暗变了，终端跟着换（UserDefaults 通知覆盖不到系统明暗切换）
        .onChange(of: appearance) { _, _ in TerminalRegistry.shared.restyleAll() }

        Settings {
            BarlySettingsView()
                .switchboardTheme()
                .barlyRoot(forceScheme: barlyScheme(appearance))
        }
        .windowResizability(.contentSize)
    }
}

struct MacRoot: View {
    // console 风格族默认打开指标看板
    @State private var screen = BarlyFamily.current == .console ? "board" : "dashboard"
    /// 每个窗口一个工作区：标签各自的，会话库所有窗口共用一份。
    /// 在 onAppear 里建：@State 的初始值表达式每次重建视图都会再算一遍，会多登记出没用的窗口
    @State private var workspace: WorkspaceStore?
    /// 界面缩放改了：窗口内容整个重建（尺寸是按缩放算出来的常量）；store 和终端进程都不受影响
    @AppStorage(BarlyScale.defaultsKey) private var interfaceScale = 1.0
    var body: some View {
        if let workspace {
            WorkspaceView(store: workspace)
                .id(interfaceScale)
                .task { CrashReportOffer.checkOnce() }
        } else {
            Color.clear.onAppear { workspace = WorkspaceStore.live() }
        }
    }
    private var examples: some View {
        Group {
            switch screen {
            case "home": AIChatScreen(thread: false, onNavigate: route)
            case "chat": AIChatScreen(thread: true, onNavigate: route)
            case "board": MetricsBoardScreen(onNavigate: route)
            // 应用页面模式（AppMock.nav 的 id）
            case "kanban": KanbanBoardScreen(onNavigate: route)
            case "calendar": CalendarScreen(onNavigate: route)
            case "inbox": MailScreen(onNavigate: route)
            case "journal": JournalScreen(onNavigate: route)
            case "habits": HabitsScreen(onNavigate: route)
            case "settings": SettingsScreen(onNavigate: route)
            case "projects": EmptyStatesScreen(onNavigate: route)
            default: DashboardScreen(onNavigate: route)
            }
        }
        .id(screen)
    }
    private func route(_ id: String) {
        switch id {
        case "chat", "home", "dashboard", "board", "kanban", "calendar", "inbox", "journal", "habits", "settings", "projects": screen = id
        default: break
        }
    }
}
