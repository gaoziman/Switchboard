# Third-party notices

Switchboard 自身以 MIT 许可发布（见 `LICENSE`）。它使用或随 app 分发了下面这些第三方组件。

## 代码与随 app 分发的程序

| 组件 | 用途 | 许可证 | 原文 |
|---|---|---|---|
| [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) 1.20.0 | 内嵌终端 | MIT | 随 Swift 包分发 |
| [Sparkle](https://github.com/sparkle-project/Sparkle) 2.x | 自动更新 | MIT | 随 Swift 包分发 |
| [tmux](https://github.com/tmux/tmux) 3.7c | 会话保活（静态编译后打包进 app） | ISC | app 内 `Contents/Resources/Tmux/licenses/tmux.txt` |
| [libevent](https://libevent.org) 2.1.13 | tmux 依赖 | BSD-3-Clause | `…/Tmux/licenses/libevent.txt` |
| [ncurses](https://invisible-island.net/ncurses/) 6.6 | tmux 依赖 | MIT-style（X11） | `…/Tmux/licenses/ncurses.txt` |
| [utf8proc](https://github.com/JuliaStrings/utf8proc) 2.12.0 | tmux 依赖 | MIT | `…/Tmux/licenses/utf8proc.txt` |
| [JustSessions](https://github.com/yangzichao/JustSessions) | 功能与交互参考；`apple/scripts/tmux/` 的 tmux 构建脚本改编自它 | MIT, © Zichao Yang | `apple/scripts/tmux/NOTICE.md` |

## 字体

| 字体 | 文件 | 许可证 | 原文 |
|---|---|---|---|
| Inter Tight | `InterTight-Variable.ttf` | SIL Open Font License 1.1 | `LICENSE-fonts/intertight.txt` |
| Inter | `Inter-Variable.ttf` | SIL Open Font License 1.1 | `LICENSE-fonts/inter.txt` |
| Geist Mono | `GeistMono-Variable.ttf` | SIL Open Font License 1.1 | `LICENSE-fonts/geistmono.txt` |
| PingFang SC | （系统字体，不打包） | 系统字体 | — |

## 图标

- **SF Symbols**（Apple）— 按 Apple SF Symbols 许可，只能用在 Apple 平台 app 的界面里；不能用作 app 图标 / logo。

## 商标

Claude Code、Codex、OpenCode、omp 等名称属于各自的所有者。Switchboard 是独立项目，与它们没有隶属关系，只是读取这些 CLI 在本机保存的会话文件。
