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

**Known environment issue in this workspace:** the installed Flutter SDK has a stale
`bin/cache/flutter.bat.lock` held by an interrupted earlier process, which blocks every
`flutter` command from starting. The app's Dart source is complete and ready — once that
lock is cleared (close the stray `flutter.bat` process, or restart the machine, then
delete the lock file if it persists), run `flutter pub get` and it should build normally.

Before running:
- Point `lib/core/config/app_config.dart` at your backend (`10.0.2.2` = Android emulator's
  localhost; use your LAN IP for a physical device).
- Add a real Google Maps API key in `android/app/src/main/AndroidManifest.xml`
  (`com.google.android.geo.API_KEY`) and iOS `ios/Runner/AppDelegate.swift` /
  `Info.plist` before using the tracking map screens.
- Replace the placeholder launcher icons (`android/app/src/main/res/mipmap-*`,
  `ios/Runner/Assets.xcassets/AppIcon.appiconset`) with the real Prosim Planat logo
  once the visual identity (cahier des charges §11.4) is finalized.

### What's implemented

- **Shipper**: registration/profile, create trip (fixed price or bidding), offer review
  and acceptance, live status tracking, POD confirmation, carrier rating, invoices,
  documents.
- **Carrier**: fleet & driver management with document-expiry alerts, load marketplace,
  bid submission, driver/vehicle assignment, return-load suggestions.
- **Driver**: ultra-simplified single-action mission screen, offline-first status
  updates (auto-sync on reconnect), mandatory loading photos, POD with signature capture,
  incident reporting.
- **Admin**: full trip pilotage (assign/reassign/invoice), network directory with
  approve/block, dispute resolution, invoicing & payments, margin/summary reports,
  platform settings, audit log.
- Arabic (RTL) / French / English throughout, instant language switching.
- Section 11 visual identity (Bitume/Acier/Béton/Sangle/Convoi/Halte palette, sharp
  corners, single-action-per-screen rule) encoded in the shared theme.

### Not implemented (out of scope per cahier des charges §3.2)

- Real electronic payment (CIB/Dahabia) — v2.
- Fleet maintenance/fuel management — v2.
- Customs/international transport.
