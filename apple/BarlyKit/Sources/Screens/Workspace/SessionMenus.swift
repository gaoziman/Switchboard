import SwiftUI
import BarlyKit
#if os(macOS)
import AppKit
#endif

/// 会话的菜单：右键和悬停「…」同一份。在跑的：分支 · 结束会话 …… 关闭并删除；没在跑的：继续 · 分支 …… 删除
struct SessionMenu: View {
    let store: WorkspaceStore
    let session: Session

    /// macOS 的 SwiftUI 菜单默认只显示文字，要显式要求图标
    var body: some View { items.labelStyle(.titleAndIcon) }

    @ViewBuilder private var items: some View {
        let running = session.activity.isRunning || store.tab(for: session) != nil
        let canBranch = session.cli.branchArguments(session.id) != nil
        if !running {
            Button { store.resume(session) } label: { Label("继续", systemImage: "play") }
        }
        if canBranch {
            Button { store.branch(session) } label: { Label("分支", systemImage: "arrow.triangle.branch") }
        }
        if running {
            Button { store.endSession(session) } label: { Label("结束会话", systemImage: "stop.circle") }
                .help(L("结束这个会话的 CLI，会话文件保留"))
        }
        Divider()
        Button { store.presentation = .renameSession(session) } label: { Label("重命名", systemImage: "pencil") }
        Button { store.togglePin(session) } label: {
            Label(session.isPinned ? "取消置顶会话" : "置顶会话", systemImage: session.isPinned ? "pin.slash" : "pin")
        }
        Button { store.setArchived([session.id], !session.isArchived) } label: {
            Label(session.isArchived ? "取消归档会话" : "归档会话", systemImage: "archivebox")
        }
        moveMenu
        Divider()
        Button { Task { await store.copyConversation(session) } } label: { Label("复制对话", systemImage: "doc.on.doc") }
        Menu {
            Button("Markdown…") { Task { await store.exportConversation(session, as: .markdown) } }
            Button("纯文本…") { Task { await store.exportConversation(session, as: .plainText) } }
            if session.sourcePath != nil, session.cli != .opencode {
                Button("原始会话文件…") { Task { await store.exportConversation(session, as: .original) } }
            }
        } label: {
            Label("导出对话", systemImage: "square.and.arrow.up")
        }
        Button { copy(session.id) } label: { Label("复制会话 ID", systemImage: "doc.on.doc") }
        #if os(macOS)
        if let path = session.sourcePath, session.cli != .opencode, session.hostID == Host.localID {
            Button { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)]) } label: {
                Label("在 Finder 中显示会话文件", systemImage: "doc.text.magnifyingglass")
            }
        }
        #endif
        Divider()
        Button { store.presentation = .confirmDelete([session]) } label: {
            Label(running ? "关闭并删除会话…" : "删除会话…", systemImage: "trash")
        }
    }

    /// 移动到：只有 Claude Code 能搬（/cd），别的 CLI 灰掉并说明
    @ViewBuilder private var moveMenu: some View {
        Menu {
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
        } label: {
            Label("移动到", systemImage: "folder")
        }
        .disabled(session.cli != .claude || !store.canMove(session))
        .help(session.cli != .claude ? L("只有 Claude Code 的会话能搬到别的文件夹")
              : store.canMove(session) ? L("用 Claude Code 的 /cd 把会话搬到另一个文件夹") : L("先结束这个会话的 CLI 再搬"))
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
            store.presentation = .confirmDelete(picked)
            store.clearMultiSelection()
        }
    }
}

/// 项目的菜单：右键和悬停「…」同一份
struct ProjectMenu: View {
    let store: WorkspaceStore
    let project: Project

    private var isLocal: Bool { project.hostID == Host.localID }

    /// macOS 的 SwiftUI 菜单默认只显示文字，要显式要求图标
    var body: some View { items.labelStyle(.titleAndIcon) }

