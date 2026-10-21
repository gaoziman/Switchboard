import SwiftUI
import BarlyKit

// 风格族示例屏：每个风格族一张能体现特色的屏（iOS 393×852；console 另有 macOS 1440×1024）。
// 都由 BarlyKit 组件拼成——组件按 BarlyFamily.current 自己换字形 / 分层 / 圆角，屏幕只管内容和构图。
// 照片是 tools/photos.sh 生成的本地质感占位图（BarlyPhoto），不外链。
// 对应参考：gallery/lovable/<slug>/mobile.jpg（见 references/apple.md §8 表）。

// MARK: - 共用零件

/// 风格族标题字阶：基于 Mobile.display，size = 最终字号（不再按族放大）
func famDisplay(_ size: CGFloat) -> BarlyTextStyle { FamilyType.display(BarlyTokens.Mobile.display.size(size), scale: false) }

/// 只有字标 + 菜单的顶栏（作品集 / 资讯 / 店铺类 app 的常见写法）
struct WordmarkBar: View {
    let wordmark: String
    var trailing: String = "barly.menu"
    var style: BarlyTextStyle? = nil
    @Environment(\.barly) private var t
    var body: some View {
        HStack {
            Text(wordmark).barlyText(style ?? famDisplay(20), color: t.text)
            Spacer()
            BarlyIcon(trailing, size: 20, color: t.text)
        }
        .padding(.horizontal, BarlyMetrics.pageX)
        .frame(height: 52)
    }
}

/// 键值行（swiss 规格表 / flood 联系方式）
struct KeyValueRow: View {
    let key: String
    let value: String
    var mono = false
    @Environment(\.barly) private var t
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key).barlyText(.mobile.caption, color: t.text3).frame(width: 110, alignment: .leading)
            Text(value).barlyText(mono ? BarlyTokens.Mobile.body.monospaced : BarlyTokens.Mobile.body, color: t.text)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 11)
        .overlay(alignment: .top) { Hairline() }
    }
}

/// 正负色：console 用生成的发散蓝 / 橙 dataPos / dataNeg（CFO Command Center），其余用语义色
extension BarlyPalette {
    var posColor: Color { BarlyFamily.current == .console ? dataPos : success }
    var negColor: Color { BarlyFamily.current == .console ? dataNeg : danger }
}

// MARK: - editorial：今日阅读 / 预约（editorial-portfolio、vellum-editorial-writer）

public struct EditorialReadingScreen: View {
    @Environment(\.barly) private var t
    public init() {}
    public var body: some View {
        VStack(spacing: 0) {
            WordmarkBar(wordmark: "Atelier Notes")
            BarlyScroll {
                VStack(alignment: .leading, spacing: 0) {
                    MonoLabel("Issue 14 · Saturday, Oct 18", color: t.text3)
                        .padding(.top, 18)
                    DisplayTitle(["The quiet art", "of slow mornings"], style: famDisplay(40), keyword: "art")
                        .padding(.top, 14)
                    Text("Notes on window light, stoneware and the hour before the inbox opens.")
                        .barlyText(.mobile.body.size(16).leading(24), color: t.text2)
                        .padding(.top, 14)
                    HStack(spacing: 8) {
                        Avatar("Elena Vance", size: 24, tint: 0)
                        Text("Elena Vance").barlyText(.mobile.caption.weight(500), color: t.text)
                        Text("· 6 min read").barlyText(.mobile.caption, color: t.text3)
                    }
                    .padding(.top, 16)
                    BarlyPhoto("still-life")
                        .frame(height: 230)
                        .padding(.top, 22)
                    Text("Plate I — Still life, 8:14 a.m.").barlyText(FamilyType.label(BarlyTokens.Mobile.sectionLabel), color: t.text3)
                        .padding(.top, 8)
                    MonoLabel("Also today", color: t.text3).padding(.top, 28).padding(.bottom, 6)
                    ForEach(Array([("02", "A ceramicist’s calendar", "Interview · 9 min"), ("03", "Ten rooms with north light", "Essay · 4 min")].enumerated()), id: \.offset) { _, r in
                        HStack(alignment: .firstTextBaseline, spacing: 14) {
                            Text(r.0).barlyText(famDisplay(22), color: t.text3)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(r.1).barlyText(famDisplay(19), color: t.text)
                                Text(r.2).barlyText(.mobile.caption, color: t.text3)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .overlay(alignment: .top) { Hairline() }
                    }
                }
                .padding(.horizontal, BarlyMetrics.pageX)
                .padding(.bottom, 130)
            }
        }
        .overlay(alignment: .bottom) { booking }
        .screenBackground(t.bg)
    }

    /// 底部预约条：发丝线分隔 + 转化按钮 cta（预约 = 这屏唯一的实心块，buttons.md）
    private var booking: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Studio visit").barlyText(famDisplay(20), color: t.text)
                Text("Thu, Oct 24 · 2:00 pm · 2 seats left").barlyText(.mobile.caption, color: t.text2)
            }
            Spacer()
            BarlyButton("Reserve", variant: .cta, size: .lg)
        }
        .padding(.horizontal, BarlyMetrics.pageX)
        .padding(.top, 14).padding(.bottom, 14)
        .background(t.bg)
        .overlay(alignment: .top) { Hairline() }
    }
}

