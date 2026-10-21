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
