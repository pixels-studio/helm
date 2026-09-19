# Helm

A local-first Electron workspace around the installed Claude Code and Codex CLIs.
Built with Svelte 5, SvelteKit, TypeScript, Tailwind, xterm.js, and node-pty. No AI APIs,
API keys, cloud services, or custom agent harness.

## Run

Requires Node 22.12+ (tested with Node 24), npm, system Git, and installed `claude` / `codex`
commands. Native builds require platform compiler tools (Xcode Command Line Tools on macOS).

```sh
npm ci
npm start
```

`npm start` builds the renderer, main process, and preload bundle before launching, so it
also works from a clean checkout. Development: `npm run dev`. Renderer changes hot reload;
restart after main/preload edits.
`npm run rebuild` repairs node-pty after changing Electron versions.

## Use

1. Add an existing local repository with **New Project**.
2. Click **＋** beside the project; name the session, choose `main`, enable **Use worktree**.
3. Add Claude, Codex, and Terminal panes with **＋** in the pane bar.
4. All panes use the same session worktree. Agent authentication and permission prompts
   appear in the actual CLI terminal. Use your existing CLI login.
5. Inspect changes in **Code Diff**. Click that heading to switch to **Files**.
6. Switch panes or sessions without stopping their processes. Quitting stops processes;
   definitions and layout restore, and terminal panes launch fresh CLI processes on reopening.
   Helm does not infer CLI resume arguments or serialize live PTYs.

Project removal only removes Helm metadata and stops associated processes; all project
folders and worktrees remain on disk. Session removal refuses dirty worktrees, uses Git's
non-force removal, and retains the branch. Closing a pane stops only its own process.

## Architecture

- `src/lib/components/`: terminal, filesystem/diff inspector, session form.
- `src/routes/`: application workspace and sidebar.
- `shared/contracts.ts`: persisted models, typed API, runtime IPC schemas.
- `electron/preload/`: narrow context-isolated bridge; no generic execution endpoint.
- `electron/main/`: persistence, Git, worktrees, terminals, filesystem, and service composition.
- `scripts/`: builds, development runner, isolated Electron integration test.

Main is the authority for `sessionId → worktreePath`. Renderer terminal requests cannot
supply a command or working directory. Every IPC invocation validates its sender, frame,
and arguments. File paths resolve through realpath and cannot escape the session root.
Electron uses context isolation, renderer sandboxing, disabled Node integration, denied
new windows, denied permission requests, and a local-only application protocol.

State is atomically written to `state.json` in Electron's Helm user-data directory
(on macOS, `~/Library/Application Support/Helm`). Worktrees live below that directory.
`HELM_USER_DATA` can select a separate profile. Malformed state fails visibly rather than
silently replacing user data. No running process objects or credentials are persisted.

Filesystem browsing is lazy, nonrecursive, hides common build/dependency folders, and
filters Git-ignored entries where practical. Watching is bounded to three directory levels;
Git status also refreshes every five seconds. Text previews are limited to 2 MB. The diff
view is a basic unified diff, with index/worktree status codes; untracked files show text.

## Validation

```sh
npm run check
npm run build
npm test
```

`npm test` launches a real Electron window with an isolated temporary profile/repository.
It exercises worktree creation, concurrent shell PTYs, installed Claude/Codex startup,
Git status/diff, text reads, traversal/symlink rejection, dirty-worktree protection,
persistence, and renderer/preload isolation. Screenshot: `artifacts/smoke.png`.
It does not send a model prompt or assert that the user's CLI account is authenticated.
No lint framework is configured. This is a source-run milestone, not a signed installer.

## Design reference

[Helm Figma frame](https://www.figma.com/design/R9cphQ7EfbVNRgY5uZAUU7/Editorial?node-id=291-2427).
Local icons are exact Figma exports. Sidebar grouping, dark panels, branch chips, and the
session form follow that frame; terminal content and changes come from real processes/files.

Electron isolation follows the [Electron context-isolation guidance](https://www.electronjs.org/docs/latest/tutorial/context-isolation).

# helm
