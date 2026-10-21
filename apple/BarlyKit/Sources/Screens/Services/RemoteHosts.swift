import Foundation

/// SSH 主机：解析别名、添加前试连、rsync 镜像会话文件、远程启动命令。
/// 后台连接一律 BatchMode（不弹密码），要密码 / 验证码的主机先标成「需要连接」
public enum SSH {
    /// `ssh -G` 解析出来的实际连接目标
    public struct Target: Equatable, Sendable {
        public var user: String
        public var hostname: String
        public var port: String
        public var proxyJump: String?

        public var summary: String {
            var s = "\(user)@\(hostname):\(port)"
            if let proxyJump, proxyJump != "none" { s += L(" · 跳板 \(proxyJump)") }
            return s
        }
    }

    public enum ProbeResult: Equatable, Sendable {
        case ok(installed: [CLIKind], hasRsync: Bool, hasTmux: Bool)
        /// 要密码、验证码，或主机指纹没见过
        case needsConnect(String)
        case unreachable(String)
    }

    /// 输入框里粘贴的 `ssh devbox` 也认
    public static func normalize(_ input: String) -> String {
        var s = input.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("ssh ") { s = String(s.dropFirst(4)).trimmingCharacters(in: .whitespaces) }
        return s
    }

    /// `ssh -G <别名>`：不连接，只算出最终的用户、地址、端口、跳板
    public static func resolve(_ alias: String) -> Target? {
        guard let out = run(["/usr/bin/ssh", "-G", alias], timeout: 5)?.stdout else { return nil }
        var values: [String: String] = [:]
        for line in out.split(separator: "\n") {
            let parts = line.split(separator: " ", maxSplits: 1).map(String.init)
            if parts.count == 2, values[parts[0]] == nil { values[parts[0]] = parts[1] }
        }
        guard let host = values["hostname"] else { return nil }
        return Target(user: values["user"] ?? NSUserName(), hostname: host, port: values["port"] ?? "22", proxyJump: values["proxyjump"])
    }

    /// 连接复用的套接字（%C 是连接参数的哈希）。后台命令、Connect…、终端标签都用它：Connect… 登录一次，大家共用。
    /// Unix 套接字路径上限 104 字节，ssh 建的时候还要临时加 17 字节：macOS 的临时目录太长，只能放 /tmp。
    /// 但 /tmp 谁都能写，名字也算得出来，别的用户能抢先占位：放进 /tmp 下只有自己能进的目录，不行再退到 ~/.ssh
    public static let controlPath: String = {
        let dir = "/tmp/sb-\(getuid())"
        return isPrivateDirectory(dir) ? dir + "/%C" : NSHomeDirectory() + "/.ssh/sb-%C"
    }()

    /// 目录是自己的、0700、不是符号链接（没有就建一个）
    static func isPrivateDirectory(_ path: String) -> Bool {
        _ = mkdir(path, 0o700)
        var st = stat()
        guard lstat(path, &st) == 0 else { return false }
        return (st.st_mode & S_IFMT) == S_IFDIR && st.st_uid == getuid() && (st.st_mode & 0o077) == 0
    }

    /// 后台命令共用的 ssh 选项：不弹密码、连接超时、复用一条连接（Touch ID / 硬件密钥只按一次）
    static func options(_ alias: String) -> [String] {
        let control = controlPath
        return ["-o", "BatchMode=yes", "-o", "ConnectTimeout=10", "-o", "ServerAliveInterval=15",
                "-o", "ControlMaster=auto", "-o", "ControlPath=\(control)", "-o", "ControlPersist=60",
                "-o", "RemoteCommand=none", "-o", "RequestTTY=no", "-o", "ClearAllForwardings=yes"]
    }

    /// 添加前试连一次：登录、在登录 shell 里找 rsync / tmux / 四个 CLI
    public static func probe(_ alias: String) async -> ProbeResult {
        let script = #"exec "${SHELL:-/bin/sh}" -lc 'echo __SB_OK__; for c in rsync tmux claude codex opencode omp; do command -v "$c" >/dev/null 2>&1 && echo "has:$c"; done'"#
        return await offPool {
            guard let r = run(["/usr/bin/ssh"] + options(alias) + [alias, script], timeout: 25) else {
                return .unreachable(L("ssh 没有在 25 秒内返回。"))
            }
            if r.stdout.contains("__SB_OK__") {
                let has = Set(r.stdout.split(separator: "\n").compactMap { $0.hasPrefix("has:") ? String($0.dropFirst(4)) : nil })
                return .ok(installed: CLIKind.allCases.filter { has.contains($0.executable) },
                           hasRsync: has.contains("rsync"), hasTmux: has.contains("tmux"))
            }
            let err = r.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if err.contains("Permission denied") || err.contains("Host key verification failed") || err.contains("keyboard-interactive") {
                return .needsConnect(err)
            }
            return .unreachable(err.isEmpty ? L("ssh 退出码 \(r.status)") : String(err.suffix(400)))
        }
    }

