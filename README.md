# Switchboard

AI 编程 CLI 的会话管理器（macOS）。把 Claude Code、Codex、OpenCode、omp 在本机和 SSH 主机上留下的所有会话收进一个侧栏，点一下就在内嵌终端里接着跑。

*A session manager for AI coding CLIs on macOS — browse every Claude Code, Codex, OpenCode and omp session on this Mac and your SSH hosts, preview it, and resume it in an embedded terminal. The UI is available in Chinese and English.*

## 功能

- **会话库**：按项目分组列出四个 CLI 的全部会话，置顶、重命名、归档、多选删除；消息全文搜索；不启动 CLI 先读对话（预览）；Claude Code 会话可以搬到别的文件夹。
- **内嵌终端**：Chrome 式标签和标签组、分屏、多窗口，标签可以拖动排序、拖到别的窗口或拖出成新窗口；SwiftTerm 渲染，支持拖文件、⌘-点按打开文件和链接。
- **保活**：CLI 跑在 app 自带的 tmux 里，关掉标签或退出 app 也不中断，下次打开接着用。
- **状态**：每个会话「正在工作 / 等你回答 / 回合结束」的状态灯，跑完一轮或停下来等你时发系统通知。
- **SSH 主机**：镜像主机上的会话、在主机上新建和接着跑、交互登录（密码 / 验证码 / 主机指纹）、断线自动重连、端口转发、主机体检、定期重新登录命令（kinit 之类）。
- **外观**：6 套主题（各有明暗）、自定义颜色、界面大小 90%–150%、终端配色（可导入 iTerm2 配色）、中英文界面。
- **自动更新**：Sparkle，每个版本带 EdDSA 签名。
- **帮助和反馈**：「帮助」菜单打开使用说明、反馈和报告问题（GitHub 表单，版本号预填）；意外退出后下次启动会问要不要报告。

使用说明：[中文](docs/guide.md) · [English](docs/guide.en.md)

## 安装

需要 **macOS 26** 或更新版本。

1. 从 [Releases](https://github.com/gaoziman/Switchboard/releases) 下载最新的 `Switchboard-x.y.z.zip`，解压后把 `Switchboard.app` 拖进「应用程序」。
2. 安装包目前没有经过 Apple 公证，第一次打开时在访达里**右键 →「打开」**，再点「打开」。之后的更新由 app 自己完成。

Switchboard 只读取各 CLI 自己保存在本机的会话文件（`~/.claude`、`~/.codex`、OpenCode 和 omp 的数据目录），不上传任何东西，也不保存你在登录对话框里输入的密码和验证码。

## 从源码构建

需要 Xcode 26 和 [XcodeGen](https://github.com/yonaskolb/XcodeGen)。

```bash
cd apple
xcodegen generate                 # 生成 Switchboard.xcodeproj
scripts/install.sh                # 单测 → Release 构建 → 签名 → 装到 /Applications → 启动
```

第一次构建会下载 tmux 及其依赖的源码并静态编译（`apple/scripts/tmux/`，几分钟）。只跑界面层的单测：

```bash
cd apple/BarlyKit && swift test
```

### 目录

| 目录 | 内容 |
|---|---|
| `apple/App/macOS` | app 入口、菜单命令、设置窗口、自动更新、字符串表 |
| `apple/BarlyKit/Sources/Screens` | 全部界面和业务：会话读取、终端、tmux、SSH、状态检测 |
| `apple/BarlyKit/Sources/BarlyKit` | 设计系统（颜色、字体、控件） |
| `apple/scripts` | 安装、发版、字符串表同步、tmux 构建 |

### 界面文字

源语言是中文，英文在 `apple/App/macOS/Resources/Localizable.xcstrings`。改了界面文字之后：

```bash
cd apple
scripts/l10n.py sync              # 构建一次，把新文字同步进字符串表
scripts/l10n.py missing new.json  # 列出没有英文的，填好后：
scripts/l10n.py import new.json
scripts/l10n.py check
```

### 发版

```bash
cd apple
scripts/release.sh 0.2.0 --notes notes.md            # 只在本地生成 dist/0.2.0/
scripts/release.sh 0.2.0 --notes notes.md --publish  # 发到 GitHub Releases
```

## 致谢

Switchboard 是对 [JustSessions](https://github.com/yangzichao/JustSessions)（MIT）的重写，功能和交互参考了它，tmux 构建脚本改编自它。第三方组件和许可证见 [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md)。

Claude Code、Codex、OpenCode、omp 属于各自的所有者，Switchboard 与它们没有隶属关系。

## 许可证

[MIT](LICENSE)
