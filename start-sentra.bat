@echo off
setlocal
title SENTRA Health - prototype
cd /d "%~dp0"

REM Port 8010, not 8000: another local project already serves on 8000.
set PORT=8010

where php >nul 2>&1
if errorlevel 1 (
  echo.
  echo   PHP was not found on PATH.
  echo   Install PHP 8.2+ ^(XAMPP works^) and try again.
  echo.
  pause
  exit /b 1
)

if not exist "vendor\autoload.php" (
  echo.
  echo   Dependencies are missing. Run this once:
  echo       composer install
  echo.
  pause
  exit /b 1
)

if not exist "public\build\manifest.json" (
  echo.
  echo   Frontend assets are not built. Run this once:
  echo       npm install ^&^& npm run build
  echo.
  pause
  exit /b 1
)

if not exist "database\database.sqlite" (
  echo   No database found - creating and seeding the synthetic dataset...
  type nul > "database\database.sqlite"
  php artisan migrate:fresh --seed --force
  echo.
)

echo.
echo   ============================================================
echo     SENTRA Health - National Health Intelligence prototype
echo   ============================================================
echo.
echo     http://127.0.0.1:%PORT%
echo.
echo     Sign in with any of these ^(password: password^)
echo       citizen@example.com      Budi Santoso, elevated metabolic risk
echo       doctor@example.com       dr. Sari Wulandari, 2 consented patients
echo       government@example.com   aggregate population intelligence
echo       sentra@example.com       cross-domain signals and alerts
echo.
echo     Guided walkthrough: DEMO.md
echo     All data is SYNTHETIC. Not connected to any live health system.
echo.
echo     Close this window to stop the server.
echo   ============================================================
echo.

REM Open the browser a moment after the server has had time to bind.
start "" /min cmd /c "timeout /t 3 >nul & start "" http://127.0.0.1:%PORT%"

php artisan serve --host=127.0.0.1 --port=%PORT%

echo.
echo   Server stopped.
pause
