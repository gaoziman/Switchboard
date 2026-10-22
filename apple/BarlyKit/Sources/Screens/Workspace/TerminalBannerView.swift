import SwiftUI
import BarlyKit

/// 终端上方的横条：CLI 退出后标签不关，留着它打印的东西，横条说清怎么结束的、下一步做什么。
/// 出错（启动 30 秒内非 0 退出）时主按钮是「检查启动命令」，断线时是「立即重连」
struct TerminalBannerView: View {
    let banner: TerminalBanner
    let cli: CLIKind?
    var onResume: () -> Void = {}
    var onClose: () -> Void = {}
    @Environment(\.barly) private var t

    var body: some View {
        HStack(spacing: 10) {
            icon
            VStack(alignment: .leading, spacing: 2) {
                Text(title).barlyText(.product.small.weight(500), color: t.text)
                Text(detail).barlyText(.product.caption, color: t.text3).lineLimit(1)
            }
            Spacer(minLength: 12)
            buttons
        }
        .padding(.horizontal, 16)
        .frame(height: BarlyScale.pt(52))
        .background(tint.opacity(0.07))
        .overlay(alignment: .leading) { Rectangle().fill(tint).frame(width: 2) }
        .overlay(alignment: .bottom) { Hairline() }
    }

    private var tint: Color {
        switch banner {
        case .exited: t.text3
        case .failed: t.danger
        case .reconnecting: t.warning
        }
    }

    @ViewBuilder private var icon: some View {
        switch banner {
        case .exited:
            ActivityLamp(.ended, size: 8)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: BarlyScale.pt(12))).foregroundStyle(t.danger)
        case .reconnecting:
            ActivityLamp(.working, size: 8)
        }
    }

    private var name: String { cli?.title ?? "Shell" }

    private var title: String {
        switch banner {
        case .exited(let code): L("\(name) 已退出 · 退出码 \(code)")
        case .failed(let code, _): L("\(name) 启动后马上退出了 · Exited (\(code))")
        case .reconnecting(let attempt, _): attempt == 0 ? L("和主机的连接断了，自动重连已经停了") : L("和主机的连接断了，正在重连…")
        }
    }

    private var detail: String {
        switch banner {
        case .exited: L("上面是它最后打印的内容。接着跑会在这个标签里重新启动它。")
        case .failed(_, let hint): L("\(hint) · 多半是启动命令写错了，或者 PATH 里找不到它")
        case .reconnecting(let attempt, let nextIn):
            attempt == 0 ? L("试了 15 分钟没连上。CLI 多半还在主机的 tmux 里，网络好了点「立即重连」接回去")
                : L("CLI 还在主机的 tmux 里跑 · 第 \(attempt) 次 · \(nextIn) 秒后再试，Mac 唤醒或回到 app 时也会马上试")
        }
    }

    @ViewBuilder private var buttons: some View {
        HStack(spacing: 8) {
            switch banner {
            case .exited:
                BarlyButton(L("关闭标签"), variant: .ghost, size: .sm, action: onClose)
                BarlyButton(L("接着跑"), icon: "play.fill", variant: .outline, size: .sm, action: onResume)
            case .failed:
                BarlyButton(L("关闭标签"), variant: .ghost, size: .sm, action: onClose)
                BarlyButton(L("再跑一次"), variant: .ghost, size: .sm, action: onResume)
                BarlyButton(L("检查启动命令…"), variant: .outline, size: .sm)
            case .reconnecting:
                BarlyButton(L("检查主机…"), variant: .ghost, size: .sm)
                BarlyButton(L("立即重连"), icon: "arrow.clockwise", variant: .outline, size: .sm, action: onResume)
            }
        }
    }
}

/// 侧栏底部的批量删除进度：「正在删除 37 / 140…」+ 细进度条 + 取消；结束时有失败就换成结果条
struct DeletionBar: View {
    let progress: DeletionProgress
    var onCancel: () -> Void = {}
    @Environment(\.barly) private var t

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ActivityLamp(.working, size: 7)
                Text("正在删除 \(progress.done) / \(progress.total)…").barlyText(.product.small, color: t.text)
                    .monospacedDigit()
                Spacer()
                BarlyButton(progress.cancelling ? L("正在停止…") : L("取消"), variant: .ghost, size: .sm, action: onCancel)
                    .disabled(progress.cancelling)
            }
            ProgressBar(progress.fraction, height: 3, color: t.text2)
            if progress.failed > 0 {
                Text("\(progress.failed) 个没删掉，结束后会说明原因").barlyText(.product.caption, color: t.text3)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .sidebarCard()
    }
}

/// 删除结束、有一部分没删掉：说清删了多少、哪台主机出了什么问题、能不能重试
public struct DeletionResultSheet: View {
    @Environment(\.barly) private var t
    public init() {}

    public var body: some View {
        SheetFrame(title: L("删了 132 个会话，8 个没删"), width: 500) {
            VStack(alignment: .leading, spacing: 12) {
                Text("没删的都在 devbox 上：删除到一半时连接断了（Mac 合盖睡眠后常见）。它们还留在列表里，没有被改动。")
                    .barlyText(.product.small, color: t.text2)
                    .fixedSize(horizontal: false, vertical: true)
                Problem(title: L("devbox · 8 个会话"), detail: L("连上 VPN 或在主机标题上点 Connect… 之后可以重试，只会重试这 8 个。"),
                        output: "client_loop: send disconnect: Broken pipe")
            }
        } buttons: {
            Spacer()
            BarlyButton(L("好"), variant: .ghost)
            BarlyButton(L("再试一次"), icon: "arrow.clockwise", variant: .outline)
        }
    }
}
