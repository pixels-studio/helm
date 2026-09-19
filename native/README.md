# Helm for macOS

Helm is implemented with SwiftUI and AppKit for macOS 14 and later. It uses system Git for repository operations, SwiftTerm 1.15.0 for real local PTYs, WKWebView for browser panes, and native image and PDF preview frameworks.

From the repository root:

```sh
./run.sh
```

Or work directly in this package:

```sh
swift test
./Scripts/package-app.sh
open .build/Helm.app
```

`Scripts/package-app.sh release` creates an optimized, ad-hoc-signed application bundle. Xcode can open `Package.swift` directly.

Application state is stored at `~/Library/Application Support/Helm/state-v2.json`. Session worktrees live under `~/Library/Application Support/Helm/worktrees/`.

Helm supports projects, persisted sessions, optional Git worktrees, real Claude/Codex/shell PTYs, retained processes across session switches, horizontal and vertical split panes, Git status and diffs, text/image/PDF previews, browser panes, and restored pane/browser state.

The visual system is derived from [Figma node 291:2427](https://www.figma.com/design/R9cphQ7EfbVNRgY5uZAUU7/Editorial?node-id=291-2427). See [the native architecture](../docs/NATIVE_ARCHITECTURE.md) for implementation details.
