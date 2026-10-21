import Foundation

/// 会话库自己记的三样东西：置顶 / 改名 / 归档 / 启动命令（library.json）、SSH 主机（hosts.json）、上次开着的标签（tabs.json）。
/// 两种存法：磁盘（~/Library/Application Support/Switchboard/，真实运行）和内存（截图、单测）。
/// 内存的也走同一套编解码，测到的就是磁盘上的格式；读写不出错：读不到当空的，写失败不打断操作
@MainActor
public final class WorkspacePersistence {
    private enum Backing { case directory(URL), memory }
    private let backing: Backing
    private var blobs: [String: Data] = [:]

    private init(_ backing: Backing) { self.backing = backing }

    public static func disk(_ directory: URL) -> WorkspacePersistence { WorkspacePersistence(.directory(directory)) }
    public static func memory() -> WorkspacePersistence { WorkspacePersistence(.memory) }

    /// 真实运行用的那份
    public static let applicationSupport = disk(FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Switchboard", isDirectory: true))

    var isDisk: Bool { if case .directory = backing { true } else { false } }

    // MARK: library.json

    /// 没有 = 空状态；读不出来（半截、格式不对）先改名成 library.json.bak-<时间> 留着，再用空状态，
    /// 免得下一次保存把用户的置顶、重命名、归档整个盖掉
    func loadLibrary() -> LibraryState {
        guard let data = read("library.json") else { return LibraryState() }
        if let state = try? JSONDecoder().decode(LibraryState.self, from: data) { return state }
        setAside("library.json")
        return LibraryState()
    }

    func saveLibrary(_ state: LibraryState) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(state) { write("library.json", data) }
    }

    // MARK: hosts.json

    func loadHosts() -> [HostRecord] {
        read("hosts.json").flatMap { try? JSONDecoder().decode([HostRecord].self, from: $0) } ?? []
    }

    func saveHosts(_ records: [HostRecord]) {
        if let data = try? JSONEncoder().encode(records) { write("hosts.json", data) }
    }

    // MARK: tabs.json

    func loadTabs() -> [WorkspaceStore.TabRecord] {
        read("tabs.json").flatMap { try? JSONDecoder().decode([WorkspaceStore.TabRecord].self, from: $0) } ?? []
    }

    func saveTabs(_ records: [WorkspaceStore.TabRecord]) {
        if let data = try? JSONEncoder().encode(records) { write("tabs.json", data) }
    }

    // MARK: 存储

    private func read(_ name: String) -> Data? {
        switch backing {
        case .directory(let dir): try? Data(contentsOf: dir.appendingPathComponent(name))
        case .memory: blobs[name]
        }
    }

    private func write(_ name: String, _ data: Data) {
        switch backing {
        case .directory(let dir):
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try? data.write(to: dir.appendingPathComponent(name), options: .atomic)
        case .memory:
            blobs[name] = data
        }
    }

    private func setAside(_ name: String) {
        switch backing {
        case .directory(let dir):
            let stamp = Int(Date().timeIntervalSince1970)
            try? FileManager.default.moveItem(at: dir.appendingPathComponent(name), to: dir.appendingPathComponent("\(name).bak-\(stamp)"))
        case .memory:
            blobs[name] = nil
        }
    }
}

/// hosts.json 的一条（格式不能变：老版本的文件直接读）
struct HostRecord: Codable {
    let alias: String
    var installed: [String]?
    var disconnected: Bool?
    var signIn: SignInConfig?
}
