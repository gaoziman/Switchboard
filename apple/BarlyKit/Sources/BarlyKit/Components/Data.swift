import SwiftUI
import Charts

// MARK: - 表格

public struct BarlyColumn<Row> {
    public let title: String
    public let width: CGFloat?        // nil = 弹性
    public let alignment: Alignment
    public let cell: (Row) -> AnyView
    public init(_ title: String, width: CGFloat? = nil, alignment: Alignment = .leading, cell: @escaping (Row) -> AnyView) {
        self.title = title; self.width = width; self.alignment = alignment; self.cell = cell
    }
    /// 纯文字列
    public static func text(_ title: String, width: CGFloat? = nil, alignment: Alignment = .leading, _ value: @escaping (Row) -> String) -> Self {
        BarlyColumn(title, width: width, alignment: alignment) { r in AnyView(BarlyCellText(value(r))) }
    }
}

public struct BarlyCellText: View {
    let s: String
    let strong: Bool
    @Environment(\.barly) private var t
    public init(_ s: String, strong: Bool = false) { self.s = s; self.strong = strong }
    public var body: some View {
        Text(s).barlyText(strong ? .product.body.weight(500) : .product.body, color: strong ? t.text : t.text.barlyMix(t.bg, 0.08)).lineLimit(1).truncationMode(.tail)
    }
}

public enum TableHeaderStyle: Sendable {
    /// 弱底 #FAFAFA + 灰字（后台）
    case subtle
    /// 强调色 10% 底 + 同色相深字（Bimbo 对话里的表格）
    case tint
}

/// 表格：外框 1px + 圆角，行线 1px，可选列竖线；不做斑马纹
public struct DataTable<Row: Identifiable>: View {
    let columns: [BarlyColumn<Row>]
    let rows: [Row]
    let rowHeight: CGFloat
    let headerHeight: CGFloat
    let header: TableHeaderStyle
    let verticalLines: Bool
    let selected: Set<Row.ID>
    let headerText: BarlyTextStyle
    let cellPad: CGFloat
    @Environment(\.barly) private var t
    public init(columns: [BarlyColumn<Row>], rows: [Row], rowHeight: CGFloat = BarlyMetrics.rowH, headerHeight: CGFloat = 36,
                header: TableHeaderStyle = .subtle, verticalLines: Bool = true, selected: Set<Row.ID> = [],
                headerText: BarlyTextStyle = BarlyTokens.Product.small, cellPad: CGFloat = 12) {
        self.columns = columns; self.rows = rows; self.rowHeight = rowHeight; self.headerHeight = headerHeight
        self.header = header; self.verticalLines = verticalLines; self.selected = selected
        self.headerText = headerText; self.cellPad = cellPad
    }

    @ViewBuilder private func cellFrame<V: View>(_ c: BarlyColumn<Row>, _ v: V) -> some View {
        if let w = c.width {
            v.padding(.horizontal, cellPad).frame(width: w, alignment: c.alignment)
        } else {
            v.padding(.horizontal, cellPad).frame(maxWidth: .infinity, alignment: c.alignment)
        }
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: BarlyRadius.md, style: .continuous)
        let line = t.isDark ? t.hairline : t.border
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(columns.enumerated()), id: \.offset) { i, c in
                    if i > 0 && verticalLines { Rectangle().fill(line).frame(width: 1) }
                    cellFrame(c, Text(c.title).barlyText(header == .tint ? headerText.weight(500) : headerText,
                                                          color: header == .tint ? t.tableHeaderFg : (t.isDark ? t.text3 : t.text2)))
                }
            }
            .frame(height: headerHeight)
            .background(header == .tint ? t.tableHeaderBg : (t.isDark ? t.fill1 : t.bgSubtle))
            ForEach(rows) { r in
                Rectangle().fill(line).frame(height: 1)
                HStack(spacing: 0) {
                    ForEach(Array(columns.enumerated()), id: \.offset) { i, c in
                        if i > 0 && verticalLines { Rectangle().fill(line).frame(width: 1) }
                        cellFrame(c, c.cell(r))
                    }
                }
                .frame(height: rowHeight)
                .background(selected.contains(r.id) ? (t.isDark ? t.fill1 : t.bgSubtle.barlyMix(t.bgMuted, 0.3)) : Color.clear)
            }
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(line, lineWidth: 1))
    }
}

