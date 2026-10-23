import Foundation

/// 要启动什么：可执行文件 + 参数 + 目录
public struct TerminalLaunch: Equatable, Sendable {
    public let tabID: UUID
    public let executable: String
    public let arguments: [String]
    public let directory: String
    public var environment: [String: String] = [:]
    /// 在 tmux 里的会话名；nil = 不走 tmux（新会话认领到真实会话后会改名）
    public var tmuxName: String?
    /// 跑在哪台 SSH 主机上；nil = 这台 Mac
    public var remoteHost: String? = nil
    /// 哪个 CLI（普通终端 nil）：决定 ⇧Return、⌘V 贴图这些键位怎么翻译
    public var cli: CLIKind? = nil
    /// 项目目录：⌘-click 相对路径按它解析（远程时 directory 是本机家目录，这里是主机上的路径）
    public var projectPath: String? = nil

    /// SSH 主机上的 CLI：ssh -t 过去，用主机自己的 tmux
    public static func remote(tabID: UUID, alias: String, command: [String], directory: String, tmuxName: String) -> TerminalLaunch {
        let (exe, args) = SSH.launch(alias: alias, directory: directory, command: command, tmuxName: tmuxName)
        return TerminalLaunch(tabID: tabID, executable: exe, arguments: args, directory: NSHomeDirectory(),
                              tmuxName: tmuxName, remoteHost: alias)
    }

    /// 恢复 / 新建一个 CLI 会话：有 tmux 就包一层 tmux，同一个会话名再次打开会直接接上
    public static func cli(tabID: UUID, command: [String], directory: String, tmuxName: String,
                           environment: [String: String] = [:], tools: Toolbox = .live) -> TerminalLaunch? {
        if let (tmux, args) = Tmux.attachOrCreate(name: tmuxName, directory: directory, command: command, environment: environment,
                                                  tmux: tools.tmux()) {
            var env: [String: String] = environment
            if let terminfo = Tmux.terminfo { env["TERMINFO_DIRS"] = terminfo + ":/usr/share/terminfo" }
            return TerminalLaunch(tabID: tabID, executable: tmux, arguments: args, directory: directory,
                                  environment: env, tmuxName: tmuxName)
        }
        guard let exe = command.first.flatMap(tools.which) else { return nil }
        return TerminalLaunch(tabID: tabID, executable: exe, arguments: Array(command.dropFirst()), directory: directory,
                              environment: environment, tmuxName: nil)
    }

    /// 普通终端：登录 shell，不走 tmux
    public static func shell(tabID: UUID, directory: String) -> TerminalLaunch {
        let shell = ShellEnvironment.shared.shell
        return TerminalLaunch(tabID: tabID, executable: shell, arguments: ["-l"], directory: directory, tmuxName: nil)
    }
}