// MARK: - swiss：目录 / 规格（sound-index、architecture-interior）

public struct SwissSpecScreen: View {
    @Environment(\.barly) private var t
    public init() {}
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("INDEX").barlyText(.mobile.headline.tracked(0.12), color: t.text3)
                // 文字即导航：发丝线框的小方块按钮（sound-index「Login」）
                Text("Saved 2").barlyText(.mobile.caption.weight(500), color: t.text)
                    .padding(.horizontal, 10).frame(height: 30)
                    .overlay(Rectangle().strokeBorder(t.borderStrong, lineWidth: 1))
                    .padding(.leading, 10)
                Spacer()
                Text("012 / 048").barlyText(.mobile.caption.monospaced, color: t.text3)
            }
            .frame(height: 52)
            Hairline()
            HStack(alignment: .top) {
                DisplayTitle(["Lamp No. 7"], style: famDisplay(40))
                Spacer()
                Text("2024").barlyText(.mobile.caption.monospaced, color: t.text3).padding(.top, 10)
            }
            .padding(.top, 22)
            Text("Brushed steel desk lamp with a spun aluminium shade.").barlyText(.mobile.body, color: t.text2)
                .padding(.top, 6)
            BarlyPhoto("lamp")
                .frame(height: 300)
                .padding(.top, 20)
            VStack(spacing: 0) {
                KeyValueRow(key: "Material", value: "Brushed steel")
                KeyValueRow(key: "Height", value: "420 mm", mono: true)
                KeyValueRow(key: "Shade", value: "Ø 260 mm", mono: true)
                KeyValueRow(key: "Light", value: "2700 K · 800 lm", mono: true)
                KeyValueRow(key: "Price", value: "€ 340", mono: true)
            }
            .padding(.top, 18)
            Hairline()
            Spacer(minLength: 12)
            HStack(spacing: 10) {
                BarlyButton("Add to list", variant: .outline, size: .lg, fullWidth: true)
                BarlyButton("Order sample", variant: .cta, size: .lg, fullWidth: true)
            }
            .padding(.bottom, 14)
        }
        .padding(.horizontal, BarlyMetrics.pageX)
        .screenBackground(t.bg)
    }
}

// MARK: - brutal：商品详情（raw-goods-shopify-storefront、inkwell-brutalist）

