import SwiftUI
import BarlyKit

// MARK: - 添加 SSH 主机

/// 添加主机：输入 ~/.ssh/config 别名或 user@host → 下方显示它解析成的账号和地址 →
/// 添加前先按后台命令的方式登录一次（预检）。登不上就说为什么，给「再试一次 / 仍然添加」；要密码或验证码就给 Connect…
public struct AddHostSheet: View {
    public enum Phase: String, CaseIterable { case typing, checking, unreachable, needsConnect }

    @State private var alias: String
    @State private var phase: Phase
    @State private var target: SSH.Target?
    @State private var error = ""
    @State private var checkStarted = Date()
    private let interactive: Bool
    var onCancel: () -> Void = {}
    var onAdd: (String, [CLIKind]) -> Void = { _, _ in }
    var onConnect: (String) -> Void = { _ in }
    @Environment(\.barly) private var t
    @Environment(\.barlySnapshot) private var snapshot

    /// 截图用：固定状态
    public init(alias: String = "devbox2", phase: Phase = .typing) {
        _alias = State(initialValue: alias)
        _phase = State(initialValue: phase)
        _target = State(initialValue: SSH.Target(user: "leo", hostname: "10.0.3.21", port: "22", proxyJump: "bastion"))
        interactive = false
    }

    /// app 里用
    public init(onCancel: @escaping () -> Void, onAdd: @escaping (String, [CLIKind]) -> Void,
                onConnect: @escaping (String) -> Void = { _ in }) {
        _alias = State(initialValue: "")
        _phase = State(initialValue: .typing)
        interactive = true
        self.onCancel = onCancel
        self.onAdd = onAdd
        self.onConnect = onConnect
    }

    private var normalized: String { SSH.normalize(alias) }

    public var body: some View {
        SheetFrame(title: L("添加 SSH 主机"), subtitle: L("主机上要有 rsync，以及你要跑的 CLI。会话会镜像到这台 Mac 的缓存里。"), width: 560) {
            VStack(alignment: .leading, spacing: 14) {
                FieldRow(label: L("主机")) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            BarlyBareField(placeholder: L("~/.ssh/config 里的别名，或 user@hostname"), text: $alias, style: .product.small.monospaced)
                        }
                        .padding(.horizontal, 10)
                        .frame(height: BarlyScale.pt(30))
                        .background(t.fieldBg, in: RoundedRectangle(cornerRadius: BarlyRadius.sm))
                        .overlay(RoundedRectangle(cornerRadius: BarlyRadius.sm)
                            .stroke(phase == .unreachable ? t.danger : phase == .typing ? t.text3 : t.borderStrong,
                                    lineWidth: phase == .typing ? 1.5 : 1))
                        if let target {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.turn.down.right").font(.system(size: BarlyScale.pt(9))).foregroundStyle(t.text4)
                                Text(verbatim: snapshot ? L("leo@10.0.3.21:22 · 经 ~/.ssh/config · 跳板 bastion") : target.summary)
                                    .barlyText(.product.caption.monospaced, color: t.text3)
                            }
                        }
                    }
                }
                switch phase {
                case .typing:
                    FieldRow(label: "") {
                        Text("填 ~/.ssh/config 里的别名，或 user@hostname。端口、密钥、跳板机这些写在 ~/.ssh/config 里。")
                            .barlyText(.product.caption, color: t.text3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                case .checking:
                    if interactive {
                        CheckSteps(steps: [(L("登录，并在登录 shell 里找 rsync、tmux 和 CLI"), .running,
                                            String(format: "%.0fs", Date().timeIntervalSince(checkStarted)))])
                    } else {
                        CheckSteps(steps: [
                            (L("登录"), .done, "0.4s"),
                            (L("读取 shell 启动脚本"), .done, "0.9s"),
                            (L("查找 rsync、tmux 和 CLI"), .running, "2.1s"),
                            (L("读取会话目录"), .pending, ""),
                        ])
                    }
                case .unreachable:
                    Problem(title: L("登不上 \(normalized)"),
                            detail: L("检查 ~/.ssh/config 里的 HostName，或者 VPN 有没有连上。主机只是暂时离线的话，可以「仍然添加」。"),
                            output: interactive ? error : "ssh: Could not resolve hostname devbox2.internal: nodename nor servname provided, or not known")
                case .needsConnect:
                    Problem(title: L("\(normalized) 要你输入密码或验证码"),
                            detail: L("后台刷新没法替你输入。点「Connect…」登录一次，之后刷新、标签、删除都走这一条登录，不会再问。"),
                            output: interactive ? error : "leo@10.0.3.21: Permission denied (publickey,keyboard-interactive).",
                            tone: .info)
                }
            }
        } buttons: {
            switch phase {
            case .typing:
                Spacer()
                BarlyButton(L("取消"), variant: .ghost, action: onCancel).keyboardShortcut(.cancelAction)
                BarlyButton(L("添加"), variant: .primary, action: check)
                    .keyboardShortcut(.defaultAction)
                    .disabled(normalized.isEmpty)
            case .checking:
                Text("正在按后台命令的方式登录一次…").barlyText(.product.caption, color: t.text3)
                Spacer()
                BarlyButton(L("取消"), variant: .ghost, action: onCancel)
                BarlyButton(L("添加"), variant: .primary).opacity(0.4)
            case .unreachable:
                BarlyButton(L("仍然添加"), variant: .ghost) { onAdd(normalized, []) }
                Spacer()
                BarlyButton(L("取消"), variant: .ghost, action: onCancel)
                BarlyButton(L("再试一次"), icon: "arrow.clockwise", variant: .outline, action: check)
            case .needsConnect:
                BarlyButton(L("仍然添加"), variant: .ghost) { onAdd(normalized, []) }
                Spacer()
                BarlyButton(L("取消"), variant: .ghost, action: onCancel)
                BarlyButton("Connect…", variant: .primary) { onConnect(normalized) }
            }
        }
        .onChange(of: alias) { _, _ in
            guard interactive else { return }
            if phase != .checking { phase = .typing }
            let a = normalized
            Task {
                try? await Task.sleep(for: .milliseconds(350))
                guard a == normalized, !a.isEmpty else { return }
                let resolved = await SSH.offPool { SSH.resolve(a) }
                if a == normalized { target = resolved }
            }
        }
    }

    private func check() {
        guard interactive, !normalized.isEmpty else { return }
        phase = .checking
        checkStarted = Date()
        let a = normalized
        Task {
            switch await SSH.probe(a) {
            case .ok(let installed, let hasRsync, _):
                if hasRsync {
                    onAdd(a, installed)
                } else {
                    error = L("主机上没有 rsync，会话没法镜像过来。装上 rsync 后再试（Debian / Ubuntu：sudo apt install rsync）。")
                    phase = .unreachable
                }
            case .needsConnect(let e):
                error = e
                phase = .needsConnect
            case .unreachable(let e):
                error = e
                phase = .unreachable
            }
        }
    }
}

