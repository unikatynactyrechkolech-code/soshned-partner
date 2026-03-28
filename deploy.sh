#!/bin/bash
# Build + deploy skript pro SOS HNED Partner (Flutter web → Vercel)
# Builduje LOKÁLNĚ na PC, na Vercel uploaduje jen hotové statické soubory.
# Žádný build na Vercelu = žádné build kredity!

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# Načti secrets z .env souboru
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

echo "🔨 Building Flutter web (release)..."
flutter build web --release \
  --dart-define=GOOGLE_WEB_CLIENT_ID="${GOOGLE_WEB_CLIENT_ID}" \
  --dart-define=GOOGLE_CLIENT_SECRET="${GOOGLE_CLIENT_SECRET}" \
  --dart-define=MAPBOX_TOKEN="${MAPBOX_TOKEN}"

echo "📋 Copying vercel.json..."
cp vercel.json build/web/

echo "🚀 Deploying to Vercel (static upload, no build)..."
cd build/web
vercel deploy --prod --yes

echo "✅ Done!"