public struct BrutalProductScreen: View {
    @State private var size = 2
    @Environment(\.barly) private var t
    public init() {}
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("RAW GOODS").barlyText(famDisplay(26), color: t.text)
                Spacer()
                HStack(spacing: 0) {
                    BarlyIcon("bag", size: 18, color: t.text).frame(width: 40, height: 36)
                    Text("2").barlyText(.mobile.caption.weight(700).monospaced, color: t.bg).frame(width: 26, height: 36).background(t.text)
                }
                .overlay(Rectangle().strokeBorder(t.text, lineWidth: 2))
            }
            .padding(.horizontal, BarlyMetrics.pageX)
            .frame(height: 56)
            // 跑马灯条：唯一的强调色面（文字用 overlay + clipped，超长不会把整屏撑宽）
            Rectangle().fill(t.accent)
                .frame(height: 30)
                .overlay(alignment: .leading) {
                    Text(verbatim: "FREE SHIPPING OVER $500 ✦ HANDCRAFTED IN OREGON ✦ 30-DAY RETURNS ✦")
                        .barlyText(.mobile.micro.monospaced.weight(700).tracked(0.06), color: t.accentFg)
                        .lineLimit(1).fixedSize()
                        .padding(.leading, 12)
                }
                .clipped()
                .overlay(alignment: .top) { Rectangle().fill(t.text).frame(height: 2) }
                .overlay(alignment: .bottom) { Rectangle().fill(t.text).frame(height: 2) }
            ZStack(alignment: .topLeading) {
                BarlyPhoto("board", grayscale: false)
                    .frame(height: 300)
                    .overlay(Rectangle().strokeBorder(t.text, lineWidth: 2))
                Text("NEW").barlyText(.mobile.micro.monospaced.weight(700), color: t.bg)
                    .padding(.horizontal, 8).frame(height: 24).background(t.text)
                    .padding(12)
            }
            .padding(.horizontal, BarlyMetrics.pageX).padding(.top, 18)
            DisplayTitle(["Hydro Board", "158 Wide"], style: famDisplay(54), keyword: "158")
                .padding(.horizontal, BarlyMetrics.pageX).padding(.top, 18)
            HStack(alignment: .firstTextBaseline) {
                Text("$500").barlyText(famDisplay(32), color: t.text)
                Spacer()
                Text("IN STOCK · SHIPS MON").barlyText(.mobile.micro.monospaced.tracked(0.06), color: t.text2)
            }
            .padding(.horizontal, BarlyMetrics.pageX).padding(.top, 6)
            HStack(spacing: -2) {
                ForEach(Array(["152", "155", "158", "161"].enumerated()), id: \.offset) { i, s in
                    // 选中 = 加粗一圈边 + 强调色角标（不填黑，buttons.md §4；brutal 的粗黑边本身保留）
                    Text(s).barlyText(.mobile.body.monospaced.weight(700), color: t.text)
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .overlay(Rectangle().strokeBorder(t.text, lineWidth: i == size ? 4 : 2))
                        .overlay(alignment: .topTrailing) { if i == size { Rectangle().fill(t.selectedMark).frame(width: 10, height: 10).padding(4) } }
                        .zIndex(i == size ? 1 : 0)
                }
            }
            .padding(.horizontal, BarlyMetrics.pageX).padding(.top, 14)
            Spacer(minLength: 12)
            // 转化按钮 = cta（强调色）+ 黑色硬投影 + 2px 黑边（brutal 身份）
            Text("ADD TO CART — $500  →")
                .barlyText(famDisplay(22), color: t.ctaFg)
                .frame(maxWidth: .infinity).frame(height: 56)
                .background(Rectangle().fill(t.cta))
                .overlay(Rectangle().strokeBorder(t.text, lineWidth: 2))
                .background(Rectangle().fill(t.text).offset(x: 5, y: 5))
                .padding(.horizontal, BarlyMetrics.pageX).padding(.trailing, 5).padding(.bottom, 18)
        }
        .screenBackground(t.bg)
    }
}

// MARK: - flood：个人名片 / 活动（ember-bold-designer-portfolio）

public struct FloodCardScreen: View {
    @Environment(\.barly) private var t
    public init() {}
    static let talks: [(String, String, String)] = [("OCT 24", "Designing calm software", "Config · Tokyo"),
                                                     ("NOV 07", "Small teams, big systems", "Hatch · Lisbon"),
                                                     ("DEC 02", "Notes on restraint", "Online")]
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("Maya Chen").barlyText(.mobile.caption.weight(500), color: t.text)
                Text("/").barlyText(.mobile.caption, color: t.text3)
                Text("Home").barlyText(.mobile.caption, color: t.text2)
                Spacer()
                BarlyIcon("barly.menu", size: 20, color: t.text)
            }
            .frame(height: 50)
            Hairline()
            DisplayTitle(["Maya Chen is a", "product designer", "at Verve in", "San Francisco."], style: famDisplay(44), keyword: "Verve")
                .padding(.top, 28)
            Text("Find her work below, and say hello\nfor freelance or speaking.")
                .barlyText(.mobile.body.leading(22), color: t.text2)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 22)
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    MonoLabel("Contact", color: t.text2)
                    Text(verbatim: "hello@maya.design").barlyText(.mobile.caption, color: t.text)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 6) {
                    MonoLabel("Social", color: t.text2)
                    Text("Journal · Studio notes").barlyText(.mobile.caption, color: t.text)
                }
                .frame(width: 150, alignment: .leading)
            }
            .padding(.top, 30)
            MonoLabel("Upcoming talks", color: t.text2).padding(.top, 30).padding(.bottom, 8)
            ForEach(Self.talks, id: \.0) { r in
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    Text(r.0).barlyText(.mobile.caption.monospaced, color: t.text2).frame(width: 56, alignment: .leading)
                    Text(r.1).barlyText(.mobile.body, color: t.text)
                    Spacer(minLength: 6)
                    Text(r.2).barlyText(.mobile.micro, color: t.text2)
                }
                .padding(.vertical, 11)
                .overlay(alignment: .top) { Hairline() }
            }
            Spacer(minLength: 12)
            // flood 的转化按钮：cta = 前景色实心（色底上不放白底块；buttons.md）
            BarlyButton("Book a call", icon: "arrow.up.right", variant: .cta, size: .xl, fullWidth: true)
                .padding(.bottom, 14)
        }
        .padding(.horizontal, BarlyMetrics.pageX)
        .screenBackground(t.bg)
    }
}

