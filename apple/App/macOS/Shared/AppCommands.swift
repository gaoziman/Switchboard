import SwiftUI
import AppKit
import Screens

/// 菜单栏命令。自绘外壳不是 NavigationSplitView，菜单项只发通知，工作区窗口用 `.onReceive` 接。
/// 每个主要动作都在菜单里、带快捷键（references/apple.md「Mac 形态」）
struct AppCommands: Commands {
    private func post(_ name: Notification.Name, _ object: Any? = nil) { NotificationCenter.default.post(name: name, object: object) }

    /// 查找：焦点在终端上就交给 SwiftTerm 自带的查找条，否则交给对话预览
    private func find(_ action: NSFindPanelAction) {
        let item = NSMenuItem()
        item.tag = Int(action.rawValue)
        if !NSApp.sendAction(NSSelectorFromString("performFindPanelAction:"), to: nil, from: item) {
            post(.switchboardFindInPreview, Int(action.rawValue))
        }
    }

    /// 终端字号 10–24，和设置里是同一个值
    private func zoom(_ delta: Int) {
        let current = UserDefaults.standard.object(forKey: "terminalFontSize") as? Int ?? TerminalStyle.defaultFontSize
        UserDefaults.standard.set(min(24, max(10, current + delta)), forKey: "terminalFontSize")
    }

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("检查更新…") { AppUpdater.shared.checkForUpdates() }
        }
        CommandGroup(replacing: .newItem) {
            Button("新会话…") { post(.switchboardNewSession) }.keyboardShortcut("n")
            Button("新标签…") { post(.switchboardNewSession) }.keyboardShortcut("t")
        }
        // 系统的「关闭窗口 ⌘W」换成关标签，关窗口挪到 ⇧⌘W
        CommandGroup(replacing: .saveItem) {
            Button("关闭标签") { post(.switchboardCloseTab) }.keyboardShortcut("w")
            Button("关闭窗口") { NSApp.keyWindow?.performClose(nil) }.keyboardShortcut("w", modifiers: [.shift, .command])
        }
        CommandGroup(after: .textEditing) {
            Button("查找…") { find(.showFindPanel) }.keyboardShortcut("f")
            Button("查找下一个") { find(.next) }.keyboardShortcut("g")
            Button("查找上一个") { find(.previous) }.keyboardShortcut("g", modifiers: [.shift, .command])
        }
        CommandGroup(before: .toolbar) {
            Button("显示 / 隐藏侧栏") { post(.switchboardToggleSidebar) }.keyboardShortcut("b")
            Divider()
            Button("放大终端字号") { zoom(+1) }.keyboardShortcut("+")
            Button("放大终端字号（=）") { zoom(+1) }.keyboardShortcut("=")
            Button("缩小终端字号") { zoom(-1) }.keyboardShortcut("-")
            Button("实际大小") { UserDefaults.standard.set(TerminalStyle.defaultFontSize, forKey: "terminalFontSize") }.keyboardShortcut("0")
            Divider()
            Button("刷新会话库") { post(.switchboardRefresh) }.keyboardShortcut("r")
            Divider()
        }
        CommandMenu("前往") {
            Button("后退") { post(.switchboardBack) }.keyboardShortcut("[")
            Button("前进") { post(.switchboardForward) }.keyboardShortcut("]")
        }
        CommandMenu("标签") {
            Button("分屏：选一个标签放右边") { post(.switchboardSplit) }.keyboardShortcut("n", modifiers: [.option, .command])
            Button("取消分屏") { post(.switchboardUnsplit) }
            Divider()
            Button("下一个标签") { post(.switchboardCycleTab, 1) }.keyboardShortcut("]", modifiers: [.shift, .command])
            Button("上一个标签") { post(.switchboardCycleTab, -1) }.keyboardShortcut("[", modifiers: [.shift, .command])
            Button("下一个标签（Ctrl+Tab）") { post(.switchboardCycleTab, 1) }.keyboardShortcut(.tab, modifiers: [.control])
            Button("上一个标签（Ctrl+Shift+Tab）") { post(.switchboardCycleTab, -1) }.keyboardShortcut(.tab, modifiers: [.control, .shift])
            Divider()
            ForEach(1..<9) { i in
                Button("第 \(i) 个标签") { post(.switchboardSelectTab, i - 1) }.keyboardShortcut(KeyEquivalent(Character("\(i)")))
            }
            Button("最后一个标签") { post(.switchboardSelectTab, -1) }.keyboardShortcut("9")
        }
    }
}
