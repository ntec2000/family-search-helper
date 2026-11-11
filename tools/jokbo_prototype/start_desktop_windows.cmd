@echo off
setlocal
cd /d "%~dp0"
where python >nul 2>nul
if errorlevel 1 (
  echo Python 3.12 is required. Install Python and enable PATH.
  pause
  exit /b 1
)
if not exist ".venv\Scripts\python.exe" (
  python -m venv .venv
  if errorlevel 1 goto failed
)
".venv\Scripts\python.exe" -m pip install --disable-pip-version-check -r requirements.txt pywebview==6.2.1
if errorlevel 1 goto failed
".venv\Scripts\python.exe" desktop.py
if errorlevel 1 goto failed
exit /b 0
:failed
echo Startup failed. See the message above.
pause
exit /b 1
