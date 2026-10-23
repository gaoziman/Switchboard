import SwiftUI
import BarlyKit
import Screens

/// macOS 入口（--mac-form window）：Dock 图标 + 自绘外壳主窗口（隐藏标题栏、内容到顶），不用系统 NavigationSplitView。
/// 另有 ⌘, 设置窗口（Shared/SettingsView.swift）和菜单命令（Shared/AppCommands.swift）；数据在 Screens 包的 WorkspaceStore。
@main
struct BarlyMacApp: App {
    @AppStorage(AppAppearance.defaultsKey) private var appearance = AppAppearance.defaultValue
    init() { BarlyFonts.register(); LiveShot.handle(); _ = AppUpdater.shared }
    var body: some Scene {
        WindowGroup(id: "workspace") {
            MacRoot()
                .switchboardTheme()
                .barlyRoot(forceScheme: barlyScheme(appearance))
                .background(WindowAppearance(value: appearance))
                .environment(\.barlyTitlebarInset, 22)   // 给红绿灯留位
                .frame(minWidth: 1200, minHeight: 820)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 1440, height: 1024)
        .commands { AppCommands(); HelpCommands() }
        // 主题、明暗变了，终端跟着换（系统明暗切换由 TerminalRegistry 另外监听）
        .onChange(of: appearance) { _, _ in TerminalRegistry.shared.restyleAll() }

        Settings {
            BarlySettingsView()
                .switchboardTheme()
                .barlyRoot(forceScheme: barlyScheme(appearance))
                .background(WindowAppearance(value: appearance))
        }
        .windowResizability(.contentSize)
    }
}

struct MacRoot: View {
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
}

/// 窗口的 NSAppearance 直接按「外观」设置设（nil = 跟随系统）。主窗口里 preferredColorScheme 传不到
/// （实测：设深色、系统浅色时侧栏仍是浅色），窗口里的系统控件（菜单、输入框、滚动条）要靠窗口外观才对得上
private struct WindowAppearance: NSViewRepresentable {
    let value: String

    final class Probe: NSView {
        var value = AppAppearance.defaultValue
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); apply() }
        func apply() {
            window?.appearance = AppAppearance.isDark(value).map { NSAppearance(named: $0 ? .darkAqua : .aqua)! }
        }
    }

    func makeNSView(context: Context) -> Probe { Probe() }

    func updateNSView(_ view: Probe, context: Context) {
        view.value = value
        view.apply()
    }
}
