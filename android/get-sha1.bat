@echo off
echo ========================================
echo Obtention du SHA-1 pour Firebase
echo ========================================
echo.
echo Veuillez copier le SHA-1 ci-dessous et l'ajouter dans Firebase Console
echo Firebase Console > Project Settings > Your apps > Android app > Add fingerprint
echo.
echo ========================================
echo.

cd ..
cd ..

keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android

echo.
echo ========================================
echo Copiez le SHA-1 ci-dessus et ajoutez-le dans Firebase Console
echo ========================================
pause

