#if os(macOS)
import Foundation
import Observation
import SwiftTerm

/// Connect…：在伪终端里跑 `ssh -f -N`（ControlMaster=yes、ControlPersist=yes），ssh 问什么就在对话框里问你。
/// 登录成功后 ssh 转到后台保持这条连接，之后的刷新、删除、标签都走 `/tmp/sb-%C` 复用它，不会再问。
/// Switchboard 不保存你输入的任何东西
@MainActor
@Observable
public final class SSHConnect {
    public enum Phase: Equatable {
        case starting
        /// ssh 停下来问一行（密码、口令、验证码）
        case asking(question: String, secret: Bool)
        /// 没见过的主机指纹
        case hostKey(question: String)
        case connected
        case failed(String)
    }

    public let alias: String
    /// nil = Connect…（只登录）；有值 = 在主机上跑这条重新登录命令（kinit 之类），问题照样搬进对话框
    public let command: String?
    public private(set) var phase = Phase.starting
    /// ssh 在问题前打印的东西（横幅、二次验证说明、指纹）
    public private(set) var transcript = ""
    /// 同一个问题又问了一次 = 上次的回答不对
    public private(set) var rejected = false

    @ObservationIgnored private var process: LocalProcess?
    @ObservationIgnored private var bridge: Bridge?
    @ObservationIgnored private var buffer = ""
    @ObservationIgnored private var lastQuestion: String?
    @ObservationIgnored public var onFinish: ((Bool) -> Void)?

    public init(alias: String, command: String? = nil) {
        self.alias = alias
        self.command = command
    }

    public func start() {
        let bridge = Bridge(owner: self)
        self.bridge = bridge
        let p = LocalProcess(delegate: bridge, dispatchQueue: .main)
        process = p
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = ShellEnvironment.shared.pathString
        let args: [String]
        if let command {
            // 带终端跑，命令会像在你手打时那样提问
            args = ["-tt", "-o", "ControlMaster=auto", "-o", "ControlPath=\(SSH.controlPath)", "-o", "ControlPersist=60",
                    "-o", "RemoteCommand=none", "-o", "ConnectTimeout=15", alias,
                    "exec \"${SHELL:-/bin/sh}\" -lc \(Tmux.shellQuote(command))"]
        } else {
            args = ["-f", "-N", "-o", "ControlMaster=yes", "-o", "ControlPath=\(SSH.controlPath)", "-o", "ControlPersist=yes",
                    "-o", "RemoteCommand=none", "-o", "RequestTTY=no", "-o", "ConnectTimeout=15",
                    "-o", "NumberOfPasswordPrompts=3", alias]
        }
        p.startProcess(executable: "/usr/bin/ssh", args: args, environment: env.map { "\($0.key)=\($0.value)" })
    }

    /// 回答当前问题（回车结尾）
    public func answer(_ text: String) {
        phase = .starting
        process?.send(data: Array((text + "\n").utf8)[...])
    }

    public func trustHostKey(_ trust: Bool) {
        answer(trust ? "yes" : "no")
    }

    public func cancel() {
        process?.terminate()
        onFinish?(false)
    }

    // MARK: 解析 ssh 的输出

    func received(_ bytes: ArraySlice<UInt8>) {
        buffer += String(decoding: bytes, as: UTF8.self).replacingOccurrences(of: "\r", with: "")
        // 最后一行没换行、以 : 或 ? 结尾 = ssh 停下来等输入
        let lastLine = buffer.split(separator: "\n", omittingEmptySubsequences: false).last.map(String.init) ?? ""
        let trimmed = lastLine.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasSuffix(":") || trimmed.hasSuffix("?") || trimmed.hasSuffix(")?") else { return }
        let before = String(buffer.dropLast(lastLine.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        if !before.isEmpty { transcript += (transcript.isEmpty ? "" : "\n") + before }
        buffer = ""
        rejected = trimmed == lastQuestion
        lastQuestion = trimmed
        if trimmed.contains("(yes/no") {
            phase = .hostKey(question: trimmed)
        } else {
            let lower = trimmed.lowercased()
            let secret = ["password", "passphrase", "pin", "code", "token", "otp", "密码"].contains { lower.contains($0) }
            phase = .asking(question: trimmed, secret: secret)
        }
    }

    func terminated(_ code: Int32?) {
        if code == 0 {
            phase = .connected
            onFinish?(true)
        } else {
            let tail = (transcript + "\n" + buffer).trimmingCharacters(in: .whitespacesAndNewlines)
            phase = .failed(tail.isEmpty ? L("ssh 退出码 \(code ?? -1)") : String(tail.suffix(400)))
        }
    }

    /// LocalProcess 的回调在主队列上
    private final class Bridge: LocalProcessDelegate {
        weak var owner: SSHConnect?
        init(owner: SSHConnect) { self.owner = owner }

        func processTerminated(_ source: LocalProcess, exitCode: Int32?) {
            MainActor.assumeIsolated { owner?.terminated(exitCode) }
        }

        func dataReceived(slice: ArraySlice<UInt8>) {
            MainActor.assumeIsolated { owner?.received(slice) }
        }

        func getWindowSize() -> winsize { winsize(ws_row: 24, ws_col: 120, ws_xpixel: 0, ws_ypixel: 0) }
    }
}
#endif
