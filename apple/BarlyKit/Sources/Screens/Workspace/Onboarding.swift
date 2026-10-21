import SwiftUI
import BarlyKit

/// 侧栏底部的小贴士：每次打开随机一条，→ 换一条，× 本次不再显示；右键可以永久关掉
struct TipCard: View {
    let text: String
    let onClose: () -> Void
    var onNext: () -> Void = {}
    @Environment(\.barly) private var t

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lightbulb").font(.system(size: BarlyScale.pt(11))).foregroundStyle(t.text3).padding(.top, 1)
            VStack(alignment: .leading, spacing: 4) {
                MonoLabel("TIP", color: t.text4)
                Text(text).barlyText(.product.caption, color: t.text2).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            VStack(spacing: 2) {
                PaneIcon(symbol: "xmark", help: L("这次不再显示"), action: onClose).scaleEffect(0.8)
                PaneIcon(symbol: "arrow.right", help: L("换一条"), action: onNext).scaleEffect(0.8)
            }
        }
        .padding(.leading, 12).padding(.trailing, 4).padding(.vertical, 8)
        .overlay(alignment: .top) { Hairline() }
    }
}

/// 首启引导讲到的那几块：视图上打 `.tourAnchor(…)`，引导层按它们真实的位置挖亮（界面缩放、窗口大小、侧栏收起都对得上）
enum TourSpot: Hashable { case library, newSession, addHost }

struct TourAnchorKey: PreferenceKey {
    static let defaultValue: [TourSpot: Anchor<CGRect>] = [:]
    static func reduce(value: inout [TourSpot: Anchor<CGRect>], nextValue: () -> [TourSpot: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    func tourAnchor(_ spot: TourSpot) -> some View {
        anchorPreference(key: TourAnchorKey.self, value: .bounds) { [spot: $0] }
    }
}

/// 说明卡放哪：讲到的那块右边、和它顶端错开一点；右边放不下放左边；上下不出窗口。那块不在界面上就放窗口中间
enum TourLayout {
    static let gap: CGFloat = 28
    static let margin: CGFloat = 16

    static func cardOrigin(spot: CGRect?, card: CGSize, in window: CGSize) -> CGPoint {
        guard let spot else { return CGPoint(x: (window.width - card.width) / 2, y: (window.height - card.height) / 2) }
        let right = spot.maxX + gap
        let x = right + card.width <= window.width - margin ? right : max(margin, spot.minX - gap - card.width)
        let y = min(max(margin, spot.minY + 58), window.height - card.height - margin)
        return CGPoint(x: x, y: y)
    }
}

/// 首启引导：把窗口压暗，只把讲到的那块挖亮，旁边一张说明卡（第几步 · 一句标题 · 一句说明 · 跳过 / 下一步）
struct TourOverlay: View {
    let step: Int
    /// 讲到的那几块在这个视图坐标里的位置（WorkspaceView 用 overlayPreferenceValue 交进来）
    let spots: [TourSpot: CGRect]
    var onNext: () -> Void = {}
    var onSkip: () -> Void = {}
    @Environment(\.barly) private var t
    @State private var cardSize = CGSize(width: 320, height: 180)

    private struct Step {
        let spot: TourSpot
        let title: String
        let body: String
    }

    private static let steps = [
        Step(spot: .library, title: L("你所有的 AI 会话都在这里"),
             body: L("按机器、再按项目文件夹分好。单击先读对话，不启动 CLI；双击就在原来的目录里接着跑。")),
        Step(spot: .newSession, title: L("从这里开一个新会话"),
             body: L("选 Claude Code、Codex、OpenCode 或 omp，再选项目文件夹。也可以按 ⌘N。")),
        Step(spot: .addHost, title: L("服务器上的会话也能管"),
             body: L("添加一台 SSH 主机，它的会话会列在这台 Mac 下面，同样可以读、接着跑、删除。")),
    ]

    var body: some View {
        GeometryReader { geo in overlay(geo.size) }
    }

    private func overlay(_ size: CGSize) -> some View {
        let all = Self.steps
        let s = all[max(0, min(step - 1, all.count - 1))]
        // 挖亮的框比那块大一圈
        let spot = spots[s.spot].map { $0.insetBy(dx: -4, dy: -4) }
        let origin = TourLayout.cardOrigin(spot: spot, card: cardSize, in: size)
        return ZStack(alignment: .topLeading) {
            Color.black.opacity(0.55)
                .mask {
                    Rectangle()
                        .overlay(alignment: .topLeading) {
                            if let spot {
                                RoundedRectangle(cornerRadius: BarlyRadius.md)
                                    .frame(width: spot.width, height: spot.height)
                                    .offset(x: spot.minX, y: spot.minY)
                                    .blendMode(.destinationOut)
                            }
                        }
                        .compositingGroup()
                }
            if let spot {
                RoundedRectangle(cornerRadius: BarlyRadius.md)
                    .stroke(t.accent, lineWidth: 1.5)
                    .frame(width: spot.width, height: spot.height)
                    .offset(x: spot.minX, y: spot.minY)
            }
            card(s, count: all.count)
                .onGeometryChange(for: CGSize.self) { $0.size } action: { cardSize = $0 }
                .offset(x: origin.x, y: origin.y)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    private func card(_ s: Step, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MonoLabel("STEP \(step) / \(count)", color: t.text4)
            Text(s.title).barlyText(.product.sectionTitle, color: t.text)
            Text(s.body).barlyText(.product.small, color: t.text2).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    ForEach(1...count, id: \.self) { i in
                        Capsule().fill(i == step ? t.text : t.fill3).frame(width: i == step ? 14 : 5, height: 5)
                    }
                }
                Spacer()
                BarlyButton(L("跳过"), variant: .ghost, size: .sm, action: onSkip).keyboardShortcut(.cancelAction)
                BarlyButton(step == count ? L("开始用") : L("下一步"), variant: .outline, size: .sm, action: onNext).keyboardShortcut(.defaultAction)
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