/// 预检步骤：每步一行，完成 = 勾，进行中 = 弧 + 已用时，未开始 = 灰点
struct CheckSteps: View {
    enum Status { case done, running, pending, failed }
    let steps: [(String, Status, String)]
    @Environment(\.barly) private var t

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { _, step in
                HStack(spacing: 10) {
                    Group {
                        switch step.1 {
                        case .done: Image(systemName: "checkmark").font(.system(size: BarlyScale.pt(9), weight: .bold)).foregroundStyle(t.success)
                        case .running: ActivityLamp(.working, size: 7)
                        case .pending: Circle().fill(t.fill3).frame(width: 5, height: 5)
                        case .failed: Image(systemName: "xmark").font(.system(size: BarlyScale.pt(9), weight: .bold)).foregroundStyle(t.danger)
                        }
                    }
                    .frame(width: 14)
                    Text(step.0).barlyText(.product.small, color: step.1 == .pending ? t.text4 : t.text2)
                    Spacer()
                    Text(step.2).barlyText(.product.caption.monospaced, color: t.text4)
                }
                .frame(height: BarlyScale.pt(28))
                .padding(.horizontal, 10)
                .overlay(alignment: .bottom) { Hairline().opacity(0.6) }
            }
        }
        .overlay(RoundedRectangle(cornerRadius: BarlyRadius.sm).stroke(t.hairline))
    }
}

/// 出错 / 需要操作的说明：一句结论 + 怎么办 + ssh 原话（等宽）
struct Problem: View {
    enum Tone { case error, info }
    let title: String
    let detail: String
    let output: String
    var tone = Tone.error
    @Environment(\.barly) private var t

