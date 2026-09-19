<script lang="ts">
  import Paperclip from '@lucide/svelte/icons/paperclip';

  let { name, detail = 'Attachment' }: { name: string; detail?: string } =
    $props();
</script>

<div class="attachment">
  <Paperclip />
  <span><strong>{name}</strong><small>{detail}</small></span>
</div>

<style>
  .attachment {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 10px 12px;
    border-radius: 8px;
    background: var(--surface-raised);
    color: var(--foreground);
  }
  :global(svg) {
    width: 18px;
    height: 18px;
  }
  span {
    display: grid;
  }
  small {
    color: var(--foreground-subtle);
  }
</style>
