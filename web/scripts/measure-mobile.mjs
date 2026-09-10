/** Drives headless Chrome over the DevTools protocol with a real mobile
 *  viewport (metrics override), then reports the document's scroll width.
 *  A screenshot alone can be misleading; this measures layout directly. */
import { spawn } from 'node:child_process';
import { setTimeout as sleep } from 'node:timers/promises';

const CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
const PAGE = process.argv[2] || 'http://localhost:4324/';
const WIDTH = Number(process.argv[3] || 390);
const PORT = 9222;

const chrome = spawn(CHROME, [
  '--headless=new',
  '--disable-gpu',
  `--remote-debugging-port=${PORT}`,
  '--no-first-run',
  '--user-data-dir=' + process.env.TEMP + '/chrome-measure',
  'about:blank',
]);

try {
  // Wait for the debugging endpoint.
  let target = null;
  for (let i = 0; i < 40 && !target; i++) {
    await sleep(500);
    try {
      const list = await fetch(`http://127.0.0.1:${PORT}/json/list`).then((r) => r.json());
      target = list.find((t) => t.type === 'page');
    } catch {
      /* not up yet */
    }
  }
  if (!target) throw new Error('Chrome DevTools endpoint never came up');

  const ws = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((res, rej) => {
    ws.onopen = res;
    ws.onerror = rej;
  });

  let id = 0;
  const pending = new Map();
  ws.onmessage = (e) => {
    const msg = JSON.parse(e.data);
    if (msg.id && pending.has(msg.id)) {
      pending.get(msg.id)(msg.result);
      pending.delete(msg.id);
    }
  };
  const send = (method, params = {}) =>
    new Promise((res) => {
      const myId = ++id;
      pending.set(myId, res);
      ws.send(JSON.stringify({ id: myId, method, params }));
    });

  await send('Page.enable');
  // The key step: force a true mobile viewport, which a bare --window-size does not.
  await send('Emulation.setDeviceMetricsOverride', {
    width: WIDTH,
    height: 900,
    deviceScaleFactor: 1,
    mobile: true,
  });
  await send('Page.navigate', { url: PAGE });
  await sleep(3500);

  const { result } = await send('Runtime.evaluate', {
    returnByValue: true,
    expression: `(() => {
      const de = document.documentElement;
      const vw = de.clientWidth;
      const offenders = [];
      for (const el of document.querySelectorAll('body *')) {
        const r = el.getBoundingClientRect();
        // Skip elements parked far off-screen (a common pattern for visually
        // hidden skip links, including ones injected by browser extensions) —
        // they do not affect the document's scroll width.
        if (r.left > vw * 2 || r.width === 0 || r.height === 0) continue;
        if (r.right > vw + 1) {
          offenders.push(el.tagName.toLowerCase() + '.' +
            String(el.className || '').split(' ').filter(Boolean).slice(0,2).join('.') +
            ' right=' + Math.round(r.right));
        }
      }
      return { vw, scrollW: de.scrollWidth, overflows: de.scrollWidth > vw + 1,
               offenders: offenders.slice(0, 10) };
    })()`,
  });

  const v = result.value;
  console.log(`\nviewport ${v.vw}px | document scrollWidth ${v.scrollW}px`);
  console.log(v.overflows ? '  HORIZONTAL OVERFLOW' : '  no horizontal overflow');
  if (v.offenders.length) {
    console.log('  elements past the right edge:');
    for (const o of v.offenders) console.log('   -', o);
  }
  // Optional: capture a screenshot through the same emulated viewport, so the
  // image matches what a phone actually shows.
  const shot = process.argv[4];
  if (shot) {
    await send('Emulation.setDeviceMetricsOverride', {
      width: WIDTH, height: 1500, deviceScaleFactor: 1, mobile: true,
    });
    await sleep(600);
    const { data } = await send('Page.captureScreenshot', { format: 'png', captureBeyondViewport: true });
    const { writeFileSync } = await import('node:fs');
    writeFileSync(shot, Buffer.from(data, 'base64'));
    console.log('  screenshot →', shot);
  }

  ws.close();
  process.exit(v.overflows ? 1 : 0);
} finally {
  chrome.kill();
}
