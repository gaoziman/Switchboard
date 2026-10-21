import SwiftUI
import BarlyKit

/// 侧栏「已打开」视图：按标签栏顺序、按项目分组列出本窗口的标签。
/// 组标题 = 组色项目名 · 主机 · 标签数；⌘-click / ⇧-click 多选后底部出现「关闭 N 个标签…」
struct OpenTabsList: View {
    @Bindable var store: WorkspaceStore
    @Environment(\.barly) private var t

    var body: some View {
        VStack(spacing: 0) {
            BarlyScroll {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(store.tabGroups) { group in
                        GroupHeading(group: group, host: store.host(group.tabs.first?.hostID ?? Host.localID)) {
                            store.toggleCollapsed(group)
                        }
                        if !group.isCollapsed {
                            ForEach(group.tabs) { tab in
                                OpenTabRow(tab: tab,
                                           current: store.selectedTab?.id == tab.id,
                                           picked: store.openTabSelection.contains(tab.id)) {
                                    store.selection = .tab(tab.id)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 12)
            }
            if !store.openTabSelection.isEmpty {
                selectionBar
            }
        }
    }

    private var selectionBar: some View {
        HStack(spacing: 8) {
            Text("已选 \(store.openTabSelection.count) 个").barlyText(.product.small, color: t.text2)
            Spacer()
            BarlyButton(L("取消"), variant: .ghost, size: .sm) { store.openTabSelection = [] }
            BarlyButton(L("关闭 \(store.openTabSelection.count) 个标签…"), variant: .outline, size: .sm)
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(t.fill1)
        .overlay(alignment: .top) { Hairline() }
    }
}

private struct GroupHeading: View {
    let group: TabGroup
    let host: Host?
    let action: () -> Void
    @Environment(\.barly) private var t

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(t.text4)
                    .rotationEffect(.degrees(group.isCollapsed ? 0 : 90))
                    .frame(width: 10)
                RoundedRectangle(cornerRadius: 1).fill(t.groupColor(group.tint)).frame(width: 3, height: 12)
                Text(group.name).barlyText(.product.small.weight(500), color: t.text)
                if let host, !host.isLocal {
                    Text(host.displayName).barlyText(.product.caption.monospaced, color: t.text4)
                }
                Spacer()
                if group.isCollapsed { ActivityLamp(group.mostUrgent, size: 6) }
                Text("\(group.tabs.count)").barlyText(.product.caption.monospaced, color: t.text4)
            }
            .padding(.horizontal, 8)
            .padding(.top, 10)
            .frame(height: WorkspaceMetrics.row + 10, alignment: .bottom)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .handCursor()
    }
}

private struct OpenTabRow: View {
    let tab: TerminalTab
    let current: Bool
    let picked: Bool
    let action: () -> Void
    @Environment(\.barly) private var t
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if picked {
                    Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundStyle(t.text)
                        .frame(width: 16, height: 16)
                        .background(t.fill3, in: RoundedRectangle(cornerRadius: 3))
                } else if case .session(_, let cli) = tab.kind {
                    CLIMark(cli)
                } else {
                    Image(systemName: "terminal").font(.system(size: 10)).foregroundStyle(t.text3).frame(width: 16)
                }
                Text(tab.title)
                    .barlyText(.product.small.weight(current ? 500 : 400), color: current || picked ? t.text : t.text2)
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text(tab.activity == .notRunning ? "" : tab.activity.shortLabel)
                    .barlyText(.product.caption, color: t.text4)
                ActivityLamp(tab.activity, size: 6)
            }
            .padding(.leading, 26).padding(.trailing, 8)
            .frame(height: WorkspaceMetrics.row)
            .background(!(current || picked) && hovered ? t.fill1 : .clear, in: RoundedRectangle(cornerRadius: BarlyRadius.sm))
            .barlySelected(current || picked, radius: BarlyRadius.sm, idleBorder: .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .handCursor()
        .accessibilityAddTraits(current || picked ? .isSelected : [])
    }
}

extension Activity {
    /// 行尾的短说明（已打开视图、铃铛）
    var shortLabel: String {
        switch self {
        case .notRunning: ""
        case .working: L("工作中")
        case .waitingForAnswer: L("等你")
        case .idle: L("空闲")
        case .doneUnseen: L("已完成")
        case .ended: L("已结束")
        }
    }
}

/// 铃铛：所有窗口里等你的会话，最近的在前。行 = CLI · 标题 · 项目 · 为什么等 · 等了多久
struct BellPopover: View {
    let sessions: [Session]
    let projectName: (Session) -> String
    var onOpen: (Session) -> Void = { _ in }
    @Environment(\.barly) private var t

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("等待你的会话").barlyText(.product.small.weight(500), color: t.text)
                Spacer()
                Text("\(sessions.count)").barlyText(.product.caption.monospaced, color: t.text3)
            }
            .padding(.horizontal, 14)
            .frame(height: 40)
            Hairline()
            if sessions.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("没有在等你的会话").barlyText(.product.small, color: t.text2)
                    Text("CLI 停下来问你、或者在你没看的时候跑完一轮，都会出现在这里。")
                        .barlyText(.product.caption, color: t.text3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
            } else {
                VStack(spacing: 1) {
                    ForEach(sessions) { session in
                        HStack(alignment: .top, spacing: 10) {
                            ActivityLamp(session.activity, size: 7).padding(.top, 3)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(session.displayTitle).barlyText(.product.small.weight(500), color: t.text).lineLimit(1)
                                HStack(spacing: 6) {
                                    CLIMark(session.cli, size: 14)
                                    Text(projectName(session)).barlyText(.product.caption, color: t.text3)
                                    Text("·").barlyText(.product.caption, color: t.text4)
                                    Text(session.activity == .waitingForAnswer ? "等你回答" : "回合已结束")
                                        .barlyText(.product.caption, color: session.activity == .waitingForAnswer ? t.accentText : t.text3)
                                }
                            }
                            Spacer(minLength: 8)
                            RelativeAge(session.lastActivity)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .contentShape(Rectangle())
                        .onTapGesture { onOpen(session) }
                        .handCursor()
                    }
                }
                .padding(4)
            }
        }
        .frame(width: 340)
        .background(t.surface)
        .clipShape(RoundedRectangle(cornerRadius: BarlyRadius.md))
        .overlay(RoundedRectangle(cornerRadius: BarlyRadius.md).stroke(t.borderStrong))
        .shadow(color: .black.opacity(0.45), radius: 20, y: 8)
    }
}
