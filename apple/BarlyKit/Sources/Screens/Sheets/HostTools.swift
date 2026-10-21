import SwiftUI
import BarlyKit
#if os(macOS)
import AppKit
#endif

// MARK: - 主机体检

/// 主机体检报告：问题在前、提醒在后，每条附主机原话和一条可以在终端里复现的命令。
/// 主按钮「用 agent 修复…」（找到可修的问题时），其余「复制报告 / 再查一次」
public struct HostCheckSheet: View {
    public enum Phase: String, CaseIterable { case running, problems, healthy }

    let phase: Phase
    @Environment(\.barly) private var t

    public init(phase: Phase = .problems) { self.phase = phase }

    public var body: some View {
        SheetFrame(title: L("检查 devbox"), subtitle: subtitle, width: 640) {
            VStack(alignment: .leading, spacing: 12) {
                switch phase {
                case .running:
                    CheckSteps(steps: [
                        (L("登录（和后台刷新同一种方式）"), .done, "0.4s"),
                        (L("追踪 zsh 启动脚本"), .done, "1.8s"),
                        (L("查找 rsync"), .done, "0.1s"),
                        (L("查找 tmux · 版本"), .done, "0.1s"),
                        ("Claude Code --version", .running, "6.2s"),
                        ("Codex --version", .pending, ""),
                    ])
                case .problems:
                    Finding(level: .problem, title: L("tmux 连不上正在跑的 tmux 服务器"),
                            detail: L("升级 tmux 后旧服务器还在跑，它的会话能继续跑但打不开，新标签会马上报错退出。用启动它的那个 tmux 重新接上，或结束这些会话后重开。"),
                            output: "protocol version mismatch (client 8, server 7)",
                            command: "tmux -L switchboard ls")
                    Finding(level: .warning, title: L("~/.bashrc 第 42 行会在每个交互 shell 里启动 zsh"),
                            detail: L("Switchboard 已改用不读交互启动脚本的方式启动 CLI。想恢复正常，把这一行改成只在你自己登录时执行。"),
                            output: "exec zsh -l",
                            command: "if [[ $- == *i* ]] && [ -z \"$SWITCHBOARD\" ]; then exec zsh -l; fi")
                    Finding(level: .ok, title: "rsync 3.2.7 · Claude Code 2.1.248 · Codex 0.160.0", detail: nil, output: nil, command: nil)
                case .healthy:
                    Finding(level: .ok, title: L("登录、shell 启动、rsync、tmux 3.4 都正常"), detail: nil, output: nil, command: nil)
                    Finding(level: .ok, title: L("Claude Code 2.1.248 · Codex 0.160.0 可以启动"), detail: nil, output: nil, command: nil)
                }
            }
        } buttons: {
            BarlyButton(L("复制报告"), icon: "doc.on.doc", variant: .ghost)
            Spacer()
            switch phase {
            case .running:
                BarlyButton(L("停止"), variant: .ghost)
            case .problems:
                BarlyButton(L("再查一次"), variant: .ghost)
                BarlyButton(L("用 agent 修复…"), variant: .primary)
            case .healthy:
                BarlyButton(L("再查一次"), variant: .ghost)
                BarlyButton(L("好"), variant: .outline)
            }
        }
    }

    private var subtitle: String {
        switch phase {
        case .running: L("只读，不改主机上的任何东西。慢的那一步会显示耗时。")
        case .problems: L("1 个问题 · 1 条提醒 · 2026-10-20 14:22")
        case .healthy: L("没有发现问题 · 2026-10-20 14:22")
        }
    }
}

private struct Finding: View {
    enum Level { case problem, warning, ok }
    let level: Level
    let title: String
    let detail: String?
    let output: String?
    let command: String?
    @Environment(\.barly) private var t

    var body: some View {
        let color: Color = switch level { case .problem: t.danger; case .warning: t.warning; case .ok: t.success }
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: level == .ok ? "checkmark" : level == .problem ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(color)
                MonoLabel(level == .problem ? "PROBLEM" : level == .warning ? "WARNING" : "OK", color: color)
                Text(title).barlyText(.product.small.weight(500), color: t.text).lineLimit(1)
            }
            if let detail {
                Text(detail).barlyText(.product.small, color: t.text2).fixedSize(horizontal: false, vertical: true)
            }
            if let output {
                Text(output).barlyText(.product.caption.monospaced, color: t.text3)
                    .padding(.horizontal, 10).padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(t.bg, in: RoundedRectangle(cornerRadius: BarlyRadius.xs))
            }
            if let command {
                HStack(spacing: 8) {
                    Text("在终端里试：").barlyText(.product.caption, color: t.text3)
                    Text(command).barlyText(.product.caption.monospaced, color: t.text2).lineLimit(1)
                    Spacer()
                    Image(systemName: "doc.on.doc").font(.system(size: 10)).foregroundStyle(t.text3).handCursor()
                }
            }
        }
        .padding(level == .ok ? 10 : 12)
        .overlay(RoundedRectangle(cornerRadius: BarlyRadius.sm).stroke(t.hairline))
    }
}

