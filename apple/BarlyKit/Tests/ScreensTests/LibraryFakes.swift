import Foundation
@testable import Screens

/// 测刷新编排用的假会话来源：内存里的会话，数读了几次；gated 时每次读都停在半路，等 release() 才交结果
actor FakeSessions {
    var local: [Session] = []
    var remote: [String: [Session]] = [:]
    var installed: [CLIKind] = [.claude]
    private(set) var localReads = 0
    private(set) var mirrorReads = 0
    var gated = false
    private var parked: [CheckedContinuation<Void, Never>] = []

    func set(local: [Session]) { self.local = local }
    func set(remote: [Session], for alias: String) { self.remote[alias] = remote }
    func gate(_ on: Bool) { gated = on }

    func readLocal(_ folders: Set<String>?) async -> SessionDiscovery.Result {
        localReads += 1
        if gated { await withCheckedContinuation { parked.append($0) } }
        let all = local.filter { s in folders.map { $0.contains(s.projectPath) } ?? true }
        return SessionDiscovery.Result(sessions: all, projects: SessionDiscovery.projects(for: all), installed: installed, elapsed: 0)
    }

    func readMirror(_ alias: String) -> [Session] {
        mirrorReads += 1
        return remote[alias] ?? []
    }

    /// 放行停着的读
    func release() {
        parked.forEach { $0.resume() }
        parked = []
    }

    var parkedCount: Int { parked.count }

    nonisolated var reader: SessionReader {
        SessionReader(local: { await self.readLocal($0) }, mirror: { await self.readMirror($0) })
    }
}

/// 假主机：镜像按主机给结果（nil = 成功），数镜像了几次；gated 时镜像停在半路
actor FakeHosts {
    var mirrorErrors: [String: String] = [:]
    var snapshots: [String: RemoteSessions.Snapshot] = [:]
    private(set) var mirrors = 0
    private(set) var snapshotCalls = 0
    var gated = false
    private var parked: [CheckedContinuation<Void, Never>] = []

    func gate(_ on: Bool) { gated = on }
    func set(snapshot: RemoteSessions.Snapshot?, for alias: String) { snapshots[alias] = snapshot }

    func mirror(_ alias: String) async -> String? {
        mirrors += 1
        if gated { await withCheckedContinuation { parked.append($0) } }
        return mirrorErrors[alias]
    }

    func snapshot(_ alias: String) -> RemoteSessions.Snapshot? {
        snapshotCalls += 1
        return snapshots[alias]
    }

    func release() {
        parked.forEach { $0.resume() }
        parked = []
    }

    var parkedCount: Int { parked.count }

    nonisolated var link: HostLink {
        HostLink(mirror: { alias, _ in await self.mirror(alias) }, snapshot: { await self.snapshot($0) })
    }
}

/// 等到条件成立（最多 3 秒）：异步任务起来要一点时间，不用固定的 sleep
@MainActor
func eventually(_ condition: () async -> Bool) async -> Bool {
    for _ in 0..<300 {
        if await condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return false
}

@MainActor
final class Flag { var on = false }