/// 勾选框 16，选中 = 强调色（状态点）
public struct Checkbox: View {
    let on: Bool
    @Environment(\.barly) private var t
    public init(_ on: Bool) { self.on = on }
    public var body: some View {
        RoundedRectangle(cornerRadius: BarlyRadius.xs * 0.7, style: .continuous)
            .fill(on ? t.accent : t.fieldBg)
            .overlay(RoundedRectangle(cornerRadius: BarlyRadius.xs * 0.7, style: .continuous).strokeBorder(on ? .clear : t.borderStrong, lineWidth: 1))
            .overlay { if on { Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.white) } }
            .frame(width: 16, height: 16)
    }
}

// MARK: - KPI

public struct KpiCard: View {
    let title: String
    let value: String
    let note: String
    let delta: String?
    let up: Bool
    let info: Bool
    @Environment(\.barly) private var t
    public init(_ title: String, value: String, note: String, delta: String? = nil, up: Bool = true, info: Bool = false) {
        self.title = title; self.value = value; self.note = note; self.delta = delta; self.up = up; self.info = info
    }
    public var body: some View {
        Card(padding: 0) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 6) {
                    Text(title).barlyText(.product.cardTitle, color: t.text)
                    if info { BarlyIcon("info.circle", size: 13, color: t.text3) }
                    Spacer()
                    if let delta { DeltaBadge(delta, up: up) }
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(value).barlyText(FamilyType.numeric(BarlyTokens.Product.kpi), color: t.text)
                    Text(note).barlyText(.product.body, color: t.text3)
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 18)
        }
    }
}

// MARK: - 图表（Swift Charts）

public struct ChartPoint: Identifiable, Sendable {
    public let id: Int
    public let label: String
    public let value: Double
    public init(_ id: Int, _ label: String, _ value: Double) { self.id = id; self.label = label; self.value = value }
}

