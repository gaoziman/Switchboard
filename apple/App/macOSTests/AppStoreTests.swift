import Foundation
import Testing
@testable import Switchboard

/// 业务逻辑（校验、筛选、持久化）先写测试；视图不测，视图靠截图评审（new-apple.sh snap）。
@MainActor
struct AppStoreTests {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("barly-store-\(UUID().uuidString)/store.json")
    }

    @Test(arguments: ["", "   ", String(repeating: "长", count: 121)])
    func invalidTitleIsRejected(title: String) {
        let store = AppStore(fileURL: nil)
        #expect(store.add(title) == nil)
        #expect(store.items.isEmpty)
    }

    @Test func titleIsTrimmed() throws {
        let store = AppStore(fileURL: nil)
        let item = try #require(store.add("  周报  "))
        #expect(item.title == "周报")
    }

    @Test func itemsSurviveRelaunch() throws {
        let url = tempURL()
        let first = AppStore(fileURL: url)
        let item = try #require(first.add("报销审批"))
        first.toggle(item.id)
        let second = AppStore(fileURL: url)          // 模拟重启：从磁盘读回
        #expect(second.items.map(\.title) == ["报销审批"])
        #expect(second.items.first?.done == true)
        #expect(second.openCount == 0)
    }

    @Test func searchIsCaseInsensitiveAndNewestFirst() {
        let old = Item(title: "Weekly report", createdAt: Date(timeIntervalSince1970: 1))
        let new = Item(title: "weekly sync", createdAt: Date(timeIntervalSince1970: 2))
        let store = AppStore(fileURL: nil, items: [old, new, Item(title: "报销")])
        #expect(store.search("WEEKLY").map(\.title) == ["weekly sync", "Weekly report"])
    }

    @Test func removeDeletesFromDisk() throws {
        let url = tempURL()
        let store = AppStore(fileURL: url)
        let item = try #require(store.add("临时"))
        store.remove(item.id)
        #expect(AppStore(fileURL: url).items.isEmpty)
    }

    @Test func corruptFileKeepsAppUsable() throws {
        let url = tempURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: url)
        let store = AppStore(fileURL: url)
        #expect(store.items.isEmpty)
        #expect(store.lastError != nil)
    }
}
