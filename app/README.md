# Evangelis — member app (Flutter)

One app for every church: members find their church, join it, see events and
announcements, register with a QR ticket, read the Bible offline and send feedback.
Runs on Android, iOS and the web (installable PWA, works offline).

## Run

```bash
# Demo mode, no backend (sign-in code: 123456)
flutter run --dart-define=DEMO=true

# Against Supabase
flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co --dart-define=SUPABASE_ANON_KEY=...
```

## Build for the pilot

```bash
SUPABASE_URL=https://xyz.supabase.co SUPABASE_ANON_KEY=... ../scripts/build_app.sh prod
```

Produces `dist/web-pilot/` (static files: deploy to any HTTPS host, e.g. Vercel,
Netlify, Cloudflare Pages; route all paths to `index.html`) and
`dist/evangelis-pilot.apk` (debug-signed; fine for sideloading during the pilot,
create an upload key before publishing on Google Play).

## Offline Bible

Convert a public-domain CSV with `scripts/build_bible_json.mjs`, then upload
`LSG1910.json` and `KJV.json` to the public `bible` storage bucket. The app
downloads a translation once and reads it from the device afterwards.

## Tests

```bash
flutter analyze && flutter test
```
