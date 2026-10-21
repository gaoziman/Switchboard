import SwiftUI

// MARK: - 应用页面模式：设置（分组表单 + 危险区）与空状态
//
// 设置依据：meeting-booker Settings（Profile / Integrations / General 分段 + 头像上传 + 字段 + 主按钮）、hireflow 候选人表单（Delete 危险按钮）。
//   macOS：左 200 设置目录 + 右侧 ≤ 720 表单列；分组 = 左标题说明 240 + 右侧卡（Barly 后台常见的「两栏表单」）。
//   iOS：分组卡（组标题 mono 小字在卡外）+ 行（标签 · 值 / 开关 / ›）。危险区 = danger 色细边卡 + danger 描边按钮。
// 空状态依据：hireflow「No jobs found」、meeting-booker「No upcoming bookings」（居中图标 + 一句说明 + 一个按钮）。

/// 设置分组：macOS = 左侧标题 + 说明，右侧卡片；compact = 卡外 mono 组标题
public struct SettingsGroup<Content: View>: View {
    let title: String
    let detail: String?
    let compact: Bool
    let content: Content
    @Environment(\.barly) private var t
    public init(_ title: String, detail: String? = nil, compact: Bool = BarlyPlatform.compact, @ViewBuilder content: () -> Content) {
        self.title = title; self.detail = detail; self.compact = compact; self.content = content()
    }
    public var body: some View {
        if compact {
            VStack(alignment: .leading, spacing: 8) {
                MonoLabel(title, color: t.text3).padding(.leading, 4)
                Card(padding: 0, radius: BarlyRadius.lg) { VStack(spacing: 0) { content } }
                if let detail { Text(detail).barlyText(.mobile.micro, color: t.text3).padding(.horizontal, 4) }
            }
        } else {
            HStack(alignment: .top, spacing: 32) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).barlyText(FamilyType.pageTitle(BarlyTokens.Product.sectionTitle), color: t.text)
                    if let detail { Text(detail).barlyText(.product.small, color: t.text3).fixedSize(horizontal: false, vertical: true) }
                }
                .frame(width: 220, alignment: .leading)
                Card(padding: 0, radius: BarlyRadius.lg) { VStack(spacing: 0) { content } }
            }
        }
    }
}

/// 设置行：标签（+ 说明）…… 右侧控件；行间发丝线（第一行不画）
public struct SettingsRow<Trailing: View>: View {
    let label: String
    let detail: String?
    let icon: String?
    let first: Bool
    let compact: Bool
    let trailing: Trailing
    @Environment(\.barly) private var t
    public init(_ label: String, detail: String? = nil, icon: String? = nil, first: Bool = false, compact: Bool = BarlyPlatform.compact,
                @ViewBuilder trailing: () -> Trailing) {
        self.label = label; self.detail = detail; self.icon = icon; self.first = first; self.compact = compact; self.trailing = trailing()
    }
    public var body: some View {
        HStack(spacing: 12) {
            if let icon {
                RoundedRectangle(cornerRadius: BarlyRadius.xs, style: .continuous).fill(t.fill1)
                    .overlay(BarlyIcon(icon, size: 14, color: t.text2))
                    .frame(width: 28, height: 28)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(label).barlyText(compact ? .mobile.label : .product.body.weight(500), color: t.text)
                if let detail { Text(detail).barlyText(compact ? .mobile.micro : .product.caption, color: t.text3).fixedSize(horizontal: false, vertical: true) }
            }
            Spacer(minLength: 12)
            trailing
        }
        .padding(.horizontal, 16)
        .frame(minHeight: compact ? 50 : 54)
        .padding(.vertical, detail == nil ? 0 : 6)
        .overlay(alignment: .top) { if !first { Hairline().padding(.leading, icon == nil ? 16 : 56) } }
    }
}

/// 只读值 + ›（iOS 列表行尾）/ 下拉（macOS）
public struct SettingsValue: View {
    let value: String
    let compact: Bool
    @Environment(\.barly) private var t
    public init(_ value: String, compact: Bool = BarlyPlatform.compact) { self.value = value; self.compact = compact }
    public var body: some View {
        if compact {
            HStack(spacing: 6) {
                Text(value).barlyText(.mobile.label, color: t.text3)
                BarlyIcon("chevron.right", size: 12, color: t.text4)
            }
        } else {
            DropdownButton(value, size: .sm)
        }
    }
}

