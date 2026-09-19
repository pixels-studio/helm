# Helm native architecture

Helm is a local-first macOS application built with SwiftUI and AppKit. Figma node `291:2427` is the visual source of truth.

## Structure

`App` owns lifecycle and menus. `Models` contains stable Codable product state. `Stores` coordinates UI-facing domain state. `Services` owns persistence, commands, Git, worktrees, files, and watchers. `Features` contains focused SwiftUI and AppKit implementations. `DesignSystem` centralizes values and assets extracted from Figma.

## Runtime model

- `AppModel` is the authority for projects, sessions, panes, and each session's working directory.
- `TerminalRegistry` retains a separate SwiftTerm process for each terminal pane while users switch sessions.
- `GitService` invokes `/usr/bin/git` with typed arguments for branches, status, and diffs.
- `WorktreeService` creates isolated session worktrees and refuses to remove a modified worktree.
- `FileSystemService` confines reads to the selected session root after standardized and symlink-resolved path checks.
- `FileWatcher` observes the selected session, coalesces changes, and triggers inspector refreshes.
- `StateStore` writes Codable state atomically in Application Support.

## Workspace

The workspace is a recursive split tree. Each leaf hosts a terminal, browser, diff, or file preview pane. Horizontal and vertical split fractions are clamped and persisted. Browser URLs and selected inspector state restore with the workspace layout.

Terminal panes start the installed Claude Code, Codex, or shell command in the session worktree. Authentication and permission prompts remain in the real CLI process. Helm does not infer resume arguments, serialize PTYs, or persist credentials.

## Safety and lifecycle

Project removal deletes only Helm metadata. Worktree removal checks Git state and never force-deletes. Closing a pane terminates only its terminal process; quitting Helm terminates all retained processes. Filesystem reads remain rooted in the selected session and reject traversal through symlinks.

## UI foundations

The app uses a 272-point sidebar, flexible workspace panes, dark surfaces, branch chips, and exact exported Figma icons. Native window controls, responder-chain commands, PDFKit, Quick Look-oriented preview routing, and WKWebView preserve platform behavior.

SwiftTerm 1.15.0 provides the Unix PTY and AppKit terminal renderer, including ANSI and true color, Unicode graphemes, selection, copy and paste, search, resizing, mouse input, and scrollback.
