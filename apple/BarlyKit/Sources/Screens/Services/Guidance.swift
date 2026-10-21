import Foundation

/// 首启引导和侧栏小贴士：第一次打开走三步引导；之后每次打开（设置里没关的话）随机一条贴士
public enum Tips {
    static var all: [String] {
        [
            L("单击会话先读对话，不启动 CLI；双击在原来的目录里接着跑。"),
            L("⌘1–9 切到第几个标签，⌃Tab 在标签之间轮换。"),
            L("关标签时可以让 CLI 留在 tmux 里接着跑，下次点这个会话直接接上。"),
            L("侧栏顶上的铃铛列出所有在等你回答的会话。"),
            L("把文件拖进终端会粘贴它的路径。"),
            L("右键主机标题可以转发端口、检查这台主机。"),
            L("⌘F 在终端或对话预览里查找。"),
            L("⌥⌘N 分屏，同时看两个会话。"),
        ]
    }
}

@MainActor
public extension WorkspaceStore {
    static let tourDoneKey = "tourDone"
    static let tourSteps = 3

    /// 窗口打开时调一次
    func startGuidance(defaults: UserDefaults = .standard) {
        if !defaults.bool(forKey: Self.tourDoneKey) {
            tourStep = 1
        } else if defaults.object(forKey: "showTips") as? Bool ?? true {
            tip = Tips.all.randomElement()
        }
    }

    func nextTourStep(defaults: UserDefaults = .standard) {
        guard let step = tourStep else { return }
        if step >= Self.tourSteps { finishTour(defaults: defaults) } else { tourStep = step + 1 }
    }

    func finishTour(defaults: UserDefaults = .standard) {
        tourStep = nil
        defaults.set(true, forKey: Self.tourDoneKey)
    }

    func replayTour() {
        tip = nil
        tourStep = 1
    }

    /// 换一条（不会和当前这条重复）
    func nextTip() {
        let all = Tips.all
        guard let current = tip, let i = all.firstIndex(of: current) else { tip = all.first; return }
        tip = all[(i + 1) % all.count]
    }
}

public extension Notification.Name {
    /// 设置「帮助 · 重新看一遍」
    static let switchboardReplayTour = Notification.Name("switchboard.replayTour")
}
