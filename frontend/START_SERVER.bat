@echo off
echo Starting Reactive Looper Frontend...
echo.
echo Opening browser at http://localhost:8000
echo Press Ctrl+C to stop the server
echo.

cd /d "%~dp0"
start http://localhost:8000/standalone.html
python -m http.server 8000