// MARK: - press：资讯首页（broadsheet-template、daily-beacon）

public struct PressFrontScreen: View {
    @Environment(\.barly) private var t
    public init() {}
    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("SAT, OCTOBER 18, 2026").barlyText(.mobile.micro.monospaced.size(10), color: t.text2)
                Spacer()
                Text("VOL. XII · NO. 291").barlyText(.mobile.micro.monospaced.size(10), color: t.text2)
            }
            .frame(height: 30)
            Text("The Daily Ledger").barlyText(famDisplay(40).weight(800).tracked(-0.01), color: t.text)
                .padding(.top, 6)
            // 双线
            VStack(spacing: 2) { Rectangle().fill(t.text).frame(height: 2); Rectangle().fill(t.text).frame(height: 1) }
                .padding(.top, 10)
            HStack {
                ForEach(["World", "City", "Business", "Culture", "Opinion"], id: \.self) { s in
                    Text(s.uppercased()).barlyText(.mobile.micro.monospaced.size(10).tracked(0.08), color: t.text)
                    if s != "Opinion" { Spacer(minLength: 0) }
                }
            }
            .frame(height: 34)
            Hairline()
            BarlyScroll {
                VStack(alignment: .leading, spacing: 0) {
                    Text("CITY").barlyText(.mobile.micro.monospaced.weight(700).tracked(0.1), color: t.accentText).padding(.top, 16)
                    Text("A quieter downtown: how the night markets came back")
                        .barlyText(famDisplay(27).weight(700).leading(31), color: t.text)
                        .padding(.top, 6)
                    BarlyPhoto("street").frame(height: 190).padding(.top, 12)
                    Text("Vendors return to Mercer Street after four years, and the council wants to keep it car-free.")
                        .barlyText(.mobile.caption.leading(19), color: t.text2)
                        .padding(.top, 8)
                    HStack(alignment: .top, spacing: 0) {
                        brief("SCIENCE", "Research bias starts early, and takes a serious toll")
                        Rectangle().fill(t.hairline).frame(width: 1).padding(.horizontal, 12)
                        brief("FOOD", "The case for the four-course lunch")
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 14)
                    .overlay(alignment: .top) { Rectangle().fill(t.text).frame(height: 1) }
                    .padding(.top, 16)
                    Text("Daily Feed").barlyText(famDisplay(20).weight(700), color: t.text)
                        .padding(.top, 6)
                    ForEach([("ECONOMY", "Nation’s economy grows again, in longest streak in 11 years"),
                             ("ARTS", "The museum trying to fix itself")], id: \.0) { r in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(r.0).barlyText(.mobile.micro.monospaced.size(10).weight(700).tracked(0.1), color: t.accentText)
                            Text(r.1).barlyText(famDisplay(17).weight(700).leading(21), color: t.text)
                        }
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(alignment: .bottom) { Hairline() }
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .padding(.horizontal, BarlyMetrics.pageX)
        .screenBackground(t.bg)
    }

    private func brief(_ kicker: String, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(kicker).barlyText(.mobile.micro.monospaced.size(10).weight(700).tracked(0.1), color: t.accentText)
            Text(title).barlyText(famDisplay(16).weight(700).leading(20), color: t.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - noir：音乐人 / 巡演（ember-electronic-music-artist、resonance-music-artist）

public struct NoirTourScreen: View {
    @Environment(\.barly) private var t
    public init() {}
    static let dates: [(String, String, String, Bool)] = [("JAN 30", "The Spectrum", "Afterglow · Metro City", false),
                                                           ("FEB 14", "The Underground", "Harbor District", false),
                                                           ("FEB 28", "Seven Frequencies", "Westside", true),
                                                           ("MAR 13", "The Crossing", "Metro City", false)]
    /// 日期字母间隔写（J A N 3 0）
    static func spaced(_ s: String) -> String { s.replacingOccurrences(of: " ", with: "").map(String.init).joined(separator: " ") }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                BarlyPhoto("stage")
                    .frame(height: 470)
                    .ignoresSafeArea(edges: .top)
                    .overlay(LinearGradient(colors: [.black.opacity(0.35), .clear, .clear, t.bg], startPoint: .top, endPoint: .bottom))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Electronic music artist").barlyText(FamilyType.label(BarlyTokens.Mobile.sectionLabel), color: t.text2)
                    DisplayTitle(["Hot Ashes"], style: famDisplay(92))
                }
                .padding(.horizontal, BarlyMetrics.pageX).padding(.bottom, 4)
            }
            .overlay(alignment: .top) {
                HStack {
                    Text("Hot Ashes").barlyText(famDisplay(22), color: .white)
                    Spacer()
                    BarlyIcon("barly.menu", size: 20, color: .white)
                }
                .padding(.horizontal, BarlyMetrics.pageX)
                .padding(.top, 8)
            }
            // 巡演 / 录音：整宽深一级色带 + 左缘强调色竖条（ember-electronic-music-artist）
            HStack(spacing: 22) {
                Text("2026 on tour").barlyText(famDisplay(28), color: t.text)
                Text("Recordings").barlyText(famDisplay(28), color: t.text3)
                Spacer()
            }
            .padding(.horizontal, BarlyMetrics.pageX)
            .frame(height: 58)
            .background(t.surface)
            .overlay(alignment: .leading) { Rectangle().fill(t.accent).frame(width: 5) }
            VStack(spacing: 0) {
                ForEach(Array(Self.dates.enumerated()), id: \.offset) { i, d in
                    HStack(spacing: 14) {
                        BarlyPhoto(i % 2 == 0 ? "stage" : "portrait-dark").frame(width: 52, height: 52)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(Self.spaced(d.0)).barlyText(.mobile.caption.weight(700).tracked(0.08), color: t.text)
                            Text("\(d.1) · \(d.2)").barlyText(.mobile.micro, color: t.text3).lineLimit(1)
                        }
                        Spacer(minLength: 6)
                        if d.3 {
                            Text("SOLD OUT").barlyText(.mobile.micro.monospaced.tracked(0.06), color: t.text3)
                        } else {
                            Text("TICKETS").barlyText(.mobile.micro.weight(700).tracked(0.08), color: t.accentText)
                                .padding(.horizontal, 10).frame(height: 28)
                                .overlay(Capsule().strokeBorder(t.accentText.opacity(0.6), lineWidth: 1))
                        }
                    }
                    .padding(.vertical, 10)
                    .overlay(alignment: .bottom) { Hairline() }
                }
            }
            .padding(.horizontal, BarlyMetrics.pageX).padding(.top, 4)
            Spacer(minLength: 0)
        }
        .screenBackground(t.bg)
    }
}

