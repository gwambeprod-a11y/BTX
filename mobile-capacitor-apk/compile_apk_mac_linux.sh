#!/usr/bin/env bash
set -e
echo "============================================================================"
echo "  BATIX v3.1 — COMPILATION AUTOMATIQUE ANDROID (.APK) & iOS (.IPA)"
echo "============================================================================"
npm install
if [ ! -d "android" ]; then
  npx cap add android
fi
npx cap sync android
cd android
./gradlew assembleDebug
echo "✅ Succès ! Fichier APK généré dans : android/app/build/outputs/apk/debug/app-debug.apk"
