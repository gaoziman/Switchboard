import Foundation

/// 主机体检：按后台命令的方式一步步查，只读、不改主机。问题在前、提醒在后，每条附主机原话和一条能在终端里复现的命令
public struct HostFinding: Identifiable, Hashable, Sendable {
    public enum Level: Int, Sendable { case problem = 0, warning = 1, ok = 2 }
    public var id: String { title }
    public let level: Level
    public let title: String
    public var detail: String?
    public var output: String?
    public var command: String?
}

public struct HostCheckStep: Identifiable, Hashable, Sendable {
    public enum Status: Sendable { case pending, running, done, failed }
    public var id: String { title }
    public let title: String
    public var status: Status = .pending
    public var seconds: Double?
}

@MainActor
@Observable
public final class HostCheck {
    public let alias: String
    public private(set) var steps: [HostCheckStep]
    public private(set) var findings: [HostFinding] = []
    public private(set) var running = false
    public private(set) var finishedAt: Date?

    public init(alias: String) {
        self.alias = alias
        steps = [L("登录（和后台刷新同一种方式）"), L("shell 启动脚本"), "rsync", "tmux"].map { HostCheckStep(title: $0) }
            + CLIKind.allCases.map { HostCheckStep(title: "\($0.title) --version") }
    }

    public var hasProblems: Bool { findings.contains { $0.level == .problem } }