/// 表单字段（macOS 设置页 / 编辑详情）：标签 + 静态输入框
public struct FormField: View {
    let label: String
    let value: String
    let hint: String?
    let multiline: Bool
    @Environment(\.barly) private var t
    public init(_ label: String, value: String, hint: String? = nil, multiline: Bool = false) {
        self.label = label; self.value = value; self.hint = hint; self.multiline = multiline
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).barlyText(.product.caption.weight(500), color: t.text2)
            Text(verbatim: value).barlyText(.product.body, color: t.text)
                .padding(.horizontal, 12).padding(.vertical, multiline ? 10 : 0)
                .frame(maxWidth: .infinity, minHeight: multiline ? 76 : 36, alignment: multiline ? .topLeading : .leading)
                .background(RoundedRectangle(cornerRadius: BarlyRadius.md, style: .continuous).fill(t.fieldBg))
                .overlay(RoundedRectangle(cornerRadius: BarlyRadius.md, style: .continuous).strokeBorder(t.fieldBorder, lineWidth: BarlyFamily.current.stroke))
            if let hint { Text(hint).barlyText(.product.caption, color: t.text3) }
        }
    }
}

/// 危险区：danger 淡边卡，每行 标题 + 说明 …… danger 描边按钮（不用实心红，实心留给二次确认弹窗）
public struct DangerZone: View {
    let items: [(String, String, String)]
    let compact: Bool
    @Environment(\.barly) private var t
    /// items = [(标题, 说明, 按钮)]
    public init(_ items: [(String, String, String)], compact: Bool = BarlyPlatform.compact) { self.items = items; self.compact = compact }
    public var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 12) {
            if compact { MonoLabel("Danger zone", color: t.danger).padding(.leading, 4) }
            else { Text("Danger zone").barlyText(FamilyType.pageTitle(BarlyTokens.Product.sectionTitle), color: t.danger) }
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { i, it in
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(it.0).barlyText(compact ? .mobile.label.weight(500) : .product.body.weight(500), color: t.text)
                            Text(it.1).barlyText(.product.caption, color: t.text3).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 8)
                        Text(it.2).barlyText(.product.small.weight(500), color: t.danger)
                            .padding(.horizontal, 12).frame(height: compact ? 34 : 32)
                            .overlay(RoundedRectangle(cornerRadius: BarlyRadius.sm, style: .continuous).strokeBorder(t.danger.opacity(0.45), lineWidth: BarlyFamily.current.stroke))
                    }
                    .padding(16)
                    .overlay(alignment: .top) { if i > 0 { Rectangle().fill(t.danger.opacity(0.18)).frame(height: 1) } }
                }
            }
            .background(RoundedRectangle(cornerRadius: BarlyRadius.lg, style: .continuous).fill(t.dangerSoft.opacity(t.isDark ? 0.35 : 0.35)))
            .overlay(RoundedRectangle(cornerRadius: BarlyRadius.lg, style: .continuous).strokeBorder(t.danger.opacity(0.3), lineWidth: BarlyFamily.current.stroke))
        }
    }
}

/// 设置目录（macOS 左栏 200）：分组标题 + 行，选中 = 弱底块
public struct SettingsNav: View {
    let sections: [(String, [(String, String)])]
    let selection: String
    @Environment(\.barly) private var t
    /// sections = [(组名, [(图标, 标题)])]
    public init(_ sections: [(String, [(String, String)])], selection: String) { self.sections = sections; self.selection = selection }
    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(sections.enumerated()), id: \.offset) { i, s in
                MonoLabel(s.0, color: t.text3).padding(.top, i == 0 ? 0 : 20).padding(.bottom, 6).padding(.leading, 10)
                ForEach(s.1, id: \.1) { r in
                    let on = r.1 == selection
                    HStack(spacing: 10) {
                        BarlyIcon(r.0, size: 15, color: on ? t.text : t.text2)
                        Text(r.1).barlyText(on ? .product.body.weight(500) : .product.body, color: on ? t.text : t.text2)
                        Spacer()
                    }
                    .padding(.horizontal, 10).frame(height: 34)
                    .background(RoundedRectangle(cornerRadius: BarlyRadius.sm, style: .continuous).fill(on ? (t.isDark ? t.fill1 : t.softSurface) : .clear))
                }
            }
        }
    }
}

// MARK: - 空状态

