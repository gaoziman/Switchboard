import SwiftUI
import BarlyKit
import BarlyExamples

/// 产品屏登记处（barly-snap 的截图入口）。id 以 mac- 开头，截图文件名就是 `<id>-light.png` / `<id>-dark.png`。
/// 和 design/brief.md 的屏幕清单一一对应。App 入口优先展示 `macos.first`（工作区）。
@MainActor
public enum ProductScreens {
    private static func workspace(_ state: String) -> some View {
        WorkspaceView(store: .fixture(state))
    }

    private static let missingDraft = NewSessionDraft(folder: "~/code/agent-board-v2")

    public static let all: [ExampleScreen] = [
        // 第 1 批：工作区全部状态 · 对话预览 · 新会话 · 关闭标签
        ExampleScreen(id: "mac-workspace", title: "工作区 · 终端标签", platform: .macos) { AnyView(workspace("default")) },
        ExampleScreen(id: "mac-workspace-empty", title: "工作区 · 首次（空）", platform: .macos) { AnyView(workspace("empty")) },
        ExampleScreen(id: "mac-workspace-loading", title: "工作区 · 加载", platform: .macos) { AnyView(workspace("loading")) },
        ExampleScreen(id: "mac-workspace-error", title: "工作区 · 出错", platform: .macos) { AnyView(workspace("error")) },
        ExampleScreen(id: "mac-workspace-search-empty", title: "工作区 · 搜索无结果", platform: .macos) { AnyView(workspace("search-empty")) },
        ExampleScreen(id: "mac-workspace-long", title: "工作区 · 超长", platform: .macos) { AnyView(workspace("long")) },
        ExampleScreen(id: "mac-preview", title: "对话预览", platform: .macos) { AnyView(workspace("preview")) },
        ExampleScreen(id: "mac-preview-missing", title: "对话预览 · 文件夹已不在", platform: .macos) { AnyView(workspace("preview-missing")) },
        ExampleScreen(id: "mac-new-session", title: "新会话", platform: .macos) {
            AnyView(SheetOverlay { workspace("default") } sheet: {
                NewSessionSheet(draft: NewSessionDraft(folder: "~/code/relay-gateway"))
            })
        },
        ExampleScreen(id: "mac-new-session-edit", title: "新会话 · 编辑启动命令（校验失败）", platform: .macos) {
            AnyView(SheetOverlay { workspace("default") } sheet: {
                NewSessionSheet(draft: NewSessionDraft(target: .cli(.codex), folder: "~/code/relay-gateway",
                                                       editingCommand: "codex --dangerously-bypass-approvals-and-sandbox; echo done"),
                                fixture: .invalidCommand)
            })
        },
        ExampleScreen(id: "mac-new-session-missing", title: "新会话 · 文件夹不存在", platform: .macos) {
            AnyView(SheetOverlay { workspace("default") } sheet: {
                NewSessionSheet(draft: missingDraft, fixture: .missingFolder)
            })
        },
        ExampleScreen(id: "mac-close-tab", title: "关闭标签确认", platform: .macos) {
            AnyView(SheetOverlay { workspace("default") } sheet: {
                CloseTabDialog(tabTitle: "上架 haiku-5-5 并核对两档计费")
            })
        },
        // 第 2 批：分屏 · 已打开视图 · 铃铛 · 添加 SSH 主机 · Connect…
        ExampleScreen(id: "mac-split", title: "分屏", platform: .macos) { AnyView(workspace("split")) },
        ExampleScreen(id: "mac-split-choose", title: "分屏 · 选右边的标签", platform: .macos) { AnyView(workspace("split-choose")) },
        ExampleScreen(id: "mac-open-tabs", title: "侧栏 · 已打开", platform: .macos) { AnyView(workspace("open-tabs")) },
        ExampleScreen(id: "mac-open-tabs-select", title: "侧栏 · 已打开 · 多选", platform: .macos) { AnyView(workspace("open-tabs-select")) },
        ExampleScreen(id: "mac-bell", title: "铃铛 · 等待你的会话", platform: .macos) { AnyView(workspace("bell")) },
        // 第 3 批：终端横条 · 删除进度 · 主机体检 · 端口转发 · 独立阅读窗口
        ExampleScreen(id: "mac-terminal-ended", title: "终端 · CLI 已退出", platform: .macos) { AnyView(workspace("ended")) },
        ExampleScreen(id: "mac-terminal-failed", title: "终端 · 启动出错", platform: .macos) { AnyView(workspace("failed")) },
        ExampleScreen(id: "mac-terminal-reconnecting", title: "终端 · 断线重连", platform: .macos) { AnyView(workspace("reconnecting")) },
        ExampleScreen(id: "mac-deleting", title: "批量删除进度", platform: .macos) { AnyView(workspace("deleting")) },
        ExampleScreen(id: "mac-delete-result", title: "删除结果 · 部分失败", platform: .macos) {
            AnyView(SheetOverlay { workspace("default") } sheet: { DeletionResultSheet() })
        },
        ExampleScreen(id: "mac-port-forward", title: "端口转发", platform: .macos) {
            AnyView(SheetOverlay { workspace("default") } sheet: { PortForwardSheet() })
        },
        ExampleScreen(id: "mac-port-forward-busy", title: "端口转发 · 本机端口被占用", platform: .macos) {
            AnyView(SheetOverlay { workspace("default") } sheet: { PortForwardSheet(busy: true) })
        },
        ExampleScreen(id: "mac-reading-window", title: "独立阅读窗口 · 查找中", platform: .macos,
                      size: CGSize(width: 1100, height: 1024)) {
            AnyView(ReadingWindow(store: .fixture("default"), sessionID: "0c93aa51"))
        },
        // 第 4 批：首启引导 · 小贴士（设置窗口是系统原生，用 liveshot 真窗口截）
        ExampleScreen(id: "mac-tour-1", title: "首启引导 · 1 会话库", platform: .macos) { AnyView(workspace("tour1")) },
        ExampleScreen(id: "mac-tour-2", title: "首启引导 · 2 新会话", platform: .macos) { AnyView(workspace("tour2")) },
        ExampleScreen(id: "mac-tour-3", title: "首启引导 · 3 SSH 主机", platform: .macos) { AnyView(workspace("tour3")) },
        ExampleScreen(id: "mac-tip", title: "侧栏小贴士", platform: .macos) { AnyView(workspace("tip")) },
    ] + HostCheckSheet.Phase.allCases.map { phase in
        ExampleScreen(id: "mac-host-check-\(phase.rawValue)", title: "主机体检 · \(phase.rawValue)", platform: .macos) {
            AnyView(SheetOverlay { workspace("default") } sheet: { HostCheckSheet(phase: phase) })
        }
    } + AddHostSheet.Phase.allCases.map { phase in
        ExampleScreen(id: "mac-add-host-\(phase.rawValue)", title: "添加 SSH 主机 · \(phase.rawValue)", platform: .macos) {
            AnyView(SheetOverlay { workspace("default") } sheet: { AddHostSheet(phase: phase) })
        }
    } + ConnectSheet.Prompt.allCases.map { prompt in
        ExampleScreen(id: "mac-connect-\(prompt.rawValue)", title: "Connect… · \(prompt.rawValue)", platform: .macos) {
            AnyView(SheetOverlay { workspace("default") } sheet: { ConnectSheet(prompt: prompt) })
        }
    }
    public static var ios: [ExampleScreen] { all.filter { $0.platform == .ios } }
    public static var macos: [ExampleScreen] { all.filter { $0.platform == .macos } }
}
