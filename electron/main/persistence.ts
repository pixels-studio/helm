import {
  mkdirSync,
  readFileSync,
  writeFileSync,
  renameSync,
  existsSync,
} from 'node:fs';
import { join } from 'node:path';
import { stateSchema, type State } from '../../shared/contracts';
export class Store {
  state: State;
  private file: string;
  constructor(root: string) {
    mkdirSync(root, { recursive: true });
    this.file = join(root, 'state.json');
    this.state = existsSync(this.file)
      ? stateSchema.parse(JSON.parse(readFileSync(this.file, 'utf8')))
      : {
          version: 1,
          projects: [],
          sessions: [],
          panes: [],
          settings: { fontSize: 13 },
        };
  }
  save() {
    const tmp = this.file + '.tmp';
    writeFileSync(tmp, JSON.stringify(this.state, null, 2), { mode: 0o600 });
    renameSync(tmp, this.file);
  }
  session(id: string) {
    const s = this.state.sessions.find((s) => s.id === id);
    if (!s) throw Error('Session not found');
    return s;
  }
  project(id: string) {
    const p = this.state.projects.find((p) => p.id === id);
    if (!p) throw Error('Project not found');
    return p;
  }
  pane(id: string) {
    const p = this.state.panes.find((p) => p.id === id);
    if (!p) throw Error('Pane not found');
    return p;
  }
}
