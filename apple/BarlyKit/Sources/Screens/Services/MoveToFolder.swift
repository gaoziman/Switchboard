import Foundation

/// 「移到…」：只有 Claude Code 能把会话搬到别的文件夹——用它自己的 `/cd`：在原目录恢复会话，第一条消息发 `/cd <文件夹>`，
/// Claude Code 自己搬对话记录、告诉模型目录换了，没在那个文件夹干过活时先在终端里问你。搬完刷新，会话出现在新文件夹下
/// （transcript 里的 relocated 行，SessionSources 已经认）。做法参考 JustSessions
@MainActor
public extension WorkspaceStore {
    /// CLI 在跑（有标签，或在 tmux 里后台跑）时不行：往跑着的 CLI 里塞 /cd 可能接在半句提示后面，或者排在一轮后面
    func canMove(_ session: Session) -> Bool {
        guard session.cli == .claude, tab(for: session) == nil else { return false }
        let name = Tmux.name(for: session.cli, sessionID: session.id)
        // 用状态轮询最近读到的 tmux 列表：菜单每次重画都会问，不能每次起 tmux（真要搬时 move 再确认一次）
        if session.hostID == Host.localID { return !data.activityInputs.tmuxRunning.contains(name) }
        return remoteSnapshots[session.hostID]?.tmux.contains(name) != true
    }

    /// 同一台机器上别的项目（侧栏顺序），文件夹得还在
    func moveDestinations(for session: Session) -> [Project] {
        let current = (session.projectPath as NSString).standardizingPath
        return projects.filter {
            $0.hostID == session.hostID && $0.folderExists && ($0.path as NSString).standardizingPath != current
        }
    }

    func move(_ session: Session, to folder: String) {
        guard canMove(session), (folder as NSString).standardizingPath != (session.projectPath as NSString).standardizingPath else { return }
        // 正在跑就不搬。问 tmux 放到后台：tmux server 卡住时要等满 3 秒超时
        if isLive, session.hostID == Host.localID {
            let name = Tmux.name(for: session.cli, sessionID: session.id)
            Task {
                guard !(await SSH.offPool { Tmux.runningSessions(fresh: true).contains(name) }) else { return }
                resumeMoved(session, to: folder)
            }
            return
        }
        resumeMoved(session, to: folder)
    }

    private func resumeMoved(_ session: Session, to folder: String) {
        if session.hostID == Host.localID { addFolder(folder, refreshNow: false) }   // 搬过去的目标文件夹进会话库（R4）
        let prompt = "/cd \(folder)"     // /cd 把后面整行当路径，带空格也照原样传
        open(session: session, arguments: session.cli.resumeArguments(session.id) + [prompt],
             tmuxName: Tmux.name(for: session.cli, sessionID: session.id),
             title: session.displayTitle)
    }
}
