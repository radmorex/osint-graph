// Generates the README screenshots in docs/screenshots/ from a fictional demo case.
//   npm run screenshots
// Uses a throw-away data folder, so your real data is never touched.
'use strict';
const { app, BrowserWindow } = require('electron');
const path = require('path');
const fs = require('fs');
const os = require('os');

app.setPath('userData', fs.mkdtempSync(path.join(os.tmpdir(), 'osint-graph-shots-')));
const OUT = path.join(__dirname, '..', 'docs', 'screenshots');
const wait = (ms) => new Promise((r) => setTimeout(r, ms));

// ---- fictional demo case (all names, domains, numbers are made up) ----------
const N = (name, type = 'group', o = {}, children = []) => ({ name, type, url: '', note: '', status: '', ...o, children });
const DEMO = N('Кейс 014 · продавець «gadget_lviv»', 'group', { note: 'Перевірка продавця з маркетплейсу. Усі дані вигадані.' }, [
  N('Вихідні дані', 'group', {}, [
    N('gadget_lviv', 'username', { status: 'ok', note: 'Нік із запиту клієнта' }),
    N('Оголошення на маркетплейсі', 'link', { url: 'https://example.com/item/48213' }),
    N('Фото товару (3 шт.)', 'photo', { note: 'EXIF видалено, є відображення у склі' }),
  ]),
  N('Акаунти', 'group', {}, [
    N('Telegram', 'group', {}, [
      N('@gadget_lviv', 'social', { status: 'ok', note: 'Той самий аватар, що й на маркетплейсі.\nАктивний з 03.2024.' }),
      N('@gl_support', 'social', { status: 'maybe', note: 'Згадується в описі каналу' }),
    ]),
    N('Instagram', 'group', {}, [N('gadget.lviv.shop', 'social', { status: 'maybe' })]),
    N('Форуми', 'group', {}, [N('forum.example.net / gadgetlviv', 'social', { status: 'no', note: 'Інша людина, збіг ніка' })]),
  ]),
  N('Контакти', 'group', {}, [
    N('gadget.lviv@example.com', 'email', { status: 'ok' }),
    N('+380 XX XXX-12-34', 'phone', { status: 'maybe', note: 'З опису оголошення' }),
  ]),
  N('Домени та інфраструктура', 'group', {}, [
    N('gadget-lviv.example', 'domain', { status: 'ok' }, [
      N('WHOIS: приватна реєстрація', 'note'),
      N('203.0.113.42', 'ip', { status: 'ok', note: 'Спільний хостинг' }),
      N('Сертифікат: shop-lviv.example', 'domain', { status: 'maybe' }),
    ]),
  ]),
  N('Геолокація', 'group', {}, [
    N('Львів, Сихів', 'location', { status: 'maybe', note: 'Збіг фону на 2 фото з 3' }),
  ]),
  N('Хронологія', 'group', {}, [
    N('2024-03 · перша активність', 'event'),
    N('2025-11 · нове оголошення', 'event'),
  ]),
  N('Інструменти', 'group', {}, [
    N('WhatsMyName', 'tool', { url: 'https://whatsmyname.app' }),
    N('Epieos', 'tool', { url: 'https://epieos.com' }),
    N('crt.sh', 'tool', { url: 'https://crt.sh' }),
    N('Google Lens', 'tool', { url: 'https://lens.google.com' }),
  ]),
]);

// ---- runs inside the page ---------------------------------------------------
function setup(demo) {
  store.cases = [{ id: uid(), root: fix(demo), updated: Date.now() }];
  ui = { side: true, insp: true, focus: false };
  applyUI();
  openCase(store.cases[0].id);
  window.byName = (name) => { let f = null; (function w(n) { if (n.name === name) f = n; n.children.forEach(w); })(cur.root); return f; };
  window.quiet = () => { $('#toast').classList.remove('on'); };
}

const SHOTS = [
  ['overview', `setCollapseAll('expand'); ui.side=false; ui.insp=true; applyUI(); select(byName('@gadget_lviv').id); fit(); quiet();`],
  ['search', `ui.side=true; ui.insp=false; applyUI(); selectedId=null; $('#q').value='lviv'; query='lviv'; render(); fillInsp(); fit(); quiet();`],
  ['focus-mode', `$('#q').value=''; query=''; ui.focus=true; ui.side=false; ui.insp=false; applyUI(); select(byName('Домени та інфраструктура').id); focusBranch(); quiet();`],
  ['text-mode', `ui.focus=false; ui.side=true; applyUI(); setCollapseAll('expand'); selectedId=null; render(); fillInsp(); fit(); openText('all'); quiet();`],
];

app.whenReady().then(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const win = new BrowserWindow({
    width: 1280, height: 800, useContentSize: true, show: false, backgroundColor: '#0a0a0a',
    webPreferences: { contextIsolation: true, sandbox: true },
  });
  await win.loadFile(path.join(__dirname, '..', 'src', 'index.html'));
  const run = (js) => win.webContents.executeJavaScript(js);
  await run(`(${setup.toString()})(${JSON.stringify(DEMO)})`);
  for (const [name, js] of SHOTS) {
    await run(js);
    await wait(500);
    const img = await win.webContents.capturePage();
    fs.writeFileSync(path.join(OUT, `${name}.png`), img.toPNG());
    console.log('saved', name, img.getSize());
  }
  app.quit();
});