public enum EmptyKind: String, CaseIterable, Sendable {
    /// 首次使用：还没有任何数据（引导创建 / 导入）
    case firstUse
    /// 搜索 / 筛选无结果
    case noResults
    /// 没有权限
    case noAccess
    /// 加载出错
    case error

    public var icon: String {
        switch self {
        case .firstUse: "tray"
        case .noResults: "magnifyingglass"
        case .noAccess: "lock"
        case .error: "exclamationmark.triangle"
        }
    }
}

/// 空状态：居中 图标块 → 标题 → 一句说明 → 主按钮 + 次按钮（可选）→ 底部小字（错误码 / 帮助链接）
/// 图标块：Barly = 56 浅灰圆角块 + 外圈虚线环；线框族 = 1px 主文字色框；出错 = danger 色图标。
public struct EmptyState: View {
    let kind: EmptyKind
    let title: String
    let message: String
    let primary: String?
    let secondary: String?
    let footnote: String?
    let compact: Bool
    let ghost: Bool
    @Environment(\.barly) private var t
    /// ghost = 背后垫几条淡骨架行、空状态浮在上面（meeting-booker「No upcoming bookings」：列表本来该在这里）
    public init(_ kind: EmptyKind, title: String, message: String, primary: String? = nil, secondary: String? = nil,
                footnote: String? = nil, ghost: Bool = false, compact: Bool = BarlyPlatform.compact) {
        self.kind = kind; self.title = title; self.message = message; self.primary = primary
        self.secondary = secondary; self.footnote = footnote; self.ghost = ghost; self.compact = compact
    }
    private var lined: Bool { [.rule, .grid, .thick, .bare].contains(BarlyFamily.current.surface) }
    public var body: some View {
        VStack(spacing: 0) {
            ZStack {
                if !lined {
                    Circle().strokeBorder(t.borderStrong.opacity(0.7), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                        .frame(width: 88, height: 88)
                }
                RoundedRectangle(cornerRadius: BarlyRadius.lg, style: .continuous)
                    .fill(lined ? Color.clear : (t.isDark ? t.fill1 : t.softSurface))
                    .overlay(RoundedRectangle(cornerRadius: BarlyRadius.lg, style: .continuous).strokeBorder(lined ? t.text : .clear, lineWidth: BarlyFamily.current.stroke))
                    .overlay(BarlyIcon(kind.icon, size: 22, color: kind == .error ? t.danger : t.text2))
                    .frame(width: 56, height: 56)
            }
            .frame(height: 88)
            Text(title).barlyText(FamilyType.pageTitle(compact ? BarlyTokens.Mobile.title : BarlyTokens.Product.pageTitle.size(18)), color: t.text)
                .multilineTextAlignment(.center)
                .padding(.top, 16)
            Text(message).barlyText(compact ? .mobile.body.leading(22) : .product.body.leading(21), color: t.text2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
            if primary != nil || secondary != nil {
                HStack(spacing: 10) {
                    if let secondary { BarlyButton(secondary, variant: .outline, size: compact ? .lg : .md) }
                    if let primary { BarlyButton(primary, icon: kind == .firstUse ? "plus" : (kind == .error ? "arrow.clockwise" : nil), variant: .primary, size: compact ? .lg : .md) }
                }
                .padding(.top, 22)
            }
            if let footnote {
                Text(verbatim: footnote).barlyText(FamilyType.label(BarlyTokens.Product.label), color: t.text3).padding(.top, 18)
            }
        }
        .padding(24)
        .background {
            // ghost：空状态做成浮卡，压在淡骨架行上
            if ghost {
                RoundedRectangle(cornerRadius: BarlyRadius.lg, style: .continuous).fill(t.isDark ? t.fill0 : t.surface)
                    .overlay(RoundedRectangle(cornerRadius: BarlyRadius.lg, style: .continuous).strokeBorder(t.border, lineWidth: 1))
                    .shadow(color: .black.opacity(t.isDark ? 0 : 0.07), radius: 16, y: 8)
            }
        }
        .padding(.top, ghost ? 40 : 0)
        .frame(maxWidth: .infinity)
        .background(alignment: .top) {
            if ghost {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(0..<6, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 3).fill(t.isDark ? t.fill1 : t.bgMuted.opacity(0.8))
                            .frame(width: [360, 260, 400, 300, 220, 340][i], height: 12)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 40)
                .mask(LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom))
            }
        }
    }
}
