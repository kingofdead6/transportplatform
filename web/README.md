# Prosim Planat — Web

Presentation site for the Prosim Planat mobile app. React + Vite, no runtime
dependencies beyond React itself (icons are inline SVG, the palette is plain CSS
custom properties).

```bash
cd web
npm install
npm run dev       # http://localhost:5173
npm run build     # → dist/
npm run preview   # serve the production build
npm test          # renders dist/ in a real DOM and asserts the page works
npm run lint

# layout check at a real mobile viewport (needs `npm run preview` running)
npm run test:mobile -- http://localhost:4173/ 390
```

## Setting the download link

The site's primary call to action is the APK download. Until you have a real
link, `apkUrl` is `'#'` and the button renders as a clearly disabled
"Bientôt disponible" control — deliberately, so it never looks like a working
link that goes nowhere.

Edit [`src/config.js`](src/config.js):

```js
apkUrl: 'https://your-host/prosim-planat.apk',  // or a Play Store URL
apkVersion: '1.0.0',
apkSizeMb: 24,   // optional, shown beside the button
```

The button turns into a real download link automatically. Everything else you
are likely to change — repo URL, contact email, API status link — lives in the
same file.

To host the APK from the site itself, drop it in `public/` and point `apkUrl` at
`/prosim-planat.apk`.

## Structure

| File | Purpose |
|---|---|
| `src/config.js` | Links, version, contact — the things you edit |
| `src/App.jsx` | All page sections |
| `src/Icon.jsx` | Inline SVG icon set |
| `src/App.css` | Layout and components |
| `src/index.css` | Design tokens (palette, radii, shadows) |
| `scripts/smoke-test.mjs` | Post-build render check |
| `scripts/measure-mobile.mjs` | Mobile-viewport overflow check |

## Design

The palette and type mirror the Flutter app
(`mobile_app/lib/core/theme/app_colors.dart`) so the site and the product look
like one thing: Bitume `#1A2027` for ink, Sangle `#FF8A34` as the single accent,
Béton `#F7F8FA` as the page ground, with Convoi/Halte reserved for state. Archivo
is the app's Latin typeface.

The layout is responsive down to 360px, honours `prefers-reduced-motion`, and
keeps visible keyboard focus.

## Tests

`npm test` builds nothing itself — run `npm run build` first. It loads `dist/` in
jsdom, executes the bundle, and asserts the page actually rendered: React
mounted, real copy present, all four roles and the eleven lifecycle steps drawn,
no dead `#` links, external links carry `rel="noreferrer"`, one `<h1>`, and the
download CTA is correct in **both** states (disabled placeholder or real link).

## Deploying

Any static host works — the build output is plain files in `dist/`.

```bash
npm run build
# then serve dist/, e.g.
npx vercel deploy --prod
```

On Netlify or Vercel: build command `npm run build`, publish directory `dist`.

### A note on screenshots

If you screenshot this (or any responsive site) with
`chrome --headless --window-size=390,1500`, the result will look like the content
overflows. It does not: bare `--window-size` sets the image size but leaves the
*layout* viewport at desktop width, so media queries never apply.
`scripts/measure-mobile.mjs` drives Chrome over the DevTools protocol and sets
`Emulation.setDeviceMetricsOverride`, which is what actually produces a mobile
viewport — it reports `scrollWidth` and names any element crossing the right
edge. At 390px the page measures 390px with no overflow.
