@echo off
REM One-click test runner for the PurrPurrTown demo.
REM This machine's PowerShell execution policy blocks .ps1 files,
REM so this wrapper passes -ExecutionPolicy Bypass.
REM Usage: tests\run_all.cmd
REM        tests\run_all.cmd "D:\Godot\godot.exe"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_all.ps1" %*
exit /b %ERRORLEVEL%
