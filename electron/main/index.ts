import { app, BrowserWindow, dialog, ipcMain, protocol, net } from 'electron';
import { join, resolve, relative, isAbsolute } from 'node:path';
import { pathToFileURL } from 'node:url';
import { homedir } from 'node:os';
import { requests } from '../../shared/contracts';
import { services } from './services';
protocol.registerSchemesAsPrivileged([
  {
    scheme: 'helm',
    privileges: { standard: true, secure: true, supportFetchAPI: true },
  },
]);
app.setName('Helm');
if (process.env.HELM_USER_DATA)
  app.setPath('userData', process.env.HELM_USER_DATA);
process.env.PATH = [
  process.env.PATH,
  join(homedir(), '.local/bin'),
  join(homedir(), '.npm-global/bin'),
  '/opt/homebrew/bin',
  '/usr/local/bin',
]
  .filter(Boolean)
  .join(process.platform === 'win32' ? ';' : ':');
let win: BrowserWindow;
let backend: ReturnType<typeof services>;
const dev = process.env.HELM_DEV_URL;
const trusted = (url: string) =>
  dev
    ? new URL(url).origin === new URL(dev).origin
    : new URL(url).protocol === 'helm:' && new URL(url).hostname === 'app';
async function window() {
  win = new BrowserWindow({
    width: 1280,
    height: 820,
    minWidth: 850,
    minHeight: 550,
    backgroundColor: '#151619',
    title: 'Helm',
    titleBarStyle: 'hiddenInset',
    trafficLightPosition: { x: 20, y: 22 },
    webPreferences: {
      preload: join(__dirname, '../preload/index.cjs'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
    },
  });
  win.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
  win.webContents.on('will-navigate', (event, url) => {
    if (!trusted(url)) event.preventDefault();
  });
  win.webContents.session.setPermissionRequestHandler(
    (_wc, _permission, callback) => callback(false),
  );
  await win.loadURL(dev || 'helm://app/');
}
app
  .whenReady()
  .then(async () => {
    const root = resolve(__dirname, '../../build');
    protocol.handle('helm', (request) => {
      const url = new URL(request.url);
      const path = resolve(
        root,
        '.' +
          decodeURIComponent(
            url.pathname === '/' ? '/index.html' : url.pathname,
          ),
      );
      const rel = relative(root, path);
      if (url.host !== 'app' || rel.startsWith('..') || isAbsolute(rel))
        return new Response('Forbidden', { status: 403 });
      return net.fetch(pathToFileURL(path).href);
    });
    backend = services(
      app.getPath('userData'),
      async () => {
        const result = await dialog.showOpenDialog(win, {
          properties: ['openDirectory'],
        });
        return result.canceled ? undefined : result.filePaths[0];
      },
      (channel, data) => {
        if (win && !win.isDestroyed()) win.webContents.send(channel, data);
      },
    );
    for (const [channel, schema] of Object.entries(requests))
      ipcMain.handle(channel, async (event, ...args) => {
        if (
          event.sender !== win.webContents ||
          event.senderFrame !== win.webContents.mainFrame ||
          !trusted(event.senderFrame.url)
        )
          throw Error('Untrusted IPC sender');
        const validated = schema.parse(args);
        const [group, method] = channel.split('.');
        const api = backend.api as unknown as Record<
          string,
          Record<string, (...args: unknown[]) => unknown>
        >;
        return api[group][method](...validated);
      });
    await window();
    if (process.env.HELM_SMOKE) {
      const { smoke } = await import('./smoke');
      await smoke(win, backend);
      app.quit();
    }
  })
  .catch((error) => {
    console.error(error);
    app.exit(1);
  });
app.on('window-all-closed', () => app.quit());
app.on('before-quit', () => {
  void backend?.close();
});