// MARK: - soft：托育 / 宠物预约（preschool-daycare-site、pediatrician-website）

public struct SoftCareScreen: View {
    @State private var slot = 1
    @Environment(\.barly) private var t
    public init() {}
    public var body: some View {
        let p = t.pastels
        VStack(spacing: 0) {
            HStack {
                Text("hazel house").barlyText(famDisplay(22), color: t.text)
                Spacer()
                Text("Menu").barlyText(.mobile.body, color: t.text)
            }
            .frame(height: 52)
            // 居中细字重标题 + 居中短说明（pediatrician-website）
            DisplayTitle(["care for growing kids"], style: famDisplay(32), keyword: "growing", alignment: .center)
                .padding(.top, 14)
            Text("Small, warm rooms for babies and toddlers in Southeast Portland. Open all year.")
                .barlyText(.mobile.body.leading(22), color: t.text2)
                .multilineTextAlignment(.center)
                .padding(.top, 10).padding(.horizontal, 10)
            // 大照片：大圆角（pediatrician-website）+ 右下错开一块粉彩，不加阴影
            BarlyPhoto("playroom", mask: .rounded(32))
                .frame(height: 240)
                .background(RoundedRectangle(cornerRadius: 32, style: .continuous).fill(p[1]).offset(x: 10, y: 10))
                .padding(.trailing, 10)
            .padding(.top, 20)
            HStack(spacing: 10) {
                room("Infants", "6 wk – 1 yr", p[0])
                room("Toddlers", "1 – 3 yrs", p[1])
                room("Preschool", "3 – 5 yrs", p[2])
            }
            .padding(.top, 20)
            HStack(spacing: 8) {
                Text("Tour").barlyText(.mobile.caption.weight(500), color: t.text2)
                Spacer()
                ForEach(Array(["Tue 10:00", "Wed 15:30", "Thu 09:00"].enumerated()), id: \.offset) { i, s in
                    // 时段选中 = 1.5pt 深色边 + 小勾（不填充，buttons.md §4）
                    Text(s).barlyText(.mobile.caption.weight(500), color: i == slot ? t.selectedFg : t.text)
                        .padding(.horizontal, 12).frame(height: 34)
                        .barlySelectCard(i == slot, radius: 17, idleFill: i == slot ? t.surface : t.bgMuted)
                }
            }
            .padding(.top, 18)
            Spacer(minLength: 12)
            BarlyButton("Book a visit", icon: "calendar", variant: .cta, size: .xl, fullWidth: true)
                .padding(.bottom, 14)
        }
        .padding(.horizontal, BarlyMetrics.pageX)
        .screenBackground(t.bg)
    }

