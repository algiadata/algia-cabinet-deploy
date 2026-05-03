@echo off
title Installation ALGIA Cabinet
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer\windows\scripts\install.ps1"
pause
