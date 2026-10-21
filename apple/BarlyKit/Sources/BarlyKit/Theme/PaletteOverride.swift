// 由 apple/scripts/gen-palette-override.py 生成：身份重新生成后重跑，不要手改
import SwiftUI

public extension BarlyPalette {
    /// 色板里的每一个颜色
    enum Key: String, CaseIterable, Sendable {
        case bg
        case bgSubtle
        case bgMuted
        case surface
        case surfaceRaised
        case surfaceTop
        case border
        case borderStrong
        case divider
        case text
        case text2
        case text3
        case text4
        case ink
        case inkFg
        case inkHover
        case inkGradientFrom
        case inkGradientTo
        case inkEdge
        case accent
        case accentHover
        case accentFg
        case accentSoft
        case accentSoftFg
        case accentText
        case accentGradientFrom
        case accentGradientTo
        case accentGlow
        case tooltipFrom
        case tooltipTo
        case overlay
        case success
        case successSoft
        case successFg
        case danger
        case dangerSoft
        case dangerFg
        case warning
        case warningSoft
        case warningFg
        case info
        case infoSoft
        case infoFg
        case primary
        case primaryFg
        case headline2
        case dataDeep
        case dataBase
        case dataLight
        case dataFaint
        case dataNeutral
        case dataPos
        case dataNeg
        case nameGradientFrom
        case nameGradientTo
        case chipIconDocs
        case chipIconSummarize
        case chipIconNews
        case chipIconVoice
        case chipIconIdea
        case chipIconImage
        case codeBg
        case codeHeader
        case codeText
        case codeComment
        case codeKeyword
        case codeString
        case codeNumber
        case orbHighlight
        case orbMid
        case orbShadow
        case orbGlow
        case chartLine
        case chartAreaFrom
        case chartAreaTo
        case chartGrid
        case chartCompare
        case canvas
        case sidebarBg
        case slot
        case navSelectedFrom
        case navSelectedTo
        case navSelectedFg
        case bannerBg
        case bannerBorder
        case bannerFg
        case tile1
        case tile2
        case tile3
        case tile4
        case tile5
        case tile6
        case chartEmpty
        case cta
        case ctaFg
        case ctaHover
        case selectedBg
        case selectedFg
        case selectedBorder
        case selectedMark
        case paper
        case pastel1
        case pastel2
        case pastel3
    }