    @ViewBuilder private var items: some View {
        Menu {
            NewSessionItems(store: store, project: project)
        } label: {
            Label("新建会话", systemImage: "plus")
        }
        Button { store.quickStart(.terminal, in: project) } label: { Label("新建终端", systemImage: "terminal") }
        #if os(macOS)
        Button { NSWorkspace.shared.open(URL(fileURLWithPath: project.path)) } label: { Label("在 Finder 中打开项目", systemImage: "folder") }
            .disabled(!project.folderExists || !isLocal)   // 主机上的路径在这台 Mac 上打不开
        if isLocal {
            Menu {
                // 子菜单是另一个菜单，父菜单的 labelStyle 传不进来，这里再要一次图标
                Group {
                    let apps = ExternalEditors.installed
                    ForEach(apps) { app in
                        Button { ExternalEditors.open(project.path, with: app) } label: {
                            Label { Text(app.name) } icon: { Image(nsImage: ExternalEditors.icon(app)) }
                        }
                    }
                    if apps.isEmpty { Text("没有找到编辑器") }
                }
                .labelStyle(.titleAndIcon)
            } label: {
                Label("打开项目于", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            .disabled(!project.folderExists)
        }
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(project.path, forType: .string)
        } label: { Label("复制项目路径", systemImage: "doc.on.doc") }
        #endif
        Button { store.presentation = .renameProject(project) } label: { Label("重命名项目…", systemImage: "pencil") }
        Button { store.togglePin(project) } label: {
            Label(project.isPinned ? "取消置顶项目" : "置顶项目", systemImage: project.isPinned ? "pin.slash" : "pin")
        }
        Divider()
        Button { store.setArchived(project, !project.isArchived) } label: {
            Label(project.isArchived ? "取消归档项目" : "归档项目", systemImage: "archivebox")
        }
        // 会话库只显示添加的文件夹，得有个拿掉的地方：只是不显示，文件不动
        Button { store.removeFolder(project) } label: { Label("从侧栏移除", systemImage: "minus.circle") }
            .help(L("只是不在侧栏显示，会话文件不会删除"))
        Divider()
        let deletable = store.deletableSessions(in: project)
        let all = store.allSessions(in: project)
        Button { store.presentation = .confirmDelete(deletable) } label: {
            Label("删除所有可删除的会话（\(deletable.count)）…", systemImage: "trash")
        }
        .disabled(deletable.isEmpty)
        .help(L("在跑的、开着标签的会话不算"))
        Button {
            store.presentation = .confirmDelete(all, archivingProject: project.id)
        } label: {
            Label("归档项目并删除所有会话（\(all.count)）…", systemImage: "trash")
        }
        .disabled(all.isEmpty)
    }
}

/// 「新建会话」子菜单和项目行「+」共用：这台主机装了的 CLI（点了直接开跑）、终端（只有「+」里有，菜单里是单独一项）、更多选项
struct NewSessionItems: View {
    let store: WorkspaceStore
    let project: Project
    var includesTerminal = false

    /// macOS 的 SwiftUI 菜单默认只显示文字，要显式要求图标
    var body: some View { items.labelStyle(.titleAndIcon) }

    @ViewBuilder private var items: some View {
        ForEach(store.quickStartCLIs(for: project), id: \.self) { cli in
            Button { store.quickStart(.cli(cli), in: project) } label: { Label(cli.title, systemImage: cli.symbol) }
        }
        if includesTerminal {
            Divider()
            Button { store.quickStart(.terminal, in: project) } label: { Label("终端", systemImage: "terminal") }
        }
        Divider()
        Button {
            NotificationCenter.default.post(.newSession(in: project.id))
        } label: { Label("更多选项…", systemImage: "slider.horizontal.3") }
    }
}

extension CLIKind {
    /// 菜单里用的 SF Symbol（侧栏里的 CLIMark 同一套形状）
    var symbol: String {
        switch self {
        case .claude: "asterisk"
        case .codex: "hexagon"
        case .opencode: "curlybraces"
        case .omp: "function"
        }
    }
}

/// SSH 主机标题的右键菜单
struct HostMenu: View {
    let store: WorkspaceStore
    let host: Host

