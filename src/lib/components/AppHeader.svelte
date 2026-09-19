<script lang="ts">
  import BarChart3 from '@lucide/svelte/icons/chart-no-axes-column-increasing';
  import ChevronLeft from '@lucide/svelte/icons/chevron-left';
  import ChevronRight from '@lucide/svelte/icons/chevron-right';
  import CircleHelp from '@lucide/svelte/icons/circle-help';
  import Plus from '@lucide/svelte/icons/plus';
  import Settings from '@lucide/svelte/icons/settings';
  import { Button } from '$lib/components/ui/button';
  import * as Tooltip from '$lib/components/ui/tooltip';
  import ProjectSwitcher from './project-switcher.svelte';
  import type { Project } from '$shared/contracts';

  let {
    projects,
    active,
    onselect,
    onaddProject,
    onaddPane,
    onprevious,
    onnext,
    onhelp,
  }: {
    projects: Project[];
    active?: Project;
    onselect: (id: string) => void;
    onaddProject: () => void;
    onaddPane: () => void;
    onprevious: () => void;
    onnext: () => void;
    onhelp: () => void;
  } = $props();
</script>

<header class="app-header">
  <div class="header-group">
    <ProjectSwitcher {projects} {active} {onselect} onadd={onaddProject} />
    <span class="divider" aria-hidden="true"></span>
    <Tooltip.Root>
      <Tooltip.Trigger>
        {#snippet child({ props })}<Button {...props} variant="secondary" size="icon" aria-label="Add new pane" onclick={onaddPane}><Plus /></Button>{/snippet}
      </Tooltip.Trigger>
      <Tooltip.Content>Add conversation</Tooltip.Content>
    </Tooltip.Root>
    <Button variant="secondary" size="icon" aria-label="Previous pane" onclick={onprevious}><ChevronLeft /></Button>
    <Button variant="secondary" size="icon" aria-label="Next pane" onclick={onnext}><ChevronRight /></Button>
  </div>
  <div class="header-group utility-actions">
    <Button variant="secondary" size="icon" aria-label="Help" onclick={onhelp}><CircleHelp /></Button>
    <Button variant="secondary" size="icon" aria-label="Insights"><BarChart3 /></Button>
    <Button variant="secondary" size="icon" aria-label="Settings"><Settings /></Button>
  </div>
</header>

<style>
  .app-header {
    position: sticky;
    top: 0;
    z-index: 20;
    display: flex;
    align-items: center;
    justify-content: space-between;
    min-height: 52px;
    padding: 8px 16px;
    background: var(--background);
    -webkit-app-region: drag;
  }
  .header-group {
    display: flex;
    align-items: center;
    gap: 12px;
    -webkit-app-region: no-drag;
  }
  .divider {
    align-self: stretch;
    width: 1px;
    background: color-mix(in srgb, var(--foreground) 8%, transparent);
  }
  .utility-actions :global(button) {
    color: var(--foreground-subtle);
  }
</style>