// MARK: - 端口转发

/// 端口转发：列出主机上 localhost 在听的端口（是你的进程就写程序名），选一个或手填；本机端口默认同号。
/// 只听 Mac 的 localhost，别的电脑用不了
public struct PortForwardSheet: View {
    let busy: Bool
    @Environment(\.barly) private var t

    public init(busy: Bool = false) { self.busy = busy }

    private let ports: [(Int, String, String)] = [
        (3000, "node", "next dev · ~/code/notes-site"),
        (5173, "node", "vite · ~/code/imagery"),
        (8080, "relay", "relay-gateway"),
        (5432, "", L("不是你的进程")),
    ]

    public var body: some View {
        SheetFrame(title: L("转发 devbox 的端口"), subtitle: L("转发只在这台 Mac 的 localhost 上监听，别的电脑连不进来。"), width: 540) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(spacing: 0) {
                    HStack {
                        MonoLabel("PORT", color: t.text4).frame(width: 64, alignment: .leading)
                        MonoLabel("PROGRAM", color: t.text4).frame(width: 80, alignment: .leading)
                        MonoLabel("WHAT", color: t.text4)
                        Spacer()
                    }
                    .padding(.horizontal, 12).frame(height: BarlyScale.pt(30))
                    Hairline()
                    ForEach(Array(ports.enumerated()), id: \.offset) { i, p in
                        let on = i == 0
                        HStack {
                            Text(verbatim: String(p.0)).barlyText(.product.small.weight(on ? 500 : 400).monospaced, color: t.text).frame(width: 64, alignment: .leading)
                            Text(p.1.isEmpty ? "—" : p.1).barlyText(.product.small.monospaced, color: t.text2).frame(width: 80, alignment: .leading)
                            Text(p.2).barlyText(.product.small, color: p.1.isEmpty ? t.text4 : t.text3).lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 12).frame(height: BarlyScale.pt(30))
                        .barlySelected(on, radius: 0, idleBorder: .clear)
                        .handCursor()
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: BarlyRadius.sm).stroke(t.hairline))
                .clipShape(RoundedRectangle(cornerRadius: BarlyRadius.sm))

                FieldRow(label: L("本机端口"), note: busy ? nil : L("访问 http://localhost:3000 就是 devbox 上的 3000。")) {
                    ValueBox(text: "3000", icon: nil, mono: true, error: busy)
                }
                if busy {
                    Problem(title: L("这台 Mac 的 3000 端口已经被占用"),
                            detail: L("另一个程序在用它。换一个本机端口，比如 3001，主机端仍然是 3000。"),
                            output: "bind [127.0.0.1]:3000: Address already in use")
                }
            }
        } buttons: {
            Spacer()
            BarlyButton(L("取消"), variant: .ghost)
            BarlyButton(L("开始转发"), variant: .primary).opacity(busy ? 0.4 : 1)
        }
    }
}

// MARK: - 独立阅读窗口

/// 独立阅读窗口：只读，不影响主窗口选中的终端；自带查找条（命中数 · 上一个 / 下一个）
public struct ReadingWindow: View {
    let store: WorkspaceStore
    let sessionID: String
    @Environment(\.barly) private var t

    public init(store: WorkspaceStore, sessionID: String) {
        self.store = store
        self.sessionID = sessionID
    }

    public var body: some View {
        if let session = store.session(sessionID) {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    TrafficLights()
                    Spacer()
                    Text(session.displayTitle).barlyText(.product.small.weight(500), color: t.text2).lineLimit(1)
                    Spacer()
                    Color.clear.frame(width: 60)
                }
                .padding(.horizontal, 16)
                .frame(height: BarlyScale.pt(40))
                .background(t.bg)
                .overlay(alignment: .bottom) { Hairline() }
                findBar
                PreviewPane(session: session, project: store.project(for: session), host: store.host(session.hostID),
                            entries: store.transcripts[session.id] ?? [], highlight: L("分组"), fixtureCurrentMatch: 3)
            }
            .background(t.canvas)
        }
    }

    private var findBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundStyle(t.text3)
                Text("分组▏").barlyText(.product.small, color: t.text)
                Spacer()
                Text("3 / 12").barlyText(.product.caption.monospaced, color: t.text3)
            }
            .padding(.horizontal, 8)
            .frame(width: BarlyScale.pt(280), height: BarlyScale.pt(28))
            .background(t.fieldBg, in: RoundedRectangle(cornerRadius: BarlyRadius.sm))
            .overlay(RoundedRectangle(cornerRadius: BarlyRadius.sm).stroke(t.text3, lineWidth: 1.5))
            PaneIcon(symbol: "chevron.up", help: L("上一个（⇧⌘G）"))
            PaneIcon(symbol: "chevron.down", help: L("下一个（⌘G）"))
            Spacer()
            Text("只搜已加载的 3 页").barlyText(.product.caption, color: t.text4)
            PaneIcon(symbol: "xmark", help: L("关闭查找（Esc）"))
        }
        .padding(.horizontal, 12)
        .frame(height: BarlyScale.pt(44))
        .background(t.bg)
        .overlay(alignment: .bottom) { Hairline() }
    }
}