    var body: some View {
        Button("添加文件夹…") { store.presentation = .hostSheet(.addFolder(host.id)) }
            .disabled(host.connection == .disconnected)
        Divider()
        Button("刷新") { Task { await store.refreshHost(host.id) } }
            .disabled(host.connection == .disconnected)
        Button("Connect…（交互登录）") { store.presentation = .connect(host: host.id) }
        Divider()
        Button("转发端口…") { store.presentation = .hostSheet(.portForward(host.id)) }.disabled(host.connection == .disconnected)
        let forwards = PortForwardManager.shared.forwards(on: host.id)
        ForEach(forwards) { f in
            Menu("localhost:\(f.local) → \(f.remote)") {
                Button("在浏览器打开") { if let u = URL(string: f.address) { NSWorkspace.shared.open(u) } }
                Button("拷贝地址") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(f.address, forType: .string) }
                Button("停止转发") { PortForwardManager.shared.stop(f) }
            }
        }
        Divider()
        Button("检查这台主机…") { store.presentation = .hostSheet(.check(host.id)) }.disabled(host.connection == .disconnected)
        Button("重新登录命令…") { store.presentation = .hostSheet(.signInSettings(host.id)) }
        if store.signInConfigs[host.id] != nil {
            Button("现在重新登录…") { store.presentation = .hostSheet(.signIn(host.id)) }
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
            .font(.system(size: BarlyScale.pt(14)))
            .foregroundStyle(store.filter == .all && !store.showsArchived ? t.text2 : t.text)
            .frame(width: BarlyScale.pt(28), height: BarlyScale.pt(28))
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
            .alert("重命名会话", isPresented: store.isPresenting(\.renamingSession)) {
                TextField("名字", text: $name)
                Button("取消", role: .cancel) { store.presentation = nil }
                Button("保存") {
                    if let s = store.presentation?.renamingSession { store.rename(s, to: name) }
                    store.presentation = nil
                }
            } message: {
                Text("只改 Switchboard 里显示的名字，不改 CLI 的会话。留空恢复原标题。")
            }
            .onChange(of: store.presentation?.renamingSession?.id) { _, _ in name = store.presentation?.renamingSession?.displayTitle ?? "" }
            .alert("重命名项目", isPresented: store.isPresenting(\.renamingProject)) {
                TextField("名字", text: $name)
                Button("取消", role: .cancel) { store.presentation = nil }
                Button("保存") {
                    if let p = store.presentation?.renamingProject { store.rename(p, to: name) }
                    store.presentation = nil
                }
            } message: {
                Text("只改 Switchboard 里显示的名字，不改文件夹。留空恢复文件夹名。")
            }
            .onChange(of: store.presentation?.renamingProject?.id) { _, _ in name = store.presentation?.renamingProject?.name ?? "" }
            .confirmationDialog(deleteTitle, isPresented: store.isPresenting(\.deleting), titleVisibility: .visible) {
                Button(store.presentation?.archivingProject == nil ? "删除" : "归档并删除", role: .destructive) {
                    Task { await store.confirmPendingDelete() }
                }
                Button("取消", role: .cancel) { store.presentation = nil }
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
        let pending = store.presentation?.deleting ?? []
        if let id = store.presentation?.archivingProject, let p = store.projects.first(where: { $0.id == id }) {
            return L("归档「\(p.name)」并删除它的 \(pending.count) 个会话？")
        }
        return pending.count == 1 ? L("删除「\(pending[0].displayTitle)」？") : L("删除 \(pending.count) 个会话？")
    }

    private var deleteMessage: String {
        let pending = store.presentation?.deleting ?? []
        let running = pending.filter { store.tab(for: $0) != nil }.count
        let permanent = pending.contains { SessionDeletion.isPermanent($0) }
        let remote = pending.contains { $0.hostID != Host.localID }
        var parts: [String] = []
        if running > 0 { parts.append(L("其中 \(running) 个还在运行，会先关标签、结束 CLI。")) }
        if remote { parts.append(L("SSH 主机上没有废纸篓，主机上的会话会永久删除。")) }
        parts.append(permanent ? L("Codex 和 OpenCode 的会话会永久删除；这台 Mac 上 Claude Code 和 omp 的移到废纸篓。") : L("会话文件会移到废纸篓。"))
        return parts.joined(separator: "\n")
    }
}
