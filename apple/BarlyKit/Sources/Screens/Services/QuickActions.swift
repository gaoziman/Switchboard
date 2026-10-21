import Foundation

/// 侧栏行上的快捷动作：项目「+」直接开跑、会话「结束会话」
@MainActor
public extension WorkspaceStore {
    /// 项目所在主机装了的 CLI（「+」菜单列这些）
    func quickStartCLIs(for project: Project) -> [CLIKind] {
        host(project.hostID)?.installedCLIs ?? installedCLIs
    }

    /// 「+」点了某个 CLI / 终端：这个文件夹、这台主机、保存过的启动命令
    func quickStartDraft(_ target: NewSessionDraft.Target, in project: Project) -> NewSessionDraft {
        var draft = NewSessionDraft(hostID: project.hostID, target: target, folder: project.path)
        if case .cli(let cli) = target { draft.savedCommand = savedCommand(for: cli) }
        return draft
    }

    /// 直接开跑：不弹面板
    func quickStart(_ target: NewSessionDraft.Target, in project: Project) {
        start(quickStartDraft(target, in: project))
    }

    /// 结束会话的 CLI（开着标签就关标签并结束 tmux，没开就直接结束 tmux）；会话文件不动
    func endSession(_ session: Session) {
        if let tab = tab(for: session) {
            close(tab, keepRunning: false)
        } else {
            Tmux.kill(Tmux.name(for: session.cli, sessionID: session.id))
        }
    }

    /// 项目下的全部会话（不算子代理）
    func allSessions(in project: Project) -> [Session] {
        sessions.filter { $0.projectID == project.id && $0.parentSessionID == nil }
    }

    /// 能直接删的：没在跑、也没开着标签的（「删除所有可删除的会话」）
    func deletableSessions(in project: Project) -> [Session] {
        allSessions(in: project).filter { !$0.activity.isRunning && tab(for: $0) == nil }
    }

    /// 重命名项目：只改 Switchboard 里显示的名字；留空恢复文件夹名
    func rename(_ project: Project, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        updateLibrary { s in s.projectNames[project.id] = trimmed.isEmpty ? nil : trimmed }
    }

    /// 删除确认里点了「删除」：删完再归档（「归档项目并删除所有会话」）
    func confirmPendingDelete() async {
        let targets = pendingDelete
        let archive = pendingArchiveProject
        pendingDelete = []
        pendingArchiveProject = nil
        deleteFailures = await delete(targets)
        if let archive, let project = projects.first(where: { $0.id == archive }) { setArchived(project, true) }
    }
}
