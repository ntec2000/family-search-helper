@echo off
setlocal
cd /d "%~dp0"
where python >nul 2>nul
if errorlevel 1 (
  echo Install Python 3.12 or later and enable Add Python to PATH.
  pause
  exit /b 1
)
if not exist "web\index.html" (
  echo Flutter web build is missing. Download the integrated web artifact.
  pause
  exit /b 1
)
if not exist ".venv\Scripts\python.exe" (
  python -m venv .venv
  if errorlevel 1 goto failed
)
".venv\Scripts\python.exe" -m pip install --disable-pip-version-check -r server\requirements.txt
if errorlevel 1 goto failed
".venv\Scripts\python.exe" server\parser_engine.py --engine rapidocr --web-build web --open-browser
if errorlevel 1 goto failed
exit /b 0
:failed
echo Startup failed. Review the message above.
pause
exit /b 1
