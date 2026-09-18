<script lang="ts">
  import { onMount } from 'svelte';
  import TerminalPane from '$lib/components/TerminalPane.svelte';
  import Inspector from '$lib/components/Inspector.svelte';
  import NewSession from '$lib/components/NewSession.svelte';
  import type { State, Project } from '$shared/contracts';
  let workspaceState = $state<State>({
    version: 1,
    projects: [],
    sessions: [],
    panes: [],
    settings: { fontSize: 13 },
  });
  let search = $state('');
  let error = $state('');
  let newProject = $state<Project | null>(null);
  let showInspector = $state(true);
  let settings = $state(false);
  let help = $state(false);
  let running = $state<Record<string, boolean>>({});
  let loaded = $state(false);
  let busy = $state(false);
  let pendingRemove = $state<{
    kind: 'project' | 'session' | 'pane';
    id: string;
  } | null>(null);
  const session = $derived(
    workspaceState.sessions.find((s) => s.id === workspaceState.lastSessionId),
  );
  const activePane = $derived(
    workspaceState.panes.find((p) => p.id === session?.layout.activePaneId),
  );
  async function refresh() {
    workspaceState = await window.helm.state.get();
  }
  async function action(fn: () => Promise<unknown>) {
    error = '';
    busy = true;
    try {
      await fn();
      await refresh();
    } catch (e) {
      error = String(e);
    } finally {
      busy = false;
    }
  }
  function modal(node: HTMLDialogElement) {
    node.showModal();
    return {
      destroy() {
        node.close();
      },
    };
  }
  function onstatus(id: string, value: boolean) {
    running = { ...running, [id]: value };
  }
  async function remove() {
    const target = pendingRemove;
    if (!target) return;
    await action(() =>
      target.kind === 'project'
        ? window.helm.projects.remove(target.id)
        : target.kind === 'session'
          ? window.helm.sessions.remove(target.id)
          : window.helm.panes.remove(target.id),
    );
    pendingRemove = null;
  }
  onMount(() => {
    if (!window.helm) {
      error =
        'Launch Helm with npm start or npm run dev to access local projects.';
      return;
    }
    void refresh()
      .then(() => (loaded = true))
      .catch((e) => (error = String(e)));
  });
</script>

