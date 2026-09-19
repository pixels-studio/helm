<script lang="ts">
  import { onMount, tick, untrack } from 'svelte';
  import Archive from '@lucide/svelte/icons/archive';
  import ArrowUp from '@lucide/svelte/icons/arrow-up';
  import Bot from '@lucide/svelte/icons/bot';
  import FileCode2 from '@lucide/svelte/icons/file-code-2';
  import Files from '@lucide/svelte/icons/folder-open';
  import GitBranch from '@lucide/svelte/icons/git-branch';
  import Maximize2 from '@lucide/svelte/icons/maximize-2';
  import MoreHorizontal from '@lucide/svelte/icons/ellipsis';
  import PanelLeft from '@lucide/svelte/icons/panel-left';
  import PanelTop from '@lucide/svelte/icons/panel-top';
  import Paperclip from '@lucide/svelte/icons/paperclip';
  import Square from '@lucide/svelte/icons/square';
  import Terminal from '@lucide/svelte/icons/square-terminal';
  import X from '@lucide/svelte/icons/x';
  import { Button } from '$lib/components/ui/button';
  import * as Card from '$lib/components/ui/card';
  import * as DropdownMenu from '$lib/components/ui/dropdown-menu';
  import * as Select from '$lib/components/ui/select';
  import * as Tooltip from '$lib/components/ui/tooltip';
  import TextView from './conversation/TextView.svelte';
  import AttachmentView from './conversation/AttachmentView.svelte';
  import ThinkingView from './conversation/ThinkingView.svelte';
  import ToolView from './conversation/ToolView.svelte';
  import Inspector from './Inspector.svelte';
  import type TerminalPane from './TerminalPane.svelte';
  import type {
    AssistantEvent,
    Attachment,
    ConversationMessage,
    Pane,
    Session,
    Usage,
  } from '$shared/contracts';

  type PaneSize = 'full' | 'half' | 'third';
  type View = 'chat' | 'terminal' | 'diff' | 'files';

  let {
    pane,
    session,
    onarchive,
    onresize,
  }: {
    pane: Pane;
    session: Session;
    onarchive: () => void;
    onresize: (size: PaneSize) => void;
  } = $props();

  let messages = $state<ConversationMessage[]>([
    ...untrack(() => pane.messages),
  ]);
  let usage = $state<Usage | undefined>(untrack(() => pane.usage));
  let running = $state(false);
  let prompt = $state('');
  let error = $state('');
  let view = $state<View>('chat');
  let model = $state(untrack(() => pane.model) || 'default');
  let attachments = $state<Attachment[]>([]);
  let displayTitle = $state(
    untrack(() =>
      pane.title === 'Codex' || pane.title === 'New Conversation'
        ? 'New Conversation'
        : pane.title,
    ),
  );
  let feed = $state<HTMLDivElement>();
  let TerminalPaneComponent = $state<typeof TerminalPane>();
  const models = [
    { value: 'default', label: 'Default' },
    { value: 'gpt-5.6-terra', label: 'Terra' },
    { value: 'gpt-6-astra', label: 'Astra' },
  ];
  const usedTokens = $derived(
    usage
      ? usage.inputTokens + usage.outputTokens + usage.reasoningOutputTokens
      : 0,
  );

  function updateMessage(message: ConversationMessage) {
    const index = messages.findIndex((item) => item.id === message.id);
    if (index === -1) messages = [...messages, message];
    else messages[index] = message;
    messages = [...messages];
    void tick().then(() => feed?.scrollTo({ top: feed.scrollHeight }));
  }

  async function submit() {
    const text = prompt.trim();
    if (!text || running) return;
    prompt = '';
    error = '';
    running = true;
    if (displayTitle === 'New Conversation') displayTitle = titleFrom(text);
    const attachmentIds = attachments.map(({ id }) => id);
    attachments = [];
    try {
      await window.helm.assistant.send({
        paneId: pane.id,
        text,
        attachmentIds,
        model: model === 'default' ? '' : model,
        reasoningEffort: pane.reasoningEffort,
      });
    } catch (cause) {
      error = cause instanceof Error ? cause.message : String(cause);
      running = false;
    }
  }

  async function pickAttachment() {
    if (attachments.length >= 8) return;
    try {
      const attachment = await window.helm.assistant.pickAttachment(pane.id);
      if (attachment) attachments = [...attachments, attachment];
    } catch (cause) {
      error = cause instanceof Error ? cause.message : String(cause);
    }
  }

  function titleFrom(text: string) {
    const compact = text.replace(/\s+/g, ' ').trim();
    return compact.length > 42 ? `${compact.slice(0, 41).trimEnd()}…` : compact;
  }

  async function toggleView(next: View) {
    view = view === next ? 'chat' : next;
    if (view === 'terminal' && !TerminalPaneComponent)
      TerminalPaneComponent = (await import('./TerminalPane.svelte')).default;
  }

  function keydown(event: KeyboardEvent) {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault();
      void submit();
    }
  }

  function contextLabel(tokens: number) {
    if (!tokens) return '0';
    return tokens >= 1000 ? `${(tokens / 1000).toFixed(1)}k` : String(tokens);
  }

  onMount(() =>
    window.helm.assistant.onEvent((event: AssistantEvent) => {
      if (event.paneId !== pane.id) return;
      if (event.type === 'message') updateMessage(event.message);
      if (event.type === 'usage') usage = event.usage;
      if (event.type === 'status') {
        running = event.status === 'running';
        if (event.error) error = event.error;
      }
    }),
  );
