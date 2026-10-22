import SwiftUI
import BarlyKit

/// 会话库里还没有本机文件夹：一句说明 + 「添加文件夹…」+ 最近有会话的几个文件夹，点一下就加
struct FolderEmptyState: View {
    @Bindable var store: WorkspaceStore
    var onAdd: () -> Void
    @Environment(\.barly) private var t

    /// 推荐：没加过、文件夹还在、不是临时目录的，最近的 5 个
    private var suggestions: [FolderLibrary.Candidate] {
        store.folderCandidates(on: Host.localID)
            .filter { !store.isInLibrary($0.id) && $0.folderExists && !FolderLibrary.isScratch($0.path) }
            .prefix(5).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "folder.badge.plus").font(.system(size: BarlyScale.pt(16))).foregroundStyle(t.text3)
            Text("添加一个文件夹").barlyText(.product.small.weight(500), color: t.text)
            Text("侧栏只显示你添加的文件夹和它们的会话。也可以把文件夹从访达拖到这里。")
                .barlyText(.product.caption, color: t.text3)
                .fixedSize(horizontal: false, vertical: true)
            BarlyButton(L("添加文件夹…"), icon: "plus", variant: .outline, size: .sm, action: onAdd)
                .padding(.top, 2)
            if !suggestions.isEmpty {
                Text("最近用过").barlyText(.product.caption, color: t.text3).padding(.top, 14)
                VStack(spacing: 1) {
                    ForEach(suggestions) { c in
                        SuggestionRow(candidate: c) { store.addFolder(c.path) }
                    }
                }
                .padding(.horizontal, -8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 18).padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .task { if store.isLive, store.folderCandidates(on: Host.localID).isEmpty { await store.loadFolderCandidates(on: Host.localID) } }
    }
}

private struct SuggestionRow: View {
    let candidate: FolderLibrary.Candidate
    let action: () -> Void
    @Environment(\.barly) private var t
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus").font(.system(size: BarlyScale.pt(9), weight: .bold)).foregroundStyle(hovered ? t.text : t.text4)
                    .frame(width: 12)
                Text(candidate.name).barlyText(.product.small, color: t.text2).lineLimit(1)
                Text("\(candidate.sessionCount)").barlyText(.product.caption.monospaced, color: t.text4)
                Spacer(minLength: 6)
                RelativeAge(candidate.lastActivity)
            }
            .padding(.horizontal, 8)
            .frame(height: WorkspaceMetrics.row)
            .background(hovered ? t.fill1 : .clear, in: RoundedRectangle(cornerRadius: WorkspaceMetrics.rowRadius))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .handCursor()
        .help(L("添加 \(candidate.path)"))
    }
}

/// 从发现过会话的文件夹里勾选：升级后的一次挑选、SSH 主机的「添加文件夹…」共用
struct FolderPickerSheet: View {
    let title: String
    let subtitle: String
    let candidates: [FolderLibrary.Candidate]
    /// 已经在会话库里的：勾着、灰掉
    var added: Set<ProjectID> = []
    /// SSH 主机：允许手动输入一个路径（主机上还没会话的文件夹）
    var allowsPath = false
    /// 正在读候选（SSH 主机镜像）
    var loading = false
    let secondaryTitle: String
    let onSecondary: () -> Void
    let onDone: ([ProjectID], String?) -> Void
    @State private var picked: Set<ProjectID>
    @State private var query = ""
    @State private var path = ""
    @Environment(\.barly) private var t

    init(title: String, subtitle: String, candidates: [FolderLibrary.Candidate], initial: [ProjectID] = [],
         added: Set<ProjectID> = [], allowsPath: Bool = false, loading: Bool = false,
         secondaryTitle: String, onSecondary: @escaping () -> Void, onDone: @escaping ([ProjectID], String?) -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.candidates = candidates
        self.added = added
        self.allowsPath = allowsPath
        self.loading = loading
        self.secondaryTitle = secondaryTitle
        self.onSecondary = onSecondary
        self.onDone = onDone
        _picked = State(initialValue: Set(initial))
    }

    private var shown: [FolderLibrary.Candidate] {
        let q = query.trimmingCharacters(in: .whitespaces)
        return q.isEmpty ? candidates : candidates.filter { $0.path.localizedStandardContains(q) }
    }

    /// 保持候选列表的顺序（最近的在前）
    private var pickedInOrder: [ProjectID] { candidates.map(\.id).filter { picked.contains($0) && !added.contains($0) } }

    private var manualPath: String? {
        let p = path.trimmingCharacters(in: .whitespaces)
        return p.hasPrefix("/") ? p : nil
    }

    private var confirmCount: Int { pickedInOrder.count + (manualPath == nil ? 0 : 1) }

