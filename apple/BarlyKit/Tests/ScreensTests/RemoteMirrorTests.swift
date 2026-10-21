import Foundation
import Testing
@testable import Screens

@Suite struct OpenCodeSnapshotTests {
    @Test func acceptsOnlyItsOwnTmpFolders() {
        #expect(OpenCodeSnapshot.path(in: "noise\nSWITCHBOARD_OPENCODE_SNAPSHOT=/tmp/switchboard-opencode-ab12_x\n") == "/tmp/switchboard-opencode-ab12_x")
        #expect(OpenCodeSnapshot.path(in: "SWITCHBOARD_OPENCODE_SNAPSHOT=/tmp/switchboard-opencode-") == nil)
        #expect(OpenCodeSnapshot.path(in: "SWITCHBOARD_OPENCODE_SNAPSHOT=/home/me") == nil)
        #expect(OpenCodeSnapshot.path(in: "SWITCHBOARD_OPENCODE_SNAPSHOT=/tmp/switchboard-opencode-x; rm -rf ~") == nil)
        #expect(OpenCodeSnapshot.path(in: "SWITCHBOARD_OPENCODE_SNAPSHOT=/tmp/switchboard-opencode-../etc") == nil)
    }

    /// 本机当主机：用同一段脚本给真实的 OpenCode 库做快照，再从快照读会话和预览，和直接读库对得上
    @Test(.enabled(if: ProcessInfo.processInfo.environment["SB_REAL"] != nil))
    func snapshotOfRealDatabaseMatches() throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", OpenCodeSnapshot.shell]
        let out = Pipe(), err = Pipe()
        p.standardOutput = out
        p.standardError = err
        try p.run()
        p.waitUntilExit()
        if p.terminationStatus == OpenCodeSnapshot.noDatabase { return }     // 这台机器没装 OpenCode
        let text = String(decoding: out.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let dir = try #require(OpenCodeSnapshot.path(in: text), "\(String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self))")
        defer { try? FileManager.default.removeItem(atPath: dir) }

        let mirrored = OpenCodeSource(mirror: URL(fileURLWithPath: dir + "/opencode.db"), hostID: "devbox").discover()
        let local = OpenCodeSource().discover().filter { $0.parentSessionID == nil }
        #expect(Set(mirrored.map(\.id)) == Set(local.map(\.id)))
        #expect(mirrored.allSatisfy { $0.hostID == "devbox" })
        // 消息数一样，预览读得出来
        let byID = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        #expect(mirrored.allSatisfy { $0.messageCount == byID[$0.id]?.messageCount })
        if let newest = mirrored.max(by: { $0.lastActivity < $1.lastActivity }) {
            let entries = TranscriptLoader.load(newest, maxBytes: 4 << 20)
            #expect(!entries.isEmpty)
        }
        // 快照里没有账号、凭据之类的表
        let db = try #require(SQLiteReader(URL(fileURLWithPath: dir + "/opencode.db")))
        let tables = Set(db.rows("SELECT name FROM sqlite_master WHERE type='table'").compactMap { $0[0] })
        #expect(tables == ["session", "message", "part"])
        let size = (try? FileManager.default.attributesOfItem(atPath: dir + "/opencode.db")[.size] as? Int) ?? 0
        print("OpenCode 快照：\(mirrored.count) 个会话，\(size / 1024) KB")
    }
}

@Suite struct OmpMirrorTests {
    @Test func mirroredSessionsBelongToHost() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("sb-omp-\(UUID().uuidString)")
        let dir = root.appendingPathComponent("--home-me-code-x--")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let lines = [
            #"{"type":"session","id":"omp-1","cwd":"/home/me/code/x"}"#,
            #"{"type":"message","message":{"role":"user","content":[{"type":"text","text":"修一下登录"}]}}"#,
        ]
        try lines.joined(separator: "\n").write(to: dir.appendingPathComponent("2026-10-20_omp-1.jsonl"), atomically: true, encoding: .utf8)
        let sessions = OmpSource(mirror: root, hostID: "devbox").discover()
        #expect(sessions.map(\.id) == ["omp-1"])
        #expect(sessions.first?.hostID == "devbox" && sessions.first?.projectPath == "/home/me/code/x")
    }
}

@Suite struct RemoteOmpDeleteTests {
    @Test func mapsMirrorPathBackToHost() {
        let root = SSH.cacheDirectory("devbox").appendingPathComponent("omp/sessions").path
        func s(_ path: String) -> Session {
            Session(id: "x", cli: .omp, hostID: "devbox", projectPath: "/srv", title: "", lastActivity: .now, messageCount: 0, sourcePath: path)
        }
        #expect(RemoteSessions.remoteOmpPath(s(root + "/--srv--/2026_x.jsonl")) == ".omp/agent/sessions/--srv--/2026_x.jsonl")
        #expect(RemoteSessions.remoteOmpPath(s(root + "/../../etc/x.jsonl")) == nil)
        #expect(RemoteSessions.remoteOmpPath(s(root + "/--srv--/deep/x.jsonl")) == nil)
        #expect(RemoteSessions.remoteOmpPath(s("/tmp/x.jsonl")) == nil)
    }
}

/// 主机能往镜像里放符号链接（指向这台 Mac 上的别处）：读、删都不能顺着它走出镜像
@Suite struct MirrorSymlinkTests {
    private func sandbox() throws -> (root: URL, outside: URL, cleanup: () -> Void) {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent("sb-mirror-\(UUID())")
        let root = base.appendingPathComponent("mirror/claude/projects")
        let outside = base.appendingPathComponent("outside")
        try FileManager.default.createDirectory(at: root.appendingPathComponent("p"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try "victim".write(to: outside.appendingPathComponent("victim.jsonl"), atomically: true, encoding: .utf8)
        try "mine".write(to: root.appendingPathComponent("p/a.jsonl"), atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("evil"), withDestinationURL: outside)
        return (base.appendingPathComponent("mirror"), outside, { try? FileManager.default.removeItem(at: base) })
    }

    @Test func deletingAMirroredCopyNeverFollowsSymlinks() throws {
        let (root, outside, cleanup) = try sandbox()
        defer { cleanup() }
        let victim = outside.appendingPathComponent("victim.jsonl")
        #expect(!RemoteSessions.removeMirrored(root.appendingPathComponent("claude/projects/evil/victim.jsonl").path, root: root))
        #expect(FileManager.default.fileExists(atPath: victim.path))
        #expect(!RemoteSessions.removeMirrored(victim.path, root: root))
        #expect(FileManager.default.fileExists(atPath: victim.path))
        let mine = root.appendingPathComponent("claude/projects/p/a.jsonl")
        #expect(RemoteSessions.removeMirrored(mine.path, root: root))
        #expect(!FileManager.default.fileExists(atPath: mine.path))
    }

    @Test func mirrorKeepsNoSymlinks() throws {
        let (root, outside, cleanup) = try sandbox()
        defer { cleanup() }
        SSH.removeSymlinks(in: root)
        #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: root.appendingPathComponent("claude/projects/evil").path)) == nil)
        #expect(FileManager.default.fileExists(atPath: outside.appendingPathComponent("victim.jsonl").path))   // 链接指向的东西不动
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("claude/projects/p/a.jsonl").path))
    }

    @Test func rsyncSkipsSymlinks() {
        #expect(SSH.mirrorFlags.contains("--no-links"))
    }
}
