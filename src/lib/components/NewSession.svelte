<script lang="ts">
  import { onMount } from 'svelte';
  import type { Project } from '$shared/contracts';
  let {
    project,
    onclose,
    oncreated,
  }: { project: Project; onclose: () => void; oncreated: () => Promise<void> } =
    $props();
  let dialog: HTMLDialogElement;
  let title = $state('');
  let base = $state('');
  let branches = $state<string[]>([]);
  let useWorktree = $state(true);
  let error = $state('');
  let busy = $state(false);
  onMount(() => {
    dialog.showModal();
    void window.helm.git
      .branches(project.id)
      .then((b) => {
        branches = b;
        base = b.includes('main') ? 'main' : b[0] || '';
        useWorktree = !!b.length;
      })
      .catch((e) => (error = String(e)));
  });
  async function create(e: SubmitEvent) {
    e.preventDefault();
    busy = true;
    try {
      await window.helm.sessions.create({
        projectId: project.id,
        title,
        base,
        useWorktree,
      });
      await oncreated();
      onclose();
    } catch (e) {
      error = String(e);
    } finally {
      busy = false;
    }
  }
</script>

<dialog
  bind:this={dialog}
  {onclose}
  oncancel={(e) => {
    if (busy) e.preventDefault();
  }}
>
  <form onsubmit={create}>
    <h2>New Session</h2>
    <label
      >Session name<input
        bind:value={title}
        placeholder="Implement Meeting Link"
        required
        maxlength="120"
      /></label
    ><label class="muted"
      >Target Branch<select
        bind:value={base}
        disabled={!branches.length || !useWorktree}
        >{#each branches as branch}<option value={branch}>{branch}</option
          >{/each}{#if !branches.length}<option value=""
            >No committed branches</option
          >{/if}</select
      ></label
    ><label class="toggle-row"
      >Use worktree<input
        type="checkbox"
        role="switch"
        bind:checked={useWorktree}
        disabled={!branches.length}
      /></label
    >{#if !useWorktree}<p class="muted mb-4 text-xs">
        Uses the project’s current directory and branch.
      </p>{/if}{#if error}<p class="error mb-3">{error}</p>{/if}<button
      class="create"
      disabled={busy || !title.trim()}>{busy ? 'Creating…' : 'Create'}</button
    ><button
      type="button"
      class="plain cancel"
      disabled={busy}
      onclick={onclose}>Cancel</button
    >
  </form>
</dialog>

<style>
  dialog {
    width: 320px;
    padding: 20px;
    background: #202020;
    border-color: #303030;
  }
  h2 {
    font-size: 14px;
  }
  .toggle-row {
    flex-direction: row;
    justify-content: space-between;
    align-items: center;
    margin: 22px 0;
  }
  input[role='switch'] {
    appearance: none;
    width: 32px;
    height: 20px;
    border: 0;
    border-radius: 20px;
    background: #444;
    padding: 2px;
    cursor: pointer;
  }
  input[role='switch']::before {
    content: '';
    display: block;
    background: white;
    border-radius: 50%;
    width: 16px;
    height: 16px;
  }
  input[role='switch']:checked {
    background: #698861;
  }
  input[role='switch']:checked::before {
    transform: translateX(12px);
  }
  .create {
    background: white;
    color: #111;
    border-radius: 30px;
    width: 100%;
    font-weight: 600;
  }
  .cancel {
    width: 100%;
    margin-top: 8px;
    color: #aaa;
  }
</style>