<svelte:head><title>Helm</title></svelte:head>
<div class="app-shell">
  <aside>
    <div class="window-drag"><span class="brand">Helm</span></div>
    <div class="search">
      <img src="/icons/search.svg" alt="" /><input
        aria-label="Search sessions"
        placeholder="Search"
        bind:value={search}
      />
    </div>
    <button
      class="plain new-project"
      disabled={busy}
      onclick={() => action(() => window.helm.projects.add())}
      ><span class="plus">＋</span>New Project</button
    >
    <nav aria-label="Projects and sessions">
      {#each workspaceState.projects as project, i}
        <section class="project-group">
          <div class="project-row">
            <span
              class="project-symbol"
              style:color={['#ff4949', '#e0e0e0', '#edcb00', '#17b144'][i % 4]}
              >✦</span
            ><button
              class="plain project-name"
              title={project.path}
              onclick={() =>
                action(() => window.helm.projects.select(project.id))}
              >{project.name}</button
            ><button
              class="plain small"
              aria-label={'Remove ' + project.name + ' from Helm'}
              onclick={() =>
                (pendingRemove = { kind: 'project', id: project.id })}
              >···</button
            ><button
              class="plain small"
              aria-label={'New session in ' + project.name}
              onclick={() => (newProject = project)}>＋</button
            >
          </div>
          {#each workspaceState.sessions.filter((s) => s.projectId === project.id && s.title
                .toLowerCase()
                .includes(search.toLowerCase())) as item}
            <div class="session-row" class:selected={item.id === session?.id}>
              <button
                class="plain session-link"
                title={item.title}
                onclick={() =>
                  action(() => window.helm.sessions.select(item.id))}
                ><span
                  class="status-dot"
                  class:live={workspaceState.panes.some(
                    (p) => p.sessionId === item.id && running[p.id],
                  )}
                ></span><span class="truncate">{item.title}</span></button
              >{#if item.id === session?.id}<button
                  class="plain small"
                  aria-label="Remove session"
                  onclick={() =>
                    (pendingRemove = { kind: 'session', id: item.id })}
                  >···</button
                >{/if}
            </div>
          {/each}
          {#if !workspaceState.sessions.some((s) => s.projectId === project.id)}<button
              class="plain muted first-session"
              onclick={() => (newProject = project)}
              >Create your first session</button
            >{/if}
        </section>
      {/each}
    </nav>
    <footer>
      <button class="plain" onclick={() => (settings = !settings)}
        ><img src="/icons/settings.svg" alt="" />Settings</button
      ><button class="plain" onclick={() => (help = !help)}
        ><img src="/icons/help.svg" alt="" />Help</button
      >
    </footer>
  </aside>
  <main>
    {#if error}<div class="error global-error" role="alert">
        {error}<button
          class="plain"
          aria-label="Dismiss error"
          onclick={() => (error = '')}>×</button
        >
      </div>{/if}
    {#if session}
      <div class="workspace">
        <section class="panel terminal-panel">
          <header>
            {#if activePane?.type === 'claude'}<img
                src="/icons/claude.svg"
                alt="Claude"
              />{:else}<span class="terminal-symbol"
                >{activePane?.type === 'codex' ? '◉' : '›_'}</span
              >{/if}<span
              class="truncate session-title"
              title={session.worktreePath}>{session.title}</span
            ><span class="badge" title={session.branch}
              >{session.branch || 'Folder'}</span
            ><button
              class="plain ml-auto"
              title="Toggle code diff and files"
              aria-label="Toggle code diff and files"
              onclick={() => (showInspector = !showInspector)}>···</button
            >
          </header>
          <div class="pane-toolbar">
            <div class="pane-tabs" role="tablist" aria-label="Terminal panes">
              {#each workspaceState.panes.filter((p) => p.sessionId === session?.id) as pane}<button
                  role="tab"
                  aria-selected={activePane?.id === pane.id}
                  class:chosen={activePane?.id === pane.id}
                  onclick={() =>
                    action(() => window.helm.panes.select(pane.id))}
                  ><span class="status-dot" class:live={running[pane.id]}
                  ></span>{pane.title}</button
                >{/each}
            </div>
            <details class="add-pane">
              <summary aria-label="Add pane">＋</summary>
              <div class="menu">
                {#each ['claude', 'codex', 'terminal'] as type}<button
                    onclick={(event) => {
                      const details = event.currentTarget.closest('details');
                      if (details) details.open = false;
                      void action(() =>
                        window.helm.panes.add(
                          session!.id,
                          type as 'claude' | 'codex' | 'terminal',
                        ),
                      );
                    }}
                    >Add {type === 'terminal'
                      ? 'Terminal'
                      : type === 'claude'
                        ? 'Claude'
                        : 'Codex'}</button
                  >{/each}{#if activePane}<button
                    class="danger"
                    onclick={() =>
                      (pendingRemove = { kind: 'pane', id: activePane!.id })}
                    >Close active pane</button
                  >{/if}
              </div>
            </details>
          </div>
          <div class="terminal-space">
            {#each workspaceState.panes as pane (pane.id)}<TerminalPane
                {pane}
                active={pane.id === activePane?.id}
                fontSize={workspaceState.settings.fontSize}
                {onstatus}
              />{/each}
            {#if !activePane}<div class="empty-workspace">
                <h1>A workspace for this piece of work.</h1>
                <p>
                  Launch an agent or a shell. Every pane uses this session’s
                  directory.
                </p>
                <div class="flex gap-2 justify-center mt-5">
                  {#each ['claude', 'codex', 'terminal'] as type}<button
                      disabled={busy}
                      onclick={() =>
                        action(() =>
                          window.helm.panes.add(
                            session!.id,
                            type as 'claude' | 'codex' | 'terminal',
                          ),
                        )}
                      >{type === 'terminal'
                        ? 'Terminal'
                        : type === 'claude'
                          ? 'Claude'
                          : 'Codex'}</button
                    >{/each}
                </div>
                <p class="worktree-path">{session.worktreePath}</p>
              </div>{/if}
          </div>
        </section>
        {#if showInspector}{#key session.id}<Inspector {session} />{/key}{/if}
      </div>
    {:else}<div class="panel welcome">
        <span class="wordmark">Helm</span>
        <h1>Your agents. One workspace.</h1>
        <p class="muted">
          Open a local project, create a session, and get to work.
        </p>
        <button
          class="mt-6"
          disabled={!loaded || busy}
          onclick={() => action(() => window.helm.projects.add())}
          >Add local project</button
        >{#if workspaceState.lastProjectId}<button
            class="mt-3"
            onclick={() =>
              (newProject = workspaceState.projects.find(
                (p) => p.id === workspaceState.lastProjectId,
              )!)}>New session</button
          >{/if}
      </div>{/if}
  </main>
</div>
{#if newProject}<NewSession
    project={newProject}
    onclose={() => (newProject = null)}
    oncreated={refresh}
  />{/if}
{#if pendingRemove}<div class="overlay">
    <dialog
      use:modal
      oncancel={() => (pendingRemove = null)}
      class="confirmation"
      aria-label="Confirm removal"
    >
      <h2>Remove {pendingRemove.kind}?</h2>
      <p class="muted mb-5">
        {pendingRemove.kind === 'project'
          ? 'Removes this project and its sessions from Helm. Folders and worktrees stay on disk. Running panes will stop.'
          : pendingRemove.kind === 'session'
            ? 'Stops this session’s panes. An owned worktree is removed only if clean; its Git branch is kept.'
            : 'Stops this pane’s process and removes the pane.'}
      </p>
      <div class="flex gap-2">
        <button onclick={() => (pendingRemove = null)}>Cancel</button><button
          class="danger"
          disabled={busy}
          onclick={remove}>Remove</button
        >
      </div>
    </dialog>
  </div>{/if}
{#if settings || help}<div class="overlay">
    <dialog
      use:modal
      oncancel={() => {
        settings = false;
        help = false;
      }}
      class="confirmation"
      aria-label={settings ? 'Settings' : 'Help'}
    >
      <h2>{settings ? 'Settings' : 'Working in Helm'}</h2>
      {#if settings}<label
          >Terminal font size<input
            type="number"
            min="10"
            max="24"
            value={workspaceState.settings.fontSize}
            onchange={(e) =>
              action(() =>
                window.helm.settings.update({
                  fontSize: Number(e.currentTarget.value),
                }),
              )}
          /></label
        >{:else}<p class="muted mb-5">
          Add a local project, then use ＋ beside its name to create a session.
          Use ＋ in the pane bar to launch Claude, Codex, or your shell. Click
          “Code Diff” to browse files. CLI login and permissions stay inside the
          real terminal. Switching sessions keeps processes running; quitting
          Helm stops them.
        </p>{/if}<button
        onclick={() => {
          settings = false;
          help = false;
        }}>Done</button
      >
    </dialog>
  </div>{/if}

<style>
  .app-shell {
    display: flex;
    height: 100vh;
    background: #111;
  }
  aside {
    width: 264px;
    flex: none;
    display: flex;
    flex-direction: column;
    padding: 0 12px 12px;
  }
  .window-drag {
    height: 58px;
    -webkit-app-region: drag;
    display: flex;
    align-items: center;
    padding-left: 100px;
  }
  .brand {
    font-size: 11px;
    letter-spacing: 2px;
    color: #555;
  }
  .search {
    display: flex;
    align-items: center;
    padding: 0 8px;
    gap: 8px;
  }
  .search img {
    width: 20px;
    height: 20px;
    opacity: 0.5;
  }
  .search input {
    width: 100%;
    background: transparent;
    border: 0;
    padding: 8px 0;
    font-size: 14px;
  }
  .new-project {
    display: flex;
    align-items: center;
    gap: 8px;
    color: #777;
    padding: 8px;
  }
  .plus {
    font-size: 23px;
    width: 20px;
  }
  nav {
    overflow: auto;
    flex: 1;
    padding-top: 42px;
  }
  .project-group {
    margin-bottom: 38px;
  }
  .project-row {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 4px 8px;
    color: #999;
  }
  .project-symbol {
    font-size: 21px;
  }
  .project-name {
    overflow: hidden;
    white-space: nowrap;
    text-overflow: ellipsis;
    flex: 1;
    text-align: left;
    padding: 4px 0;
    font-weight: 500;
  }
  .small {
    padding: 4px;
    width: 24px;
    font-size: 18px;
  }
  .session-row {
    display: flex;
    align-items: center;
    border-radius: 6px;
  }
  .session-row.selected {
    background: #252525;
  }
  .session-link {
    display: flex;
    align-items: center;
    gap: 14px;
    min-width: 0;
    flex: 1;
    padding: 10px 12px;
    text-align: left;
    font-size: 14px;
  }
  .status-dot {
    display: inline-block;
    width: 8px;
    height: 8px;
    border-radius: 50%;
    background: #454545;
    flex: none;
  }
  .status-dot.live {
    background: #19ad59;
  }
  .first-session {
    font-size: 12px;
    padding-left: 36px;
  }
  footer {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  footer button {
    display: flex;
    gap: 10px;
    color: #777;
    align-items: center;
    text-align: left;
    padding: 8px;
  }
  footer img {
    width: 20px;
    height: 20px;
    opacity: 0.5;
  }
  main {
    min-width: 0;
    flex: 1;
    padding: 8px 8px 8px 8px;
    display: flex;
    flex-direction: column;
  }
  .workspace {
    display: flex;
    gap: 8px;
    flex: 1;
    min-height: 0;
  }
  .terminal-panel {
    flex: 1;
    min-width: 340px;
    display: flex;
    flex-direction: column;
  }
  .terminal-symbol {
    color: #ff721c;
    font-family: monospace;
    font-size: 20px;
  }
  .pane-toolbar {
    display: flex;
    padding: 0 12px;
    gap: 6px;
    align-items: center;
    min-height: 35px;
  }
  .pane-tabs {
    display: flex;
    gap: 3px;
    overflow: auto;
    flex: 1;
  }
  .pane-tabs button {
    white-space: nowrap;
    display: flex;
    align-items: center;
    gap: 7px;
    padding: 5px 8px;
    font-size: 11px;
    background: none;
    border-color: transparent;
    color: #888;
  }
  .pane-tabs .chosen {
    color: #ddd;
    background: #242424;
  }
  .add-pane {
    position: relative;
  }
  .add-pane summary {
    cursor: pointer;
    list-style: none;
    padding: 6px;
    font-size: 18px;
    color: #aaa;
  }
  .menu {
    position: absolute;
    right: 0;
    top: 32px;
    width: 165px;
    background: #242424;
    border: 1px solid #444;
    border-radius: 8px;
    padding: 6px;
    z-index: 5;
  }
  .menu button {
    width: 100%;
    text-align: left;
    background: none;
    border: 0;
  }
  .terminal-space {
    position: relative;
    flex: 1;
    min-height: 0;
  }
  .session-title {
    font-size: 14px;
  }
  .empty-workspace {
    padding: 80px 30px;
    text-align: center;
    color: #888;
  }
  .empty-workspace h1 {
    font-size: 17px;
    color: #ccc;
    margin-bottom: 12px;
  }
  .worktree-path {
    font: 11px/1.7 monospace;
    margin-top: 25px;
    overflow-wrap: anywhere;
    color: #666;
  }
  .welcome {
    height: 100%;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
  }
  .welcome h1 {
    font-size: 25px;
    margin: 12px 0;
  }
  .wordmark {
    letter-spacing: 4px;
    text-transform: uppercase;
    color: #777;
  }
  .global-error {
    display: flex;
    justify-content: space-between;
    margin-bottom: 8px;
  }
  .overlay {
    position: fixed;
    inset: 0;
    background: #0008;
    display: grid;
    place-items: center;
    z-index: 10;
  }
  .confirmation {
    width: 380px;
    background: #202020;
    border: 1px solid #383838;
    padding: 24px;
    border-radius: 10px;
  }
  @media (max-width: 1050px) {
    aside {
      width: 225px;
    }
    .workspace {
      overflow-x: auto;
    }
    .terminal-panel {
      min-width: 400px;
    }
  }
</style>
