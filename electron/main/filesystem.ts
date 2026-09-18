import { realpath, readdir, readFile, stat } from 'node:fs/promises';
import { resolve, relative, isAbsolute, sep } from 'node:path';
import { watch, type FSWatcher } from 'chokidar';
import { git } from './git';
export async function safePath(root: string, path: string) {
  const base = await realpath(root);
  const target = await realpath(resolve(base, path));
  const rel = relative(base, target);
  if (
    rel === '..' ||
    rel.startsWith('..' + sep) ||
    isAbsolute(rel) ||
    rel.split(sep).includes('.git')
  )
    throw Error('Path is outside the workspace or is Git metadata');
  return target;
}
export class Filesystem {
  watchers = new Map<string, FSWatcher>();
  async list(root: string, path: string) {
    const dir = await safePath(root, path);
    const items = await readdir(dir, { withFileTypes: true });
    const visible = items.filter(
      (e) =>
        !['.git', 'node_modules', 'dist', 'build', '.svelte-kit'].includes(
          e.name,
        ) && !e.isSymbolicLink(),
    );
    const ignored = new Set(
      (
        await git(root, [
          'ls-files',
          '--others',
          '--ignored',
          '--exclude-standard',
          '--directory',
          '-z',
          '--',
          relative(root, dir) || '.',
        ]).catch(() => '')
      )
        .split('\0')
        .map((s) => s.replace(/\/$/, '')),
    );
    return visible
      .filter((e) => !ignored.has(relative(root, resolve(dir, e.name))))
      .map((e) => ({ name: e.name, directory: e.isDirectory() }))
      .sort(
        (a, b) =>
          Number(b.directory) - Number(a.directory) ||
          a.name.localeCompare(b.name),
      );
  }
  async read(root: string, path: string) {
    const target = await safePath(root, path);
    if ((await stat(target)).size > 2 * 1024 * 1024)
      throw Error('Preview limited to 2 MB');
    const data = await readFile(target);
    if (data.includes(0)) throw Error('Binary file; text previews only');
    return data.toString('utf8');
  }
  async stat(root: string, path: string) {
    const s = await stat(await safePath(root, path));
    return { size: s.size, directory: s.isDirectory(), modifiedAt: s.mtimeMs };
  }
  watch(
    id: string,
    root: string,
    emit: (event: { sessionId: string; path: string }) => void,
  ) {
    if (this.watchers.has(id)) return;
    const w = watch(root, {
      ignoreInitial: true,
      depth: 3,
      followSymlinks: false,
      ignored: (p) =>
        p
          .split(/[\\/]/)
          .some((s) =>
            ['.git', 'node_modules', 'dist', 'build', '.svelte-kit'].includes(
              s,
            ),
          ),
    });
    w.on('all', (_, p) => emit({ sessionId: id, path: relative(root, p) }));
    w.on('error', (e) => console.error('Watcher:', e));
    this.watchers.set(id, w);
  }
  async unwatch(id: string) {
    await this.watchers.get(id)?.close();
    this.watchers.delete(id);
  }
  async close() {
    await Promise.all([...this.watchers.keys()].map((id) => this.unwatch(id)));
  }
}
