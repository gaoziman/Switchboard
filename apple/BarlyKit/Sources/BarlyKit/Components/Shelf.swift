import SwiftUI

// Mac 原生质感层（references/mac-native.md）+ 拖放货架形态（--mac-form shelf）。
// 货架参考 Dropover 5.x（macos-native-app/library/dropover、vibe-coding/_re/dropover）：约 180pt 见方的毛玻璃小窗，
// 左上 ✕、右上 ⌄ 两个圆钮，中间叠放的文件缩略图，底部「4 Items ›」计数胶囊；拖入时外圈亮强调色描边。

// MARK: - 系统材质

/// Mac 工具形态（菜单栏弹窗 / 浮动面板 / 货架）的底：系统毛玻璃 + 1px 内描边 + 窗口阴影由 NSPanel 给。
/// ImageRenderer 画不出系统材质，快照模式（barlySnapshot）退成接近的实色，截图才有底。
public struct BarlyGlass: ViewModifier {
    let radius: CGFloat
    @Environment(\.barly) private var t
    @Environment(\.barlySnapshot) private var snapshot
    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background {
                if snapshot {
                    shape.fill(t.isDark ? Color(hex: 0x2A2B2F).opacity(0.96) : Color(hex: 0xF6F6F8).opacity(0.97))
                } else {
                    shape.fill(.regularMaterial)
                }
            }
            .overlay(shape.strokeBorder(t.isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.08), lineWidth: 1))
            .clipShape(shape)
    }
}

public extension View {
    /// `.barlyGlass(18)`：工具形态的毛玻璃底（见 BarlyGlass）
    func barlyGlass(_ radius: CGFloat = 16) -> some View { modifier(BarlyGlass(radius: radius)) }
}

// MARK: - 货架

/// 货架里的一个文件（截图 / 预览用的轻量模型；App 里由 ShelfController 按真实 URL 生成）
public struct ShelfFile: Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let kind: String          // SF Symbol：doc.text / photo / film / folder / doc.zipper …
    public let detail: String        // 「2.4 MB · PDF」
    public let tone: Int             // 缩略图底色（多色分类图标块 tile1…6）
    public init(_ name: String, kind: String, detail: String, tone: Int = 1, id: String? = nil) {
        self.id = id ?? name; self.name = name; self.kind = kind; self.detail = detail; self.tone = tone
    }
}

/// 叠放的文件缩略图：最多露 3 张，后面的逐张偏移、旋转、缩小（Dropover 的一摞）。
public struct ShelfStack: View {
    let files: [ShelfFile]
    let size: CGFloat
    @Environment(\.barly) private var t
    public init(_ files: [ShelfFile], size: CGFloat = 92) { self.files = files; self.size = size }
    public var body: some View {
        ZStack {
            ForEach(Array(files.prefix(3).enumerated().reversed()), id: \.offset) { i, f in
                thumb(f)
                    .rotationEffect(.degrees(Double(i) * (i % 2 == 0 ? 6 : -6)))
                    .offset(x: CGFloat(i) * 6, y: CGFloat(i) * -4)
                    .scaleEffect(1 - CGFloat(i) * 0.06)
            }
        }
        .frame(width: size + 24, height: size + 12)
    }
    private func thumb(_ f: ShelfFile) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(LinearGradient(colors: [t.tile(f.tone).barlyMix(.white, 0.25), t.tile(f.tone)], startPoint: .top, endPoint: .bottom))
            .overlay(BarlyIcon(f.kind, size: size * 0.36, color: .white))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.white.opacity(0.35), lineWidth: 1))
            .frame(width: size, height: size * 0.82)
            .shadow(color: .black.opacity(0.22), radius: 6, y: 3)
    }
}

