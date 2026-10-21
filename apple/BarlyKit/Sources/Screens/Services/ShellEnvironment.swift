import Foundation

/// 从访达 / Dock 打开的 app 只有 launchd 的极简 PATH，找不到 nvm、bun、Homebrew 装的 CLI。
/// 启动时读一次登录 shell 的 PATH（`$SHELL -lic`，3 秒超时），再补上常见安装目录
public final class ShellEnvironment: @unchecked Sendable {
    public static let shared = ShellEnvironment()

    public let shell: String
    public private(set) var path: [String]

    private init() {
        let env = ProcessInfo.processInfo.environment
        shell = env["SHELL"] ?? "/bin/zsh"
        let home = NSHomeDirectory()
        // fnm 的 multishell 目录是临时的（shell 结束就删），换成它的默认 Node 目录
        var dirs = (Self.loginShellPath(shell) ?? env["PATH"] ?? "").split(separator: ":").map(String.init)
            .filter { !$0.contains("/fnm_multishells/") }
        dirs += ["\(home)/.local/share/fnm/aliases/default/bin", "\(home)/.fnm/aliases/default/bin",
                 "\(home)/Library/Application Support/fnm/aliases/default/bin"]
        dirs += ["\(home)/.local/bin", "\(home)/.bun/bin", "\(home)/.claude/local", "/opt/homebrew/bin", "/usr/local/bin",
                 "/usr/bin", "/bin", "/usr/sbin", "/sbin"]
        var seen = Set<String>()
        path = dirs.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    public var pathString: String { path.joined(separator: ":") }

    /// 可执行文件的完整路径；nil = 找不到
    public func which(_ name: String) -> String? {
        if name.hasPrefix("/") { return FileManager.default.isExecutableFile(atPath: name) ? name : nil }
        return path.lazy.map { "\($0)/\(name)" }.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// 给终端里的进程用的环境变量
    public func processEnvironment(extra: [String: String] = [:]) -> [String] {
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = pathString
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"
        env["LANG"] = env["LANG"] ?? "zh_CN.UTF-8"
        env["SWITCHBOARD"] = "1"
        env.merge(extra) { _, new in new }
        return env.map { "\($0.key)=\($0.value)" }
    }

    private static func loginShellPath(_ shell: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-lic", "printf '__SBPATH__%s' \"$PATH\""]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        let deadline = Date().addingTimeInterval(3)
        while process.isRunning && Date() < deadline { usleep(20_000) }
        if process.isRunning { process.terminate(); return nil }
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard let range = out.range(of: "__SBPATH__") else { return nil }
        return String(out[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// tmux：优先用 app 包里静态编译的那个（Resources/Tmux/bin/tmux），独立 server `-L switchboard`、
/// 不读 ~/.tmux.conf，不碰你自己的 tmux 会话。没有就退回 PATH 里的 tmux；都没有就直接跑 CLI（关标签即结束）
public enum Tmux {
    public static let socket = "switchboard"

    public static var executable: String? {
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("Tmux/bin/tmux").path,
           FileManager.default.isExecutableFile(atPath: bundled) { return bundled }
        return ShellEnvironment.shared.which("tmux")
    }

    /// 打包的 terminfo 目录（tmux-256color 等），给 TERMINFO_DIRS 用
    static var terminfo: String? {
        Bundle.main.resourceURL?.appendingPathComponent("Tmux/share/terminfo").path
    }

    /// 会话在 tmux 里的名字：CLI + 会话 ID，同一个会话永远落在同一个 tmux 会话上
    public static func name(for cli: CLIKind, sessionID: String) -> String {
        "\(cli.rawValue)-\(sessionID.prefix(36))".replacingOccurrences(of: ".", with: "-").replacingOccurrences(of: ":", with: "-")
    }

    /// Switchboard 自己的 tmux 配置（只在 server 启动时读一次，不读 ~/.tmux.conf）：
    /// 关状态栏、去掉前缀键（每个键都给 CLI）、鼠标滚动、出错退出时保留输出、真彩色
    static var configFile: String {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Switchboard", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("tmux.conf")
        let conf = """
        set -g default-terminal "tmux-256color"
        set -ga terminal-overrides ",xterm-256color:Tc"
        set -g status off
        set -g prefix None
        unbind-key -a -T prefix
        set -g mouse on
        set -g history-limit 10000
        set -sg escape-time 0
        set -g extended-keys on
        set -g remain-on-exit failed
        set -g allow-passthrough on
        set -g set-titles on
        set -g set-titles-string "#{pane_title}"
        """
        if (try? String(contentsOf: file, encoding: .utf8)) != conf { try? conf.write(to: file, atomically: true, encoding: .utf8) }
        return file.path
    }

    /// `tmux -L switchboard -f <配置> new-session -A -s <名字> -c <目录> <命令>`：已经在跑就直接 attach（重新接上），否则新建
    /// environment 用 `-e` 交给这个会话：已经在跑的 tmux server 看不到客户端新加的环境变量
    public static func attachOrCreate(name: String, directory: String, command: [String],
                                      environment: [String: String] = [:]) -> (String, [String])? {
        guard let tmux = executable else { return nil }
        let shellCommand = command.map(shellQuote).joined(separator: " ")
        let env = environment.sorted { $0.key < $1.key }.flatMap { ["-e", "\($0.key)=\($0.value)"] }
        return (tmux, ["-L", socket, "-f", configFile, "new-session", "-A", "-s", name, "-c", directory] + env + [shellCommand])
    }

    /// -t 的会话名按全名精确匹配：不加 = 的话 tmux 找不到同名会话时会退回前缀和通配匹配，可能结束掉别的会话
    static func target(_ name: String) -> String { "=" + name }

    /// 这个 tmux 会话还在不在（标签关了、CLI 还在后台跑）
    public static func isRunning(_ name: String) -> Bool {
        run(["has-session", "-t", target(name)]) == 0
    }

    /// 结束会话（End session）
    public static func kill(_ name: String) {
        _ = run(["kill-session", "-t", target(name)])
    }

    nonisolated(unsafe) private static var runningCache: (at: Date, names: Set<String>)?

    /// 当前还在跑的 Switchboard tmux 会话名（每秒轮询会调，缓存 2 秒，别每次都起进程）
    public static func runningSessions(fresh: Bool = false) -> Set<String> {
        if !fresh, let c = runningCache, Date().timeIntervalSince(c.at) < 2 { return c.names }
        let names = listSessions()
        runningCache = (Date(), names)
        return names
    }

    private static func listSessions() -> Set<String> {
        guard let tmux = executable else { return [] }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tmux)
        p.arguments = ["-L", socket, "list-sessions", "-F", "#{session_name}"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return [] }
        p.waitUntilExit()
        let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return Set(out.split(separator: "\n").map(String.init))
    }

    @discardableResult
    static func run(_ args: [String]) -> Int32 {
        guard let tmux = executable else { return -1 }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tmux)
        p.arguments = ["-L", socket] + args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return -1 }
        p.waitUntilExit()
        return p.terminationStatus
    }

    static func shellQuote(_ s: String) -> String {
        // = 开头的词 zsh 会当成命令路径展开（=foo → foo 的路径），要加引号
        if !s.hasPrefix("="), s.range(of: #"^[A-Za-z0-9_@%+=:,./-]+$"#, options: .regularExpression) != nil { return s }
        return "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
