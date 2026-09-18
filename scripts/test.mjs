import { spawn } from 'node:child_process';
import { mkdtemp } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import electron from 'electron';
const data = await mkdtemp(join(tmpdir(), 'helm-test-state-'));
for (const phase of ['1', 'restart']) {
  const code = await new Promise((resolve) => {
    const child = spawn(electron, ['.'], {
      stdio: 'inherit',
      env: { ...process.env, HELM_SMOKE: phase, HELM_USER_DATA: data },
    });
    const timeout = setTimeout(() => {
      console.error('Smoke test timed out');
      child.kill('SIGKILL');
    }, 60000);
    child.on('exit', (code) => {
      clearTimeout(timeout);
      resolve(code ?? 1);
    });
  });
  if (code) process.exit(code);
}