    /// 以这套色板为底，换掉给出的颜色（app 主题用：外壳换色，代码高亮、图表色保留身份的）
    func replacing(_ o: [Key: Color]) -> BarlyPalette {
        BarlyPalette(
            bg: o[.bg] ?? bg,
            bgSubtle: o[.bgSubtle] ?? bgSubtle,
            bgMuted: o[.bgMuted] ?? bgMuted,
            surface: o[.surface] ?? surface,
            surfaceRaised: o[.surfaceRaised] ?? surfaceRaised,
            surfaceTop: o[.surfaceTop] ?? surfaceTop,
            border: o[.border] ?? border,
            borderStrong: o[.borderStrong] ?? borderStrong,
            divider: o[.divider] ?? divider,
            text: o[.text] ?? text,
            text2: o[.text2] ?? text2,
            text3: o[.text3] ?? text3,
            text4: o[.text4] ?? text4,
            ink: o[.ink] ?? ink,
            inkFg: o[.inkFg] ?? inkFg,
            inkHover: o[.inkHover] ?? inkHover,
            inkGradientFrom: o[.inkGradientFrom] ?? inkGradientFrom,
            inkGradientTo: o[.inkGradientTo] ?? inkGradientTo,
            inkEdge: o[.inkEdge] ?? inkEdge,
            accent: o[.accent] ?? accent,
            accentHover: o[.accentHover] ?? accentHover,
            accentFg: o[.accentFg] ?? accentFg,
            accentSoft: o[.accentSoft] ?? accentSoft,
            accentSoftFg: o[.accentSoftFg] ?? accentSoftFg,
            accentText: o[.accentText] ?? accentText,
            accentGradientFrom: o[.accentGradientFrom] ?? accentGradientFrom,
            accentGradientTo: o[.accentGradientTo] ?? accentGradientTo,
            accentGlow: o[.accentGlow] ?? accentGlow,
            tooltipFrom: o[.tooltipFrom] ?? tooltipFrom,
            tooltipTo: o[.tooltipTo] ?? tooltipTo,
            overlay: o[.overlay] ?? overlay,
            success: o[.success] ?? success,
            successSoft: o[.successSoft] ?? successSoft,
            successFg: o[.successFg] ?? successFg,
            danger: o[.danger] ?? danger,
            dangerSoft: o[.dangerSoft] ?? dangerSoft,
            dangerFg: o[.dangerFg] ?? dangerFg,
            warning: o[.warning] ?? warning,
            warningSoft: o[.warningSoft] ?? warningSoft,
            warningFg: o[.warningFg] ?? warningFg,
            info: o[.info] ?? info,
            infoSoft: o[.infoSoft] ?? infoSoft,
            infoFg: o[.infoFg] ?? infoFg,
            primary: o[.primary] ?? primary,
            primaryFg: o[.primaryFg] ?? primaryFg,
            headline2: o[.headline2] ?? headline2,
            dataDeep: o[.dataDeep] ?? dataDeep,
            dataBase: o[.dataBase] ?? dataBase,
            dataLight: o[.dataLight] ?? dataLight,
            dataFaint: o[.dataFaint] ?? dataFaint,
            dataNeutral: o[.dataNeutral] ?? dataNeutral,
            dataPos: o[.dataPos] ?? dataPos,
            dataNeg: o[.dataNeg] ?? dataNeg,
            nameGradientFrom: o[.nameGradientFrom] ?? nameGradientFrom,
            nameGradientTo: o[.nameGradientTo] ?? nameGradientTo,
            chipIconDocs: o[.chipIconDocs] ?? chipIconDocs,
            chipIconSummarize: o[.chipIconSummarize] ?? chipIconSummarize,
            chipIconNews: o[.chipIconNews] ?? chipIconNews,
            chipIconVoice: o[.chipIconVoice] ?? chipIconVoice,
            chipIconIdea: o[.chipIconIdea] ?? chipIconIdea,
            chipIconImage: o[.chipIconImage] ?? chipIconImage,
            codeBg: o[.codeBg] ?? codeBg,
            codeHeader: o[.codeHeader] ?? codeHeader,
            codeText: o[.codeText] ?? codeText,
            codeComment: o[.codeComment] ?? codeComment,
            codeKeyword: o[.codeKeyword] ?? codeKeyword,
            codeString: o[.codeString] ?? codeString,
            codeNumber: o[.codeNumber] ?? codeNumber,
            orbHighlight: o[.orbHighlight] ?? orbHighlight,
            orbMid: o[.orbMid] ?? orbMid,
            orbShadow: o[.orbShadow] ?? orbShadow,
            orbGlow: o[.orbGlow] ?? orbGlow,
            chartLine: o[.chartLine] ?? chartLine,
            chartAreaFrom: o[.chartAreaFrom] ?? chartAreaFrom,
            chartAreaTo: o[.chartAreaTo] ?? chartAreaTo,
            chartGrid: o[.chartGrid] ?? chartGrid,
            chartCompare: o[.chartCompare] ?? chartCompare,
            canvas: o[.canvas] ?? canvas,
            sidebarBg: o[.sidebarBg] ?? sidebarBg,
            slot: o[.slot] ?? slot,
            navSelectedFrom: o[.navSelectedFrom] ?? navSelectedFrom,
            navSelectedTo: o[.navSelectedTo] ?? navSelectedTo,
            navSelectedFg: o[.navSelectedFg] ?? navSelectedFg,
            bannerBg: o[.bannerBg] ?? bannerBg,
            bannerBorder: o[.bannerBorder] ?? bannerBorder,
            bannerFg: o[.bannerFg] ?? bannerFg,
            tile1: o[.tile1] ?? tile1,
            tile2: o[.tile2] ?? tile2,
            tile3: o[.tile3] ?? tile3,
            tile4: o[.tile4] ?? tile4,
            tile5: o[.tile5] ?? tile5,
            tile6: o[.tile6] ?? tile6,
            chartEmpty: o[.chartEmpty] ?? chartEmpty,
            cta: o[.cta] ?? cta,
            ctaFg: o[.ctaFg] ?? ctaFg,
            ctaHover: o[.ctaHover] ?? ctaHover,
            selectedBg: o[.selectedBg] ?? selectedBg,
            selectedFg: o[.selectedFg] ?? selectedFg,
            selectedBorder: o[.selectedBorder] ?? selectedBorder,
            selectedMark: o[.selectedMark] ?? selectedMark,
            paper: o[.paper] ?? paper,
            pastel1: o[.pastel1] ?? pastel1,
            pastel2: o[.pastel2] ?? pastel2,
            pastel3: o[.pastel3] ?? pastel3
        )
    }
}
