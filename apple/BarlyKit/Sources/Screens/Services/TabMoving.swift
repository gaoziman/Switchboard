import Foundation

/// 一个标签连同它的运行状态，从一个窗口搬到另一个窗口。终端视图按标签 ID 存在 TerminalRegistry 里，
/// 搬过去还是同一个视图、同一个进程，不重启 CLI
public struct TabTransfer {
    public let tab: TerminalTab
    let launch: TerminalLaunch?
    let banner: TerminalBanner?
    let title: String?
    let claim: PendingClaim?
    let reconnects: Int?
}

@MainActor
public extension WorkspaceStore {
    /// 同一个项目组里调顺序：放到 target 前面（nil = 组的最后）。不同项目的标签不能混进别的组
    func moveTab(_ id: UUID, before target: UUID?) {
        guard id != target, let g = tabGroups.firstIndex(where: { $0.tabs.contains { $0.id == id } }) else { return }
        if let target, !tabGroups[g].tabs.contains(where: { $0.id == target }) { return }
        let tab = tabGroups[g].tabs.first { $0.id == id }!
        tabGroups[g].tabs.removeAll { $0.id == id }
        let at = target.flatMap { t in tabGroups[g].tabs.firstIndex { $0.id == t } } ?? tabGroups[g].tabs.count
        tabGroups[g].tabs.insert(tab, at: at)
        saveTabs()
    }

    /// 从这个窗口拿走一个标签（不断开终端）
    func detachTab(_ id: UUID) -> TabTransfer? {
        guard let tab = tab(id) else { return nil }
        let transfer = TabTransfer(tab: tab, launch: launches[id], banner: tabBanners[id], title: terminalTitles[id],
                                   claim: pendingClaims[id], reconnects: reconnectAttempts[id])
        let ordered = allTabs
        let index = ordered.firstIndex { $0.id == id }
        for g in tabGroups.indices { tabGroups[g].tabs.removeAll { $0.id == id } }
        tabGroups.removeAll { $0.tabs.isEmpty }
        launches[id] = nil
        tabBanners[id] = nil
        terminalTitles[id] = nil
        pendingClaims[id] = nil
        reconnectAttempts[id] = nil
        if split?.contains(id) == true { split = nil }
        if case .tab(id)? = selection {
            let rest = allTabs
            selection = index.flatMap { rest.isEmpty ? nil : .tab(rest[min($0, rest.count - 1)].id) }
        }
        return transfer
    }

    /// 接收别的窗口搬来的标签：进它项目的组（没有就新建组），选中它
    func attachTab(_ t: TabTransfer, before target: UUID? = nil) {
        let projectID = t.tab.projectID
        if let g = tabGroups.firstIndex(where: { $0.projectID == projectID }) {
            let at = target.flatMap { id in tabGroups[g].tabs.firstIndex { $0.id == id } } ?? tabGroups[g].tabs.count
            tabGroups[g].tabs.insert(t.tab, at: at)
            tabGroups[g].isCollapsed = false
        } else {
            let name = (t.tab.projectPath as NSString).lastPathComponent
            tabGroups.append(TabGroup(projectID: projectID, name: name.isEmpty ? "/" : name, tint: Self.tint(for: projectID.raw, avoiding: Set(tabGroups.map(\.tint))), tabs: [t.tab]))
        }
        launches[t.tab.id] = t.launch
        tabBanners[t.tab.id] = t.banner
        terminalTitles[t.tab.id] = t.title
        pendingClaims[t.tab.id] = t.claim
        reconnectAttempts[t.tab.id] = t.reconnects
        selection = .tab(t.tab.id)
        saveTabs()
    }

    /// 搬到另一个已经开着的窗口
    func moveTab(_ id: UUID, to other: WorkspaceStore, before target: UUID? = nil) {
        guard other !== self, let t = detachTab(id) else { return }
        other.attachTab(t, before: target)
        other.bringWindowToFront()
    }

    /// 搬到一个新窗口：先放进待领取，新窗口建 store 时领走（WorkspaceStore.live）
    func moveTabToNewWindow(_ id: UUID) -> Bool {
        guard let t = detachTab(id) else { return false }
        WorkspaceWindows.pendingTransfer = t
        return true
    }

    /// 别的开着的窗口（菜单「移到窗口」用）
    var otherWindows: [WorkspaceStore] { WorkspaceWindows.live.filter { $0 !== self } }

    /// 窗口在菜单里叫什么：选中标签的标题
    var windowTitle: String { selectedTab?.title ?? allTabs.first?.title ?? L("空窗口") }
}
