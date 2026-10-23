import SwiftUI
import BarlyKit

/// 设置里的主题卡：缩小的工作区窗口（侧栏 · 标签 · 终端里的几行高亮），左上浅色、右下深色，一条斜线分开。
/// 颜色取这套主题的真实值（含你改过的颜色），终端那几行用它的终端配色；选中的描边用这套主题自己的强调色
public struct ThemePreviewCard: View {
    let theme: AppTheme
    var selected = false
    @Environment(\.colorScheme) private var scheme

    public init(theme: AppTheme, selected: Bool = false) {
        self.theme = theme
        self.selected = selected
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                MiniWindow(theme: theme, dark: false)
                MiniWindow(theme: theme, dark: true)
                    .mask(Path { p in
                        p.move(to: CGPoint(x: w * 0.58, y: 0))
                        p.addLine(to: CGPoint(x: w, y: 0))
                        p.addLine(to: CGPoint(x: w, y: h))
                        p.addLine(to: CGPoint(x: w * 0.36, y: h))
                        p.closeSubpath()
                    })
            }
        }
        .aspectRatio(1.6, contentMode: .fit)
        .clipShape(shape)
        .overlay(shape.strokeBorder(.black.opacity(0.14)))
        .padding(3)
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Color(hex: theme.spec(dark: scheme == .dark).accent), lineWidth: selected ? 2.5 : 0))
        .accessibilityHidden(true)
    }
}

private struct MiniWindow: View {
    let theme: AppTheme
    let dark: Bool

    var body: some View {
        let s = ThemeColors.apply(ThemeColors.changes(theme, dark: dark), to: theme.baseSpec(dark: dark), dark: dark)
        let ansi = TerminalColors.themed(theme, dark: dark, canvas: s.canvas, text: s.text).ansi
        // 红 绿 黄 蓝 品红
        let syntax = [ansi[1], ansi[2], ansi[3], ansi[4], ansi[5]]
        HStack(spacing: 0) {
            sidebar(s)
            code(s, syntax)
        }
        .background(Color(hex: s.sidebar))
    }

    private func bar(_ hex: UInt32, _ w: CGFloat) -> some View {
        Capsule().fill(Color(hex: hex)).frame(width: w, height: 3)
    }

    private func sidebar(_ s: AppTheme.Spec) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 3) {
                ForEach([0xFF5F57, 0xFEBC2E, 0x28C840] as [UInt32], id: \.self) { Circle().fill(Color(hex: $0)).frame(width: 5, height: 5) }
            }
            RoundedRectangle(cornerRadius: 2).fill(Color(hex: s.surface)).frame(height: 7)
            bar(s.text3, 20)
            row(s, selected: false, 24)
            row(s, selected: true, 26)
            row(s, selected: false, 18)
            row(s, selected: false, 22)
            Spacer(minLength: 0)
        }
        .padding(7)
        .frame(width: 66)
        .frame(maxHeight: .infinity)
    }

    private func row(_ s: AppTheme.Spec, selected: Bool, _ w: CGFloat) -> some View {
        HStack(spacing: 4) {
            Circle().fill(Color(hex: selected ? s.accent : s.text4)).frame(width: 3.5, height: 3.5)
            bar(selected ? s.text : s.text4, w)
        }
        .padding(.vertical, 2.5).padding(.horizontal, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: selected ? s.surface : s.sidebar), in: RoundedRectangle(cornerRadius: 2))
        .overlay(alignment: .leading) {
            if selected { Rectangle().fill(Color(hex: s.accent)).frame(width: 1.5, height: 7) }
        }
    }

    private func code(_ s: AppTheme.Spec, _ c: [UInt32]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                HStack(spacing: 3) { Circle().fill(Color(hex: s.accent)).frame(width: 3, height: 3); bar(s.text, 16) }
                    .padding(.horizontal, 5).frame(height: 10)
                    .background(Color(hex: s.surface), in: RoundedRectangle(cornerRadius: 2.5))
                bar(s.text4, 14).padding(.horizontal, 4)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6).padding(.top, 7).padding(.bottom, 6)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 4) { bar(c[3], 12); bar(s.text2, 40); bar(c[2], 26) }
                HStack(spacing: 4) { bar(s.text3, 8); bar(c[1], 32); bar(s.text2, 44) }
                HStack(spacing: 4) { bar(c[4], 20); bar(s.text2, 34); bar(c[0], 28) }
                HStack(spacing: 4) { bar(s.text3, 8); bar(c[0], 18); bar(c[3], 16); bar(s.text2, 42) }
                HStack(spacing: 4) { bar(s.text4, 52); bar(s.text4, 30) }
                HStack(spacing: 4) { bar(c[1], 18); bar(s.text2, 30); bar(c[4], 22) }
            }
            .padding(.horizontal, 9)
            Spacer(minLength: 0)
            HStack { Spacer(); Capsule().fill(Color(hex: s.accent)).frame(width: 24, height: 7) }.padding(7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: s.canvas), in: UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 4))
        .padding([.vertical, .trailing], 3)
    }
}

/// 截图用：设置里那一格主题卡，全部 18 套
struct ThemeCardsPreview: View {
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(200), spacing: 26), count: 5), spacing: 18) {
            ForEach(AppTheme.allCases) { item in
                VStack(spacing: 6) {
                    ThemePreviewCard(theme: item, selected: item == .switchboard)
                    Text(item.title).font(.callout)
                }
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(hex: 0xF2F2F4))
        .foregroundStyle(Color(hex: 0x1D1D1F))
    }
}