    private func room(_ title: String, _ age: String, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).barlyText(famDisplay(18), color: t.text)
            Spacer(minLength: 8)
            Text(age).barlyText(.mobile.micro, color: t.text2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 92)
        .background(RoundedRectangle(cornerRadius: BarlyRadius.xl, style: .continuous).fill(c))
    }
}

// MARK: - gallery：摄影集（mono-photographer、minimal-photographer、savora）

public struct GalleryAlbumScreen: View {
    @Environment(\.barly) private var t
    public init() {}
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                // 当前导航 = 深色字 + 2px 下划线（gallery 的选中写法，buttons.md §4）
                Text("Index").barlyText(.mobile.caption.weight(500), color: t.text)
                    .overlay(alignment: .bottom) { Rectangle().fill(t.text).frame(height: 2).offset(y: 5) }
                Text("Series").barlyText(.mobile.caption, color: t.text2).padding(.leading, 14)
                Spacer()
                Text("About").barlyText(.mobile.caption, color: t.text2)
            }
            .padding(.horizontal, BarlyMetrics.pageX)
            .frame(height: 44)
            // 名字就是标题（minimal-photographer）：grotesk 大字 + 一行身份
            DisplayTitle(["Sofia Martini"], style: famDisplay(40))
                .padding(.horizontal, BarlyMetrics.pageX).padding(.top, 10)
            Text("Landscape & still-life photographer, Milan").barlyText(.mobile.body.size(16), color: t.text)
                .padding(.horizontal, BarlyMetrics.pageX).padding(.top, 6)
            BarlyPhoto("dunes").frame(height: 360).padding(.top, 22)
            HStack {
                Text("01 — Dunes, Merzouga").barlyText(.mobile.caption, color: t.text)
                Spacer()
                Text("2025").barlyText(.mobile.micro.monospaced, color: t.text3)
            }
            .padding(.horizontal, BarlyMetrics.pageX).padding(.top, 10)
            HStack(alignment: .top, spacing: 8) {
                BarlyPhoto("sea").frame(height: 120)
                BarlyPhoto("mountain").frame(height: 150)
                BarlyPhoto("garden").frame(height: 120)
            }
            .padding(.horizontal, BarlyMetrics.pageX).padding(.top, 20)
            Spacer(minLength: 0)
        }
        .screenBackground(t.bg)
    }
}

// MARK: - console：指标看板（cfo-command-center、customer-health-dashboard）

struct ConsoleKpi: Identifiable {
    let id: String
    let value: String
    let delta: String
    let up: Bool
    let note: String
}

enum ConsoleMock {
    static let kpis: [ConsoleKpi] = [
        ConsoleKpi(id: "ARR", value: "$14.97M", delta: "2.0%", up: true, note: "vs prior month"),
        ConsoleKpi(id: "Gross margin", value: "77.9%", delta: "1.5 pts", up: true, note: "MoM"),
        ConsoleKpi(id: "Net burn", value: "$467K", delta: "1.0%", up: false, note: "vs prior month"),
        ConsoleKpi(id: "Runway", value: "50.2 mo", delta: "72.4%", up: true, note: "at current burn"),
    ]
    static let watch: [(String, String, String, Int)] = [("Fenwick Legal", "ENTERPRISE", "$720K", 22), ("Marlowe Capital", "ENTERPRISE", "$840K", 54),
                                                         ("Ironpine Energy", "MID-MARKET", "$610K", 28), ("Norvale Petroleum", "ENTERPRISE", "$566K", 51),
                                                         ("Bastion Claims", "MID-MARKET", "$455K", 31)]
}

