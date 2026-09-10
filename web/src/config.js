/**
 * Everything you are likely to want to change lives here.
 *
 * NOTE: `apkUrl` is a PLACEHOLDER. Replace it with the real APK or Play Store
 * link once you have one — it is the site's primary call to action. While it is
 * left as '#', the download buttons render in a disabled state and say so,
 * rather than silently linking nowhere.
 */
export const config = {
  appName: 'Prosim Planat',
  tagline: 'Transport & Logistique',

  // ---- Primary call to action -------------------------------------------
  apkUrl: '#', // <-- replace with e.g. 'https://.../prosim-planat.apk'
  apkVersion: '1.0.0',
  apkSizeMb: null, // e.g. 24 — shown next to the download button when set


};

export const isPlaceholder = (url) => !url || url === '#';
