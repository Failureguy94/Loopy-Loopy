@echo off
echo ================================================
echo    Reactive Looper Frontend
echo ================================================
echo.

cd /d "%~dp0"

echo Installing dependencies...
call npm install

echo.
echo Starting development server...
call npm run dev