/// 2×2（手机）/ 1×4（桌面）KPI 格：共用发丝线，不用卡片；标签 mono 大写，数值等宽
struct ConsoleKpiCell: View {
    let k: ConsoleKpi
    var big: CGFloat = 26
    @Environment(\.barly) private var t
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(k.id).barlyText(FamilyType.label(BarlyTokens.Mobile.sectionLabel).size(10), color: t.text3)
            Text(k.value).barlyText(BarlyTokens.Mobile.display.size(big).monospaced.tracked(-0.03), color: t.text)
            HStack(spacing: 4) {
                Text("\(k.up ? "▲" : "▼") \(k.delta)").barlyText(.mobile.micro.monospaced, color: k.up ? t.posColor : t.negColor)
                Text(k.note).barlyText(.mobile.micro, color: t.text3).lineLimit(1)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WatchRow: View {
    let r: (String, String, String, Int)
    @Environment(\.barly) private var t
    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(r.0).barlyText(.mobile.caption.weight(500), color: t.text)
                Text(r.1).barlyText(FamilyType.label(BarlyTokens.Mobile.sectionLabel).size(9), color: t.text3)
            }
            Spacer()
            Text(r.2).barlyText(.mobile.caption.monospaced, color: t.text)
            Text("\(r.3)").barlyText(.mobile.caption.monospaced, color: r.3 < 35 ? t.negColor : t.text2).frame(width: 30, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) { Hairline() }
    }
}

public struct ConsoleMetricsScreen: View {
    @State private var scenario = 0
    @Environment(\.barly) private var t
    public init() {}
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Circle().fill(t.posColor).frame(width: 6, height: 6)
                Text("NORTHWIND CLOUD · FINANCIAL REPORTING").barlyText(.mobile.micro.monospaced.size(10).tracked(0.08), color: t.text3)
            }
            .padding(.top, 10)
            Text("CFO Command Center").barlyText(famDisplay(28), color: t.text).padding(.top, 8)
            Text("Booked results, close of Sep 2026 · books locked").barlyText(.mobile.caption, color: t.text3).padding(.top, 4)
            Segmented(["Actuals", "Board plan", "Upside"], selection: $scenario, height: 34, style: BarlyTokens.Mobile.caption, fullWidth: true)
                .padding(.top, 16)
            // KPI 2×2：共用线框
            VStack(spacing: 0) {
                HStack(spacing: 0) { ConsoleKpiCell(k: ConsoleMock.kpis[0]); Rectangle().fill(t.border).frame(width: 1); ConsoleKpiCell(k: ConsoleMock.kpis[1]) }
                Rectangle().fill(t.border).frame(height: 1)
                HStack(spacing: 0) { ConsoleKpiCell(k: ConsoleMock.kpis[2]); Rectangle().fill(t.border).frame(width: 1); ConsoleKpiCell(k: ConsoleMock.kpis[3]) }
            }
            .fixedSize(horizontal: false, vertical: true)
            .overlay(Rectangle().strokeBorder(t.border, lineWidth: 1))
            .padding(.top, 14)
            HStack {
                Text("ARR, trailing 12 mo").barlyText(.mobile.caption.weight(500), color: t.text)
                Spacer()
                Text("$M").barlyText(.mobile.micro.monospaced, color: t.text3)
            }
            .padding(.top, 18)
            LineChart(Mock.revenueSeries, highlight: 30, tooltipTitle: "JAN 2026", tooltipValue: "$14.2M", yFormat: { "\(Int($0 / 2500))" }, xStride: 9)
                .frame(height: 150).padding(.top, 8)
            MonoLabel("Watchlist", color: t.text3).padding(.top, 16)
            ForEach(ConsoleMock.watch.prefix(3), id: \.0) { WatchRow(r: $0) }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, BarlyMetrics.pageX)
        .screenBackground(t.bg)
    }
}

// MARK: - console（macOS）：指标看板，外壳按身份骨架

public struct MetricsBoardScreen: View {
    public var onNavigate: (String) -> Void
    public init(onNavigate: @escaping (String) -> Void = { _ in }) { self.onNavigate = onNavigate }
    static var spec: ShellSpec {
        ShellSpec(brand: ("Northwind", "Finance"), workspace: "FY 2026",
                  nav: [SidebarNavItem("board", icon: "square.grid.2x2", title: "Metrics board"),
                        SidebarNavItem("rev", icon: "chart.line.uptrend.xyaxis", title: "Revenue"),
                        SidebarNavItem("cash", icon: "banknote", title: "Cash"),
                        SidebarNavItem("people", icon: "person.2", title: "Headcount"),
                        SidebarNavItem("acc", icon: "building.2", title: "Accounts", badge: "160")],
                  selection: "board",
                  footer: [SidebarNavItem("settings", icon: "gearshape", title: "Settings")],
                  user: ("Dana Okafor", "dana@northwind.cloud"),
                  listTitle: "Boards", listAction: "New board",
                  list: [ShellListSection("Pinned", [ShellListItem("b", "Close · Sep 2026", detail: "Live"), ShellListItem("f", "13-week cash", detail: "Mon")]),
                         ShellListSection("Scenarios", [ShellListItem("s1", "Board plan"), ShellListItem("s2", "Efficiency case"), ShellListItem("s3", "Upside case")])],
                  listSelection: "b")
    }
    public var body: some View {
        AppShell(Self.spec, onSelect: onNavigate) { MetricsBoardContent() } inspector: { MetricsInspector() }
    }
}

