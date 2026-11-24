@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"
if exist "build\windows-v0.7.1\毅川救我.exe" (
  start "" "build\windows-v0.7.1\毅川救我.exe"
  exit /b 0
)
set "engine=.tools\godot\Godot_v4.5.2-stable_win64.exe"
if not exist "%engine%" (
  echo Godot runtime not found. Open project.godot with Godot 4.5 or newer.
  pause
  exit /b 1
)
echo Checking game assets...
set "import_log=.tools\startup-import.log"
if exist "%import_log%" del "%import_log%"
start "" /wait /b "%engine%" --headless --path "%~dp0." --import --log-file "%import_log%"
if errorlevel 1 goto import_failed
if not exist "%import_log%" goto import_failed
findstr /b /c:"ERROR:" /c:"SCRIPT ERROR:" "%import_log%" >nul
if errorlevel 2 goto import_failed
if not errorlevel 1 goto import_failed
start "" "%engine%" --path "%~dp0." || exit /b 1
exit /b 0

:import_failed
echo Godot asset import failed. See %import_log%.
pause
exit /b 1
