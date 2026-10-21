#if os(macOS)
import AppKit
#endif
import SwiftUI
import BarlyKit

/// sheet 的外框：标题区 · 内容 · 底部按钮条。真 app 里放进 `.sheet`，截图时由 `SheetOverlay` 叠在工作区上
struct SheetFrame<Content: View, Buttons: View>: View {
    let title: String
    var subtitle: String?
    var width: CGFloat = 520
    @ViewBuilder var content: Content
    @ViewBuilder var buttons: Buttons
    @Environment(\.barly) private var t

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).barlyText(.product.sectionTitle, color: t.text)
                if let subtitle { Text(subtitle).barlyText(.product.small, color: t.text3) }
            }
            .padding(.horizontal, 22).padding(.top, 20).padding(.bottom, 16)
            content
                .padding(.horizontal, 22)
                .padding(.bottom, 18)
            Hairline()
            HStack(spacing: 8) { buttons }
                .padding(.horizontal, 16)
                .frame(height: 56)
        }
        .frame(width: width)
        .background(t.surface)
    }
}

/// 截图用：把 sheet 叠在暗下去的工作区上，位置和系统 sheet 一样（窗口上沿居中）
struct SheetOverlay<Base: View, Sheet: View>: View {
    @ViewBuilder var base: Base
    @ViewBuilder var sheet: Sheet
    @Environment(\.barly) private var t

    var body: some View {
        base
            .overlay(Color.black.opacity(0.45))
            .overlay(alignment: .top) {
                sheet
                    .clipShape(RoundedRectangle(cornerRadius: BarlyRadius.md))
                    .overlay(RoundedRectangle(cornerRadius: BarlyRadius.md).stroke(t.borderStrong))
                    .shadow(color: .black.opacity(0.5), radius: 30, y: 12)
                    .padding(.top, 72)
            }
    }
}

