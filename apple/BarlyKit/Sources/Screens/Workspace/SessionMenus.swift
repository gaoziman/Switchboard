import SwiftUI
import BarlyKit
#if os(macOS)
import AppKit
#endif

/// 会话行的右键菜单（和预览里的「更多」同一份）
struct SessionMenu: View {
    let store: WorkspaceStore
    let session: Session

    var body: some View {
        let running = store.tab(for: session) != nil
        Button(running ? "显示标签" : "接着跑") { store.resume(session) }
        if session.cli.branchArguments(session.id) != nil {
            Button("分叉为新会话") { store.branch(session) }
        }
        if session.cli == .claude {
            Menu("移到…") {
                ForEach(store.moveDestinations(for: session)) { p in
                    Button(p.name) { store.move(session, to: p.path) }
                }
                #if os(macOS)
                if session.hostID == Host.localID {
                    if !store.moveDestinations(for: session).isEmpty { Divider() }
                    Button("其他文件夹…") {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        panel.canCreateDirectories = true
                        panel.prompt = L("移到这里")
                        if panel.runModal() == .OK, let url = panel.url { store.move(session, to: url.path) }
                    }
                }
                #endif
            }
            .disabled(!store.canMove(session))
            .help(store.canMove(session) ? L("用 Claude Code 的 /cd 把会话搬到另一个文件夹") : L("先结束这个会话的 CLI 再搬"))
        }
        Divider()
        Button("重命名…") { store.renaming = session }
        Button(session.isPinned ? "取消置顶" : "置顶") { store.togglePin(session) }
        Button(session.isArchived ? "取消归档" : "归档") { store.setArchived([session.id], !session.isArchived) }
        Divider()
        Button("拷贝对话（Markdown）") { Task { await store.copyConversation(session) } }
        Button("导出对话…") { Task { await store.exportConversation(session) } }
        Divider()
        Button("复制会话 ID") { copy(session.id) }
        Button("复制项目路径") { copy(session.projectPath) }
        #if os(macOS)
        if let path = session.sourcePath, session.cli != .opencode {
            Button("在访达中显示会话文件") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)]) }
        }
        #endif
        Divider()
        Button(running ? "关闭并删除会话…" : "删除会话…", role: .destructive) { store.pendingDelete = [session] }
            .disabled(session.hostID != Host.localID && (session.cli == .opencode || session.cli == .omp))
    }

    private func copy(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #endif
    }
}

/// 多选时的右键菜单
struct MultiSessionMenu: View {
    let store: WorkspaceStore

    var body: some View {
        let picked = store.multiSelection
        Button("归档 \(picked.count) 个会话") { store.setArchived(picked.map(\.id), true); store.clearMultiSelection() }
        Button("取消归档") { store.setArchived(picked.map(\.id), false); store.clearMultiSelection() }
        Button("置顶 \(picked.count) 个") { for s in picked where !s.isPinned { store.togglePin(s) } }
        Divider()
        Button("删除 \(picked.count) 个会话…", role: .destructive) {
            store.pendingDelete = picked
            store.clearMultiSelection()
        }
    }
}

/// 项目行的右键菜单
struct ProjectMenu: View {
    let store: WorkspaceStore
    let project: Project

    var body: some View {
        Button("新会话…") {
            NotificationCenter.default.post(name: .switchboardNewSession, object: project.id)   // 「主机:路径」
        }
        Divider()
        Button(project.isPinned ? "取消置顶" : "置顶") { store.togglePin(project) }
        Button(project.isArchived ? "取消归档项目" : "归档项目") { store.setArchived(project, !project.isArchived) }
        Divider()
        #if os(macOS)
        Button("在访达中打开") { NSWorkspace.shared.open(URL(fileURLWithPath: project.path)) }
            .disabled(!project.folderExists)
        Button("复制路径") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(project.path, forType: .string)
        }
        #endif
        Divider()
        let all = store.sessions.filter { $0.projectID == project.id && $0.parentSessionID == nil }
        Button("删除这个项目的 \(all.count) 个会话…", role: .destructive) { store.pendingDelete = all }
            .disabled(all.isEmpty)
    }
}

/// SSH 主机标题的右键菜单
struct HostMenu: View {
    let store: WorkspaceStore
    let host: Host

