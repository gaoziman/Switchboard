import Foundation

@MainActor
public extension WorkspaceStore {
    /// 搜索框变化时调：等 0.3 秒没再输入，再查消息全文（第一次会先建索引，顶部显示进度）
    func searchMessages() {
        searchTask?.cancel()
        let query = trimmedQuery
        guard isLive, query.count >= 2 else {
            messageHits = [:]
            indexProgress = nil
            return
        }
        let targets = sessions.filter { $0.parentSessionID == nil && (showsArchived || !$0.isArchived) }
        let all = sessions
        // @MainActor 的类本身是 Sendable，任务跑完就释放，不会循环引用
        let store = self
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await MessageIndex.shared.update(targets, retaining: all) { done, total in
                Task { @MainActor in
                    guard store.trimmedQuery == query else { return }
                    store.indexProgress = done < total ? (done, total) : nil
                }
            }
            guard !Task.isCancelled else { return }
            let hits = await MessageIndex.shared.search(query, in: targets)
            guard !Task.isCancelled, store.trimmedQuery == query else { return }
            store.messageHits = hits
            store.indexProgress = nil
        }
    }
}