/// 拖放货架（--mac-form shelf）：毛玻璃小窗。状态：
/// - 空：虚线拖入区 +「拖到这里」
/// - 有文件：叠放缩略图 + 底部计数胶囊「4 个文件 ›」
/// - dropTarget：拖着文件悬停时外圈 2px 强调色描边（唯一用强调色的地方）
/// - expanded：展开成列表（缩略图 + 名称 + 大小 · 类型，行可拖走），宽 300
public struct ShelfView: View {
    let files: [ShelfFile]
    let dropTarget: Bool
    let expanded: Bool
    let onClose: () -> Void
    let onToggle: () -> Void
    let dragOverlay: AnyView?
    let onDragFile: ((ShelfFile) -> NSItemProvider)?
    @Environment(\.barly) private var t
    /// dragOverlay：叠在缩略图那一摞上的拖拽源（App 里放多文件 NSDraggingSession）；onDragFile：展开列表里单行拖走
    public init(files: [ShelfFile], dropTarget: Bool = false, expanded: Bool = false, onClose: @escaping () -> Void = {}, onToggle: @escaping () -> Void = {},
                dragOverlay: AnyView? = nil, onDragFile: ((ShelfFile) -> NSItemProvider)? = nil) {
        self.files = files; self.dropTarget = dropTarget; self.expanded = expanded; self.onClose = onClose; self.onToggle = onToggle
        self.dragOverlay = dragOverlay; self.onDragFile = onDragFile
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                circleButton("xmark", action: onClose)
                Spacer()
                if expanded { Text("\(files.count) 个文件").barlyText(.product.small.weight(500), color: t.text) ; Spacer() }
                circleButton(expanded ? "chevron.up" : "chevron.down", action: onToggle)
            }
            .padding(10)
            if expanded { list } else { stack }
        }
        .frame(width: expanded ? 300 : 184)
        .barlyGlass(18)
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(dropTarget ? t.accent : .clear, lineWidth: 2))
    }

    private func circleButton(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            BarlyIcon(icon, size: 10, color: t.text2)
                .frame(width: 22, height: 22)
                .background(Circle().fill(t.isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.06)))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var stack: some View {
        if files.isEmpty {
            VStack(spacing: 8) {
                BarlyIcon("tray.and.arrow.down", size: 26, color: dropTarget ? t.accent : t.text3)
                Text(dropTarget ? "松手放进货架" : "拖到这里").barlyText(.product.small, color: dropTarget ? t.text : t.text3)
            }
            .frame(width: 150, height: 118)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [4, 4])).foregroundStyle(dropTarget ? t.accent : t.text4))
            .padding(.bottom, 14)
        } else {
            ShelfStack(files).overlay { dragOverlay }.padding(.top, 2)
            HStack(spacing: 4) {
                Text("\(files.count) 个文件").barlyText(.product.small.weight(500), color: t.text)
                BarlyIcon("chevron.right", size: 9, color: t.text2)
            }
            .padding(.horizontal, 10).frame(height: 24)
            .background(Capsule().fill(t.isDark ? Color.white.opacity(0.1) : Color.black.opacity(0.06)))
            .padding(.top, 8).padding(.bottom, 14)
        }
    }

    private var list: some View {
        VStack(spacing: 2) {
            ForEach(files) { f in
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous).fill(t.tile(f.tone))
                        .overlay(BarlyIcon(f.kind, size: 13, color: .white)).frame(width: 30, height: 26)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(f.name).barlyText(.product.small.weight(500), color: t.text).lineLimit(1)
                        Text(f.detail).barlyText(.product.caption, color: t.text3)
                    }
                    Spacer(minLength: 4)
                    BarlyIcon("line.3.horizontal", size: 11, color: t.text4)
                }
                .padding(.horizontal, 8).frame(height: 40)
                .contentShape(Rectangle())
                .onDrag { onDragFile?(f) ?? NSItemProvider() }
            }
            HStack(spacing: 8) {
                Text("全部拖走").barlyText(.product.caption.weight(500), color: t.text2)
                Spacer()
                BarlyIcon("square.and.arrow.up", size: 12, color: t.text2)
                BarlyIcon("trash", size: 12, color: t.text2)
            }
            .padding(.horizontal, 10).padding(.top, 8).padding(.bottom, 12)
        }
        .padding(.horizontal, 6)
    }
}
