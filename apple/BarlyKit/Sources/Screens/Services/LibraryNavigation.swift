import Foundation

/// 侧栏的一行（键盘导航用）
public enum LibraryRow: Hashable, Sendable {
    case project(String)
    case session(String)
}

public enum LibraryKey: Sendable { case up, down, left, right, open }

/// 侧栏多选、键盘导航、后退 / 前进、置顶拖动排序、子代理
@MainActor
public extension WorkspaceStore {
    // MARK: 多选

    /// 侧栏现在从上到下显示的会话（⇧-click 选区间用；不算子代理）
    var visibleSessionOrder: [Session] {
        libraryRows(showingSubagents: false).compactMap { row in
            if case .session(let id) = row { session(id) } else { nil }
        }
    }

    /// 侧栏从上到下画出来的行，和 SessionSidebar.library 一一对应：主机折叠了（搜索时不算）就跳过；
    /// 展开的项目列出它显示的会话，展开了子代理的会话后面跟着子代理
    func libraryRows(showingSubagents: Bool? = nil) -> [LibraryRow] {
        let subagentsShown = showingSubagents ?? showsSubagents
        var rows: [LibraryRow] = []
        for host in hosts where !(collapsedHostIDs.contains(host.id) && !isFiltering) {
            for project in projects(on: host.id) {
                rows.append(.project(project.id))
                guard isExpanded(project) else { continue }
                for s in visibleSessions(in: project).shown {
                    rows.append(.session(s.id))
                    if subagentsShown, expandedSubagentParents.contains(s.id) { rows += subagents(of: s).map { .session($0.id) } }
                }
            }
        }
        return rows
    }

    // MARK: 键盘

    /// 侧栏有焦点时的方向键和 Return（像访达的列表）：↑ ↓ 一行行走，停在会话上就预览；
    /// → 展开项目 / 进到它的第一个会话 / 展开子代理；← 收起 / 回到上一层；Return 会话接着跑、项目展开收起。
    /// 返回 false = 没处理（列表是空的）
    @discardableResult
    func libraryKey(_ key: LibraryKey, showingSubagents: Bool? = nil) -> Bool {
        let subagentsShown = showingSubagents ?? showsSubagents
        let rows = libraryRows(showingSubagents: subagentsShown)
        guard !rows.isEmpty else { return false }
        let current = libraryCursor.flatMap(rows.firstIndex(of:))
            ?? previewedSession.flatMap { rows.firstIndex(of: .session($0.id)) }
        func move(_ i: Int) {
            libraryCursor = rows[i]
            if case .session(let id) = rows[i], let s = session(id) {
                selectedSessionIDs = []
                selectionAnchor = id
                select(s)
            }
        }
        guard let i = current else { move(0); return true }
        switch (key, rows[i]) {
        case (.down, _): move(min(i + 1, rows.count - 1))
        case (.up, _): move(max(i - 1, 0))
        case (.right, .project(let id)):
            guard let p = projects.first(where: { $0.id == id }) else { break }
            if !isExpanded(p) { toggleExpanded(p) } else if i + 1 < rows.count, case .session = rows[i + 1] { move(i + 1) }
        case (.right, .session(let id)):
            if subagentsShown, let s = session(id), !subagents(of: s).isEmpty, !expandedSubagentParents.contains(id) { toggleSubagents(s) }
        case (.left, .project(let id)):
            if let p = projects.first(where: { $0.id == id }), expandedProjectIDs.contains(p.id) { toggleExpanded(p) }
        case (.left, .session(let id)):
            guard let s = session(id) else { break }
            if expandedSubagentParents.contains(id) { expandedSubagentParents.remove(id); break }
            let up: LibraryRow = s.parentSessionID.map { .session($0) } ?? .project(s.projectID)
            if let j = rows.firstIndex(of: up) { move(j) }
        case (.open, .project(let id)):
            if let p = projects.first(where: { $0.id == id }) { toggleExpanded(p) }
        case (.open, .session(let id)):
            if let s = session(id) { resume(s) }
        }
        return true
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
        libraryCursor = .session(session.id)
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
