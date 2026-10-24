import SwiftUI
import BarlyKit

/// AI 重命名：转圈 → 3 个候选（点一个选中，下面的输入框还能改）→ 使用。出错就说原因，可以重试
public struct NameSuggestionsSheet: View {
    let session: Session
    let load: () async throws -> [String]
    let onPick: (String) -> Void
    let onCancel: () -> Void
    @State private var phase: Phase = .loading
    @State private var name = ""
    @State private var attempt = 0
    @Environment(\.barly) private var t

    enum Phase: Equatable { case loading, ready([String]), failed(String) }

    /// fixture：截图用，直接给好候选、不去调模型
    public init(session: Session, fixture: [String]? = nil, load: @escaping () async throws -> [String] = { [] },
                onPick: @escaping (String) -> Void = { _ in }, onCancel: @escaping () -> Void = {}) {
        self.session = session
        self.load = load
        self.onPick = onPick
        self.onCancel = onCancel
        self.fixture = fixture
        if let fixture {
            _phase = State(initialValue: .ready(fixture))
            _name = State(initialValue: fixture.first ?? "")
        }
    }
    private let fixture: [String]?

    public var body: some View {
        SheetFrame(title: L("AI 重命名"), subtitle: L("现在叫：\(session.displayTitle)"), width: 480) {
            VStack(alignment: .leading, spacing: 12) {
                switch phase {
                case .loading:
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("正在读对话、起名…").barlyText(.product.small, color: t.text2)
                    }
                    .frame(maxWidth: .infinity, minHeight: BarlyScale.pt(120), alignment: .center)
                case .ready(let names):
                    VStack(spacing: 2) {
                        ForEach(names, id: \.self) { candidate in candidateRow(candidate) }
                    }
                    TextField("名字", text: $name)
                        .textFieldStyle(.plain)
                        .barlyText(.product.small, color: t.text)
                        .padding(.horizontal, 10)
                        .frame(height: BarlyScale.pt(30))
                        .background(t.fieldBg, in: RoundedRectangle(cornerRadius: BarlyRadius.sm))
                        .overlay(RoundedRectangle(cornerRadius: BarlyRadius.sm).stroke(t.borderStrong))
                    Text("格式「主题｜动作」，只改 Switchboard 里显示的名字。").barlyText(.product.caption, color: t.text3)
                case .failed(let message):
                    Text(message).barlyText(.product.small, color: t.danger).fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, minHeight: BarlyScale.pt(60), alignment: .leading)
                }
            }
        } buttons: {
            BarlyButton(L("重新生成"), variant: .ghost) { attempt += 1 }.disabled(phase == .loading)
            Spacer()
            BarlyButton(L("取消"), variant: .ghost, action: onCancel).keyboardShortcut(.cancelAction)
            BarlyButton(L("使用"), variant: .primary) { onPick(name) }
                .keyboardShortcut(.defaultAction)
                .disabled(SessionName.clean(name) == nil)
        }
        .task(id: attempt) {
            if fixture != nil && attempt == 0 { return }
            phase = .loading
            do {
                let names = try await load()
                name = names.first ?? ""
                phase = .ready(names)
            } catch is CancellationError {
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    private func candidateRow(_ candidate: String) -> some View {
        let picked = candidate == name
        return HStack(spacing: 8) {
            Image(systemName: picked ? "largecircle.fill.circle" : "circle")
                .font(.system(size: BarlyScale.pt(11)))
                .foregroundStyle(picked ? t.accent : t.text3)
            SessionName.text(candidate, separator: t.text4)
                .barlyText(.product.small.weight(picked ? 600 : 400), color: t.text)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(height: BarlyScale.pt(30))
        .background(picked ? t.shellSelected : .clear, in: RoundedRectangle(cornerRadius: BarlyRadius.sm, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onPick(candidate) }     // 双击直接用（双击要写在单击前面）
        .onTapGesture { name = candidate }
        .handCursor()
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(picked ? [.isButton, .isSelected] : .isButton)
    }
}
