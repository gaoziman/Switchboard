import Foundation
import Testing
@testable import Screens

/// 项目 ID「主机:路径」：拼、拆只在 ProjectID 里做一次（原来 6 处各自找冒号）
@Suite("项目 ID")
struct ProjectIDTests {
    @Test("拼成和原来一样的字符串（存盘格式不变）")
    func raw() {
        #expect(ProjectID(host: "local", path: "/Users/me/app").raw == "local:/Users/me/app")
        #expect(ProjectID(host: "devbox", path: "~/srv").raw == "devbox:~/srv")
    }

    @Test("拆：按第一个冒号，路径里有冒号也不切坏；没冒号不是项目 ID")
    func parse() {
        #expect(ProjectID(raw: "devbox:/srv/a:b") == ProjectID(host: "devbox", path: "/srv/a:b"))
        #expect(ProjectID(raw: "local:/") == ProjectID(host: "local", path: "/"))
        #expect(ProjectID(raw: "no-colon") == nil)
    }

    @Test("会话、项目、标签算出来的是同一个 ID")
    func sameAcrossTypes() {
        let s = Session(id: "s", cli: .claude, hostID: "devbox", projectPath: "/srv", title: "t", lastActivity: .now, messageCount: 1)
        let tab = TerminalTab(kind: .session(id: "s", cli: .claude), hostID: "devbox", projectPath: "/srv", title: "t", activity: .idle)
        #expect(s.projectID == Project(hostID: "devbox", path: "/srv").id)
        #expect(tab.projectID == s.projectID)
        #expect(s.projectID.host == "devbox" && s.projectID.path == "/srv")
    }
}

@Suite("新会话通知")
struct NewSessionNoteTests {
    @Test("项目菜单的「更多选项…」带着项目过去，新会话对话框预选它（通知的 object 是 Any，类型对不上编译器查不出）")
    func carriesProject() {
        let id = ProjectID(host: "devbox", path: "/srv/app")
        #expect(Notification.newSession(in: id).newSessionProject == id)
        #expect(Notification.newSession(in: nil).newSessionProject == nil)
        #expect(Notification.newSession(in: id).name == .switchboardNewSession)
    }
}
