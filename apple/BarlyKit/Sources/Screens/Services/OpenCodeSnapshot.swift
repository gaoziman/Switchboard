import Foundation

/// 在 SSH 主机上给 OpenCode 的库做一个只含会话的快照（python3 自带 sqlite3）。账号、凭据、事件日志都不拷，
/// 子代理会话也不拷（只要 parent_id 为空的）。写在 /tmp 下的私有目录，拷完就删。
/// 每一步可以有几种写法，前一种因为老版本的库缺列 / 主机 SQLite 缺 JSON 函数失败时试下一种。改编自 JustSessions（MIT）
enum OpenCodeSnapshot {
    static let prefix = "/tmp/switchboard-opencode-"
    static let heading = "SWITCHBOARD_OPENCODE_SNAPSHOT="
    static let noDatabase: Int32 = 3

    /// 片段只留预览要读的：工具留名字和参数，附件只留类型
    static let partData = """
        CASE json_extract(data, '$.type') \
        WHEN 'tool' THEN json_object('type', 'tool', 'tool', json_extract(data, '$.tool'), \
        'state', json_object('input', json(json_extract(data, '$.state.input')))) \
        WHEN 'file' THEN json_object('type', 'file') \
        ELSE data END
        """

    static let steps: [[String]] = [
        ["CREATE TABLE session (id TEXT PRIMARY KEY, parent_id TEXT, directory TEXT, title TEXT, time_created INTEGER, time_updated INTEGER, time_archived INTEGER)"],
        ["CREATE TABLE message (id TEXT PRIMARY KEY, session_id TEXT, time_created INTEGER, time_updated INTEGER, data TEXT)"],
        ["CREATE TABLE part (id TEXT PRIMARY KEY, message_id TEXT, session_id TEXT, time_created INTEGER, time_updated INTEGER, data TEXT)"],
        [
            "INSERT INTO session SELECT id, parent_id, directory, title, time_created, time_updated, time_archived FROM source.session WHERE parent_id IS NULL AND time_archived IS NULL",
            "INSERT INTO session (id, parent_id, directory, title, time_updated) SELECT id, parent_id, directory, title, time_updated FROM source.session WHERE parent_id IS NULL",
        ],
        ["INSERT INTO message SELECT id, session_id, time_created, time_updated, data FROM source.message WHERE session_id IN (SELECT id FROM session)"],
        [
            // 预览只看文字、推理、工具名和参数、有附件这件事：工具输出、附件内容留在主机上
            "INSERT INTO part SELECT id, message_id, session_id, time_created, time_updated, " + partData
                + " FROM source.part WHERE session_id IN (SELECT id FROM session) AND json_extract(data, '$.type') IN ('text', 'reasoning', 'tool', 'file')",
            "INSERT INTO part SELECT id, message_id, session_id, time_created, time_updated, data FROM source.part WHERE session_id IN (SELECT id FROM session)",
        ],
        ["CREATE INDEX message_session_idx ON message (session_id, time_created, id)"],
        ["CREATE INDEX part_message_idx ON part (message_id, id)"],
    ]

    static var python: String {
        let json = String(decoding: (try? JSONSerialization.data(withJSONObject: steps, options: [.withoutEscapingSlashes])) ?? Data("[]".utf8), as: UTF8.self)
        return """
            import pathlib, shutil, sqlite3, sys, tempfile
            source = pathlib.Path(sys.argv[1])
            steps = \(json)
            snapshot = pathlib.Path(tempfile.mkdtemp(prefix='switchboard-opencode-', dir='/tmp'))
            try:
                copy = sqlite3.connect(str(snapshot / 'opencode.db'), timeout=5, isolation_level=None)
                copy.execute('ATTACH DATABASE ? AS source', (source.as_uri() + '?mode=ro',))
                copy.execute('BEGIN')
                for alternatives in steps:
                    for index, statement in enumerate(alternatives):
                        try:
                            copy.execute(statement)
                            break
                        except sqlite3.OperationalError as error:
                            if index == len(alternatives) - 1 or 'no such' not in str(error): raise
                copy.execute('COMMIT')
                copy.execute('DETACH DATABASE source')
                copy.close()
                print('\(heading)' + str(snapshot))
            except BaseException:
                shutil.rmtree(str(snapshot), ignore_errors=True)
                raise
            """
    }

    /// 主机的登录 shell 里跑：找库（遵守 OPENCODE_DB、XDG_DATA_HOME），没有就退出 3
    static var shell: String {
        """
        case "${OPENCODE_DB:-}" in
          /*) db=$OPENCODE_DB ;;
          *) case "${XDG_DATA_HOME:-}" in
               /*) db=$XDG_DATA_HOME/opencode/opencode.db ;;
               *) db=$HOME/.local/share/opencode/opencode.db ;;
             esac ;;
        esac
        [ -f "$db" ] || exit \(noDatabase)
        exec python3 -c \(Tmux.shellQuote(python)) "$db"
        """
    }

    /// 只认 /tmp/switchboard-opencode-<字母数字> 这种路径（后面要 rm -rf 它）
    static func path(in output: String) -> String? {
        guard let line = output.split(separator: "\n").last(where: { $0.hasPrefix(heading) }) else { return nil }
        let path = String(line.dropFirst(heading.count))
        let suffix = path.dropFirst(prefix.count)
        guard path.hasPrefix(prefix), !suffix.isEmpty,
              suffix.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }) else { return nil }
        return path
    }
}