    var body: some View {
        let color = tone == .error ? t.danger : t.text2
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: tone == .error ? "exclamationmark.triangle.fill" : "key.horizontal")
                    .font(.system(size: BarlyScale.pt(11))).foregroundStyle(color)
                Text(title).barlyText(.product.small.weight(500), color: t.text)
            }
            Text(detail).barlyText(.product.small, color: t.text2).fixedSize(horizontal: false, vertical: true)
            Text(output)
                .barlyText(.product.caption.monospaced, color: t.text3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(t.bg, in: RoundedRectangle(cornerRadius: BarlyRadius.xs))
        }
        .padding(12)
        .overlay(alignment: .leading) { Rectangle().fill(tone == .error ? t.danger : t.borderStrong).frame(width: 2) }
        .background(tone == .error ? t.danger.opacity(0.07) : t.fill1)
    }
}

// MARK: - Connect…

/// 交互登录：把 ssh 问的每个问题搬进对话框。上面是 ssh 之前打印的内容（横幅、二次验证说明），
/// 下面一行是它停下来问的问题 + 输入框。新主机指纹单独一屏，核对后才信任
public struct ConnectSheet: View {
    public enum Prompt: String, CaseIterable { case password, otp, hostKey }

    let host: String
    let prompt: Prompt
    @Environment(\.barly) private var t

    public init(host: String = "jp-gpu", prompt: Prompt = .password) {
        self.host = host
        self.prompt = prompt
    }

    public var body: some View {
        SheetFrame(title: L("连接 \(host)"), subtitle: L("Switchboard 不保存你在这里输入的任何内容。"), width: 560) {
            VStack(alignment: .leading, spacing: 14) {
                transcript
                switch prompt {
                case .password:
                    question("leo@jp-gpu's password:", value: "••••••••••", note: nil)
                case .otp:
                    question("Verification code:", value: "", note: L("密码已通过。硬件密钥会把验证码直接打进这个框。"))
                case .hostKey:
                    hostKey
                }
            }
        } buttons: {
            Spacer()
            BarlyButton(L("取消"), variant: .ghost)
            switch prompt {
            case .password, .otp: BarlyButton(L("继续"), variant: .primary)
            case .hostKey: BarlyButton(L("信任并连接"), variant: .outline)
            }
        }
    }

