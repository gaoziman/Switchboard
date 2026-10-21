# Switchboard User Guide

[中文](guide.md)

Switchboard gathers the sessions that Claude Code, Codex, OpenCode and omp leave on this Mac and on your SSH hosts into one sidebar. Read a conversation first, then decide where to resume it.

- [Getting started](#user-content-start)
- [The session library](#user-content-library)
- [Terminal and tabs](#user-content-terminal)
- [Status lights and notifications](#user-content-status)
- [SSH hosts](#user-content-ssh)
- [Port forwarding](#user-content-forwarding)
- [Checking a host](#user-content-check)
- [Periodic sign-in](#user-content-sign-in)
- [Appearance and language](#user-content-appearance)
- [Keyboard shortcuts](#user-content-shortcuts)
- [Privacy](#user-content-privacy)
- [Troubleshooting](#user-content-troubleshooting)

<a id="start"></a>
## Getting started

1. Open Switchboard. The sidebar lists every session of the four CLIs on this Mac, grouped by project folder. The first read can take a few seconds; after that it is cached.
2. **Click** a session to read the conversation on the right without starting the CLI.
3. **Double-click** it (or use Resume in the preview) to open a terminal tab in the original project folder, with the CLI continuing that session.
4. The **+** at the top right of the sidebar (⌘N) starts a new session: pick a CLI and a project folder.

Install the CLIs you use yourself; they only need to be on the `PATH` of your login shell. Switchboard starts them with your login shell's environment.

<a id="library"></a>
## The session library

- **Projects / Open**: switch between all sessions by project and only the tabs that are open.
- **Right-click a session**: Resume, Fork as a new session (Claude Code, Codex, OpenCode), Move To (Claude Code only, see below), Rename, Pin, Archive, copy or export the conversation as Markdown, copy the session ID, show in Finder, Delete.
- **Multiple selection**: ⌘-click or ⇧-click; actions for the selection appear at the bottom. Esc clears it.
- **Search** (magnifier at the top of the sidebar): searches titles and the full text of every message. The first search builds an index; later searches are fast.
- **Filter**: last 7 days, one CLI, running, or waiting for you.
- **Subagents**: turn them on in Settings › General › Session Library to list Claude Code subagent sessions under the session that started them.
- **Delete**: Claude Code and omp session files go to the Trash. Codex and OpenCode are deleted with their own delete commands, which is permanent. SSH hosts have no Trash, so deleting there is permanent too. The confirmation says which.

**Moving to another folder** (Claude Code only): right-click a session › Move To, then pick another project on the same machine (or Other Folder… on this Mac). Switchboard resumes the session in its original folder and sends Claude Code's own `/cd <folder>` as the first message, so Claude Code moves the transcript itself; in a folder the session hasn't worked in, it asks you first in the terminal. A session can't be moved while its CLI is running; end it first.

Pins, names and archives are stored in `~/Library/Application Support/Switchboard/`. Switchboard never changes the CLIs' own files.

<a id="terminal"></a>
## Terminal and tabs

- Tabs are grouped by project, like Chrome tab groups. ⌘1–8 jumps to a tab, ⌘9 to the last one; ⇧⌘[ / ⇧⌘] or ⌃Tab cycle through them.
- **Split**: ⌥⌘N, then pick a tab for the right side.
- **Dragging tabs**: drag within a project's group to reorder; drop on another window's tab bar to move it there; release outside every window to open it in a new window. Right-click a tab for Move to New Window and Move to Window. A moved terminal keeps running; it isn't restarted.
- **Several windows**: ⇧⌘N opens a new window. All windows share one session library; each has its own tabs. Closing a window leaves its tabs' CLIs running in tmux.
- **Keep alive**: CLIs run inside Switchboard's own tmux. When you close a tab you can let the CLI keep running, or set a default per machine in Settings › Host. Quitting Switchboard doesn't end them either. Clicking the session again (or relaunching, which restores tabs) reattaches.
- **Plain terminal**: choose Terminal in New Session for a login shell. It doesn't use tmux and ends when closed.
- Dropping a file on the terminal pastes its path. ⌘-click a path or link in the terminal to open it (Settings › General decides with what).
- ⌘F finds; ⌘+ / ⌘− / ⌘0 change the terminal font size.

<a id="status"></a>
## Status lights and notifications

The light in front of each session (colors as in the default theme):

| Light | Meaning |
|---|---|
| Spinner | Working |
| Accent-colored dot (coral by default) | Waiting for you (a permission prompt or a question) |
| Blue dot | Finished a turn you haven't looked at |
| Green dot | Running, idle |
| Hollow ring | Ended |

- A system notification arrives when a CLI finishes a turn or stops to wait for you (each can be turned off in Settings › General › Notifications). Clicking it opens that session.
- The bell at the top of the sidebar lists every session waiting for you.
- Claude Code's status is read wherever it was started. The detailed status of Codex, OpenCode and omp works only for sessions **started from Switchboard**, which adds a status-reporting option or plugin when it launches them.

<a id="ssh"></a>
## SSH hosts

1. Click Add SSH Host… at the bottom of the sidebar and enter an alias from `~/.ssh/config`, or `user@hostname`. Ports, keys and jump hosts belong in `~/.ssh/config`.
2. Switchboard connects once in the background (without prompting) and checks for rsync, tmux and each CLI on the host.
3. **Claude Code and Codex** sessions on the host are mirrored to this Mac (the host needs `rsync`) and listed under the host's name, where you can read, resume and delete them as usual. OpenCode and omp sessions on hosts are not listed yet.
4. If the host has tmux, remote sessions are kept alive too; without it, the CLI ends when the connection drops.

**Hosts that ask for a password or a code**: click Connect… on the host's heading. Switchboard brings ssh's questions (password, verification code, host key fingerprint) into a dialog. After one sign-in, background refreshes, deletes and tabs share that connection and won't ask again. Switchboard doesn't store anything you type.

**Dropped connections**: tabs reconnect on their own (after 2 s, 5 s, 10 s and longer, stopping after about 15 minutes), and retry right away when the Mac wakes or the app comes to the front.

<a id="ssh-startup"></a>
### The host's shell startup files

Switchboard starts CLIs on a host with `$SHELL -lc`, which reads login files (`~/.profile`, `~/.bash_profile`, `~/.zprofile`) but not interactive ones. Common problems:

- **The CLI isn't found**: nvm, fnm and similar are set up in `~/.bashrc` after its "exit if not interactive" check, so the login shell has no node. Move those lines above the check, or into `~/.profile`.
- **A login file runs `exec zsh` or attaches tmux automatically**: this makes background commands hang. Only do it when you log in interactively:

```sh
if [[ $- == *i* ]] && [ -z "$SWITCHBOARD" ]; then exec zsh -l; fi
```

Check Host… finds these problems.

<a id="forwarding"></a>
## Port forwarding

Right-click a host's heading › Forward Port…: lists the ports listening on the host's localhost. Pick one (or type it); the local port defaults to the same number. Forwards listen only on this Mac's localhost, so other computers can't connect. Once running, the host's menu lets you open it in the browser, copy the address, or stop forwarding. Disconnecting or removing the host stops its forwards.

<a id="check"></a>
## Checking a host

Right-click a host's heading › Check Host…: a read-only check of sign-in, the shell startup files, rsync, tmux (including an old tmux server that a newer tmux can't talk to) and whether each CLI runs, with the time each step took. Every finding includes what the host said and a command you can run in Terminal to reproduce it.

- Copy Report: send it to someone who can help.
- Fix with Agent…: opens a Claude Code session on this Mac with the report. It investigates and fixes over ssh, and asks you before changing anything on the host.

<a id="sign-in"></a>
## Periodic sign-in

Some hosts need you to authenticate again every so often (Kerberos `kinit`, for example). Right-click a host's heading › Re-authentication Command…:

- **Command**: runs in the host's login shell with a terminal, e.g. `kinit`. Whatever it asks appears in a dialog.
- **Check command** (optional): exit code 0 means still valid, e.g. `klist -s`. Runs every 5 minutes.
- Without a check command, the interval in hours is used.

When it's due, the host's heading shows Sign In… and a system notification is sent.

<a id="appearance"></a>
## Appearance and language

- Settings › Appearance: 6 themes, each with light and dark variants; light/dark can follow the system.
- **Custom Colors**: change the current theme's background, sidebar, panels, text and accent, separately for its light and dark versions; changes apply right away, and button text switches between black and white to stay readable. They're kept when you switch themes and come back; Reset All returns to the theme's own colors.
- **Interface Size**: 90%–150%. Text in the sidebar, tabs and dialogs gets larger or smaller (set the terminal font size separately in Terminal).
- Settings › Terminal: color scheme (follow the app theme, a built-in scheme, or an imported iTerm2 `.itermcolors`), font, size and color intensity.
- Settings › General › Interface Language: Match System / 简体中文 / English, applied after a relaunch. Session tabs reopen and CLIs keep running in tmux; plain terminals close.

<a id="shortcuts"></a>
## Keyboard shortcuts

| Action | Shortcut |
|---|---|
| New session | ⌘N |
| New window | ⇧⌘N |
| Split | ⌥⌘N |
| Close tab / close window | ⌘W / ⇧⌘W |
| Tabs 1–8 / last tab | ⌘1…8 / ⌘9 |
| Next / previous tab | ⇧⌘] / ⇧⌘[, ⌃Tab / ⌃⇧Tab |
| Show / hide sidebar | ⌘B |
| Back / forward | ⌘[ / ⌘] |
| Find / next / previous | ⌘F / ⌘G / ⇧⌘G |
| Terminal font size | ⌘+ / ⌘− / ⌘0 |
| Refresh library | ⌘R |
| Settings | ⌘, |

<a id="privacy"></a>
## Privacy

- Switchboard only reads the session files the CLIs keep on this Mac (and on hosts you add). Nothing is uploaded.
- It doesn't store passwords or codes typed into sign-in dialogs.
- It goes online in two cases only: a daily update check (GitHub Releases; turn it off in Settings › Help), and when you choose Send Feedback or Report an Issue, which opens GitHub in your browser.
- Crash reports: after an unexpected quit, the next launch asks whether you'd like to report it. The report contains versions, the exception and the backtrace, without your file paths. Nothing is sent unless you choose to.

<a id="troubleshooting"></a>
## Troubleshooting

**A CLI's sessions are missing from the sidebar**: make sure you've run sessions with that CLI on this Mac and that its data folder is in the default place (`~/.claude`, `~/.codex`, and so on). Press ⌘R to reload.

**Double-clicking a session says the command isn't found**: the CLI isn't on your login shell's `PATH`. In Terminal, run `$SHELL -lc 'command -v claude'` to check.

**A host's heading says it needs a password or code**: click Connect… and sign in once. Later refreshes share that connection.

**A host's sessions don't appear**: the host needs `rsync` (Debian / Ubuntu: `sudo apt install rsync`). Right-click the host › Check Host… tells you what's missing.

**A CLI won't start on a host, but works when you ssh in yourself**: usually a shell startup file problem; see [The host's shell startup files](#user-content-ssh-startup).

**The status light doesn't change**: detailed status for Codex, OpenCode and omp works only for sessions started from Switchboard.

**Still stuck**: Help › Report an Issue… opens GitHub's issue form with the versions filled in. Attaching a Check Host report helps a lot.
