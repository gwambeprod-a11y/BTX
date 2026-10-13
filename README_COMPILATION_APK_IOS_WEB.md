# 🏗️ BATIX v3.1 — Plateforme Complète (Web PWA, Android APK, iOS & Backend Go/PostGIS)

Ce dépôt contient l'intégralité de l'application **BATIX** conforme au **Cahier des Charges v3.1 (Octobre 2026)** et aux **8 maquettes graphiques** (Catalogue Client Styles Sombre, Clair, Style M Terracotta, Style N Cyber-Industriel, et Application Chauffeur Styles Premium Or, Style A Contraste Extrême, Style B Pas-à-Pas, Style C Cartographique Compact).

## 📁 Structure du Projet

1. **`mobile-capacitor-apk/`** : Projet Mobile Android (`.apk`) & iOS (`.ipa`) basé sur **Capacitor 6** embarquant l'application complète (`www/index.html`, `manifest.json`, `sw.js`).
   - Inclut `COMPILE_APK_WINDOWS.bat` et `compile_apk_mac_linux.sh` pour compiler l'APK en 1 clic sur votre ordinateur.
   - Inclut `.github/workflows/build-apk.yml` pour compiler le fichier `BATIX.apk` automatiquement dans le Cloud GitHub Actions sans rien installer sur votre PC.
2. **`mobile-flutter/`** : Code source natif **Flutter** (`pubspec.yaml`, `lib/main.dart`) pour l'application Chauffeur/Magasinier (caméra directe sans galerie, géofencing 150m Haversine hors-ligne, filigrane et signature).
3. **`backend-go/` & `docker-compose.yml`** : Le cœur du système en **Go**, le schéma **PostgreSQL + PostGIS** (`migrations/001_init_batix_postgis.sql` avec triggers d'immuabilité et contrôle de séparation des tâches), **Redis** et **MinIO**.

---

## 📱 Comment obtenir votre fichier `.APK` (3 méthodes au choix)

### Méthode 1 : Installation directe sur Android & iOS sans compilation (PWA — Immédiat)
Ouvrez `BATIX_App_Interactive.html` (ou hébergez le dossier `mobile-capacitor-apk/www/` sur Netlify/Vercel/GitHub Pages) depuis Chrome sur Android ou Safari sur iPhone, puis appuyez sur **« Ajouter à l'écran d'accueil / Installer l'application »**.

### Méthode 2 : Compilation automatique de l'APK dans le Cloud (Sans rien installer sur votre PC)
1. Créez un dépôt sur GitHub et envoyez le contenu de ce dossier `BATIX-Platform/`.
2. Le fichier `.github/workflows/build-apk.yml` se lance automatiquement dans l'onglet **Actions** de GitHub.
3. En 2 minutes, téléchargez directement **`BATIX-v3.1-Android-APK.zip`** contenant votre fichier `app-debug.apk` prêt à installer sur tous vos téléphones Android à Yaoundé !

### Méthode 3 : Compilation locale sur votre PC (Windows / Mac / Linux)
Assurez-vous d'avoir Node.js et Android Studio (ou Android SDK) installés, puis double-cliquez sur :
- Sous Windows : `mobile-capacitor-apk/COMPILE_APK_WINDOWS.bat`
- Sous Mac/Linux : `bash mobile-capacitor-apk/compile_apk_mac_linux.sh`

Le fichier APK sera généré dans :
`mobile-capacitor-apk/android/app/build/outputs/apk/debug/app-debug.apk`