</script>

<Card.Root class="assistant-card">
  <header class="pane-header">
    <div class="pane-title">
      <Bot aria-hidden="true" />
      <span title={displayTitle}>{displayTitle}</span>
      <Tooltip.Root>
        <Tooltip.Trigger>
          {#snippet child({ props })}<button {...props} class="branch-chip"
              ><GitBranch /> {session.branch || 'Folder'}</button
            >{/snippet}
        </Tooltip.Trigger>
        <Tooltip.Content
          >{session.ownsWorktree ? 'Worktree' : 'Local project'} · {session.worktreePath}</Tooltip.Content
        >
      </Tooltip.Root>
    </div>
    <div class="pane-actions">
      <Button
        variant="ghost"
        size="icon"
        aria-label="Open file preview"
        class={view === 'files' ? 'active' : ''}
        onclick={() => (view = view === 'files' ? 'chat' : 'files')}
        ><Files /></Button
      >
      <Button
        variant="ghost"
        size="icon"
        aria-label="Open terminal"
        class={view === 'terminal' ? 'active' : ''}
        onclick={() => toggleView('terminal')}><Terminal /></Button
      >
      <Button
        variant="ghost"
        size="icon"
        aria-label="Open code diff"
        class={view === 'diff' ? 'active' : ''}
        onclick={() => (view = view === 'diff' ? 'chat' : 'diff')}
        ><FileCode2 /></Button
      >
      <DropdownMenu.Root>
        <DropdownMenu.Trigger>
          {#snippet child({ props })}<Button
              {...props}
              variant="ghost"
              size="icon"
              aria-label="Conversation options"><MoreHorizontal /></Button
            >{/snippet}
        </DropdownMenu.Trigger>
        <DropdownMenu.Content align="end">
          <DropdownMenu.Label>Pane size</DropdownMenu.Label>
          <DropdownMenu.Item onclick={() => onresize('full')}
            ><Maximize2 /> Full</DropdownMenu.Item
          >
          <DropdownMenu.Item onclick={() => onresize('half')}
            ><PanelLeft /> Half</DropdownMenu.Item
          >
          <DropdownMenu.Item onclick={() => onresize('third')}
            ><PanelTop /> Third</DropdownMenu.Item
          >
          <DropdownMenu.Separator />
          <DropdownMenu.Item onclick={onarchive}
            ><Archive /> Archive</DropdownMenu.Item
          >
        </DropdownMenu.Content>
      </DropdownMenu.Root>
    </div>
  </header>

  <div class="pane-content">
    {#if view === 'chat'}
      <div class="conversation" bind:this={feed} aria-live="polite">
        {#if messages.length === 0}
          <div class="empty-conversation">
            <Bot />
            <p>Ask Codex to explore, explain, or change this project.</p>
          </div>
        {/if}
        {#each messages as message (message.id)}
          {#if message.kind === 'text' || message.kind === 'error'}
            <TextView {message} />
          {:else if message.kind === 'thinking'}
            <ThinkingView {message} />
          {:else if message.kind === 'tool'}
            <ToolView {message} />
          {:else if message.kind === 'attachment'}
            <AttachmentView name={message.text} detail="Image" />
          {/if}
        {/each}
        {#if error}<p class="pane-error" role="alert">{error}</p>{/if}
      </div>
    {:else if view === 'terminal'}
      <div class="terminal-view">
        {#if TerminalPaneComponent}
          <TerminalPaneComponent
            pane={{ ...pane, type: 'terminal', title: 'Terminal' }}
            active={true}
            onstatus={() => {}}
          />
        {/if}
      </div>
    {:else}
      {#key view}<Inspector {session} initialMode={view} embedded />{/key}
    {/if}
  </div>

  {#if view === 'chat'}
    <div class="composer-wrap">
      {#if messages.length === 0}
        <div class="new-conversation-options">
          <span
            title={session.ownsWorktree
              ? 'This conversation uses an isolated Git worktree'
              : 'This conversation uses your local checkout'}
            >{session.ownsWorktree ? 'Use worktree' : 'Use local'}</span
          >
          <span><GitBranch /> {session.branch || 'Folder'}</span>
        </div>
      {/if}
      <form
        class="composer"
        onsubmit={(event) => {
          event.preventDefault();
          void submit();
        }}
      >
        {#if attachments.length}
          <div class="pending-attachments" aria-label="Selected attachments">
            {#each attachments as attachment (attachment.id)}
              <div class="attachment-chip">
                <AttachmentView name={attachment.name} detail="Image" />
                <button
                  type="button"
                  aria-label={`Remove ${attachment.name}`}
                  onclick={() =>
                    (attachments = attachments.filter(
                      ({ id }) => id !== attachment.id,
                    ))}><X /></button
                >
              </div>
            {/each}
          </div>
        {/if}
        <textarea
          aria-label="Message Codex"
          placeholder="Ask for changes"
          bind:value={prompt}
          onkeydown={keydown}
          disabled={running}></textarea>
        <div class="composer-footer">
          <div class="composer-meta">
            <Select.Root type="single" items={models} bind:value={model}>
              <Select.Trigger aria-label="Select model" class="model-trigger"
                ><Select.Value placeholder="Default" /></Select.Trigger
              >
              <Select.Content>
                {#each models as item}<Select.Item
                    value={item.value}
                    label={item.label}>{item.label}</Select.Item
                  >{/each}
              </Select.Content>
            </Select.Root>
            <span class="effort">· {pane.reasoningEffort}</span>
            <Tooltip.Root>
              <Tooltip.Trigger>
                {#snippet child({ props })}<button
                    {...props}
                    class="context-usage"
                    >{contextLabel(usedTokens)} tokens</button
                  >{/snippet}
              </Tooltip.Trigger>
              <Tooltip.Content>
                {usage
                  ? `${usage.inputTokens.toLocaleString()} input · ${usage.outputTokens.toLocaleString()} output · ${usage.reasoningOutputTokens.toLocaleString()} reasoning`
                  : 'Context usage appears after the first response'}
              </Tooltip.Content>
            </Tooltip.Root>
          </div>
          <div class="composer-actions">
            <Tooltip.Root>
              <Tooltip.Trigger>
                {#snippet child({ props })}<Button
                    {...props}
                    variant="ghost"
                    size="icon"
                    aria-label="Add image"
                    disabled={running || attachments.length >= 8}
                    onclick={pickAttachment}><Paperclip /></Button
                  >{/snippet}
              </Tooltip.Trigger>
              <Tooltip.Content>Add image</Tooltip.Content>
            </Tooltip.Root>
            {#if running}
              <Button
                variant="secondary"
                size="icon"
                aria-label="Stop response"
                onclick={() => window.helm.assistant.cancel(pane.id)}
                ><Square /></Button
              >
            {:else}
              <Button
                class="send"
                size="icon"
                aria-label="Send message"
                type="submit"
                disabled={!prompt.trim()}><ArrowUp /></Button
              >
            {/if}
          </div>
        </div>
      </form>
    </div>
  {/if}
</Card.Root>

<style>
  :global(.assistant-card) {
    height: 100%;
    min-width: 0;
    background: var(--panel);
  }
  .pane-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    flex: none;
    gap: 12px;
    padding: 12px 16px;
  }
  .pane-title,
  .pane-actions,
  .composer-footer,
  .composer-meta,
  .composer-actions,
  .new-conversation-options,
  .branch-chip {
    display: flex;
    align-items: center;
  }
  .pane-title {
    min-width: 0;
    gap: 8px;
  }
  .pane-title > :global(svg) {
    flex: none;
    width: 20px;
    height: 20px;
  }
  .pane-title > span {
    overflow: hidden;
    color: var(--foreground);
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .branch-chip {
    flex: none;
    gap: 5px;
    padding: 0 8px;
    border: 0;
    border-radius: 48px;
    background: var(--control);
    color: var(--foreground);
    font: inherit;
    font-size: 12px;
    line-height: 20px;
  }
  .branch-chip :global(svg) {
    width: 13px;
    height: 13px;
  }
  .pane-actions {
    gap: 8px;
  }
  .pane-actions :global(button) {
    color: var(--foreground-subtle);
  }
  .pane-actions :global(button.active) {
    background: var(--control-active);
    color: var(--foreground);
  }
  .pane-content {
    position: relative;
    flex: 1;
    min-height: 0;
  }
  .conversation {
    position: absolute;
    inset: 0;
    display: flex;
    flex-direction: column;
    gap: 24px;
    overflow-y: auto;
    padding: 26px 16px 28px;
    scroll-behavior: smooth;
  }
  .empty-conversation {
    display: grid;
    flex: 1;
    place-content: center;
    justify-items: center;
    color: var(--foreground-subtle);
    text-align: center;
  }
  .empty-conversation :global(svg) {
    width: 24px;
    height: 24px;
  }
  .empty-conversation p {
    max-width: 260px;
  }
  .pane-error {
    color: var(--destructive);
  }
  .terminal-view {
    position: absolute;
    inset: 0;
  }
  .composer-wrap {
    flex: none;
    padding: 0 16px 16px;
  }
  .new-conversation-options {
    gap: 24px;
    padding: 0 2px 12px;
    color: var(--foreground-subtle);
    font-size: 14px;
  }
  .new-conversation-options span {
    display: flex;
    align-items: center;
    gap: 7px;
  }
  .new-conversation-options :global(svg) {
    width: 16px;
    height: 16px;
  }
  .composer {
    padding: 12px 16px;
    border-radius: 8px;
    background: var(--composer);
  }
  .pending-attachments {
    display: flex;
    gap: 8px;
    overflow-x: auto;
    padding-bottom: 8px;
  }
  .attachment-chip {
    position: relative;
    flex: none;
  }
  .attachment-chip > button {
    position: absolute;
    top: 4px;
    right: 4px;
    display: grid;
    place-items: center;
    padding: 3px;
    border: 0;
    border-radius: 50%;
    background: var(--control-active);
    color: var(--foreground);
  }
  .attachment-chip > button :global(svg) {
    width: 12px;
    height: 12px;
  }
  textarea {
    display: block;
    width: 100%;
    min-height: 60px;
    resize: none;
    border: 0;
    outline: 0;
    background: transparent;
    color: var(--foreground);
    font: inherit;
    font-size: 16px;
    line-height: 20px;
  }
  textarea::placeholder {
    color: var(--foreground-subtle);
  }
  .composer-footer {
    justify-content: space-between;
    gap: 12px;
  }
  .composer-meta {
    min-width: 0;
    gap: 3px;
  }
  :global(.model-trigger) {
    border: 0;
    padding: 6px 0;
    background: transparent;
    color: var(--foreground);
  }
  .effort,
  .context-usage {
    color: var(--foreground-subtle);
    font-size: 12px;
    text-transform: capitalize;
  }
  .context-usage {
    margin-left: 7px;
    padding: 4px;
    border: 0;
    background: transparent;
  }
  .composer-actions {
    gap: 10px;
  }
  :global(.send) {
    background: var(--accent);
    color: white;
  }
  @media (prefers-reduced-motion: reduce) {
    .conversation {
      scroll-behavior: auto;
    }
  }
</style>
