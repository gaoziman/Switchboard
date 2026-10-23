import Foundation
import Testing
@testable import Screens

/// 共享会话库的刷新编排（WorkspaceData.refresh / pollHosts / start）：用假的会话来源和假主机跑完整流程，
/// 不碰真实磁盘、不起 rsync / ssh
@MainActor
@Suite("会话库刷新")
struct LibraryRefreshTests {
    private let devbox = Screens.Host(id: "devbox", kind: .ssh(target: "devbox"), displayName: "devbox", connection: .connected)

    private func s(_ id: String, _ path: String = "/p", host: String = Host.localID, at minutes: Double = 1) -> Session {
        Session(id: id, cli: .claude, hostID: host, projectPath: path, title: id,
                lastActivity: Date().addingTimeInterval(-minutes * 60), messageCount: 1)
    }

    /// 会话库里加好 /p 和 devbox:/srv，升级挑选做过了
    private func data(_ sessions: FakeSessions, _ hosts: FakeHosts) -> WorkspaceData {
        let d = WorkspaceData(hosts: [MockData.local, devbox], projects: [], sessions: [], reader: sessions.reader, link: hosts.link)
        d.library.folders = ["local:/p", "devbox:/srv"]
        d.library.foldersMigrated = true
        return d
    }

    @Test("正在读时又要刷新：读完补读一次，后来的调用等补读完才返回；同时来的几个并成一次")
    func coalesces() async {
        let src = FakeSessions(), hosts = FakeHosts()
        await src.gate(true)
        let d = data(src, hosts)
        _ = WorkspaceStore(data: d)
        let first = Task { await d.refresh() }
        #expect(await eventually { await src.parkedCount == 1 })
        await src.set(local: [s("new")])                     // 第一次读开始以后才有的改动（刚加的会话）
        let secondDone = Flag()
        let second = Task { await d.refresh(); secondDone.on = true }
        let third = Task { await d.refresh() }
        await src.release()                                   // 第一次读完 → 马上补读
        #expect(await eventually {
            let parked = await src.parkedCount, reads = await src.localReads
            return parked == 1 && reads == 2
        })
        #expect(!secondDone.on)                               // 补读还没完，后来的调用不返回
        await src.release()
        await first.value; await second.value; await third.value
        #expect(await src.localReads == 2)
        #expect(d.sessions.map(\.id) == ["new"])
        #expect(d.loadState == .loaded)
    }

    @Test("同一台主机的镜像同时只跑一份；库改了只重读镜像，不跑 rsync")
    func hostJobsDedupe() async {
        let src = FakeSessions(), hosts = FakeHosts()
        await hosts.gate(true)
        await src.set(remote: [s("r1", "/srv", host: "devbox")], for: "devbox")
        let d = data(src, hosts)
        _ = WorkspaceStore(data: d)
        let first = Task { await d.refresh(.host("devbox")) }
        #expect(await eventually { await hosts.parkedCount == 1 })
        await d.refresh(.host("devbox"))                     // 正在镜像：这次直接跳过
        #expect(await hosts.mirrors == 1)
        await hosts.release()
        await first.value
        #expect(d.hosts.last?.connection == .connected)
        #expect(d.sessions.map(\.id) == ["r1"])
        await d.refresh(.folders("devbox"))                  // 加了主机上的文件夹：重读本机的镜像
        #expect(await hosts.mirrors == 1)
        #expect(await src.mirrorReads == 2)
    }

    @Test("镜像失败按原因标主机：要登录 / 连不上，已有的会话列表留着")
    func hostErrors() async {
        let src = FakeSessions(), hosts = FakeHosts()
        await src.set(remote: [s("r1", "/srv", host: "devbox")], for: "devbox")
        let d = data(src, hosts)
        _ = WorkspaceStore(data: d)
        await d.refresh(.host("devbox"))
        await hosts.setError("Permission denied (publickey)", for: "devbox")
        await d.refresh(.host("devbox"))
        #expect(d.hosts.last?.connection == .needsConnect)
        await hosts.setError("ssh: connect to host devbox: Operation timed out", for: "devbox")
        await d.refresh(.host("devbox"))
        #expect(d.hosts.last?.connection == .unreachable("ssh: connect to host devbox: Operation timed out"))
        #expect(d.sessions.map(\.id) == ["r1"])
    }

    @Test("镜像途中点了断开：镜像跑完不把主机改回已连接")
    func disconnectDuringMirror() async {
        let src = FakeSessions(), hosts = FakeHosts()
        await hosts.gate(true)
        let d = data(src, hosts)
        let st = WorkspaceStore(data: d)
        let refresh = Task { await d.refresh(.host("devbox")) }
        #expect(await eventually { await hosts.parkedCount == 1 })
        st.setDisconnected("devbox", true)
        await hosts.release()
        await refresh.value
        #expect(d.hosts.last?.connection == .disconnected)
    }

    @Test("多窗口：每个窗口都认领自己的新会话标签；展开项目、恢复远程标签只在主窗口")
    func fansOutToWindows() async {
        let src = FakeSessions(), hosts = FakeHosts()
        let d = data(src, hosts)
        let primary = WorkspaceStore(data: d), other = WorkspaceStore(data: d)
        #expect(d.primaryWindow === primary)
        // 读完展开最近的项目：只在主窗口（原来落在发起刷新的那个窗口）
        await src.set(local: [s("old", at: 60)])
        await d.refresh()
        #expect(primary.expandedProjectIDs == ["local:/p"])
        #expect(other.expandedProjectIDs.isEmpty)
        // 第二个窗口里开着一个新会话标签，等认领：它自己认领（认领的窗口展开那个项目）
        let tab = TerminalTab(kind: .pending(cli: .claude), projectPath: "/p", title: "新的 Claude Code 会话", activity: .working)
        other.tabGroups = [TabGroup(projectID: "local:/p", name: "p", tint: 0, tabs: [tab])]
        other.pendingClaims[tab.id] = PendingClaim(cli: .claude, folder: "/p", startedAt: Date().addingTimeInterval(-30))
        await src.set(local: [s("old", at: 60), s("fresh", at: 0)])
        await d.refresh()
        #expect(other.tab(tab.id)?.kind == .session(id: "fresh", cli: .claude))
        #expect(!primary.allTabs.contains { $0.kind == .session(id: "fresh", cli: .claude) })
        // 上次开着的远程标签：那台主机读完以后恢复到主窗口（不管是谁发起的刷新）
        d.pendingRemoteTabs = [WorkspaceStore.TabRecord(cli: "claude", sessionID: "r1", projectPath: "/srv", title: "r1",
                                                        tmuxName: nil, selected: false, hostID: "devbox")]
        await src.set(remote: [s("r1", "/srv", host: "devbox")], for: "devbox")
        await d.refresh(.host("devbox"))
        #expect(primary.allTabs.contains { $0.kind == .session(id: "r1", cli: .claude) })
        #expect(!other.allTabs.contains { $0.kind == .session(id: "r1", cli: .claude) })
        #expect(primary.expandedProjectIDs.contains("devbox:/srv"))
    }

    @Test("开着标签的会话：文件夹移出了会话库也留在列表里（断线重连、接着跑要找得到它）")
    func keepsOpenTabSessions() async {
        let src = FakeSessions(), hosts = FakeHosts()
        let d = data(src, hosts)
        let w = WorkspaceStore(data: d)
        await src.set(local: [s("keep", "/gone")])
        d.library.folders = ["local:/gone"]
        await d.refresh()
        w.tabGroups = [TabGroup(projectID: "local:/gone", name: "gone", tint: 0,
                                tabs: [TerminalTab(kind: .session(id: "keep", cli: .claude), projectPath: "/gone", title: "keep", activity: .idle)])]
        d.library.folders = []
        await d.refresh()
        #expect(d.sessions.map(\.id) == ["keep"])
    }

    @Test("还没做过升级挑选：全量读一次，给出候选，侧栏只放库里的")
    func migration() async {
        let src = FakeSessions(), hosts = FakeHosts()
        let d = data(src, hosts)
        d.library.foldersMigrated = false
        d.library.folders = []
        _ = WorkspaceStore(data: d)
        await src.set(local: [s("a", "/x"), s("b", "/y")])
        await d.refresh()
        #expect(Set(d.migrationCandidates?.map(\.path) ?? []) == ["/x", "/y"])
        #expect(d.sessions.isEmpty)
    }

    @Test("轮询主机状态：问不到就退避，到点前不再起 ssh；问到了恢复")
    func pollBacksOff() async {
        let src = FakeSessions(), hosts = FakeHosts()
        let d = data(src, hosts)
        _ = WorkspaceStore(data: d)
        let t0 = Date()
        await d.pollHosts(now: t0)
        #expect(await hosts.snapshotCalls == 1)
        await d.pollHosts(now: t0.addingTimeInterval(5))       // 还在退避（10 秒）
        #expect(await hosts.snapshotCalls == 1)
        var snap = RemoteSessions.Snapshot()
        snap.claude["r1"] = .working
        await hosts.set(snapshot: snap, for: "devbox")
        await d.pollHosts(now: t0.addingTimeInterval(11))
        #expect(await hosts.snapshotCalls == 2)
        #expect(d.remoteSnapshots["devbox"]?.claude["r1"] == .working)
    }

    @Test("启动：先读存盘的会话库和主机，再读本机，再镜像主机")
    func start() async {
        let src = FakeSessions(), hosts = FakeHosts()
        let p = WorkspacePersistence.memory()
        var lib = LibraryState()
        lib.folders = ["local:/p"]
        lib.foldersMigrated = true
        p.saveLibrary(lib)
        p.saveHosts([HostRecord(alias: "devbox")])
        let d = WorkspaceData(hosts: [MockData.local], projects: [], sessions: [], loadState: .loading, persistence: p,
                              reader: src.reader, link: hosts.link)
        _ = WorkspaceStore(data: d)
        await src.set(local: [s("a")])
        await d.start()
        #expect(d.library.folders == ["local:/p"])
        #expect(d.sessions.map(\.id) == ["a"])
        #expect(d.loadState == .loaded)
        #expect(d.hosts.map(\.id) == [Host.localID, "devbox"])
        #expect(await hosts.mirrors == 1)
    }
}

extension FakeHosts {
    func setError(_ error: String?, for alias: String) { mirrorErrors[alias] = error }
}
