import { randomUUID } from 'node:crypto';
import { basename } from 'node:path';
import { realpath } from 'node:fs/promises';
import { Store } from './persistence';
import { Worktrees } from './worktrees';
import { Filesystem } from './filesystem';
import { Terminals } from './terminal';
import * as git from './git';
import type { API, Session } from '../../shared/contracts';
export function services(
  root: string,
  choose: () => Promise<string | undefined>,
  emit: (channel: string, data: unknown) => void,
) {
  const store = new Store(root),
    worktrees = new Worktrees(root),
    fs = new Filesystem(),
    terminal = new Terminals(store, (e) => emit('terminal:data', e));
  const removeSession = async (id: string) => {
    const s = store.session(id);
    if (s.ownsWorktree) await worktrees.remove(s);
    terminal.closeSession(id);
    await fs.unwatch(id);
    store.state.sessions = store.state.sessions.filter((s) => s.id !== id);
    store.state.panes = store.state.panes.filter((p) => p.sessionId !== id);
    if (store.state.lastSessionId === id) delete store.state.lastSessionId;
    store.save();
  };
  const api: Omit<API, 'terminal' | 'filesystem'> & {
    terminal: Omit<API['terminal'], 'onData'>;
    filesystem: Omit<API['filesystem'], 'onChange'>;
  } = {
    state: { get: async () => store.state },
    projects: {
      list: async () => store.state.projects,
      add: async () => {
        const selected = await choose();
        if (!selected) return null;
        const path = await realpath(selected);
        let p = store.state.projects.find((p) => p.path === path);
        if (!p) {
          p = {
            id: randomUUID(),
            name: basename(path),
            path,
            createdAt: Date.now(),
            lastOpenedAt: Date.now(),
          };
          store.state.projects.push(p);
        }
        store.state.lastProjectId = p.id;
        delete store.state.lastSessionId;
        store.save();
        return p;
      },
      select: async (id) => {
        store.project(id).lastOpenedAt = Date.now();
        store.state.lastProjectId = id;
        delete store.state.lastSessionId;
        store.save();
      },
      remove: async (id) => {
        store.project(id);
        for (const s of store.state.sessions.filter(
          (s) => s.projectId === id,
        )) {
          terminal.closeSession(s.id);
          await fs.unwatch(s.id);
        }
        const ids = new Set(
          store.state.sessions
            .filter((s) => s.projectId === id)
            .map((s) => s.id),
        );
        store.state.panes = store.state.panes.filter(
          (p) => !ids.has(p.sessionId),
        );
        store.state.sessions = store.state.sessions.filter(
          (s) => s.projectId !== id,
        );
        store.state.projects = store.state.projects.filter((p) => p.id !== id);
        if (store.state.lastProjectId === id) {
          delete store.state.lastProjectId;
          delete store.state.lastSessionId;
        }
        store.save();
      },
    },
    sessions: {
      create: async (input) => {
        const p = store.project(input.projectId),
          id = randomUUID();
        const wt = input.useWorktree
          ? await worktrees.create(p.path, p.id, id, input.title, input.base)
          : undefined;
        const s: Session = {
          id,
          projectId: p.id,
          title: input.title,
          worktreePath: wt?.path ?? p.path,
          branch: wt?.branch || (await git.status(p.path)).branch,
          ownsWorktree: !!wt,
          createdAt: Date.now(),
          lastOpenedAt: Date.now(),
          layout: { paneIds: [] },
        };
        store.state.sessions.push(s);
        store.state.lastProjectId = p.id;
        store.state.lastSessionId = s.id;
        store.save();
        return s;
      },
      select: async (id) => {
        const s = store.session(id);
        s.lastOpenedAt = Date.now();
        store.state.lastSessionId = id;
        store.state.lastProjectId = s.projectId;
        store.save();
      },
      remove: removeSession,
    },
    panes: {
      add: async (sessionId, type) => {
        const s = store.session(sessionId);
        const p = {
          id: randomUUID(),
          sessionId,
          type,
          title:
            type === 'terminal'
              ? 'Terminal'
              : type === 'claude'
                ? 'Claude'
                : 'Codex',
        };
        store.state.panes.push(p);
        s.layout.paneIds.push(p.id);
        s.layout.activePaneId = p.id;
        store.save();
        return p;
      },
      select: async (id) => {
        const p = store.pane(id);
        store.session(p.sessionId).layout.activePaneId = id;
        store.save();
      },
      remove: async (id) => {
        const p = store.pane(id),
          s = store.session(p.sessionId);
        terminal.closePane(id);
        store.state.panes = store.state.panes.filter((p) => p.id !== id);
        s.layout.paneIds = s.layout.paneIds.filter((pid) => pid !== id);
        if (s.layout.activePaneId === id)
          s.layout.activePaneId = s.layout.paneIds[0];
        store.save();
      },
    },
    terminal: {
      create: async (i) => terminal.create(i),
      write: async (id, data) => terminal.write(id, data),
      resize: async (id, c, r) => terminal.resize(id, c, r),
      kill: async (id) => terminal.kill(id),
      snapshot: async (id) => {
        const r = terminal.get(id);
        return { data: r.data, sequence: r.sequence, exitCode: r.exitCode };
      },
    },
    git: {
      status: async (id) => git.status(store.session(id).worktreePath),
      branches: async (id) => git.branches(store.project(id).path),
      diff: async (id, path) => {
        const root = store.session(id).worktreePath;
        if (path.includes('\0') || path.split(/[\\/]/).includes('..'))
          throw Error('Invalid path');
        const s = await git.status(root);
        const change = s.changes.find((c) => c.path === path);
        if (!change) throw Error('File is not a current change');
        if (change.index === '?')
          return 'Untracked file\n\n' + (await fs.read(root, path));
        return git.diff(root, path);
      },
    },
    filesystem: {
      list: async (id, path) => fs.list(store.session(id).worktreePath, path),
      readFile: async (id, path) =>
        fs.read(store.session(id).worktreePath, path),
      stat: async (id, path) => fs.stat(store.session(id).worktreePath, path),
      watch: async (id) =>
        fs.watch(id, store.session(id).worktreePath, (e) =>
          emit('filesystem:change', e),
        ),
      unwatch: async (id) => {
        store.session(id);
        await fs.unwatch(id);
      },
    },
    worktrees: { remove: removeSession },
    settings: {
      update: async (settings) => {
        store.state.settings = settings;
        store.save();
      },
    },
  };
  return {
    api,
    store,
    terminal,
    close: async () => {
      terminal.close();
      await fs.close();
    },
  };
}
