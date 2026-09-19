<script lang="ts">
  import Check from '@lucide/svelte/icons/check';
  import ChevronDown from '@lucide/svelte/icons/chevron-down';
  import Plus from '@lucide/svelte/icons/plus';
  import { Button } from '$lib/components/ui/button';
  import * as DropdownMenu from '$lib/components/ui/dropdown-menu';
  import type { Project } from '$shared/contracts';

  let {
    projects,
    active,
    onselect,
    onadd,
  }: {
    projects: Project[];
    active?: Project;
    onselect: (id: string) => void;
    onadd: () => void;
  } = $props();
</script>

<DropdownMenu.Root>
  <DropdownMenu.Trigger>
    {#snippet child({ props })}
      <Button {...props} variant="secondary" class="project-trigger">
        <span class="favicon" aria-hidden="true">{active?.name[0]?.toUpperCase() || 'H'}</span>
        <span class="project-name">{active?.name || 'Select project'}</span>
        <ChevronDown class="chevron" />
      </Button>
    {/snippet}
  </DropdownMenu.Trigger>
  <DropdownMenu.Content align="start" class="project-menu">
    <DropdownMenu.Label>Projects</DropdownMenu.Label>
    {#each projects as project}
      <DropdownMenu.Item onclick={() => onselect(project.id)}>
        <span class="menu-favicon">{project.name[0]?.toUpperCase()}</span>
        <span class="menu-label">{project.name}</span>
        {#if project.id === active?.id}<Check class="check" />{/if}
      </DropdownMenu.Item>
    {/each}
    <DropdownMenu.Separator />
    <DropdownMenu.Item onclick={onadd}><Plus /> Add project</DropdownMenu.Item>
  </DropdownMenu.Content>
</DropdownMenu.Root>

<style>
  :global(.project-trigger) {
    max-width: 240px;
    gap: 8px;
    padding-left: 8px;
    background: var(--control);
    color: var(--foreground);
  }
  .favicon,
  .menu-favicon {
    display: grid;
    flex: none;
    place-items: center;
    width: 20px;
    height: 20px;
    border-radius: 5px;
    background: var(--accent);
    color: white;
    font-size: 11px;
    font-weight: 600;
  }
  .project-name,
  .menu-label {
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  :global(.chevron) {
    width: 14px;
    height: 14px;
    color: var(--foreground-subtle);
  }
  :global(.project-menu) {
    width: 224px;
  }
  :global(.check) {
    margin-left: auto;
  }
</style>
