@echo off
rem Double-click to play CodeWar locally (and on your Wi-Fi). Close this window to stop.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File run_server.ps1 -NoTunnel
pause
