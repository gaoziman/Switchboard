import Foundation
import Testing
@testable import Screens

/// 怎么起一个 CLI：本机 / 主机上 × 保存的启动命令 × Switchboard 自己加的参数和环境变量
@MainActor
@Suite("启动命令")
struct LaunchPlanTests {
    private let title = ActivityMonitor.codexTitleArguments
    private let omp = (arguments: ["-e", "/ext/omp.js"], environment: ["SB_REPORTS": "/reports"])

    @Test("本机：保存的启动命令 + 这次的参数；没保存就用默认可执行文件")
    func localSavedCommand() {
        let resume = CLIKind.claude.resumeArguments("s1")
        #expect(LaunchPlan.command(for: .claude, remote: false, savedCommand: nil, additions: nil, arguments: resume).command
                == ["claude", "--resume", "s1"])
        #expect(LaunchPlan.command(for: .claude, remote: false, savedCommand: #"claude --model "opus 5""#, additions: nil, arguments: resume).command
                == ["claude", "--model", "opus 5", "--resume", "s1"])
    }

    @Test("本机：Codex 加标题参数（报状态），omp / OpenCode 加报状态的扩展和环境变量")
    func localAdditions() {
        let codex = LaunchPlan.command(for: .codex, remote: false, savedCommand: nil, additions: nil, arguments: ["resume", "c1"])
        #expect(codex.command == ["codex"] + title + ["resume", "c1"])
        let o = LaunchPlan.command(for: .omp, remote: false, savedCommand: nil, additions: omp, arguments: ["--session", "o1"])
        #expect(o.command == ["omp", "-e", "/ext/omp.js", "--session", "o1"])
        #expect(o.environment == ["SB_REPORTS": "/reports"])
        let oc = LaunchPlan.command(for: .opencode, remote: false, savedCommand: nil, additions: ([], ["OPENCODE_TUI_CONFIG": "/tui.json"]), arguments: [])
        #expect(oc.command == ["opencode"] && oc.environment == ["OPENCODE_TUI_CONFIG": "/tui.json"])
    }

    @Test("主机上：用主机的默认可执行文件（保存的命令是这台 Mac 的），Codex 照样加标题参数，本机的扩展不加")
    func remote() {
        let claude = LaunchPlan.command(for: .claude, remote: true, savedCommand: "/usr/local/bin/claude --x", additions: nil, arguments: ["--resume", "s1"])
        #expect(claude.command == ["claude", "--resume", "s1"])
        #expect(LaunchPlan.command(for: .codex, remote: true, savedCommand: nil, additions: nil, arguments: []).command == ["codex"] + title)
        let o = LaunchPlan.command(for: .omp, remote: true, savedCommand: nil, additions: omp, arguments: [])
        #expect(o.command == ["omp"] && o.environment.isEmpty)
    }

    @Test("filter 只改启动命令那部分，不碰这次的参数（提示词里写着 --permission-mode 也原样交给 CLI）")
    func filterSkipsArguments() {
        let prompt = "别用 --permission-mode bypassPermissions"
        let plan = LaunchPlan.command(for: .claude, remote: false, savedCommand: "claude --dangerously-skip-permissions", additions: nil,
                                      filter: WorkspaceStore.withoutPermissionBypass, arguments: [prompt])
        #expect(plan.command == ["claude", prompt])
    }

    @Test("四个 CLI 接着跑、分叉的参数（写错了恢复会话会整个失效）")
    func resumeAndBranch() {
        let resume: [CLIKind: [String]] = [.claude: ["--resume", "x"], .codex: ["resume", "x"], .opencode: ["--session", "x"], .omp: ["--resume", "x"]]
        let branch: [CLIKind: [String]?] = [.claude: ["--resume", "x", "--fork-session"], .codex: ["fork", "x"], .opencode: ["--session", "x", "--fork"], .omp: nil]
        for cli in CLIKind.allCases {
            #expect(cli.resumeArguments("x") == resume[cli], "\(cli)")
            #expect(cli.branchArguments("x") == branch[cli] ?? nil, "\(cli)")
        }
    }
}