/// 表单一行：左标签固定宽，右控件
struct FieldRow<Control: View>: View {
    let label: String
    var note: String?
    @ViewBuilder var control: Control
    @Environment(\.barly) private var t

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(label).barlyText(.product.small, color: t.text2)
                .frame(width: 72, alignment: .leading)
            VStack(alignment: .leading, spacing: 6) {
                control
                if let note { Text(note).barlyText(.product.caption, color: t.text3).fixedSize(horizontal: false, vertical: true) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// 静态值框（下拉 / 路径）：fieldBg + 边，右侧一个小图标
struct ValueBox: View {
    let text: String
    var icon: String? = "chevron.up.chevron.down"
    var mono = false
    var dim = false
    var error = false
    @Environment(\.barly) private var t

    var body: some View {
        HStack(spacing: 8) {
            Text(text)
                .barlyText(mono ? .product.small.monospaced : .product.small, color: dim ? t.text3 : t.text)
                .lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 4)
            if let icon { Image(systemName: icon).font(.system(size: 10, weight: .medium)).foregroundStyle(t.text3) }
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(t.fieldBg, in: RoundedRectangle(cornerRadius: BarlyRadius.sm))
        .overlay(RoundedRectangle(cornerRadius: BarlyRadius.sm).stroke(error ? t.danger : t.borderStrong))
        .handCursor()
    }
}

// MARK: - 新会话

public struct NewSessionSheet: View {
    public enum Fixture: String { case normal, editing, invalidCommand, missingFolder }

    @Binding var draft: NewSessionDraft
    let fixture: Fixture
    var installed: [CLIKind] = CLIKind.allCases
    var recentFolders: [String] = []
    /// 能选的主机（这台 Mac + 连着的 SSH 主机）
    var hosts: [Host] = []
    /// 某台主机最近用过的文件夹
    var recentFoldersFor: (String) -> [String] = { _ in [] }
    var savedCommandFor: (CLIKind) -> String? = { _ in nil }
    var onCancel: () -> Void = {}
    var onStart: () -> Void = {}
    @Environment(\.barly) private var t
    @Environment(\.barlySnapshot) private var snapshot

    /// 截图用：固定草稿
    public init(draft: NewSessionDraft, fixture: Fixture = .normal) {
        _draft = .constant(draft)
        self.fixture = fixture
    }

    /// app 里用：可编辑
    public init(draft: Binding<NewSessionDraft>, installed: [CLIKind], recentFolders: [String],
                savedCommandFor: @escaping (CLIKind) -> String? = { _ in nil },
                hosts: [Host] = [], recentFoldersFor: @escaping (String) -> [String] = { _ in [] },
                onCancel: @escaping () -> Void, onStart: @escaping () -> Void) {
        self.savedCommandFor = savedCommandFor
        self.hosts = hosts
        self.recentFoldersFor = recentFoldersFor
        _draft = draft
        fixture = .normal
        self.installed = installed
        self.recentFolders = recentFolders
        self.onCancel = onCancel
        self.onStart = onStart
    }

    private var expandedFolder: String { (draft.folder as NSString).expandingTildeInPath }
    private var isRemote: Bool { draft.hostID != Host.localID }
    /// 当前主机装了的 CLI
    private var hostCLIs: [CLIKind] { isRemote ? (hosts.first { $0.id == draft.hostID }?.installedCLIs ?? CLIKind.allCases) : installed }
    private var folders: [String] { isRemote ? recentFoldersFor(draft.hostID) : recentFolders }
    private var folderExists: Bool {
        if fixture == .missingFolder { return false }
        if isRemote { return true }   // 主机上的目录启动时由主机检查
        var isDir: ObjCBool = false
        return snapshot || draft.folder.isEmpty || (FileManager.default.fileExists(atPath: expandedFolder, isDirectory: &isDir) && isDir.boolValue)
    }
    private var problem: String? { draft.startProblem(folderExists: folderExists) }

    public var body: some View {
        SheetFrame(title: L("新会话"), subtitle: L("在项目文件夹里启动一个 CLI，会话立刻出现在侧栏。")) {
            VStack(alignment: .leading, spacing: 16) {
                FieldRow(label: L("主机"), note: isRemote ? L("路径是主机上的；~ 是主机的家目录。主机上的会话用它自己的 tmux。") : nil) {
                    if hosts.count > 1 {
                        Picker("", selection: $draft.hostID) {
                            ForEach(hosts) { Text($0.isLocal ? L("这台 Mac") : $0.displayName).tag($0.id) }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .handCursor()
                        .onChange(of: draft.hostID) { _, _ in
                            draft.folder = ""
                            if case .cli(let cli) = draft.target, !hostCLIs.contains(cli) { draft.target = hostCLIs.first.map { .cli($0) } ?? .terminal }
                        }
                    } else {
                        ValueBox(text: L("这台 Mac"))
                    }
                }
                FieldRow(label: L("启动")) { targetPicker }
                FieldRow(label: L("文件夹"), note: folderNote) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            HStack {
                                BarlyBareField(placeholder: L("~/code/项目"), text: $draft.folder, style: .product.small.monospaced)
                            }
                            .padding(.horizontal, 10)
                            .frame(height: 30)
                            .background(t.fieldBg, in: RoundedRectangle(cornerRadius: BarlyRadius.sm))
                            .overlay(RoundedRectangle(cornerRadius: BarlyRadius.sm)
                                .stroke(!folderExists ? t.danger : t.borderStrong))
                            if !isRemote { BarlyButton(L("选择…"), variant: .outline, size: .sm, action: chooseFolder) }
                        }
                        if !folders.isEmpty {
                            HStack(spacing: 6) {
                                ForEach(folders.prefix(4), id: \.self) { folder in
                                    Text((folder as NSString).lastPathComponent)
                                        .barlyText(.product.caption, color: t.text2)
                                        .padding(.horizontal, 8).frame(height: 22)
                                        .barlySelected(expandedFolder == folder || draft.folder == folder, radius: BarlyRadius.xs, idleFill: t.fill1)
                                        .onTapGesture { draft.folder = isRemote ? folder : abbreviate(folder) }
                                        .handCursor()
                                        .help(folder)
                                }
                            }
                        }
                    }
                }
                FieldRow(label: L("启动命令"), note: commandNote) { commandField }
            }
        } buttons: {
            if fixture == .missingFolder {
                Text("文件夹会连同缺失的上级一起创建").barlyText(.product.caption, color: t.text3)
            } else if let problem, !draft.folder.isEmpty {
                Text(problem).barlyText(.product.caption, color: t.text3)
            } else {
                KeyCombo(["⌘", "↩"]).opacity(0.8)
            }
            Spacer()
            BarlyButton(L("取消"), variant: .ghost, size: .md, action: onCancel)
                .keyboardShortcut(.cancelAction)
            BarlyButton(!folderExists ? L("创建文件夹并开始") : L("开始会话"), variant: .primary, size: .md) {
                if !folderExists { try? FileManager.default.createDirectory(atPath: expandedFolder, withIntermediateDirectories: true) }
                onStart()
            }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(draft.isEditingCommand || draft.folder.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(fixture == .editing || fixture == .invalidCommand || draft.folder.isEmpty ? 0.4 : 1)
        }
    }

    private var targetPicker: some View {
        let options: [(NewSessionDraft.Target, String)] =
            CLIKind.allCases.filter { hostCLIs.contains($0) }.map { (.cli($0), $0.title) } + [(.terminal, L("终端"))]
        return HStack(spacing: 6) {
            ForEach(options, id: \.1) { option in
                let on = option.0 == draft.target
                VStack(spacing: 6) {
                    if case .cli(let cli) = option.0 {
                        CLIMark(cli, size: 18)
                    } else {
                        Image(systemName: "terminal").font(.system(size: 12)).foregroundStyle(t.text2).frame(height: 18)
                    }
                    Text(option.1).barlyText(.product.caption.weight(on ? 500 : 400), color: on ? t.text : t.text2)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .barlySelectCard(on, radius: BarlyRadius.sm, mark: false, idleFill: t.fill1)
                .contentShape(Rectangle())
                .onTapGesture {
                    draft.target = option.0
                    if case .cli(let cli) = option.0 { draft.savedCommand = savedCommandFor(cli) } else { draft.savedCommand = nil }
                    draft.editingCommand = nil
                }
                .handCursor()
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    private var folderNote: String? {
        if !folderExists { return L("这台 Mac 上没有 \(draft.folder)。") }
        return draft.target == .terminal ? L("终端不是会话：不进会话库、不走 tmux，关标签就结束。") : nil
    }

    private var commandNote: String? {
        switch fixture {
        case .invalidCommand:
            return NewSessionDraft.commandProblem(draft.editingCommand ?? "")
        case .editing:
            return L("像在 shell 里那样写；引号、~、前置 NAME=value 都行，别名不行。Switchboard 会在后面补上自己的参数（比如要恢复的会话）。")
        default:
            if let editing = draft.editingCommand, let problem = NewSessionDraft.commandProblem(editing) { return problem }
            return draft.savedCommand == nil ? L("空着就用默认命令。这个 CLI 在这台主机上恢复、分叉都会用它。") : nil
        }
    }

    @ViewBuilder private var commandField: some View {
        if draft.editingCommand != nil {
            let editing = Binding(get: { draft.editingCommand ?? "" }, set: { draft.editingCommand = $0 })
            let invalid = fixture == .invalidCommand || NewSessionDraft.commandProblem(editing.wrappedValue) != nil
            HStack(spacing: 6) {
                HStack {
                    BarlyBareField(placeholder: draft.effectiveCommand, text: editing, style: .product.small.monospaced)
                }
                .padding(.horizontal, 10)
                .frame(height: 30)
                .background(t.fieldBg, in: RoundedRectangle(cornerRadius: BarlyRadius.sm))
                .overlay(RoundedRectangle(cornerRadius: BarlyRadius.sm).stroke(invalid ? t.danger : t.text3, lineWidth: invalid ? 1 : 1.5))
                BarlyButton(L("取消"), variant: .ghost, size: .sm) { draft.editingCommand = nil }
                BarlyButton(L("保存"), variant: .outline, size: .sm) {
                    guard !invalid else { return }
                    let trimmed = editing.wrappedValue.trimmingCharacters(in: .whitespaces)
                    draft.savedCommand = trimmed.isEmpty ? nil : trimmed
                    draft.editingCommand = nil
                }
            }
        } else {
            HStack(spacing: 6) {
                ValueBox(text: draft.savedCommand ?? draft.effectiveCommand, icon: "lock", mono: true, dim: draft.savedCommand == nil)
                BarlyButton(L("编辑"), variant: .outline, size: .sm) { draft.editingCommand = draft.savedCommand ?? "" }
                    .disabled(draft.target == .terminal || isRemote)
                    .help(isRemote ? "主机上用 CLI 的默认命令（按主机保存命令以后支持）" : "")
            }
        }
    }

    private func abbreviate(_ path: String) -> String {
        let home = NSHomeDirectory()
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    private func chooseFolder() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = L("选择")
        if panel.runModal() == .OK, let url = panel.url { draft.folder = abbreviate(url.path) }
        #endif
    }
}

// MARK: - 关闭标签确认

public struct CloseTabDialog: View {
    let tabTitle: String
    let hostName: String
    var onEnd: (Bool) -> Void = { _ in }
    var onCancel: () -> Void = {}
    var onKeep: (Bool) -> Void = { _ in }
    @State private var remember = false
    @Environment(\.barly) private var t

    /// onEnd / onKeep 的参数：是否勾了「不再询问」
    public init(tabTitle: String, hostName: String = L("这台 Mac"), onEnd: @escaping (Bool) -> Void = { _ in },
                onCancel: @escaping () -> Void = {}, onKeep: @escaping (Bool) -> Void = { _ in }) {
        self.tabTitle = tabTitle
        self.hostName = hostName
        self.onEnd = onEnd
        self.onCancel = onCancel
        self.onKeep = onKeep
    }

    public var body: some View {
        SheetFrame(title: L("关闭「\(tabTitle)」？"), width: 460) {
            VStack(alignment: .leading, spacing: 14) {
                Text("CLI 正在 tmux 里运行。让它继续跑的话，关掉标签、退出 Switchboard 都不影响；之后点这个会话就会重新接上。")
                    .barlyText(.product.small, color: t.text2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Checkbox(remember)
                    Text("在\(hostName)上不再询问，以后照这次的选择做").barlyText(.product.small, color: t.text2)
                }
                .contentShape(Rectangle())
                .onTapGesture { remember.toggle() }
                .handCursor()
            }
        } buttons: {
            BarlyButton(L("结束会话"), variant: .danger, size: .md) { onEnd(remember) }
            Spacer()
            BarlyButton(L("取消"), variant: .ghost, size: .md, action: onCancel)
                .keyboardShortcut(.cancelAction)
            BarlyButton(L("继续运行"), variant: .primary, size: .md) { onKeep(remember) }
                .keyboardShortcut(.defaultAction)
        }
    }
}
