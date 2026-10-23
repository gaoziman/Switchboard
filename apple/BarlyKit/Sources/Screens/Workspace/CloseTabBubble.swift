import SwiftUI
import BarlyKit

/// 标签在窗口里的位置：关标签的确认气泡挂在它下面，箭头对着它的 ×
struct TabAnchorKey: PreferenceKey {
    static let defaultValue: [UUID: Anchor<CGRect>] = [:]
    static func reduce(value: inout [UUID: Anchor<CGRect>], nextValue: () -> [UUID: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    func tabAnchor(_ id: UUID) -> some View {
        anchorPreference(key: TabAnchorKey.self, value: .bounds) { [id: $0] }
    }
}

/// 「关闭标签」确认（CLI 还在 tmux 里跑、这台主机没设关闭行为）：从标签下面冒出来的小气泡，不压暗窗口。
/// 回车 = 后台运行，Esc 或点气泡外面 = 取消。标签不在界面上（组收起、滚出去了）就挂在标签栏下面正中
struct CloseTabLayer: View {
    @Bindable var store: WorkspaceStore
    let tab: TerminalTab
    let anchors: [UUID: Anchor<CGRect>]

    var body: some View {
        GeometryReader { proxy in
            let width = BarlyScale.pt(CloseTabBubble.width)
            let place = Self.place(tab: anchors[tab.id].map { proxy[$0] }, bubbleWidth: width, in: proxy.size)
            ZStack(alignment: .topLeading) {
                // 点气泡外面：取消（这一下不传给下面的终端，和系统弹出框一样）
                Color.black.opacity(0.001)
                    .contentShape(Rectangle())
                    .onTapGesture { cancel() }
                CloseTabBubble(hostName: tab.hostID == Host.localID ? L("这台 Mac ") : " \(tab.hostID) ",
                               arrowX: place.arrowX,
                               onEnd: { remember in finish(keepRunning: false, remember: remember) },
                               onKeep: { remember in finish(keepRunning: true, remember: remember) },
                               onCancel: cancel)
                    .offset(x: place.x, y: place.y)
            }
        }
    }

    private func finish(keepRunning: Bool, remember: Bool) {
        if remember { WorkspaceStore.setCloseBehavior(keepRunning ? "keep" : "end", for: tab.hostID) }
        store.close(tab, keepRunning: keepRunning)
    }

    private func cancel() {
        store.presentation = nil
        TerminalRegistry.shared.focus(tab.id)
    }

    /// 气泡左上角和箭头位置：箭头对准 ×（标签右边内缩 17），气泡尽量往左摆、不出窗口；没有标签位置时箭头不画
    static func place(tab rect: CGRect?, bubbleWidth w: CGFloat, in size: CGSize) -> (x: CGFloat, y: CGFloat, arrowX: CGFloat?) {
        guard let rect else { return ((size.width - w) / 2, WorkspaceMetrics.tabBar + 8, nil) }
        let target = rect.maxX - 17
        let x = min(max(target - w + 30, 8), max(size.width - w - 8, 8))
        return (x, rect.maxY + 2, min(max(target - x, 14), w - 14))
    }
}

struct CloseTabBubble: View {
    static let width: CGFloat = 260
    let hostName: String
    /// 箭头尖离气泡左边多远；nil = 不画箭头
    var arrowX: CGFloat?
    var onEnd: (Bool) -> Void = { _ in }
    var onKeep: (Bool) -> Void = { _ in }
    var onCancel: () -> Void = {}
    @State private var remember = false
    /// 气泡出来就拿走键盘：回车、Esc 归它，不再打进下面的终端
    @FocusState private var focused: Bool
    @Environment(\.barly) private var t

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: BarlyRadius.md, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            Text("关闭标签").barlyText(.product.small.weight(600), color: t.text)
            Text("CLI 会在后台继续运行，之后点会话就能接上。")
                .barlyText(.product.caption, color: t.text3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
            HStack(spacing: 8) {
                BarlyButton(L("结束会话"), variant: .outlineDanger, size: .sm, fullWidth: true) { onEnd(remember) }
                BarlyButton(L("后台运行"), variant: .primary, size: .sm, fullWidth: true) { onKeep(remember) }
            }
            .focusEffectDisabled()
            .padding(.top, 12)
            HStack(spacing: 7) {
                Checkbox(remember)
                Text("不再询问").barlyText(.product.caption, color: t.text3)
            }
            .contentShape(Rectangle())
            .tapButton { remember.toggle() }
            .handCursor()
            .help(L("在\(hostName)上以后照这次的选择做，可以在设置里改回来"))
            .padding(.top, 10)
        }
        .padding(14)
        .frame(width: BarlyScale.pt(Self.width), alignment: .leading)
        .background(t.surface, in: shape)
        .overlay(shape.strokeBorder(t.borderStrong))
        .overlay(alignment: .topLeading) {
            if let arrowX {
                Arrow().fill(t.borderStrong)
                    .overlay(Arrow().fill(t.surface).padding(.top, 1.5).padding(.horizontal, 1.5).offset(y: 0.5))
                    .frame(width: 16, height: 8)
                    .offset(x: arrowX - 8, y: -7.5)
            }
        }
        .shadow(color: .black.opacity(0.45), radius: 24, y: 10)
        .focusable()
        .focusEffectDisabled()
        .focused($focused)
        .onAppear { focused = true }
        .onKeyPress(.return) { onKeep(remember); return .handled }
        .onKeyPress(.escape) { onCancel(); return .handled }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L("关闭标签"))
    }

    private struct Arrow: Shape {
        func path(in r: CGRect) -> Path {
            Path { p in
                p.move(to: CGPoint(x: r.midX, y: r.minY))
                p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
                p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
                p.closeSubpath()
            }
        }
    }
}
