@echo off
setlocal
cd /d "%~dp0"
if not exist ".tools\godot\Godot_v4.5.2-stable_win64.exe" (
  echo Godot runtime not found. Open project.godot with Godot 4.5 or newer.
  pause
  exit /b 1
)
start "" ".tools\godot\Godot_v4.5.2-stable_win64.exe" --path "%~dp0."
