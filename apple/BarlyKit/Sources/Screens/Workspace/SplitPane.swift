import SwiftUI
import BarlyKit

/// 分屏：两个标签并排。每个窗格一圈细线框 + 角上的小工具条（标题 · 状态 · ×），
/// 中间是可拖的分隔条（双击互换），右边还没选时是「选一个标签」列表
public struct SplitPane: View {
    @Bindable var store: WorkspaceStore
    let split: SplitState
    /// 每一边放什么终端（app 里是真实终端，原型里是假画面）
    var terminal: (TerminalTab) -> AnyView
    @Environment(\.barly) private var t
    @State private var dragStartRatio: Double?

    public init(store: WorkspaceStore, split: SplitState, terminal: @escaping (TerminalTab) -> AnyView = { AnyView(TerminalPane(tab: $0)) }) {
        self.store = store
        self.split = split
        self.terminal = terminal
    }

    public var body: some View {
        GeometryReader { proxy in
            let usable = proxy.size.width - 16 - 12
            HStack(spacing: 0) {
                pane(for: split.left, focused: store.selectedTab?.id == split.left)
                    .frame(width: usable * split.ratio)
                Divider()
                    .gesture(DragGesture(minimumDistance: 1)
                        .onChanged { v in
                            let start = dragStartRatio ?? split.ratio
                            if dragStartRatio == nil { dragStartRatio = split.ratio }
                            var r = start + v.translation.width / max(usable, 1)
                            if abs(r - 0.5) < 0.02 { r = 0.5 }          // 靠近中间吸附到一半
                            store.split?.ratio = min(0.8, max(0.2, r))
                        }
                        .onEnded { _ in dragStartRatio = nil })
                    .onTapGesture(count: 2) { store.swapSplit() }
                Group {
                    if let right = split.right {
                        pane(for: right, focused: store.selectedTab?.id == right)
                    } else {
                        TabChooser(candidates: store.splitCandidates, groupFor: store.group(for:)) { store.fillSplit(with: $0) }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(8)
        }
        .background(t.canvas)
    }

    @ViewBuilder private func pane(for id: UUID, focused: Bool) -> some View {
        if let tab = store.tab(id) {
            VStack(spacing: 0) {
                PaneToolbar(tab: tab, tint: store.group(for: tab)?.tint ?? 0, focused: focused) { store.closeSplitSide(id) }
                terminal(tab)
            }
            .clipShape(RoundedRectangle(cornerRadius: BarlyRadius.md))
            .overlay(RoundedRectangle(cornerRadius: BarlyRadius.md)
                .stroke(focused ? t.borderStrong : t.hairline, lineWidth: 1))
            .contentShape(Rectangle())
            .onTapGesture { store.selection = .tab(id) }
        }
    }

    /// 分隔条：12pt 热区，中间一根 3×28 的把手
    private struct Divider: View {
        @Environment(\.barly) private var t
        @State private var hovered = false

        var body: some View {
            Rectangle().fill(.clear)
                .frame(width: 12)
                .overlay {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(hovered ? t.text3 : t.borderStrong)
                        .frame(width: BarlyScale.pt(3), height: BarlyScale.pt(28))
                }
                .onHover { hovered = $0 }
                .contentShape(Rectangle())
                .help("拖动调整宽度，双击左右互换")
        }
    }
}

/// 窗格角上的小工具条：组色细点 · 标题 · 状态 · 关闭
private struct PaneToolbar: View {
    let tab: TerminalTab
    let tint: Int
    let focused: Bool
    var onClose: () -> Void = {}
    @Environment(\.barly) private var t

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 1).fill(t.groupColor(tint)).frame(width: 3, height: 12)
            if case .session(_, let cli) = tab.kind { CLIMark(cli, size: 14) }
            Text(tab.title).barlyText(.product.caption.weight(focused ? 500 : 400), color: focused ? t.text : t.text3)
                .lineLimit(1)
            ActivityLamp(tab.activity, size: 6)
            Spacer(minLength: 8)
            PaneIcon(symbol: "xmark", help: L("这一边不分屏了（标签还开着）"), action: onClose)
                .scaleEffect(0.85)
        }
        .padding(.leading, 10).padding(.trailing, 4)
        .frame(height: BarlyScale.pt(30))
        .background(focused ? t.fill1 : t.bg)
        .overlay(alignment: .bottom) { Hairline() }
    }
}

/// 分屏右边的「选一个标签」：本窗口不在分屏里的其他标签，↑↓ + Return 选
private struct TabChooser: View {
    let candidates: [TerminalTab]
    let groupFor: (TerminalTab) -> TabGroup?
    let pick: (TerminalTab) -> Void
    @Environment(\.barly) private var t

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                MonoLabel("SPLIT VIEW", color: t.text4)
                Text("右边放哪个标签？").barlyText(.product.sectionTitle, color: t.text)
                Text("最近用过的在前。点一下，或用 ↑ ↓ 和 Return 选。").barlyText(.product.small, color: t.text3)
            }
            .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 14)
            Hairline()
            VStack(spacing: 1) {
                ForEach(Array(candidates.enumerated()), id: \.element.id) { index, tab in
                    let group = groupFor(tab)
                    HStack(spacing: 10) {
                        if case .session(_, let cli) = tab.kind {
                            CLIMark(cli)
                        } else {
                            Image(systemName: "terminal").font(.system(size: 10)).foregroundStyle(t.text3).frame(width: 16)
                        }
                        Text(tab.title).barlyText(.product.small.weight(index == 0 ? 500 : 400), color: index == 0 ? t.text : t.text2)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        if let group {
                            Text(group.name).barlyText(.product.caption, color: t.groupColor(group.tint))
                        }
                        ActivityLamp(tab.activity, size: 6)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: BarlyScale.pt(34))
                    .barlySelected(index == 0, radius: BarlyRadius.sm, idleBorder: .clear)
                    .contentShape(Rectangle())
                    .onTapGesture { pick(tab) }
                    .handCursor()
                }
            }
            .padding(8)
            Spacer()
            HStack(spacing: 14) {
                hint(["↑", "↓"], L("选择"))
                hint(["↩"], L("放到右边"))
                hint(["⌘", "W"], L("不分屏了"))
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(t.canvas)
        .clipShape(RoundedRectangle(cornerRadius: BarlyRadius.md))
        .overlay(RoundedRectangle(cornerRadius: BarlyRadius.md).stroke(t.borderStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
    }

    private func hint(_ keys: [String], _ text: String) -> some View {
        HStack(spacing: 6) {
            KeyCombo(keys)
            Text(text).barlyText(.product.caption, color: t.text3)
        }
    }
}
