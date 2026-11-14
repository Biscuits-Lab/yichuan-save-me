@echo off
chcp 65001 >nul
setlocal
cd /d "%~dp0"
if exist "build\windows-v0.5.1\毅川救我.exe" (
  start "" "build\windows-v0.5.1\毅川救我.exe"
  exit /b 0
)
if not exist ".tools\godot\Godot_v4.5.2-stable_win64.exe" (
  echo Godot runtime not found. Open project.godot with Godot 4.5 or newer.
  pause
  exit /b 1
)
start "" ".tools\godot\Godot_v4.5.2-stable_win64.exe" --path "%~dp0."
