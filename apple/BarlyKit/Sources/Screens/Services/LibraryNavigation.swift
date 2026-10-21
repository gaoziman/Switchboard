import Foundation

/// 侧栏多选、后退 / 前进、置顶拖动排序、子代理
@MainActor
public extension WorkspaceStore {
    // MARK: 多选

    /// 侧栏现在从上到下显示的会话（⇧-click 选区间用）
    var visibleSessionOrder: [Session] {
        hosts.flatMap { host in
            projects(on: host.id).filter { isExpanded($0) && !collapsedHostIDs.contains(host.id) }
                .flatMap { visibleSessions(in: $0).shown }
        }
    }

    /// 单击 / ⌘-click / ⇧-click
    func click(_ session: Session, command: Bool, shift: Bool) {
        if command {
            if selectedSessionIDs.isEmpty, case .preview(let id)? = selection, id != session.id { selectedSessionIDs.insert(id) }
            if selectedSessionIDs.contains(session.id) { selectedSessionIDs.remove(session.id) } else { selectedSessionIDs.insert(session.id) }
            selectionAnchor = session.id
        } else if shift, let anchor = selectionAnchor ?? previewedSession?.id {
            let order = visibleSessionOrder.map(\.id)
            if let a = order.firstIndex(of: anchor), let b = order.firstIndex(of: session.id) {
                selectedSessionIDs = Set(order[min(a, b)...max(a, b)])
            }
        } else {
            selectedSessionIDs = []
            selectionAnchor = session.id
            select(session)
        }
    }

    var multiSelection: [Session] { sessions.filter { selectedSessionIDs.contains($0.id) } }

    func clearMultiSelection() {
        selectedSessionIDs = []
        selectionAnchor = nil
    }

    // MARK: 后退 / 前进

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }

    /// 跳过已经关掉的标签、看不到的会话
    private func isReachable(_ s: MainSelection) -> Bool {
        switch s {
        case .tab(let id): tab(id) != nil
        case .preview(let id): session(id) != nil
        }
    }

    func goBack() {
        while let target = backStack.popLast() {
            guard isReachable(target) else { continue }
            if let current = selection { forwardStack.append(current) }
            navigatingHistory = true
            selection = target
            navigatingHistory = false
            return
        }
    }

    func goForward() {
        while let target = forwardStack.popLast() {
            guard isReachable(target) else { continue }
            if let current = selection { backStack.append(current) }
            navigatingHistory = true
            selection = target
            navigatingHistory = false
            return
        }
    }

    // MARK: 置顶拖动排序

    /// 把 dragged 放到 target 前面；dragged 没置顶就顺便置顶
    func movePinnedSession(_ dragged: String, before target: String) {
        guard dragged != target else { return }
        var order = library.pinnedSessions.filter { $0 != dragged }
        let i = order.firstIndex(of: target) ?? order.count
        order.insert(dragged, at: i)
        library.pinnedSessions = order
        if isLive { library.save() }
        applyLibraryState()
    }

    func movePinnedProject(_ dragged: String, before target: String) {
        guard dragged != target else { return }
        var order = library.pinnedProjects.filter { $0 != dragged }
        let i = order.firstIndex(of: target) ?? order.count
        order.insert(dragged, at: i)
        library.pinnedProjects = order
        if isLive { library.save() }
        applyLibraryState()
    }

    // MARK: 子代理

    var showsSubagents: Bool { UserDefaults.standard.bool(forKey: "showSubagents") }

    func subagents(of session: Session) -> [Session] {
        (data.sessionIndex.children[session.id] ?? []).sorted { $0.lastActivity > $1.lastActivity }
    }

    func toggleSubagents(_ session: Session) {
        if expandedSubagentParents.contains(session.id) { expandedSubagentParents.remove(session.id) } else { expandedSubagentParents.insert(session.id) }
    }
}