    private var transcript: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(lines, id: \.self) { line in
                Text(line).barlyText(.product.caption.monospaced, color: t.text3)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.bg, in: RoundedRectangle(cornerRadius: BarlyRadius.sm))
        .overlay(RoundedRectangle(cornerRadius: BarlyRadius.sm).stroke(t.hairline))
    }

    private var lines: [String] {
        switch prompt {
        case .password: ["Authorized users only. All activity may be monitored.", "", "(leo@jp-gpu) keyboard-interactive"]
        case .otp: ["Authorized users only. All activity may be monitored.", "(leo@jp-gpu) Password: ********", "Duo two-factor login for leo", "Enter a passcode or select one of the following options:"]
        case .hostKey: ["The authenticity of host 'jp-gpu (203.0.113.42)' can't be established.", "ED25519 key fingerprint is shown below.", "This key is not known by any other names."]
        }
    }

    private func question(_ q: String, value: String, note: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(q).barlyText(.product.small.weight(500).monospaced, color: t.text)
            HStack {
                Text(value.isEmpty ? "▏" : value + "▏").barlyText(.product.small.monospaced, color: t.text)
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(height: BarlyScale.pt(32))
            .background(t.fieldBg, in: RoundedRectangle(cornerRadius: BarlyRadius.sm))
            .overlay(RoundedRectangle(cornerRadius: BarlyRadius.sm).stroke(t.text3, lineWidth: 1.5))
            if let note { Text(note).barlyText(.product.caption, color: t.text3) }
        }
    }

    private var hostKey: some View {
        VStack(alignment: .leading, spacing: 8) {
            MonoLabel("ED25519 FINGERPRINT", color: t.text4)
            Text("SHA256:9xQf3kLr+2bWm0vT8yHc4ZpN1sUe7aJdKoGi5RtXwBM")
                .barlyText(.product.small.weight(500).monospaced, color: t.text)
                .textSelection(.enabled)
            Text("这台 Mac 没见过这台主机的密钥。只有和主机管理员给你的指纹完全一致时才信任；不一致就取消，可能有人在中间冒充它。")
                .barlyText(.product.small, color: t.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .overlay(alignment: .leading) { Rectangle().fill(t.warning).frame(width: 2) }
        .background(t.warning.opacity(0.07))
    }
}

#if os(macOS)
/// app 里真正用的 Connect…：跟着 SSHConnect 的状态走
public struct LiveConnectSheet: View {
    @State private var session: SSHConnect
    @State private var input = ""
    @FocusState private var focused: Bool
    let onDone: (Bool) -> Void
    @Environment(\.barly) private var t

    public init(alias: String, command: String? = nil, onDone: @escaping (Bool) -> Void) {
        _session = State(initialValue: SSHConnect(alias: alias, command: command))
        self.onDone = onDone
    }

    public var body: some View {
        SheetFrame(title: session.command == nil ? L("连接 \(session.alias)") : L("在 \(session.alias) 上重新登录"),
                   subtitle: session.command.map { L("运行 \($0) · Switchboard 不保存你在这里输入的任何内容。") } ?? L("Switchboard 不保存你在这里输入的任何内容。"),
                   width: 560) {
            VStack(alignment: .leading, spacing: 14) {
                if !session.transcript.isEmpty {
                    ScrollView {
                        Text(session.transcript).barlyText(.product.caption.monospaced, color: t.text3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 140)
                    .padding(12)
                    .background(t.bg, in: RoundedRectangle(cornerRadius: BarlyRadius.sm))
                    .overlay(RoundedRectangle(cornerRadius: BarlyRadius.sm).stroke(t.hairline))
                }
                switch session.phase {
                case .starting:
                    HStack(spacing: 8) {
                        ActivityLamp(.working, size: 7)
                        Text("正在连接…").barlyText(.product.small, color: t.text2)
                    }
                case .asking(let question, let secret):
                    VStack(alignment: .leading, spacing: 6) {
                        Text(question).barlyText(.product.small.weight(500).monospaced, color: t.text)
                        Group {
                            if secret { SecureField("", text: $input) } else { TextField("", text: $input) }
                        }
                        .textFieldStyle(.plain)
                        .font(.system(size: BarlyScale.pt(13), design: .monospaced))
                        .focused($focused)
                        .onSubmit(send)
                        .padding(.horizontal, 10)
                        .frame(height: BarlyScale.pt(32))
                        .background(t.fieldBg, in: RoundedRectangle(cornerRadius: BarlyRadius.sm))
                        .overlay(RoundedRectangle(cornerRadius: BarlyRadius.sm).stroke(session.rejected ? t.danger : t.text3, lineWidth: 1.5))
                        if session.rejected {
                            Text("ssh 又问了一次：上一次的回答没被接受。").barlyText(.product.caption, color: t.danger)
                        }
                    }
                    .onAppear { focused = true }
                case .hostKey(let question):
                    VStack(alignment: .leading, spacing: 8) {
                        Text(question).barlyText(.product.small.weight(500), color: t.text)
                        Text("这台 Mac 没见过这台主机的密钥。只有和主机管理员给你的指纹（上面）完全一致时才信任；不一致就取消。")
                            .barlyText(.product.small, color: t.text2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .overlay(alignment: .leading) { Rectangle().fill(t.warning).frame(width: 2) }
                    .background(t.warning.opacity(0.07))
                case .connected:
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark").foregroundStyle(t.success)
                        Text(session.command == nil ? "已登录。刷新、删除、标签都会用这条连接，不会再问。" : "重新登录成功。")
                            .barlyText(.product.small, color: t.text2)
                    }
                case .failed(let reason):
                    Problem(title: L("没登上 \(session.alias)"), detail: L("看看下面 ssh 说了什么；改好之后再连一次。"), output: reason)
                }
            }
        } buttons: {
            Spacer()
            switch session.phase {
            case .asking:
                BarlyButton(L("取消"), variant: .ghost) { session.cancel(); onDone(false) }.keyboardShortcut(.cancelAction)
                BarlyButton(L("继续"), variant: .primary, action: send).keyboardShortcut(.defaultAction)
            case .hostKey:
                BarlyButton(L("取消"), variant: .ghost) { session.trustHostKey(false) }.keyboardShortcut(.cancelAction)
                BarlyButton(L("信任并连接"), variant: .outline) { session.trustHostKey(true) }
            case .connected:
                BarlyButton(L("好"), variant: .primary) { onDone(true) }.keyboardShortcut(.defaultAction)
            case .failed:
                BarlyButton(L("关闭"), variant: .ghost) { onDone(false) }.keyboardShortcut(.cancelAction)
            case .starting:
                BarlyButton(L("取消"), variant: .ghost) { session.cancel(); onDone(false) }.keyboardShortcut(.cancelAction)
            }
        }
        .onAppear { session.start() }
    }

    private func send() {
        session.answer(input)
        input = ""
    }
}
#endif
