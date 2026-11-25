// OSINT Graph — desktop shell (Electron) for Windows, macOS and Linux.
// The whole UI lives in ../src/index.html. This process only:
//   • stores data in <userData>/data.json (+ one backup per day in <userData>/backups, last 30 kept)
//   • shows native "Save as…" dialogs for exports
//   • opens links in the system browser
// No network requests are made by the app itself.
'use strict';
const { app, BrowserWindow, ipcMain, dialog, shell, Menu } = require('electron');
const path = require('path');
const fs = require('fs');

// Optional: keep data in a custom folder (e.g. on an encrypted / USB drive):
//   OSINT_GRAPH_DATA_DIR=/path/to/folder
if (process.env.OSINT_GRAPH_DATA_DIR) app.setPath('userData', path.resolve(process.env.OSINT_GRAPH_DATA_DIR));

if (!app.requestSingleInstanceLock()) { app.quit(); process.exit(0); }

const isMac = process.platform === 'darwin';
const REPO_URL = 'https://github.com/radmorex/osint-graph';
let win = null;

const dataDir = () => app.getPath('userData');
const dataFile = () => path.join(dataDir(), 'data.json');
const backupDir = () => path.join(dataDir(), 'backups');

function readData() {
  try { return JSON.parse(fs.readFileSync(dataFile(), 'utf8')); } catch { return null; }
}
function writeAtomic(file, content) {
  const tmp = file + '.tmp';
  fs.writeFileSync(tmp, content);
  fs.renameSync(tmp, file);
}
function dailyBackup(content) {
  fs.mkdirSync(backupDir(), { recursive: true });
  const d = new Date();
  const stamp = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
  const target = path.join(backupDir(), `data-${stamp}.json`);
  if (!fs.existsSync(target)) fs.writeFileSync(target, content);
  const old = fs.readdirSync(backupDir()).filter(f => /^data-\d{4}-\d{2}-\d{2}\.json$/.test(f)).sort().reverse().slice(30);
  for (const f of old) fs.rmSync(path.join(backupDir(), f), { force: true });
}
function openExternalSafe(raw) {
  try {
    const u = new URL(String(raw));
    if (u.protocol === 'http:' || u.protocol === 'https:') shell.openExternal(u.href);
  } catch { /* not a URL — ignore */ }
}

// ---- messages from the page -------------------------------------------------
ipcMain.on('load-data', (e) => { e.returnValue = { data: readData(), dataPath: dataFile() }; });

ipcMain.on('native', async (e, msg) => {
  if (!win || e.sender !== win.webContents || !msg || typeof msg !== 'object') return;
  switch (msg.type) {
    case 'save': {
      if (typeof msg.data !== 'string') return;
      try {
        JSON.parse(msg.data); // never write broken JSON over good data
        fs.mkdirSync(dataDir(), { recursive: true });
        writeAtomic(dataFile(), msg.data);
        dailyBackup(msg.data);
      } catch (err) {
        dialog.showErrorBox('OSINT Graph', 'Не удалось сохранить данные:\n' + err.message);
      }
      break;
    }
    case 'open':
      openExternalSafe(msg.url);
      break;
    case 'export': {
      const name = String(msg.name || 'export').replace(/[\\/:*?"<>|]+/g, '_');
      let buf;
      if (typeof msg.text === 'string') buf = Buffer.from(msg.text, 'utf8');
      else if (typeof msg.base64 === 'string') buf = Buffer.from(msg.base64, 'base64');
      else return;
      const r = await dialog.showSaveDialog(win, { defaultPath: path.join(app.getPath('documents'), name) });
      if (r.canceled || !r.filePath) return;
      try { fs.writeFileSync(r.filePath, buf); }
      catch (err) { dialog.showErrorBox('OSINT Graph', 'Не удалось сохранить файл:\n' + err.message); }
      break;
    }
  }
});

// ---- window -----------------------------------------------------------------
function createWindow() {
  win = new BrowserWindow({
    width: 1440, height: 900, minWidth: 720, minHeight: 480,
    backgroundColor: '#0a0a0a',
    title: 'OSINT Graph',
    autoHideMenuBar: true,
    icon: path.join(__dirname, '..', 'build', 'icon.png'),
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: true,
      spellcheck: false,
    },
  });
  win.loadFile(path.join(__dirname, '..', 'src', 'index.html'));

  // links never open inside the app
  win.webContents.setWindowOpenHandler(({ url }) => { openExternalSafe(url); return { action: 'deny' }; });
  win.webContents.on('will-navigate', (e, url) => {
    if (url !== win.webContents.getURL()) { e.preventDefault(); openExternalSafe(url); }
  });
  win.on('closed', () => { win = null; });
}

function buildMenu() {
  const openData = { label: 'Открыть папку с данными', click: () => shell.openPath(dataDir()) };
  const template = [
    ...(isMac
      ? [{ label: app.name, submenu: [{ role: 'about' }, { type: 'separator' }, openData, { type: 'separator' },
          { role: 'hide' }, { role: 'hideOthers' }, { role: 'unhide' }, { type: 'separator' }, { role: 'quit' }] }]
      : [{ label: 'Файл', submenu: [openData, { type: 'separator' }, { role: 'quit', label: 'Выход' }] }]),
    { label: 'Правка', submenu: [{ role: 'undo' }, { role: 'redo' }, { type: 'separator' },
      { role: 'cut' }, { role: 'copy' }, { role: 'paste' }, { role: 'selectAll' }] },
    { label: 'Вид', submenu: [{ role: 'resetZoom' }, { role: 'zoomIn' }, { role: 'zoomOut' },
      { type: 'separator' }, { role: 'togglefullscreen' }] },
    { label: 'Окно', submenu: [{ role: 'minimize' }, { role: 'close' }] },
    { label: 'Справка', submenu: [{ label: 'Страница проекта на GitHub', click: () => openExternalSafe(REPO_URL) }] },
  ];
  Menu.setApplicationMenu(Menu.buildFromTemplate(template));
}

app.on('second-instance', () => { if (win) { if (win.isMinimized()) win.restore(); win.focus(); } });
app.whenReady().then(() => {
  buildMenu();
  createWindow();
  app.on('activate', () => { if (BrowserWindow.getAllWindows().length === 0) createWindow(); });
});
app.on('window-all-closed', () => { app.quit(); });
