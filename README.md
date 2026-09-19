# Helm

Helm is a local-first native macOS workspace for the installed Claude Code and Codex CLIs. It uses SwiftUI, AppKit, WebKit, PDFKit, system Git, and SwiftTerm. Helm does not call AI APIs or store API keys.

## Requirements

- macOS 14 or later
- Xcode 26 or later
- Git
- An installed `claude` or `codex` CLI

## Run

```sh
./run.sh
```

For an optimized build:

```sh
./run.sh release
```

The first build resolves SwiftTerm 1.15.0. The script builds an ad-hoc-signed app bundle at `native/.build/Helm.app` and opens it.

## Test

```sh
cd native
swift test
```

## Use

1. Add an existing local repository with **New Project**.
2. Click **＋** beside the project, name the session, choose a target branch, and optionally enable **Use worktree**.
3. Add Claude, Codex, Terminal, Browser, and inspector panes from the pane bar.
4. Inspect repository changes in **Code Diff** and browse project files from **Files**.

All terminal panes in a session use the session worktree. Switching panes or sessions keeps their processes running. Closing a pane stops its process. Quitting Helm stops processes and restores project, session, layout, and browser state the next time it opens.

Project removal only removes Helm metadata. Session removal refuses dirty worktrees, uses Git's non-force removal, and retains the branch.

## Architecture

- `native/Sources/HelmNative/App`: lifecycle and native commands
- `native/Sources/HelmNative/Models`: Codable product state
- `native/Sources/HelmNative/Stores`: UI-facing coordination and persistence
- `native/Sources/HelmNative/Services`: Git, worktrees, files, watchers, and terminal processes
- `native/Sources/HelmNative/Features`: SwiftUI and AppKit product surfaces
- `native/Sources/HelmNative/DesignSystem`: Figma-derived tokens and assets
- `native/Tests`: service and worktree integration tests

State is atomically stored at `~/Library/Application Support/Helm/state-v2.json`. Managed worktrees live under `~/Library/Application Support/Helm/worktrees/`.

See [`native/README.md`](native/README.md) and [`docs/NATIVE_ARCHITECTURE.md`](docs/NATIVE_ARCHITECTURE.md) for implementation details.

## Design reference

[Helm Figma frame](https://www.figma.com/design/R9cphQ7EfbVNRgY5uZAUU7/Editorial?node-id=291-2427) is the visual source of truth.
