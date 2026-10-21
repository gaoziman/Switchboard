import Foundation
import Observation
import Screens

/// 一条数据。做真产品时换成自己的模型（保持 Codable + Identifiable，持久化和单测都不用改结构）。
struct Item: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var title: String
    var done = false
    var createdAt = Date()
}

/// 产品数据的唯一来源：@Observable + JSON 持久化（~/Library/Application Support/<bundle id>/store.json）。
/// 视图只读它、调它的方法，不自己持有业务数据；校验规则写在这里而不是视图里，方便单测（App/macOSTests）。
@MainActor
@Observable
final class AppStore {
    private(set) var items: [Item] = []
    private(set) var lastError: String?
    private let fileURL: URL?

    /// fileURL = nil：只在内存里（截图、预览、单测用）
    init(fileURL: URL?, items: [Item] = []) {
        self.fileURL = fileURL
        self.items = items
        if fileURL != nil { load() }
    }

    static func live() -> AppStore { AppStore(fileURL: defaultURL) }

    static var defaultURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent(Bundle.main.bundleIdentifier ?? "BarlyApp", isDirectory: true)
            .appendingPathComponent("store.json")
    }

    // MARK: 读

    var openCount: Int { items.filter { !$0.done }.count }

    /// 标题包含查询词（忽略大小写和全半角），新的在前；空查询返回全部
    func search(_ query: String) -> [Item] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let hits = q.isEmpty ? items : items.filter { $0.title.localizedStandardContains(q) }
        return hits.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: 写

    /// 返回 nil 表示没加（空标题 / 超过 120 字）
    @discardableResult
    func add(_ title: String) -> Item? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 120 else { return nil }
        let item = Item(title: trimmed)
        items.append(item)
        save()
        return item
    }

    func toggle(_ id: Item.ID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].done.toggle()
        save()
    }

    func remove(_ id: Item.ID) {
        items.removeAll { $0.id == id }
        save()
    }

    // MARK: 持久化

    func load() {
        guard let fileURL, FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            items = try JSONDecoder().decode([Item].self, from: Data(contentsOf: fileURL))
        } catch {
            lastError = L("数据文件读不出来，已保留原文件：\(error.localizedDescription)")
        }
    }

    func save() {
        guard let fileURL else { return }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            try enc.encode(items).write(to: fileURL, options: .atomic)
            lastError = nil
        } catch {
            lastError = L("保存失败：\(error.localizedDescription)")
        }
    }
}
