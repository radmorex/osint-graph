// Narrow bridge between the page and the main process (contextIsolation + sandbox).
'use strict';
const { contextBridge, ipcRenderer } = require('electron');

const init = ipcRenderer.sendSync('load-data') || {};

contextBridge.exposeInMainWorld('osintNative', {
  platform: process.platform,
  initialData: init.data ?? null,
  dataPath: init.dataPath || '',
  post: (msg) => ipcRenderer.send('native', msg),
});
