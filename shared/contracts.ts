import { z } from 'zod';
export const id = z.string().uuid();
export const paneType = z.enum([
  'claude',
  'codex',
  'terminal',
  'file',
  'diff',
  'git',
  'browser',
]);
export const paneSchema = z.object({
  id,
  sessionId: id,
  type: paneType,
  title: z.string(),
  path: z.string().optional(),
});
export const sessionSchema = z.object({
  id,
  projectId: id,
  title: z.string(),
  branch: z.string().optional(),
  worktreePath: z.string(),
  ownsWorktree: z.boolean(),
  createdAt: z.number(),
  lastOpenedAt: z.number(),
  layout: z.object({ paneIds: z.array(id), activePaneId: id.optional() }),
});
export const projectSchema = z.object({
  id,
  name: z.string(),
  path: z.string(),
  createdAt: z.number(),
  lastOpenedAt: z.number(),
});
export const stateSchema = z.object({
  version: z.literal(1),
  projects: z.array(projectSchema),
  sessions: z.array(sessionSchema),
  panes: z.array(paneSchema),
  lastProjectId: id.optional(),
  lastSessionId: id.optional(),
  settings: z.object({ fontSize: z.number().int().min(10).max(24) }),
});
export type Project = z.infer<typeof projectSchema>;
export type Session = z.infer<typeof sessionSchema>;
export type Pane = z.infer<typeof paneSchema>;
export type State = z.infer<typeof stateSchema>;
export type Change = { path: string; index: string; worktree: string };
export type GitStatus = { isGit: boolean; branch: string; changes: Change[] };
export type Entry = { name: string; directory: boolean };
export type TerminalEvent = {
  terminalId: string;
  sequence: number;
  data?: string;
  exitCode?: number;
};
export const requests = {
  'projects.list': z.tuple([]),
  'projects.add': z.tuple([]),
  'projects.remove': z.tuple([id]),
  'projects.select': z.tuple([id]),
  'sessions.create': z.tuple([
    z.object({
      projectId: id,
      title: z.string().trim().min(1).max(120),
      base: z.string().max(200),
      useWorktree: z.boolean(),
    }),
  ]),
  'sessions.select': z.tuple([id]),
  'sessions.remove': z.tuple([id]),
  'panes.add': z.tuple([id, z.enum(['claude', 'codex', 'terminal'])]),
  'panes.select': z.tuple([id]),
  'panes.remove': z.tuple([id]),
  'terminal.create': z.tuple([
    z.object({
      sessionId: id,
      paneId: id,
      type: z.enum(['claude', 'codex', 'shell']),
    }),
  ]),
  'terminal.write': z.tuple([id, z.string().max(1048576)]),
  'terminal.resize': z.tuple([
    id,
    z.number().int().min(2).max(500),
    z.number().int().min(1).max(300),
  ]),
  'terminal.kill': z.tuple([id]),
  'terminal.snapshot': z.tuple([id]),
  'git.status': z.tuple([id]),
  'git.branches': z.tuple([id]),
  'git.diff': z.tuple([id, z.string().max(4096)]),
  'filesystem.list': z.tuple([id, z.string().max(4096)]),
  'filesystem.readFile': z.tuple([id, z.string().max(4096)]),
  'filesystem.stat': z.tuple([id, z.string().max(4096)]),
  'filesystem.watch': z.tuple([id]),
  'filesystem.unwatch': z.tuple([id]),
  'settings.update': z.tuple([stateSchema.shape.settings]),
  'state.get': z.tuple([]),
  'worktrees.remove': z.tuple([id]),
};
export type API = {
  state: { get(): Promise<State> };
  projects: {
    list(): Promise<Project[]>;
    add(): Promise<Project | null>;
    remove(id: string): Promise<void>;
    select(id: string): Promise<void>;
  };
  sessions: {
    create(input: {
      projectId: string;
      title: string;
      base: string;
      useWorktree: boolean;
    }): Promise<Session>;
    select(id: string): Promise<void>;
    remove(id: string): Promise<void>;
  };
  panes: {
    add(
      sessionId: string,
      type: 'claude' | 'codex' | 'terminal',
    ): Promise<Pane>;
    select(id: string): Promise<void>;
    remove(id: string): Promise<void>;
  };
  terminal: {
    create(input: {
      sessionId: string;
      paneId: string;
      type: 'claude' | 'codex' | 'shell';
    }): Promise<string>;
    write(id: string, data: string): Promise<void>;
    resize(id: string, cols: number, rows: number): Promise<void>;
    kill(id: string): Promise<void>;
    snapshot(
      id: string,
    ): Promise<{ data: string; sequence: number; exitCode?: number }>;
    onData(fn: (event: TerminalEvent) => void): () => void;
  };
  git: {
    status(sessionId: string): Promise<GitStatus>;
    branches(projectId: string): Promise<string[]>;
    diff(sessionId: string, path: string): Promise<string>;
  };
  filesystem: {
    list(sessionId: string, path: string): Promise<Entry[]>;
    readFile(sessionId: string, path: string): Promise<string>;
    stat(
      sessionId: string,
      path: string,
    ): Promise<{ size: number; directory: boolean; modifiedAt: number }>;
    watch(sessionId: string): Promise<void>;
    unwatch(sessionId: string): Promise<void>;
    onChange(
      fn: (event: { sessionId: string; path: string }) => void,
    ): () => void;
  };
  worktrees: { remove(sessionId: string): Promise<void> };
  settings: { update(settings: State['settings']): Promise<void> };
};
