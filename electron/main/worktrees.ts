import { mkdir } from 'node:fs/promises';
import { join } from 'node:path';
import { git, status } from './git';
import type { Session } from '../../shared/contracts';
export class Worktrees {
  constructor(private root: string) {}
  async create(
    projectPath: string,
    projectId: string,
    id: string,
    title: string,
    base: string,
  ) {
    if (!base || base.startsWith('-'))
      throw Error('Select a valid base branch');
    await git(projectPath, ['rev-parse', '--verify', base + '^{commit}']);
    const branch =
      'helm/' +
      (title
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/^-|-$/g, '') || 'session') +
      '-' +
      id.slice(0, 8);
    const parent = join(this.root, 'worktrees', projectId);
    await mkdir(parent, { recursive: true });
    const path = join(parent, id);
    await git(projectPath, ['worktree', 'add', '-b', branch, path, base]);
    return { branch, path };
  }
  async remove(session: Session) {
    if (!session.ownsWorktree)
      throw Error('This session does not own a worktree');
    if ((await status(session.worktreePath)).changes.length)
      throw Error(
        'Worktree has changes. Commit or move them before removing it.',
      );
    await git(session.worktreePath, [
      'worktree',
      'remove',
      session.worktreePath,
    ]);
  }
}