    /// 本机缓存：~/Library/Caches/design.barly.switchboard/hosts/<别名>/
    public static func cacheDirectory(_ alias: String) -> URL {
        let safe = alias.replacingOccurrences(of: "/", with: "_")
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("design.barly.switchboard/hosts/\(safe)", isDirectory: true)
    }

    /// 镜像不要符号链接：主机能放一个指向这台 Mac 别处的链接，读会话、删会话都会顺着它走出镜像
    static let mirrorFlags = ["-a", "--no-links", "-m", "--delete"]

    /// 以前镜像下来的符号链接（--delete 不清跳过的链接）：删链接本身，指向的东西不动
    static func removeSymlinks(in root: URL) {
        guard let items = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isSymbolicLinkKey]) else { return }
        for case let url as URL in items where (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// 把主机上的会话文件镜像到本机（只读主机，只拉 .jsonl，跳过子代理）。progress(已完成步骤, 总步骤)
    public static func mirror(_ alias: String, progress: @escaping @Sendable (Int, Int) -> Void) async -> String? {
        await offPool {
            let root = cacheDirectory(alias)
            let ssh = (["/usr/bin/ssh"] + options(alias)).map(Tmux.shellQuote).joined(separator: " ")
            let filters = ["--exclude=subagents/", "--include=*/", "--include=*.jsonl", "--exclude=*"]
            let jobs: [(String, String, [String])] = [
                (".claude/projects/", "claude/projects/", filters),
                (".codex/sessions/", "codex/sessions/", filters),
                (".codex/session_index.jsonl", "codex/session_index.jsonl", []),
                // omp：每个项目一层目录，只要里面的 .jsonl（扩展放在更深目录里的东西不拉）
                (".omp/agent/sessions/", "omp/sessions/", ["--include=/*/", "--include=/*/*.jsonl", "--exclude=*"]),
            ]
            var firstError: String?
            for (i, job) in jobs.enumerated() {
                let dest = root.appendingPathComponent(job.1)
                try? FileManager.default.createDirectory(at: job.1.hasSuffix("/") ? dest : dest.deletingLastPathComponent(),
                                                         withIntermediateDirectories: true)
                let args = ["/usr/bin/rsync"] + mirrorFlags + ["-e", ssh] + job.2 + ["\(alias):\(job.0)", dest.path]
                if let r = run(args, timeout: 600), r.status != 0, !r.stderr.contains("No such file") {
                    firstError = firstError ?? String(r.stderr.trimmingCharacters(in: .whitespacesAndNewlines).suffix(300))
                }
                progress(i + 1, jobs.count + 1)
            }
            removeSymlinks(in: root)
            if let error = mirrorOpenCode(alias, ssh: ssh, into: root.appendingPathComponent("opencode")) { firstError = firstError ?? error }
            progress(jobs.count + 1, jobs.count + 1)
            return firstError
        }
    }

    /// OpenCode 的库里还有它的账号和凭据，不整个拷：在主机上用 python3 建一个只有会话、消息、片段的快照，
    /// 拷快照，再删掉主机上的快照。主机上没有 OpenCode 的库就什么都不做。做法参考 JustSessions
    static func mirrorOpenCode(_ alias: String, ssh: String, into dir: URL) -> String? {
        let script = OpenCodeSnapshot.shell
        guard let r = run(["/usr/bin/ssh"] + options(alias) + [alias, "exec \"${SHELL:-/bin/sh}\" -lc " + Tmux.shellQuote(script)], timeout: 120) else {
            return L("主机上建 OpenCode 快照超时。")
        }
        if r.status == OpenCodeSnapshot.noDatabase {
            try? FileManager.default.removeItem(at: dir)      // 主机上没有（或删了）OpenCode：镜像里也清掉
            return nil
        }
        guard r.status == 0, let path = OpenCodeSnapshot.path(in: r.stdout) else {
            let err = r.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return err.contains("python3") ? L("主机上没有 python3，列不出 OpenCode 会话。") : String(err.suffix(300))
        }
        defer { _ = run(["/usr/bin/ssh"] + options(alias) + [alias, "rm -rf " + Tmux.shellQuote(path)], timeout: 20) }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let args = ["/usr/bin/rsync", "-a", "--no-links", "--ignore-times", "-e", ssh, "\(alias):\(path)/opencode.db", dir.appendingPathComponent("opencode.db").path]
        if let c = run(args, timeout: 600), c.status != 0 { return String(c.stderr.trimmingCharacters(in: .whitespacesAndNewlines).suffix(300)) }
        return nil
    }

    /// 在终端标签里远程接着跑：ssh -t 过去，进项目目录，用主机自己的 tmux（没有就直接跑）
    public static func launch(alias: String, directory: String, command: [String], tmuxName: String?) -> (String, [String]) {
        let cli = command.map(Tmux.shellQuote).joined(separator: " ")
        let cd = "cd " + remoteDirectory(directory)
        let inner: String
        if let tmuxName {
            // 主机的 tmux 把 CLI 设的标题透传出来（Codex 在标题里报状态），关掉状态栏
            let tmuxCmd = "tmux new-session -A -s \(Tmux.shellQuote(tmuxName)) \(Tmux.shellQuote(cli))"
                + " \\; set-option status off \\; set-option set-titles on \\; set-option set-titles-string '#{pane_title}'"
            inner = "\(cd) && if command -v tmux >/dev/null 2>&1; then \(tmuxCmd); else \(cli); fi"
        } else {
            inner = "\(cd) && exec \"${SHELL:-/bin/sh}\" -l"
        }
        let remote = "SWITCHBOARD=1 exec \"${SHELL:-/bin/sh}\" -lc \(Tmux.shellQuote(inner))"
        // 有 Connect… 登好的连接就复用（不再问密码）；没有就在这个标签的终端里正常登录
        return ("/usr/bin/ssh", ["-t", "-o", "RemoteCommand=none", "-o", "ServerAliveInterval=15", "-o", "ServerAliveCountMax=3",
                                 "-o", "ControlMaster=auto", "-o", "ControlPath=\(controlPath)", "-o", "ControlPersist=60",
                                 alias, remote])
    }

    /// 主机上的目录：`~/x` 要让主机的 shell 展开成它自己的家目录，其余原样加引号
    static func remoteDirectory(_ path: String) -> String {
        if path == "~" { return "\"$HOME\"" }
        if path.hasPrefix("~/") { return "\"$HOME\"/" + Tmux.shellQuote(String(path.dropFirst(2))) }
        return Tmux.shellQuote(path)
    }

    /// 结束主机 tmux 里的一个会话（全名精确匹配）
    static func killTmuxCommand(_ name: String) -> String { "tmux kill-session -t " + Tmux.shellQuote(Tmux.target(name)) }

    /// 只有 `~` 和 `~/…` 要问主机；`~别人` 不猜
    static func needsHome(_ path: String) -> Bool { path == "~" || path.hasPrefix("~/") }

    /// 会话文件里记的是绝对路径：会话库里的主机文件夹也要存成绝对路径才对得上
    static func expandingHome(_ path: String, home: String) -> String {
        guard needsHome(path) else { return path }
        let joined = (home as NSString).appendingPathComponent(String(path.dropFirst(1)))
        return joined.count > 1 && joined.hasSuffix("/") ? String(joined.dropLast()) : joined
    }

    /// 主机的家目录（登录 shell 的 rc 文件可能也往 stdout 打东西：只认带标记的那行）
    static func home(_ alias: String) -> String? {
        guard let r = run(["/usr/bin/ssh"] + options(alias) + [alias, #"printf '__SB_HOME__%s\n' "$HOME""#], timeout: 15),
              r.status == 0 else { return nil }
        return parseHome(r.stdout)
    }

    static func parseHome(_ out: String) -> String? {
        let marker = "__SB_HOME__"
        guard let line = out.split(separator: "\n").last(where: { $0.hasPrefix(marker) }) else { return nil }
        let home = String(line.dropFirst(marker.count)).trimmingCharacters(in: .whitespaces)
        return home.hasPrefix("/") ? home : nil
    }

    // MARK: 进程

    /// 阻塞着等 ssh / rsync 的活放到 GCD 线程上，不占 Swift 并发的线程池：
    /// 池子只有 CPU 核数那么多线程，被等网络（最长几分钟）的占满，会话扫描、索引这些 async 工作都会停下来
    static func offPool<T: Sendable>(_ work: @escaping @Sendable () -> T) async -> T {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async { continuation.resume(returning: work()) }
        }
    }

    struct Output { let status: Int32; let stdout: String; let stderr: String }

    static func run(_ argv: [String], timeout: TimeInterval) -> Output? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: argv[0])
        p.arguments = Array(argv.dropFirst())
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = ShellEnvironment.shared.pathString
        p.environment = env
        let out = Pipe(), err = Pipe()
        p.standardOutput = out
        p.standardError = err
        p.standardInput = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return nil }
        // 边跑边读，输出大也不会把管道塞满卡死
        var outData = Data(), errData = Data()
        let group = DispatchGroup()
        group.enter(); DispatchQueue.global().async { outData = out.fileHandleForReading.readDataToEndOfFile(); group.leave() }
        group.enter(); DispatchQueue.global().async { errData = err.fileHandleForReading.readDataToEndOfFile(); group.leave() }
        let deadline = Date().addingTimeInterval(timeout)
        while p.isRunning && Date() < deadline { usleep(50_000) }
        if p.isRunning { p.terminate(); _ = group.wait(timeout: .now() + 2); return nil }
        _ = group.wait(timeout: .now() + 5)
        return Output(status: p.terminationStatus, stdout: String(decoding: outData, as: UTF8.self),
                      stderr: String(decoding: errData, as: UTF8.self))
    }
}