struct MetricsBoardContent: View {
    @State private var search = ""
    @State private var range = 3
    @Environment(\.barly) private var t
    @Environment(\.barlyContentWidth) private var w
    var body: some View {
        VStack(spacing: 0) {
            TitleBar("Metrics board") {
                SearchField("Search accounts", text: $search, shortcut: "⌘K", width: 220)
                BarlyButton("Export", icon: "square.and.arrow.up", variant: .outline)
            }
            HStack(spacing: 8) {
                Circle().fill(t.posColor).frame(width: 6, height: 6)
                Text("NORTHWIND CLOUD · FINANCIAL REPORTING · CLOSE OF SEP 2026").barlyText(.product.label.size(10).tracked(0.1), color: t.text3)
                Spacer()
                Segmented(["1M", "3M", "6M", "12M"], selection: $range, height: 30, style: BarlyTokens.Product.caption)
            }
            .padding(.horizontal, BarlyMetrics.contentPad).frame(height: 52)
            .overlay(alignment: .bottom) { Hairline() }
            BarlyScroll {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 0) {
                        ForEach(Array(ConsoleMock.kpis.enumerated()), id: \.offset) { i, k in
                            if i > 0 { Rectangle().fill(t.border).frame(width: 1) }
                            ConsoleKpiCell(k: k, big: w > 900 ? 32 : 26)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .overlay(Rectangle().strokeBorder(t.border, lineWidth: 1))
                    Card(padding: 20) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Where every dollar went").barlyText(.product.sectionTitle, color: t.text)
                                Spacer()
                                LegendDot("Revenue", color: t.posColor)
                                LegendDot("Cost", color: t.negColor)
                            }
                            LineChart(Mock.revenueSeries, highlight: 30, tooltipTitle: "JAN 2026", tooltipValue: "$1.36M")
                                .frame(height: 240)
                        }
                    }
                    Card(padding: 0) {
                        VStack(spacing: 0) {
                            HStack {
                                Text("Watchlist").barlyText(.product.sectionTitle, color: t.text)
                                Spacer()
                                Text("ARR").barlyText(.product.label, color: t.text3).frame(width: 90, alignment: .trailing)
                                Text("HEALTH").barlyText(.product.label, color: t.text3).frame(width: 70, alignment: .trailing)
                            }
                            .padding(.horizontal, 20).frame(height: 48)
                            .overlay(alignment: .bottom) { Hairline() }
                            ForEach(ConsoleMock.watch, id: \.0) { r in
                                HStack {
                                    Text(r.0).barlyText(.product.body.weight(500), color: t.text)
                                    Text(r.1).barlyText(.product.label.size(10), color: t.text3).padding(.leading, 8)
                                    Spacer()
                                    Text(r.2).barlyText(.product.body.monospaced, color: t.text).frame(width: 90, alignment: .trailing)
                                    Text("\(r.3)").barlyText(.product.body.monospaced, color: r.3 < 35 ? t.negColor : t.text2).frame(width: 70, alignment: .trailing)
                                }
                                .padding(.horizontal, 20).frame(height: 44)
                                .overlay(alignment: .bottom) { Hairline() }
                            }
                        }
                    }
                }
                .padding(BarlyMetrics.contentPad)
            }
        }
    }
}

struct MetricsInspector: View {
    @State private var hiring = true
    @State private var fx = false
    @Environment(\.barly) private var t
    var body: some View {
        InspectorSection("Scenario") {
            VStack(spacing: 10) {
                KeyValueRow(key: "Base", value: "Board plan")
                KeyValueRow(key: "Hiring", value: "+14 FTE", mono: true)
                KeyValueRow(key: "Price change", value: "+6% Jan", mono: true)
            }
            Toggle(isOn: $hiring) { HStack { Text("Freeze hiring in Q1").barlyText(.product.body, color: t.text2); Spacer() } }.toggleStyle(.barly)
            Toggle(isOn: $fx) { HStack { Text("FX hedge").barlyText(.product.body, color: t.text2); Spacer() } }.toggleStyle(.barly)
        }
        InspectorSection("Runway") {
            Text("50.2 months").barlyText(BarlyTokens.Product.heroNumber.monospaced, color: t.text)
            ProgressBar(0.72, height: 4)
            Text("At current burn; 41.6 with hiring plan.").barlyText(.product.caption, color: t.text3)
        }
    }
}
