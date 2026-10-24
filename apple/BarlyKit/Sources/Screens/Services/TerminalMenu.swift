import Foundation
#if os(macOS)
import AppKit
#endif

/// 标签的右键菜单：终端区和标签栏共用一份。终端区多一组文字操作；会话的标签有和侧栏会话菜单一样的会话操作；最后是关标签。
/// 终端区右键不再交给 tmux / CLI
enum TerminalMenu {
    enum Item: Equatable {
        case copy, paste, selectAll
        case rename, aiRename
        case copyConversation, export([TranscriptExport.Format]), copySessionID, revealSessionFile
        case split
        case closeTab, endSession, deleteSession

        var title: String {
            switch self {
            case .copy: L("复制")
            case .paste: L("粘贴")
            case .selectAll: L("全选")
            case .rename: L("重命名")
            case .aiRename: L("AI 重命名…")
            case .copyConversation: L("复制对话")
            case .export: L("导出对话")
            case .copySessionID: L("复制会话 ID")
            case .revealSessionFile: L("在 Finder 中显示会话文件")
            case .split: L("使用当前标签页创建新的拆分视图")
            case .closeTab: L("关闭标签")
            case .endSession: L("关闭并结束会话")
            case .deleteSession: L("关闭并删除会话…")
            }
        }

        var symbol: String {
            switch self {
            case .copy, .copyConversation, .copySessionID: "doc.on.doc"
            case .paste: "doc.on.clipboard"
            case .selectAll: "selection.pin.in.out"
            case .rename: "pencil"
            case .aiRename: "sparkles"
            case .export: "square.and.arrow.up"
            case .revealSessionFile: "doc.text.magnifyingglass"
            case .split: "rectangle.split.2x1"
            case .closeTab: "xmark"
            case .endSession: "stop.circle"
            case .deleteSession: "trash"
            }
        }
    }

    /// session：标签对上的会话（还没认领的新会话、普通终端是 nil）；runsInTmux：CLI 还在 tmux 里开着；canSplit：本窗口还没分屏；
    /// text：带不带文字操作（标签栏上右键没有文字可复制）
    static func sections(session: Session?, runsInTmux: Bool, canSplit: Bool, text: Bool = true) -> [[Item]] {
        var sections: [[Item]] = text ? [[.copy, .paste, .selectAll]] : []
        if let session {
            let hasFile = session.sourcePath != nil && session.cli != .opencode
            sections.append([.rename, .aiRename])
            sections.append([.copyConversation, .export(hasFile ? [.markdown, .plainText, .original] : [.markdown, .plainText]), .copySessionID]
                            + (hasFile && session.hostID == Host.localID ? [.revealSessionFile] : []))
        }
        if canSplit { sections.append([.split]) }
        sections.append([.closeTab] + (runsInTmux ? [.endSession] : []) + (session != nil ? [.deleteSession] : []))
        return sections
    }

    /// 这个窗口里的这个标签现在该有哪些项（「还在 tmux 里跑」和关标签时的判断一样：有 tmux 名字、没出退出横幅）
    @MainActor
    static func sections(for tab: TerminalTab, in store: WorkspaceStore, text: Bool) -> [[Item]] {
        sections(session: store.session(for: tab),
                 runsInTmux: store.launches[tab.id]?.tmuxName != nil && store.tabBanners[tab.id] == nil,
                 canSplit: store.split == nil, text: text)
    }

    static func exportTitle(_ format: TranscriptExport.Format) -> String {
        switch format {
        case .markdown: "Markdown…"
        case .plainText: L("纯文本…")
        case .original: L("原始会话文件…")
        }
    }

    /// 会话和标签的操作（文字操作、导出的子菜单不走这里）
    @MainActor
    static func perform(_ item: Item, tab: TerminalTab, in store: WorkspaceStore) {
        let session = store.session(for: tab)
        switch item {
        case .rename: if let session { store.presentation = .renameSession(session) }
        case .aiRename: if let session { store.presentation = .nameSuggestions(session) }
        case .copyConversation: if let session { Task { await store.copyConversation(session) } }
        case .copySessionID:
            #if os(macOS)
            if let session {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(session.id, forType: .string)
            }
            #endif
        case .revealSessionFile:
            #if os(macOS)
            if let path = session?.sourcePath { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)]) }
            #endif
        case .split:
            store.selection = .tab(tab.id)
            store.startSplit()
        case .closeTab: store.requestClose(tab)
        case .endSession: store.close(tab, keepRunning: false)
        case .deleteSession: if let session { store.presentation = .confirmDelete([session]) }
        case .copy, .paste, .selectAll, .export: break
        }
    }

    @MainActor
    static func export(_ format: TranscriptExport.Format, tab: TerminalTab, in store: WorkspaceStore) {
        guard let session = store.session(for: tab) else { return }
        Task { await store.exportConversation(session, as: format) }
    }
}

#if os(macOS)
extension TerminalMenu {
    /// 终端区右键：每次现建（标签可能刚搬了窗口、刚认领上会话）。截图用的假 store 不登记窗口，只剩文字操作
    @MainActor
    static func menu(for terminal: any EngineTerminalView) -> NSMenu {
        let store = terminal.tabID.flatMap { WorkspaceWindows.owner(ofTab: $0) }
        let tab = terminal.tabID.flatMap { store?.tab($0) }
        let sections: [[Item]] = if let store, let tab { Self.sections(for: tab, in: store, text: true) } else { [[.copy, .paste, .selectAll]] }

        let menu = NSMenu()
        for (i, section) in sections.enumerated() {
            if i > 0 { menu.addItem(.separator()) }
            for item in section {
                let m: NSMenuItem
                switch item {
                case .copy, .paste, .selectAll:
                    // 发给这个终端（分屏时键盘可能在另一边）；能不能点由终端自己判断（没选中文字时「复制」灰掉）
                    let (selector, key) = switch item {
                    case .copy: (#selector(NSText.copy(_:)), "c")
                    case .paste: (#selector(NSText.paste(_:)), "v")
                    default: (#selector(NSText.selectAll(_:)), "a")
                    }
                    m = NSMenuItem(title: item.title, action: selector, keyEquivalent: key)
                    m.target = terminal
                case .export(let formats):
                    m = NSMenuItem(title: item.title, action: nil, keyEquivalent: "")
                    let sub = NSMenu()
                    for format in formats {
                        sub.addItem(ClosureMenuItem(exportTitle(format)) { if let store, let tab { export(format, tab: tab, in: store) } })
                    }
                    m.submenu = sub
                default:
                    m = ClosureMenuItem(item.title) { if let store, let tab { perform(item, tab: tab, in: store) } }
                }
                m.image = NSImage(systemSymbolName: item.symbol, accessibilityDescription: nil)
                menu.addItem(m)
            }
        }
        return menu
    }
}
#endif
