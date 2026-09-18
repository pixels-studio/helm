import * as pty from 'node-pty';
import { randomUUID } from 'node:crypto';
import type { Store } from './persistence';
import type { TerminalEvent } from '../../shared/contracts';
type Record = {
  id: string;
  paneId: string;
  sessionId: string;
  process: pty.IPty;
  sequence: number;
  data: string;
  exitCode?: number;
};
export class Terminals {
  records = new Map<string, Record>();
  constructor(
    private store: Store,
    private emit: (e: TerminalEvent) => void,
  ) {}
  create(input: {
    sessionId: string;
    paneId: string;
    type: 'claude' | 'codex' | 'shell';
  }) {
    const session = this.store.session(input.sessionId);
    const pane = this.store.pane(input.paneId);
    if (
      pane.sessionId !== session.id ||
      (pane.type === 'terminal' ? 'shell' : pane.type) !== input.type
    )
      throw Error('Pane/session mismatch');
    const existing = [...this.records.values()].find(
      (r) => r.paneId === pane.id && r.exitCode === undefined,
    );
    if (existing) return existing.id;
    const command =
      input.type === 'shell'
        ? process.env.SHELL ||
          (process.platform === 'win32' ? 'powershell.exe' : '/bin/sh')
        : input.type;
    const env = Object.fromEntries(
      Object.entries(process.env).filter(
        (entry): entry is [string, string] => entry[1] !== undefined,
      ),
    );
    delete env.ELECTRON_RUN_AS_NODE;
    env.TERM = 'xterm-256color';
    env.COLORTERM = 'truecolor';
    let proc: pty.IPty;
    try {
      proc = pty.spawn(
        command,
        input.type === 'shell' && process.platform !== 'win32' ? ['-l'] : [],
        {
          name: 'xterm-256color',
          cols: 80,
          rows: 24,
          cwd: session.worktreePath,
          env,
        },
      );
    } catch (e) {
      throw Error(
        `Could not launch ${command}. Install the CLI and ensure it is on PATH. ${String(e)}`,
      );
    }
    const id = randomUUID();
    const r: Record = {
      id,
      paneId: pane.id,
      sessionId: session.id,
      process: proc,
      sequence: 0,
      data: '',
    };
    this.records.set(id, r);
    proc.onData((data) => {
      r.data = (r.data + data).slice(-1024 * 1024);
      this.emit({ terminalId: id, sequence: ++r.sequence, data });
    });
    proc.onExit(({ exitCode }) => {
      r.exitCode = exitCode;
      this.emit({ terminalId: id, sequence: ++r.sequence, exitCode });
    });
    return id;
  }
  get(id: string) {
    const r = this.records.get(id);
    if (!r) throw Error('Terminal not found');
    return r;
  }
  write(id: string, data: string) {
    const r = this.get(id);
    if (r.exitCode === undefined) r.process.write(data);
  }
  resize(id: string, cols: number, rows: number) {
    const r = this.get(id);
    if (r.exitCode === undefined) r.process.resize(cols, rows);
  }
  kill(id: string) {
    const r = this.get(id);
    if (r.exitCode === undefined) r.process.kill();
  }
  closePane(id: string) {
    for (const [key, r] of this.records)
      if (r.paneId === id) {
        this.kill(key);
        this.records.delete(key);
      }
  }
  closeSession(id: string) {
    for (const r of this.records.values())
      if (r.sessionId === id) this.closePane(r.paneId);
  }
  close() {
    for (const id of this.records.keys()) this.kill(id);
  }
}