// MARK: - app 里真正用的版本

/// 端口转发（真实）：列出主机在听的端口 → 选一个 / 手填 → 本机端口默认同号 → 开始
public struct LivePortForwardSheet: View {
    let alias: String
    let onDone: () -> Void
    @State private var ports: [ListeningPort]?
    @State private var remote = ""
    @State private var local = ""
    @State private var error: String?
    @State private var starting = false
    @Environment(\.barly) private var t

    public init(alias: String, onDone: @escaping () -> Void) {
        self.alias = alias
        self.onDone = onDone
    }

    public var body: some View {
        SheetFrame(title: L("转发 \(alias) 的端口"), subtitle: L("转发只在这台 Mac 的 localhost 上监听，别的电脑连不进来。"), width: 540) {
            VStack(alignment: .leading, spacing: 14) {
                if let ports {
                    if ports.isEmpty {
                        Text("主机上没有在 localhost 监听的端口。可以直接在下面填。").barlyText(.product.small, color: t.text3)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(ports) { p in
                                let on = remote == String(p.port)
                                HStack {
                                    Text(verbatim: String(p.port)).barlyText(.product.small.weight(on ? 500 : 400).monospaced, color: t.text).frame(width: 64, alignment: .leading)
                                    Text(p.program ?? "—").barlyText(.product.small.monospaced, color: p.program == nil ? t.text4 : t.text2)
                                    Spacer()
                                }
                                .padding(.horizontal, 12).frame(height: BarlyScale.pt(30))
                                .barlySelected(on, radius: 0, idleBorder: .clear)
                                .contentShape(Rectangle())
                                .onTapGesture { remote = String(p.port); local = String(p.port); error = nil }
                                .handCursor()
                            }
                        }
                        .overlay(RoundedRectangle(cornerRadius: BarlyRadius.sm).stroke(t.hairline))
                        .clipShape(RoundedRectangle(cornerRadius: BarlyRadius.sm))
                    }
                } else {
                    HStack(spacing: 8) { ActivityLamp(.working, size: 7); Text("正在列出主机上在听的端口…").barlyText(.product.small, color: t.text2) }
                }
                FieldRow(label: L("主机端口")) { field($remote, "3000") }
                FieldRow(label: L("本机端口"), note: local.isEmpty ? nil : L("访问 http://localhost:\(local) 就是 \(alias) 上的 \(remote.isEmpty ? "…" : remote)。")) { field($local, remote.isEmpty ? L("同上") : remote) }
                if let error {
                    Problem(title: L("转发没建起来"), detail: L("本机端口被别的程序占用，就换一个本机端口；主机不允许转发要找管理员。"), output: error)
                }
            }
        } buttons: {
            Spacer()
            BarlyButton(L("取消"), variant: .ghost, action: onDone).keyboardShortcut(.cancelAction)
            BarlyButton(starting ? L("正在转发…") : L("开始转发"), variant: .primary) {
                guard let r = Int(remote) else { return }
                let l = Int(local) ?? r
                starting = true
                Task {
                    error = await PortForwardManager.shared.start(host: alias, local: l, remote: r)
                    starting = false
                    if error == nil { onDone() }
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(Int(remote) == nil || starting)
        }
        .task {
            let alias = self.alias
            ports = await Task.detached { PortForwarding.listPorts(alias) ?? [] }.value
        }
    }

    private func field(_ text: Binding<String>, _ placeholder: String) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 13, design: .monospaced))
            .padding(.horizontal, 10)
            .frame(width: BarlyScale.pt(120), height: BarlyScale.pt(30))
            .background(t.fieldBg, in: RoundedRectangle(cornerRadius: BarlyRadius.sm))
            .overlay(RoundedRectangle(cornerRadius: BarlyRadius.sm).stroke(t.borderStrong))
    }
}

/// 主机体检（真实）：一步步跑、显示耗时，跑完列发现；有问题可以交给 agent 修
public struct LiveHostCheckSheet: View {
    @State private var check: HostCheck
    let onFixWithAgent: (String) -> Void
    let onDone: () -> Void
    @Environment(\.barly) private var t