    var body: some View {
        SheetFrame(title: title, subtitle: subtitle, width: 560) {
            VStack(alignment: .leading, spacing: 10) {
                if candidates.count > 8 {
                    BarlyBareField(placeholder: L("筛选路径"), text: $query, style: .product.small)
                        .padding(.horizontal, 8)
                        .frame(height: BarlyScale.pt(28))
                        .background(t.fieldBg, in: RoundedRectangle(cornerRadius: WorkspaceMetrics.rowRadius))
                        .overlay(RoundedRectangle(cornerRadius: WorkspaceMetrics.rowRadius).stroke(t.borderStrong))
                }
                if loading && candidates.isEmpty {
                    HStack(spacing: 8) {
                        ActivityLamp(.working, size: 6)
                        Text("正在读取主机上的会话…").barlyText(.product.small, color: t.text3)
                    }
                    .frame(height: 60)
                } else if candidates.isEmpty {
                    Text(allowsPath ? "主机上还没有发现会话，可以直接填一个文件夹路径。" : "没有发现会话。")
                        .barlyText(.product.small, color: t.text3)
                        .frame(height: 40)
                } else {
                    BarlyScroll {
                        LazyVStack(spacing: 1) {
                            ForEach(shown) { c in row(c) }
                        }
                    }
                    .frame(height: min(CGFloat(shown.count) * (WorkspaceMetrics.row + 13), BarlyScale.pt(340)))
                }
                if allowsPath {
                    HStack(spacing: 8) {
                        Text("路径").barlyText(.product.small, color: t.text3)
                        BarlyBareField(placeholder: "/home/me/project", text: $path, style: .product.small.monospaced)
                            .padding(.horizontal, 8)
                            .frame(height: BarlyScale.pt(28))
                            .background(t.fieldBg, in: RoundedRectangle(cornerRadius: WorkspaceMetrics.rowRadius))
                            .overlay(RoundedRectangle(cornerRadius: WorkspaceMetrics.rowRadius).stroke(t.borderStrong))
                    }
                    .padding(.top, 4)
                }
            }
        } buttons: {
            BarlyButton(secondaryTitle, variant: .ghost, size: .md, action: onSecondary)
                .keyboardShortcut(.cancelAction)
            Spacer()
            BarlyButton(confirmCount > 0 ? L("添加 \(confirmCount) 个") : L("完成"), variant: .primary, size: .md) {
                onDone(pickedInOrder, manualPath)
            }
            .keyboardShortcut(.defaultAction)
        }
    }

    private func row(_ c: FolderLibrary.Candidate) -> some View {
        let isAdded = added.contains(c.id)
        let on = isAdded || picked.contains(c.id)
        return HStack(spacing: 10) {
            Checkbox(on)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(c.name).barlyText(.product.small.weight(500), color: isAdded ? t.text3 : t.text).lineLimit(1)
                    Text("\(c.sessionCount)").barlyText(.product.caption.monospaced, color: t.text4)
                    if !c.folderExists {
                        Text("文件夹不在了").barlyText(.product.caption, color: t.warning)
                    } else if isAdded {
                        Text("已添加").barlyText(.product.caption, color: t.text4)
                    }
                }
                Text(c.path).barlyText(.product.caption, color: t.text4).lineLimit(1).truncationMode(.head)
            }
            Spacer(minLength: 8)
            RelativeAge(c.lastActivity)
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .contentShape(Rectangle())
        .tapButton {
            guard !isAdded else { return }
            if picked.contains(c.id) { picked.remove(c.id) } else { picked.insert(c.id) }
        }
        .handCursor()
        .opacity(isAdded ? 0.7 : 1)
    }
}

/// 侧栏底部：库外有会话在跑（Claude 自己报的工作目录）→ 添加 / 忽略
struct OutsideRunningBar: View {
    let outside: FolderLibrary.Outside
    let onAdd: () -> Void
    let onDismiss: () -> Void
    @Environment(\.barly) private var t

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ActivityLamp(.working, size: 5).padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: L("「\(outside.name)」里有 \(outside.count) 个会话在跑"))
                    .barlyText(.product.caption.weight(500), color: t.text2)
                    .lineLimit(1)
                Text(outside.path).barlyText(.product.caption, color: t.text4).lineLimit(1).truncationMode(.head)
                HStack(spacing: 6) {
                    BarlyButton(L("添加到侧栏"), variant: .outline, size: .sm, action: onAdd)
                    BarlyButton(L("忽略"), variant: .ghost, size: .sm, action: onDismiss)
                }
                .padding(.top, 3)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .sidebarCard()
    }
}

/// 升级到「手动添加文件夹」：主窗口弹一次挑选（只弹这一次）
struct FolderMigration: ViewModifier {
    let store: WorkspaceStore

    func body(content: Content) -> some View {
        content.sheet(isPresented: Binding(get: { store.migrationCandidates != nil && store.isPrimary }, set: { _ in })) {
            FolderPickerSheet(title: L("侧栏改为只显示你添加的文件夹"),
                              subtitle: L("从发现过会话的文件夹里挑要保留的；以后可以随时添加或移除，会话文件不受影响。"),
                              candidates: store.migrationCandidates ?? [], initial: store.migrationPicks,
                              secondaryTitle: L("全都不要"), onSecondary: { store.finishMigration(picked: []) }) { picked, _ in
                store.finishMigration(picked: picked)
            }
            .interactiveDismissDisabled()
        }
    }
}
