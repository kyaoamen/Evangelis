#!/usr/bin/env bash
# Builds the Evangelis member app for the pilot.
#   Demo (no backend):   scripts/build_app.sh demo
#   Real backend:        SUPABASE_URL=https://xyz.supabase.co SUPABASE_ANON_KEY=... scripts/build_app.sh prod
# Outputs go to dist/.
set -euo pipefail
mode="${1:-demo}"
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root/app"
if [ "$mode" = demo ]; then
  defines=(--dart-define=DEMO=true)
  suffix=demo
else
  : "${SUPABASE_URL:?set SUPABASE_URL}" "${SUPABASE_ANON_KEY:?set SUPABASE_ANON_KEY}"
  defines=(--dart-define=SUPABASE_URL="$SUPABASE_URL" --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY")
  suffix=pilot
fi
mkdir -p "$root/dist"
flutter build web --release --no-web-resources-cdn --pwa-strategy=none "${defines[@]}"
rm -rf "$root/dist/web-$suffix" && cp -r build/web "$root/dist/web-$suffix"
flutter build apk --release "${defines[@]}"
cp build/app/outputs/flutter-apk/app-release.apk "$root/dist/evangelis-$suffix.apk"
echo "Built dist/web-$suffix and dist/evangelis-$suffix.apk"
