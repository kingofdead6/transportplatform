/**
 * Loads the built site in a real DOM, runs the bundled React app, and asserts
 * the page actually rendered — a successful `vite build` only proves the code
 * compiles, not that anything appears on screen.
 *
 *   node scripts/smoke-test.mjs
 */
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { JSDOM, VirtualConsole } from 'jsdom';

const here = dirname(fileURLToPath(import.meta.url));
const dist = resolve(here, '..', 'dist');

let pass = 0;
let fail = 0;
const check = (name, cond, detail = '') => {
  if (cond) {
    pass++;
    console.log('  PASS ', name, detail);
  } else {
    fail++;
    console.log('  FAIL ', name, detail);
  }
};

const html = readFileSync(resolve(dist, 'index.html'), 'utf8');

// Surface real page errors, but ignore jsdom's unsupported-CSS noise
// (backdrop-filter, etc.), which is not a defect in the page.
const virtualConsole = new VirtualConsole();
virtualConsole.on('jsdomError', (e) => {
  if (!/Could not parse CSS/i.test(e.message)) console.error('PAGE ERROR:', e.message);
});

const dom = new JSDOM(html, {
  runScripts: 'dangerously',
  resources: undefined,
  url: 'http://localhost/',
  virtualConsole,
  pretendToBeVisual: true,
});

const { window } = dom;

// Serve the built JS/CSS off disk: jsdom will not fetch them itself here.
for (const script of window.document.querySelectorAll('script[src]')) {
  const src = script.getAttribute('src').replace(/^\//, '');
  const code = readFileSync(resolve(dist, src), 'utf8');
  const el = window.document.createElement('script');
  el.textContent = code;
  window.document.body.appendChild(el);
}

// Let React commit.
await new Promise((r) => setTimeout(r, 300));

const doc = window.document;
const root = doc.getElementById('root');
// Measure #root, not <body>: body also contains the bundle <script> we injected
// above, whose source text would inflate the count into the hundreds of
// thousands and make this assertion meaningless.
const text = root ? root.textContent || '' : '';

console.log('\n--- rendered page ---');

check('React mounted into #root', root && root.children.length > 0);
check('page has real copy', text.trim().length > 2000, `(${text.trim().length} visible chars)`);

check('hero headline present', /de bout en bout/i.test(text));
check('all four roles listed', ['Chargeur', 'Transporteur', 'Chauffeur', 'Administration'].every((r) => text.includes(r)));
check('features section rendered', /Suivi en direct/.test(text) && /Résistant au réseau/.test(text));
check('lifecycle steps rendered', doc.querySelectorAll('.flow__step').length === 11, `(${doc.querySelectorAll('.flow__step').length} steps)`);

// The link the whole page exists to deliver.
const repoLink = [...doc.querySelectorAll('a[href]')].find((a) =>
  a.getAttribute('href').includes('github.com/kingofdead6/transportplatform')
);
check('GitHub source link present', !!repoLink);
check('external links are rel-safe', [...doc.querySelectorAll('a[target="_blank"]')].every((a) => (a.getAttribute('rel') || '').includes('noreferrer')));

// The download CTA behaves differently depending on whether a real APK URL has
// been configured yet. Both paths must be sound, so assert whichever applies.
const disabledCta = doc.querySelector('.btn--disabled');
const deadLinks = [...doc.querySelectorAll('a[href="#"]')];
const downloadLinks = [...doc.querySelectorAll('a[download]')];

check('no dead "#" links anywhere', deadLinks.length === 0, `(${deadLinks.length})`);

if (disabledCta) {
  console.log('  (apkUrl is still a placeholder — checking the disabled state)');
  check('placeholder CTA renders as a disabled control', true);
  check('disabled CTA is marked for assistive tech', disabledCta.getAttribute('aria-disabled') === 'true');
} else {
  console.log('  (apkUrl is configured — checking the real download link)');
  check('download link is rendered', downloadLinks.length > 0, `(${downloadLinks.length})`);
  check(
    'download link points at the configured APK',
    downloadLinks.every((a) => /^https?:\/\//.test(a.getAttribute('href'))),
    `(${downloadLinks[0]?.getAttribute('href') ?? 'none'})`
  );
}

// Accessibility basics
check('exactly one <h1>', doc.querySelectorAll('h1').length === 1);
check('page language is set', doc.documentElement.getAttribute('lang') === 'fr');
check('nav landmarks present', !!doc.querySelector('header.nav') && !!doc.querySelector('main') && !!doc.querySelector('footer'));
check('decorative icons hidden from AT', [...doc.querySelectorAll('svg')].every((s) => s.getAttribute('aria-hidden') === 'true'));

console.log(`\n  ${pass} passed, ${fail} failed\n`);
window.close();
process.exit(fail ? 1 : 0);
