import Foundation

/// 会话库只显示手动添加的文件夹（一个文件夹 = 一个工作目录，子文件夹不算）。
/// 这里是不碰 store 的规则：过滤、候选索引、升级时默认勾哪些、后台发现的「库外在跑」
public enum FolderLibrary {
    /// 一个发现过会话的文件夹（添加列表、升级挑选、空状态推荐用）
    public struct Candidate: Identifiable, Hashable, Sendable {
        public var id: ProjectID { ProjectID(host: hostID, path: path) }
        public let hostID: String
        public let path: String
        public let sessionCount: Int
        public let lastActivity: Date
        public let folderExists: Bool
        public var name: String { (path as NSString).lastPathComponent.isEmpty ? path : (path as NSString).lastPathComponent }
    }

    /// 库外有会话在跑的文件夹
    public struct Outside: Identifiable, Hashable, Sendable {
        public var id: ProjectID { ProjectID(host: Host.localID, path: path) }
        public let path: String
        public let count: Int
        public var name: String { (path as NSString).lastPathComponent.isEmpty ? path : (path as NSString).lastPathComponent }
    }

    /// Claude Code 存会话的目录名：路径里每个不是字母数字的 UTF-16 单元换成「-」
    public static func claudeDirectoryName(for path: String) -> String {
        String(String.UnicodeScalarView(path.utf16.map { unit -> Unicode.Scalar in
            let ascii = (0x30...0x39).contains(unit) || (0x41...0x5A).contains(unit) || (0x61...0x7A).contains(unit)
            return ascii ? Unicode.Scalar(UInt8(unit)) : "-"
        }))
    }

    /// 只留添加过的文件夹里的会话（项目 ID 精确匹配）
    public static func sessions(_ all: [Session], in folders: Set<ProjectID>) -> [Session] {
        all.filter { folders.contains($0.projectID) }
    }

    /// 按文件夹汇总：会话数（不算子代理）、最近活动；最近的在前
    public static func index(_ sessions: [Session], exists: (String) -> Bool) -> [Candidate] {
        let top = sessions.filter { $0.parentSessionID == nil }
        return Dictionary(grouping: top, by: \.projectID).compactMap { _, group in
            guard let first = group.first else { return nil }
            let local = first.hostID == Host.localID
            return Candidate(hostID: first.hostID, path: first.projectPath, sessionCount: group.count,
                             lastActivity: group.map(\.lastActivity).max() ?? .distantPast,
                             folderExists: !local || exists(first.projectPath))
        }
        .sorted { $0.lastActivity != $1.lastActivity ? $0.lastActivity > $1.lastActivity : $0.path < $1.path }
    }

    /// 根目录、家目录、各种临时目录、隐藏目录里的（工具自己的工作区，如 ~/.tds/workspaces/<uuid>）：
    /// 会话常有，但很少是「项目」
    public static func isScratch(_ path: String) -> Bool {
        let p = (path as NSString).standardizingPath
        if p == "/" || p == (NSHomeDirectory() as NSString).standardizingPath { return true }
        if p.split(separator: "/").contains(where: { $0.hasPrefix(".") }) { return true }
        return ["/tmp", "/private/tmp", "/var/folders", "/private/var/folders"].contains { p == $0 || p.hasPrefix($0 + "/") }
    }

    /// 升级时默认勾上：置顶的、有标签开着的、最近 14 天有活动且不是临时目录且文件夹还在的
    public static func defaultPicks(_ index: [Candidate], pinned: Set<ProjectID>, openTabs: Set<ProjectID>, now: Date = .now) -> [ProjectID] {
        let recent = now.addingTimeInterval(-14 * 86_400)
        return index.filter { c in
            if pinned.contains(c.id) || openTabs.contains(c.id) { return true }
            return c.folderExists && !isScratch(c.path) && c.lastActivity >= recent
        }
        .map(\.id)      // 顺序跟 index：最近活动在前
    }

    /// 后台在跑、但文件夹没添加也没被忽略的会话（会话 ID, cwd）→ 每个文件夹几个；多的在前
    public static func runningOutside(_ running: [(String, String)], folders: Set<ProjectID>, dismissed: Set<ProjectID>) -> [Outside] {
        let outside = running.filter { _, cwd in
            let id = ProjectID(host: Host.localID, path: cwd)
            return !folders.contains(id) && !dismissed.contains(id)
        }
        return Dictionary(grouping: outside, by: \.1).map { Outside(path: $0.key, count: $0.value.count) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.path < $1.path }
    }
}
