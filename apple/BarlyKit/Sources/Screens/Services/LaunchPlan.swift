import Foundation

/// 起一个 CLI 时跑哪条命令行、加哪些环境变量。新建、接着跑、分叉、搬文件夹、断线重连都算这一份（原来 5 处各拼一遍）。
/// 纯计算：Switchboard 自己加的报状态扩展（会写文件）由调用方读好交进来
enum LaunchPlan {
    /// 本机：保存的启动命令（没保存就用默认可执行文件）+ Switchboard 加的参数（Codex 的标题、omp 的报状态扩展）+ arguments，
    /// 带报状态的环境变量。
    /// 主机上：主机的默认可执行文件（保存的命令是这台 Mac 的；按主机保存命令还没做）+ Codex 的标题参数 + arguments；
    /// 本机的报状态扩展在主机上没有，不加。
    /// filter 只作用在 arguments 前面那部分：去掉跳过权限确认的参数时不碰提示词
    static func command(for cli: CLIKind, remote: Bool, savedCommand: String?,
                        additions: (arguments: [String], environment: [String: String])?,
                        filter: ([String]) -> [String] = { $0 }, arguments: [String]) -> (command: [String], environment: [String: String]) {
        let codexTitle = cli == .codex ? ActivityMonitor.codexTitleArguments : []
        if remote { return (filter([cli.executable] + codexTitle) + arguments, [:]) }
        let base = savedCommand.map(CommandLineSplitter.split) ?? [cli.executable]
        let extra = cli == .codex ? codexTitle : additions?.arguments ?? []
        return (filter(base + extra) + arguments, additions?.environment ?? [:])
    }
}

@MainActor
extension WorkspaceStore {
    /// 一个 CLI 标签要启动的进程：本机包一层 tmux（同名会话再开直接接上），主机上 ssh 过去用主机的 tmux。
    /// nil = 本机找不到这个 CLI
    func cliLaunch(tabID: UUID, cli: CLIKind, hostID: String, directory: String, tmuxName: String,
                   arguments: [String], filter: ([String]) -> [String] = { $0 }) -> TerminalLaunch? {
        let remote = hostID != Host.localID
        let plan = LaunchPlan.command(for: cli, remote: remote, savedCommand: remote ? nil : savedCommand(for: cli),
                                      additions: remote ? nil : LiveReporting.launchAdditions(for: cli), filter: filter, arguments: arguments)
        var launch = remote
            ? TerminalLaunch.remote(tabID: tabID, alias: hostID, command: plan.command, directory: directory, tmuxName: tmuxName)
            : TerminalLaunch.cli(tabID: tabID, command: plan.command, directory: directory, tmuxName: tmuxName, environment: plan.environment,
                                 tools: data.tools)
        launch?.cli = cli
        launch?.projectPath = directory
        return launch
    }
}
