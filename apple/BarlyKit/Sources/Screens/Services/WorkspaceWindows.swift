import Foundation
#if os(macOS)
import AppKit
#endif

/// 开着的工作区窗口（真实运行时）。会话库数据所有窗口共用一份（WorkspaceData.shared），标签各窗口自己管。
/// 第一个还开着的窗口是「主窗口」：负责每分钟刷新、读主机状态、定期重新登录，以及没开标签的会话的状态和通知，
/// 免得每个窗口各轮询一遍、同一条通知发好几次
@MainActor
public enum WorkspaceWindows {
    private final class Ref { weak var store: WorkspaceStore?; init(_ s: WorkspaceStore) { store = s } }
    private static var refs: [Ref] = []

    /// 按打开先后
    public static var live: [WorkspaceStore] {
        refs.removeAll { $0.store == nil }
        return refs.compactMap(\.store)
    }

    public static var primary: WorkspaceStore? { live.first }

    /// 拖出 / 「移到新窗口」的标签，等新窗口建好来领
    static var pendingTransfer: TabTransfer?

    /// 退出 app 时窗口也会一个个关：这时不能按「关窗口」处理（会把别的窗口的标签记录改掉）
    nonisolated(unsafe) static var isTerminating = false

    static func register(_ store: WorkspaceStore) {
        refs.append(Ref(store))
        #if os(macOS)
        if observer == nil {
            observer = NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { _ in
                isTerminating = true
                // 端口转发的 ssh 不会跟着 app 退：留着会一直占着本机端口，下次开同一个转发报「端口被占」
                MainActor.assumeIsolated { PortForwardManager.shared.stopAll() }
            }
        }
        #endif
    }
    nonisolated(unsafe) private static var observer: NSObjectProtocol?

    static func unregister(_ store: WorkspaceStore) { refs.removeAll { $0.store == nil || $0.store === store } }

    /// 这个标签在哪个窗口
    public static func owner(ofTab id: UUID) -> WorkspaceStore? { live.first { $0.tab(id) != nil } }

    #if os(macOS)
    /// 是不是工作区窗口（窗口上挂着的 sheet 算它的窗口）。⌘W 只在工作区窗口在前面时关标签，设置窗口等在前面时关它自己
    public static func isWorkspace(_ window: NSWindow) -> Bool {
        let window = window.sheetParent ?? window
        return live.contains { $0.hostWindow === window }
    }
    #endif

    /// 这个会话的标签开在哪个窗口
    public static func tabOwner(of session: Session) -> (store: WorkspaceStore, tab: TerminalTab)? {
        for store in live { if let tab = store.tab(for: session) { return (store, tab) } }
        return nil
    }
}

@MainActor
public extension WorkspaceStore {
    /// 截图 / 单测里的 store 只有自己，算主窗口
    var isPrimary: Bool { !isLive || WorkspaceWindows.primary === self }

    /// 这个窗口负责算哪个会话的状态：标签在哪个窗口就归哪个窗口；哪儿都没开标签的归主窗口
    func ownsActivity(of session: Session) -> Bool {
        guard isLive else { return true }
        if tab(for: session) != nil { return true }
        return isPrimary && WorkspaceWindows.tabOwner(of: session) == nil
    }

    /// 关窗口：从登记里拿掉（标签里的 CLI 留在 tmux 里接着跑），剩下的窗口重写一遍标签记录
    func windowClosed() {
        guard isLive, !WorkspaceWindows.isTerminating else { return }
        WorkspaceWindows.unregister(self)
        // 断开这个窗口里的终端；tmux 里的 CLI 接着跑，下次点会话就接上
        for tab in allTabs { TerminalRuntime.close(tab.id, endingTmux: nil) }
        WorkspaceWindows.primary?.saveTabs()
    }
}

#if os(macOS)
import AppKit

@MainActor
public extension WorkspaceStore {
    func bringWindowToFront() {
        guard let window = hostWindow as? NSWindow else { return }   // 截图、单测里没有窗口
        NSApp?.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
#else
@MainActor
public extension WorkspaceStore {
    func bringWindowToFront() {}
}
#endif
