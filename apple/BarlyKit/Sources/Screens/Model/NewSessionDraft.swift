import Foundation

/// 新会话 sheet 的草稿与校验。规则写在这里而不是视图里，方便单测。
public struct NewSessionDraft: Equatable, Sendable {
    public enum Target: Hashable, Sendable {
        case cli(CLIKind)
        /// 登录 shell，不是会话，不走 tmux
        case terminal
    }

    public var hostID: String
    public var target: Target
    public var folder: String
    /// 用户保存过的启动命令；nil = 用默认命令
    public var savedCommand: String?
    /// 正在编辑的命令；nil = 锁定状态
    public var editingCommand: String?

    public init(hostID: String = Host.localID, target: Target = .cli(.claude), folder: String = "",
                savedCommand: String? = nil, editingCommand: String? = nil) {
        self.hostID = hostID
        self.target = target
        self.folder = folder
        self.savedCommand = savedCommand
        self.editingCommand = editingCommand
    }

    public var isEditingCommand: Bool { editingCommand != nil }

    /// 实际会跑的命令
    public var effectiveCommand: String {
        switch target {
        case .terminal: "$SHELL -l"
        case .cli(let cli): savedCommand ?? cli.defaultCommand
        }
    }

    /// 启动命令的问题；nil = 可以保存
    public static func commandProblem(_ command: String) -> String? {
        let trimmed = command.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return nil }  // 空 = 回到默认命令
        var quote: Character?
        for ch in trimmed {
            if let q = quote {
                if ch == q { quote = nil }
            } else if ch == "\"" || ch == "'" {
                quote = ch
            } else if [";", "|", "&", "#", "`"].contains(ch) {
                return L("启动命令里不能有 shell 运算符「\(ch)」，要组合多条命令请写成脚本再填脚本路径。")
            }
        }
        if quote != nil { return L("引号没有闭合。") }
        return nil
    }

    /// 开始会话前的问题；nil = 可以开始
    public func startProblem(folderExists: Bool) -> String? {
        if isEditingCommand { return L("先保存或取消启动命令的修改。") }
        if folder.trimmingCharacters(in: .whitespaces).isEmpty { return L("选一个项目文件夹。") }
        if !folderExists { return L("这台主机上没有这个文件夹。") }
        return nil
    }
}

/// 把启动命令拆成参数：支持单双引号、`~`；不支持运算符（校验时已经拦了）
public enum CommandLineSplitter {
    public static func split(_ command: String) -> [String] {
        var args: [String] = []
        var current = ""
        var quote: Character?
        var inToken = false
        for ch in command {
            if let q = quote {
                if ch == q { quote = nil } else { current.append(ch) }
            } else if ch == "\"" || ch == "'" {
                quote = ch
                inToken = true
            } else if ch == " " || ch == "\t" {
                if inToken { args.append(current); current = ""; inToken = false }
            } else {
                current.append(ch)
                inToken = true
            }
        }
        if inToken { args.append(current) }
        return args.map { $0.hasPrefix("~/") ? NSHomeDirectory() + $0.dropFirst(1) : $0 }
    }
}