/// 深色 tooltip：同色相压暗的竖向渐变块，日期 13 浅灰 + 数值 20/500 白
public struct ChartTooltip: View {
    let title: String
    let value: String
    @Environment(\.barly) private var t
    public init(title: String, value: String) { self.title = title; self.value = value }
    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: BarlyRadius.sm, style: .continuous)
        let fg: Color = t.isDark ? t.text.barlyMix(.black, 0.9) : .white
        VStack(alignment: .leading, spacing: 6) {
            Text(title).barlyText(.product.small, color: fg.opacity(0.7))
            Text(value).barlyText(.product.kpi, color: fg)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(shape.fill(LinearGradient(colors: [t.tooltipFrom, t.tooltipTo], startPoint: .top, endPoint: .bottom)))
        .overlay(shape.strokeBorder(.white.opacity(t.isDark ? 0 : 0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
    }
}

/// 折线：线 1.75pt 强调色深阶，面积填充几乎看不见，横向虚线网格，悬停竖虚线 + 圆点 + 深色 tooltip
public struct LineChart: View {
    let points: [ChartPoint]
    let highlight: Int?
    let tooltipTitle: String
    let tooltipValue: String
    let yTicks: [Double]
    let yFormat: (Double) -> String
    let xStride: Int?
    let yDomain: ClosedRange<Double>?
    @Environment(\.barly) private var t
    /// xStride：每隔几个点标一个 x 轴刻度（默认约 12 个刻度；手机宽度给 9 左右）
    /// yDomain：不给 = 0…最大刻度×1.08；净资产、股价这类不从 0 起的序列传 yDomain（否则线被压成一条平线、刻度挤在顶上）
    public init(_ points: [ChartPoint], highlight: Int? = nil, tooltipTitle: String = "", tooltipValue: String = "",
                yTicks: [Double] = [10_000, 20_000, 30_000, 40_000], yFormat: @escaping (Double) -> String = { "\(Int($0 / 1000))k" },
                xStride: Int? = nil, yDomain: ClosedRange<Double>? = nil) {
        self.points = points; self.highlight = highlight; self.tooltipTitle = tooltipTitle; self.tooltipValue = tooltipValue
        self.yTicks = yTicks; self.yFormat = yFormat; self.xStride = xStride; self.yDomain = yDomain
    }
    public var body: some View {
        let line = t.chartLine
        Chart {
            ForEach(points) { p in
                // yDomain 不从 0 起时，面积从 domain 下沿起画，否则会溢出到 x 轴下面
                AreaMark(x: .value("x", p.id), yStart: .value("y", yDomain?.lowerBound ?? 0), yEnd: .value("y", p.value))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LinearGradient(colors: [t.chartAreaFrom, t.chartAreaTo], startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("x", p.id), y: .value("y", p.value))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(line)
                    .lineStyle(StrokeStyle(lineWidth: 1.75, lineCap: .round, lineJoin: .round))
            }
            if let h = highlight, let p = points.first(where: { $0.id == h }) {
                RuleMark(x: .value("x", p.id))
                    .foregroundStyle(t.text)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                PointMark(x: .value("x", p.id), y: .value("y", p.value))
                    .symbolSize(30)
                    .foregroundStyle(line)
                    .annotation(position: .leading, spacing: 10, overflowResolution: .init(x: .fit, y: .fit)) {
                        ChartTooltip(title: tooltipTitle, value: tooltipValue)
                    }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: yTicks) { v in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4])).foregroundStyle(t.chartGrid)
                AxisValueLabel { if let d = v.as(Double.self) { Text(yFormat(d)).barlyText(.product.caption, color: t.text3) } }
            }
        }
        .chartXAxis {
            AxisMarks(values: points.map(\.id).filter { $0 % (xStride ?? max(1, points.count / 12)) == 0 }) { v in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 1, dash: [4, 4])).foregroundStyle(t.chartGrid.opacity(0.7))
                AxisValueLabel {
                    if let i = v.as(Int.self), let p = points.first(where: { $0.id == i }) {
                        Text(p.label).barlyText(.product.caption, color: t.text3)
                    }
                }
            }
        }
        .chartYScale(domain: yDomain ?? 0...(yTicks.max() ?? 1) * 1.08)
    }
}

public struct BarGroup: Identifiable, Sendable {
    public let id: Int
    public let label: String
    public let values: [Double]
    public init(_ id: Int, _ label: String, _ values: [Double]) { self.id = id; self.label = label; self.values = values }
}

/// 细柱三柱成组，同色相三阶（浅→中→深），柱顶直角，无网格、无 y 轴
public struct BarChart: View {
    let groups: [BarGroup]
    let barWidth: CGFloat
    @Environment(\.barly) private var t
    public init(_ groups: [BarGroup], barWidth: CGFloat = 5) { self.groups = groups; self.barWidth = barWidth }
    public var body: some View {
        let tones = [t.dataLight, t.dataBase, t.dataDeep]
        Chart {
            ForEach(groups) { g in
                ForEach(Array(g.values.enumerated()), id: \.offset) { i, v in
                    BarMark(x: .value("m", g.label), y: .value("v", v), width: .fixed(barWidth))
                        .foregroundStyle(tones[i % tones.count])
                        .position(by: .value("s", "\(i)"), axis: .horizontal, span: .ratio(0.55))
                }
            }
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks { v in
                AxisValueLabel { if let s = v.as(String.self) { Text(s).barlyText(.product.caption, color: t.text3) } }
            }
        }
        .chartLegend(.hidden)
    }
}

/// 图例点 + 名称
public struct LegendDot: View {
    let label: String
    let color: Color
    @Environment(\.barly) private var t
    public init(_ label: String, color: Color) { self.label = label; self.color = color }
    public var body: some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).barlyText(.product.small, color: t.text2)
        }
    }
}
