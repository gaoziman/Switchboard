import Foundation

/// 一次刷新：四种 CLI 并行读，合并成「项目 + 会话」。在后台线程跑，结果回主线程交给 WorkspaceStore
public enum SessionDiscovery {
    public struct Result: Sendable {
        public var sessions: [Session]
        public var projects: [Project]
        public var installed: [CLIKind]
        public var elapsed: TimeInterval
    }

    static let sources: [any SessionSource] = [ClaudeSource(), CodexSource(), OpenCodeSource(), OmpSource()]

    /// folders：本机只读这些工作目录（会话库添加过的文件夹）；nil = 全部（候选索引、升级挑选用）
    public static func run(folders: Set<String>? = nil) async -> Result {
        let start = Date()
        let sessions = await withTaskGroup(of: [Session].self) { group in
            for source in sources { group.addTask(priority: .userInitiated) { source.discover(in: folders) } }
            var all: [Session] = []
            for await batch in group { all += batch }
            return all
        }
        return Result(sessions: sessions, projects: projects(for: sessions), installed: installedCLIs(),
                      elapsed: Date().timeIntervalSince(start))
    }

    /// 每个出现过的「主机 + 目录」是一个项目；本机文件夹不在了的标出来（预览里提示、接着跑置灰）。
    /// SSH 主机上的目录不在这里检查，终端启动时主机会报
    static func projects(for sessions: [Session]) -> [Project] {
        let fm = FileManager.default
        var seen = Set<String>()
        return sessions.compactMap { s in
            guard seen.insert(s.projectID).inserted else { return nil }
            let local = s.hostID == Host.localID
            return Project(hostID: s.hostID, path: s.projectPath, folderExists: !local || fm.fileExists(atPath: s.projectPath))
        }
    }

    /// 一台 SSH 主机：读它在本机的镜像。folders 同 run（主机上的路径）
    public static func runRemote(_ alias: String, folders: Set<String>? = nil) async -> [Session] {
        let root = SSH.cacheDirectory(alias)
        let sources: [any SessionSource] = [ClaudeSource(mirror: root.appendingPathComponent("claude"), hostID: alias),
                                            CodexSource(mirror: root.appendingPathComponent("codex"), hostID: alias),
                                            OmpSource(mirror: root.appendingPathComponent("omp/sessions"), hostID: alias),
                                            OpenCodeSource(mirror: root.appendingPathComponent("opencode/opencode.db"), hostID: alias)]
        return await withTaskGroup(of: [Session].self) { group in
            for source in sources { group.addTask { source.discover(in: folders) } }
            var all: [Session] = []
            for await batch in group { all += batch }
            return all
        }
    }

    /// 本机装了哪些 CLI（新会话只给装了的）
    static func installedCLIs() -> [CLIKind] {
        CLIKind.allCases.filter { ShellEnvironment.shared.which($0.executable) != nil }
    }
}