    public init(alias: String, onFixWithAgent: @escaping (String) -> Void, onDone: @escaping () -> Void) {
        _check = State(initialValue: HostCheck(alias: alias))
        self.onFixWithAgent = onFixWithAgent
        self.onDone = onDone
    }

    public var body: some View {
        SheetFrame(title: L("检查 \(check.alias)"), subtitle: subtitle, width: 640) {
            VStack(alignment: .leading, spacing: 12) {
                if check.running || check.findings.isEmpty {
                    CheckSteps(steps: check.steps.map { s in
                        (s.title, s.status == .done ? .done : s.status == .running ? .running : s.status == .failed ? .failed : .pending,
                         s.seconds.map { String(format: "%.1fs", $0) } ?? "")
                    })
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(check.findings) { f in
                            Finding(level: f.level == .problem ? .problem : f.level == .warning ? .warning : .ok,
                                    title: f.title, detail: f.detail, output: f.output, command: f.command)
                        }
                    }
                }
                .frame(maxHeight: check.running ? 0 : 420)
            }
        } buttons: {
            BarlyButton(L("复制报告"), icon: "doc.on.doc", variant: .ghost) {
                #if os(macOS)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(check.report, forType: .string)
                #endif
            }
            .disabled(check.running)
            Spacer()
            BarlyButton(L("关闭"), variant: .ghost, action: onDone).keyboardShortcut(.cancelAction)
            BarlyButton(L("再查一次"), variant: check.hasProblems ? .ghost : .outline) { Task { await check.run() } }.disabled(check.running)
            if check.hasProblems && !check.running {
                BarlyButton(L("用 agent 修复…"), variant: .primary) { onFixWithAgent(check.report) }
            }
        }
        .task { await check.run() }
    }

    private var subtitle: String {
        if check.running { return L("只读，不改主机上的任何东西。慢的那一步会显示耗时。") }
        let p = check.findings.filter { $0.level == .problem }.count, w = check.findings.filter { $0.level == .warning }.count
        return p + w == 0 ? L("没有发现问题") : L("\(p) 个问题 · \(w) 条提醒")
    }
}

/// 定期重新登录的设置
public struct SignInSettingsSheet: View {
    let alias: String
    let initial: SignInConfig?
    let onSave: (SignInConfig?) -> Void
    @State private var command: String
    @State private var check: String
    @State private var hours: Double
    @Environment(\.barly) private var t

    public init(alias: String, config: SignInConfig?, onSave: @escaping (SignInConfig?) -> Void) {
        self.alias = alias
        initial = config
        self.onSave = onSave
        _command = State(initialValue: config?.command ?? "")
        _check = State(initialValue: config?.check ?? "")
        _hours = State(initialValue: config?.hours ?? 10)
    }

    public var body: some View {
        SheetFrame(title: L("\(alias) 的重新登录命令"), subtitle: L("有些主机登录后还要隔一阵重新认证一次（kinit 之类）。到期时 Switchboard 会弹窗问你命令问的东西。"), width: 560) {
            VStack(alignment: .leading, spacing: 14) {
                FieldRow(label: L("命令"), note: L("在主机的登录 shell 里、带终端运行，比如 kinit。")) { input($command, "kinit") }
                FieldRow(label: L("检查命令"), note: L("可选。退出码为 0 表示还有效，比如 klist -s；每 5 分钟跑一次。")) { input($check, "klist -s") }
                if check.trimmingCharacters(in: .whitespaces).isEmpty {
                    FieldRow(label: L("间隔")) {
                        Stepper(value: $hours, in: 1...72) { Text(verbatim: L("每 \(Int(hours)) 小时")).barlyText(.product.small, color: t.text2) }
                    }
                }
            }
        } buttons: {
            if initial != nil { BarlyButton(L("移除"), variant: .ghost) { onSave(nil) } }
            Spacer()
            BarlyButton(L("取消"), variant: .ghost) { onSave(initial) }.keyboardShortcut(.cancelAction)
            BarlyButton(L("保存"), variant: .primary) {
                let c = command.trimmingCharacters(in: .whitespaces)
                onSave(c.isEmpty ? nil : SignInConfig(command: c, check: check.trimmingCharacters(in: .whitespaces).isEmpty ? nil : check,
                                                      hours: hours, lastSignIn: initial?.lastSignIn))
            }
            .keyboardShortcut(.defaultAction)
        }
    }

    private func input(_ text: Binding<String>, _ placeholder: String) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 13, design: .monospaced))
            .padding(.horizontal, 10)
            .frame(height: BarlyScale.pt(30))
            .background(t.fieldBg, in: RoundedRectangle(cornerRadius: BarlyRadius.sm))
            .overlay(RoundedRectangle(cornerRadius: BarlyRadius.sm).stroke(t.borderStrong))
    }
}
