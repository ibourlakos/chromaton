@echo off
rem Chromaton tasks: make help. Runs tools\make.ps1 without needing a
rem PowerShell script policy change.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\make.ps1" %*
exit /b %ERRORLEVEL%
