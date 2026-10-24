@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0Prepare-Port.ps1"
if errorlevel 1 (
  echo.
  echo The preparer stopped. Read the actual error shown above.
  echo Python is not required. See README.md for Windows script-policy instructions.
  pause
)