    public func run() async {
        running = true
        findings = []
        for i in steps.indices { steps[i].status = .pending; steps[i].seconds = nil }
        defer { running = false; finishedAt = Date() }

        // 1. 登录
        guard let first = await step(0, "echo __SB_OK__") else {
            findings.append(HostFinding(level: .problem, title: L("登不上 \(alias)"), detail: L("ssh 没有在时限内返回：主机离线、VPN 没连、或网络不通。"),
                                        command: "ssh \(alias) true"))
            return
        }
        guard first.stdout.contains("__SB_OK__") else {
            let err = first.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            let needs = err.contains("Permission denied") || err.contains("Host key verification")
            findings.append(HostFinding(level: .problem, title: needs ? L("\(alias) 要密码、验证码或确认主机指纹") : L("登不上 \(alias)"),
                                        detail: needs ? L("在主机标题上点「连接…」登录一次。") : L("ssh 说了下面这些。"), output: err, command: "ssh \(alias) true"))
            return
        }
        // 2. 交互启动脚本：卡住或者起了别的程序（exec zsh、tmux）就提醒
        let interactive = await step(1, #"exec "${SHELL:-/bin/sh}" -lic 'echo __SB_OK__'"#, timeout: 10)
        if interactive?.stdout.contains("__SB_OK__") != true {
            findings.append(HostFinding(level: .warning, title: L("交互启动脚本会卡住或启动别的程序"),
                                        detail: L("Switchboard 用不读交互启动脚本的方式（$SHELL -lc）启动 CLI，不受影响；但写在 ~/.bashrc 交互判断后面的 PATH（比如 nvm）会找不到。把那一行改成只在你自己登录时执行。"),
                                        output: interactive.map { ($0.stdout + $0.stderr).suffix(300).description },
                                        command: #"if [[ $- == *i* ]] && [ -z "$SWITCHBOARD" ]; then exec zsh -l; fi"#))
        }
        // 3. rsync
        let rsync = await step(2, login("command -v rsync >/dev/null && rsync --version | head -1"))
        if rsync?.status != 0 || rsync?.stdout.isEmpty != false {
            findings.append(HostFinding(level: .problem, title: L("主机上没有 rsync"), detail: L("会话没法镜像过来。Debian / Ubuntu 装一下：sudo apt install rsync"),
                                        command: "ssh \(alias) 'command -v rsync'"))
        } else {
            findings.append(HostFinding(level: .ok, title: rsync!.stdout.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        // 4. tmux：版本、server 是否连得上
        let tmux = await step(3, login("command -v tmux >/dev/null || exit 3; tmux -V; tmux ls 2>&1 | head -3"))
        if tmux?.status == 3 {
            findings.append(HostFinding(level: .warning, title: L("主机上没有 tmux"), detail: L("连接断了或关掉标签，CLI 会跟着结束。装上 tmux，会话就能一直跑：sudo apt install tmux"),
                                        command: "ssh \(alias) 'tmux -V'"))
        } else if let out = tmux?.stdout, out.contains("protocol version mismatch") {
            findings.append(HostFinding(level: .problem, title: L("tmux 连不上正在跑的 tmux 服务器"),
                                        detail: L("升级 tmux 后旧服务器还在跑：它的会话还在，但打不开，新标签会马上报错。用启动它的那个 tmux 接上，或者结束这些会话后重开。"),
                                        output: out.trimmingCharacters(in: .whitespacesAndNewlines), command: "ssh \(alias) 'tmux ls'"))
        } else if let v = tmux?.stdout.split(separator: "\n").first {
            findings.append(HostFinding(level: .ok, title: String(v)))
        }
        // 5. 每个 CLI 的版本（10 秒）
        var found: [String] = []
        for (i, cli) in CLIKind.allCases.enumerated() {
            let r = await step(4 + i, login("command -v \(cli.executable) >/dev/null || exit 3; \(cli.executable) --version 2>&1 | head -1"), timeout: 12)
            if r?.status == 3 { continue }
            if let r, r.status == 0, !r.stdout.isEmpty {
                found.append("\(cli.title) \(r.stdout.trimmingCharacters(in: .whitespacesAndNewlines))")
            } else {
                findings.append(HostFinding(level: .problem, title: L("\(cli.title) 装了，但跑不起来"),
                                            detail: L("多半是它依赖的 node 不在登录 shell 的 PATH 里（nvm 写在 ~/.bashrc 交互判断后面）。这种情况下会话也启动不了。"),
                                            output: r.map { ($0.stdout + $0.stderr).trimmingCharacters(in: .whitespacesAndNewlines) },
                                            command: "ssh \(alias) '$SHELL -lc \"\(cli.executable) --version\"'"))
            }
        }
        findings.append(HostFinding(level: .ok, title: found.isEmpty ? L("没有找到 Claude Code、Codex、OpenCode、omp") : found.joined(separator: " · ")))
        // OpenCode 的会话要在主机上用 python3 做快照才能列出来
        if found.contains(where: { $0.hasPrefix(CLIKind.opencode.title) }) {
            let alias = self.alias
            let py = await Task.detached { SSH.run(["/usr/bin/ssh"] + SSH.options(alias) + [alias, "command -v python3"], timeout: 15) }.value
            if py?.status != 0 {
                findings.append(HostFinding(level: .warning, title: L("主机上没有 python3，列不出 OpenCode 会话"),
                                            detail: L("Switchboard 在主机上用 python3 给 OpenCode 的库做一份只含会话的快照再拷过来（不拷账号和凭据）。装上 python3 就行。"),
                                            command: "ssh \(alias) 'command -v python3'"))
            }
        }
        findings.sort { $0.level.rawValue < $1.level.rawValue }
    }

    /// 在主机的登录 shell（不读交互启动脚本）里跑
    private func login(_ cmd: String) -> String {
        #"exec "${SHELL:-/bin/sh}" -lc "# + Tmux.shellQuote(cmd)
    }

    private func step(_ i: Int, _ script: String, timeout: TimeInterval = 20) async -> SSH.Output? {
        steps[i].status = .running
        let start = Date()
        let alias = self.alias
        let r = await Task.detached { SSH.run(["/usr/bin/ssh"] + SSH.options(alias) + [alias, script], timeout: timeout) }.value
        steps[i].seconds = Date().timeIntervalSince(start)
        steps[i].status = r == nil ? .failed : .done
        return r
    }

    /// 「复制报告」：先写这台 Mac 的版本，再列发现
    public var report: String {
        let mac = ProcessInfo.processInfo.operatingSystemVersionString
        let ssh = SSH.run(["/usr/bin/ssh", "-V"], timeout: 5)?.stderr.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var lines = [L("Switchboard 主机体检：\(alias)"), "macOS \(mac) · \(ssh)", ""]
        for f in findings {
            let tag = f.level == .problem ? L("[问题]") : f.level == .warning ? L("[提醒]") : L("[正常]")
            lines.append("\(tag) \(f.title)")
            if let d = f.detail { lines.append("  \(d)") }
            if let o = f.output, !o.isEmpty { lines.append(L("  主机输出：\(o)")) }
            if let c = f.command { lines.append(L("  在终端里试：\(c)")) }
        }
        return lines.joined(separator: "\n")
    }
}
