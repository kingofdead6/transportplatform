# Prosim Planat

Digital platform for managing road freight transport — Flutter mobile app (shipper/carrier/driver/admin) + Node.js/Express/MongoDB/Cloudinary backend.

## Structure

```
backend/       Node.js + Express + MongoDB + Cloudinary API
mobile_app/    Flutter app (Android + iOS), all 4 roles
```

## Backend

```bash
cd backend
npm install
cp .env.example .env   # fill in MONGO_URI, JWT_SECRET, CLOUDINARY_*
npm run seed             # demo admin/shipper/carrier/driver accounts + 1 sample trip
npm run dev               # http://localhost:5000
```

See `backend/README.md` for the full API reference and demo credentials.

## Mobile app

```bash
cd mobile_app
flutter pub get
flutter run
```

**Known environment issue in this workspace:** every `flutter` command hangs here.
The cause is not a stale lock left by a crashed process — it is file permissions.
Flutter is installed under `C:\Program Files\flutter`, where the current user has
only read/execute rights, so the tool cannot open `bin/cache/lockfile` for writing
and blocks forever. Confirm with:

```
icacls "C:\Program Files\flutter\bin\cache\lockfile"
```

`BUILTIN\Utilisateurs:(I)(RX)` — read/execute, no write. Two ways to fix it:

1. **Reinstall Flutter to a user-writable path** (recommended), e.g. `C:\src\flutter`
   or `%LOCALAPPDATA%\flutter`, then update `PATH`.
2. **Grant your account write access** to the existing install, from an
   *elevated* terminal:
   ```
   icacls "C:\Program Files\flutter" /grant "%USERNAME%":(OI)(CI)M /T
   ```

Until then the analyzer still runs, via the bundled Dart SDK, which does not take
that lock:

```
"C:\Program Files\flutter\bin\cache\dart-sdk\bin\dart.exe" analyze lib test
```

`lib/` + `test/` currently analyze clean. The widget tests in `mobile_app/test/`
need the Flutter test runner, so they can only be run (`flutter test`) once the
permission problem above is resolved.

Before running:
- Point `lib/core/config/app_config.dart` at your backend (`10.0.2.2` = Android emulator's
  localhost; use your LAN IP for a physical device).
- Add a real Google Maps API key in `android/app/src/main/AndroidManifest.xml`
  (`com.google.android.geo.API_KEY`) and iOS `ios/Runner/AppDelegate.swift` /
  `Info.plist` before using the tracking map screens.
- Replace the placeholder launcher icons (`android/app/src/main/res/mipmap-*`,
  `ios/Runner/Assets.xcassets/AppIcon.appiconset`) with the real Prosim Planat logo
  once the visual identity (cahier des charges §11.4) is finalized.

### Verification status

- **Backend:** `cd backend && npm run test:e2e` — 43 end-to-end checks against an
  in-memory MongoDB, all passing.
- **Mobile app:** `dart analyze lib test` — clean. Widget tests are written
  (`mobile_app/test/app_test.dart`) but cannot run in this workspace until the
  Flutter permission issue above is fixed.

### What's implemented

- **Shipper**: registration/profile, create trip (fixed price or bidding), offer review
  and acceptance, live status tracking, POD confirmation, carrier rating, invoices,
  documents.
- **Carrier**: fleet & driver management with document-expiry alerts, load marketplace,
  bid submission **and one-tap acceptance of fixed-price loads**, driver/vehicle
  assignment, return-load suggestions.
- **Driver**: ultra-simplified single-action mission screen, offline-first status
  updates (auto-sync on reconnect), mandatory loading photos, POD with signature capture,
  incident reporting.
- **Admin**: full trip pilotage (assign/reassign/invoice), network directory with
  approve/block, dispute resolution, invoicing & payments, margin/summary reports,
  platform settings, audit log.
- Notification centre (bell + unread badge on every role's home), fed by the
  existing Socket.IO channel.
- Arabic (RTL) / French / English throughout, instant language switching.
- Section 11 visual identity (Bitume/Acier/Béton/Sangle/Convoi/Halte palette, sharp
  corners, single-action-per-screen rule) encoded in the shared theme.

### Not implemented (out of scope per cahier des charges §3.2)

- Real electronic payment (CIB/Dahabia) — v2.
- Fleet maintenance/fuel management — v2.
- Customs/international transport.
