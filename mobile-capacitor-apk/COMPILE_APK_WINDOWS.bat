@echo off
echo ============================================================================
echo   BATIX v3.1 — COMPILATION AUTOMATIQUE DU FICHIER ANDROID (.APK)
echo ============================================================================
echo Verification de Node.js...
node -v
if %errorlevel% neq 0 (
    echo [ERREUR] Veuillez installer Node.js LTS depuis https://nodejs.org/
    pause
    exit /b 1
)
echo Installation des dependances Capacitor...
call npm install
if not exist "android" (
    echo Creation du projet natif Android...
    call npx cap add android
)
echo Synchronisation du code Web/PWA vers Android...
call npx cap sync android
echo Compilation de l'APK Debug...
cd android
call gradlew.bat assembleDebug
echo.
echo ============================================================================
echo   SUCCES ! Votre fichier APK est pret ici :
echo   android\app\build\outputs\apk\debug\app-debug.apk
echo ============================================================================
pause
