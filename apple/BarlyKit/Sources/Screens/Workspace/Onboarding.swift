import SwiftUI
import BarlyKit

/// 侧栏底部的小贴士：每次打开随机一条，→ 换一条，× 本次不再显示；右键可以永久关掉
struct TipCard: View {
    let text: String
    let onClose: () -> Void
    @Environment(\.barly) private var t

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb").font(.system(size: 11)).foregroundStyle(t.text3).padding(.top, 1)
            VStack(alignment: .leading, spacing: 4) {
                MonoLabel("TIP", color: t.text4)
                Text(text).barlyText(.product.caption, color: t.text2).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            VStack(spacing: 2) {
                PaneIcon(symbol: "xmark", help: L("这次不再显示"), action: onClose).scaleEffect(0.8)
                PaneIcon(symbol: "arrow.right", help: L("换一条")).scaleEffect(0.8)
            }
        }
        .padding(.leading, 12).padding(.trailing, 4).padding(.vertical, 8)
        .overlay(alignment: .top) { Hairline() }
    }
}

/// 首启引导：把窗口压暗，只把讲到的那块挖亮，旁边一张说明卡（第几步 · 一句标题 · 一句说明 · 跳过 / 下一步）
struct TourOverlay: View {
    let step: Int
    @Environment(\.barly) private var t

    private struct Step {
        let spot: CGRect
        let card: CGPoint
        let title: String
        let body: String
    }

    private var steps: [Step] {
        [
            Step(spot: CGRect(x: 6, y: 92, width: 276, height: 878), card: CGPoint(x: 310, y: 150),
                 title: L("你所有的 AI 会话都在这里"),
                 body: L("按机器、再按项目文件夹分好。单击先读对话，不启动 CLI；双击就在原来的目录里接着跑。")),
            Step(spot: CGRect(x: 238, y: 6, width: 44, height: 40), card: CGPoint(x: 310, y: 40),
                 title: L("从这里开一个新会话"),
                 body: L("选 Claude Code、Codex、OpenCode 或 omp，再选项目文件夹。也可以按 ⌘N。")),
            Step(spot: CGRect(x: 6, y: 976, width: 160, height: 40), card: CGPoint(x: 190, y: 840),
                 title: L("服务器上的会话也能管"),
                 body: L("添加一台 SSH 主机，它的会话会列在这台 Mac 下面，同样可以读、接着跑、删除。")),
        ]
    }

    var body: some View {
        let s = steps[max(0, min(step - 1, steps.count - 1))]
        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.55)
                .mask {
                    Rectangle()
                        .overlay(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: BarlyRadius.md)
                                .frame(width: s.spot.width, height: s.spot.height)
                                .offset(x: s.spot.minX, y: s.spot.minY)
                                .blendMode(.destinationOut)
                        }
                        .compositingGroup()
                }
            RoundedRectangle(cornerRadius: BarlyRadius.md)
                .stroke(t.accent, lineWidth: 1.5)
                .frame(width: s.spot.width, height: s.spot.height)
                .offset(x: s.spot.minX, y: s.spot.minY)
            card(s).offset(x: s.card.x, y: s.card.y)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func card(_ s: Step) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MonoLabel("STEP \(step) / \(steps.count)", color: t.text4)
            Text(s.title).barlyText(.product.sectionTitle, color: t.text)
            Text(s.body).barlyText(.product.small, color: t.text2).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    ForEach(1...steps.count, id: \.self) { i in
                        Capsule().fill(i == step ? t.text : t.fill3).frame(width: i == step ? 14 : 5, height: 5)
                    }
                }
                Spacer()
                BarlyButton(L("跳过"), variant: .ghost, size: .sm)
                BarlyButton(step == steps.count ? L("开始用") : L("下一步"), variant: .outline, size: .sm)
            }
            .padding(.top, 4)
        }
        .padding(16)
        .frame(width: 320)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: BarlyRadius.md))
        .overlay(RoundedRectangle(cornerRadius: BarlyRadius.md).stroke(t.borderStrong))
        .shadow(color: .black.opacity(0.5), radius: 24, y: 10)
    }
}