    var body: some View {
        Button("刷新") { Task { await store.refreshHost(host.id) } }
            .disabled(host.connection == .disconnected)
        Button("Connect…（交互登录）") { store.connectingHost = host.id }
        Divider()
        Button("转发端口…") { store.hostSheet = .portForward(host.id) }.disabled(host.connection == .disconnected)
        let forwards = PortForwardManager.shared.forwards(on: host.id)
        ForEach(forwards) { f in
            Menu("localhost:\(f.local) → \(f.remote)") {
                Button("在浏览器打开") { if let u = URL(string: f.address) { NSWorkspace.shared.open(u) } }
                Button("拷贝地址") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(f.address, forType: .string) }
                Button("停止转发") { PortForwardManager.shared.stop(f) }
            }
        }
        Divider()
        Button("检查这台主机…") { store.hostSheet = .check(host.id) }.disabled(host.connection == .disconnected)
        Button("重新登录命令…") { store.hostSheet = .signInSettings(host.id) }
        if store.signInConfigs[host.id] != nil {
            Button("现在重新登录…") { store.hostSheet = .signIn(host.id) }
        }
        if host.connection == .disconnected {
            Button("连接") { store.setDisconnected(host.id, false) }
        } else {
            Button("断开（不再自动访问）") { store.setDisconnected(host.id, true) }
        }
        Divider()
        Button("移除主机", role: .destructive) { store.removeHost(host.id) }
    }
}

/// 过滤菜单（侧栏「项目 | 已打开」右边）
struct FilterMenu: View {
    @Bindable var store: WorkspaceStore
    @Environment(\.barly) private var t
    @Environment(\.barlySnapshot) private var snapshot

    private var icon: some View {
        Image(systemName: store.filter == .all && !store.showsArchived ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
            .font(.system(size: 14))
            .foregroundStyle(store.filter == .all && !store.showsArchived ? t.text2 : t.text)
            .frame(width: 28, height: 28)
    }

    var body: some View {
        // 离屏截图画不出系统 Menu（会变成占位块），截图时只画图标
        if snapshot { icon } else { menu }
    }

    private var menu: some View {
        Menu {
            Picker("范围", selection: $store.filter) {
                Text("全部").tag(SessionFilter.all)
                Text("最近 7 天").tag(SessionFilter.recent7Days)
                Divider()
                Text("运行中").tag(SessionFilter.running)
                Text("等你").tag(SessionFilter.waitingForYou)
                Divider()
                ForEach(CLIKind.allCases.filter { cli in store.sessions.contains { $0.cli == cli } }) {
                    Text($0.title).tag(SessionFilter.cli($0))
                }
            }
            .pickerStyle(.inline)
            Divider()
            Toggle("显示已归档", isOn: $store.showsArchived)
        } label: {
            icon
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .handCursor()
        .help("过滤")
    }
}

/// 重命名、删除确认、删除结果：挂在工作区窗口上
struct LibraryDialogs: ViewModifier {
    @Bindable var store: WorkspaceStore
    @State private var name = ""

    func body(content: Content) -> some View {
        content
            .alert("重命名会话", isPresented: Binding(get: { store.renaming != nil }, set: { if !$0 { store.renaming = nil } })) {
                TextField("名字", text: $name)
                Button("取消", role: .cancel) { store.renaming = nil }
                Button("保存") {
                    if let s = store.renaming { store.rename(s, to: name) }
                    store.renaming = nil
                }
            } message: {
                Text("只改 Switchboard 里显示的名字，不改 CLI 的会话。留空恢复原标题。")
            }
            .onChange(of: store.renaming?.id) { _, _ in name = store.renaming?.displayTitle ?? "" }
            .confirmationDialog(deleteTitle, isPresented: Binding(get: { !store.pendingDelete.isEmpty },
                                                                  set: { if !$0 { store.pendingDelete = [] } }),
                                titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    let targets = store.pendingDelete
                    store.pendingDelete = []
                    Task {
                        let failures = await store.delete(targets)
                        store.deleteFailures = failures
                    }
                }
                Button("取消", role: .cancel) { store.pendingDelete = [] }
            } message: {
                Text(deleteMessage)
            }
            .alert("有 \(store.deleteFailures.count) 个会话没删掉", isPresented: Binding(get: { !store.deleteFailures.isEmpty },
                                                                              set: { if !$0 { store.deleteFailures = [:] } })) {
                Button("好") { store.deleteFailures = [:] }
            } message: {
                Text(store.deleteFailures.values.prefix(3).joined(separator: "\n"))
            }
    }

    private var deleteTitle: String {
        store.pendingDelete.count == 1 ? L("删除「\(store.pendingDelete[0].displayTitle)」？") : L("删除 \(store.pendingDelete.count) 个会话？")
    }

    private var deleteMessage: String {
        let running = store.pendingDelete.filter { store.tab(for: $0) != nil }.count
        let permanent = store.pendingDelete.contains { SessionDeletion.isPermanent($0) }
        let remote = store.pendingDelete.contains { $0.hostID != Host.localID }
        var parts: [String] = []
        if running > 0 { parts.append(L("其中 \(running) 个还在运行，会先关标签、结束 CLI。")) }
        if remote { parts.append(L("SSH 主机上没有废纸篓，主机上的会话会永久删除。")) }
        parts.append(permanent ? L("Codex 和 OpenCode 的会话会永久删除；这台 Mac 上 Claude Code 和 omp 的移到废纸篓。") : L("会话文件会移到废纸篓。"))
        return parts.joined(separator: "\n")
    }
}
