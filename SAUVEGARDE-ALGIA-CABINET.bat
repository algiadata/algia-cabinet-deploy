@echo off
title Sauvegarde ALGIA Cabinet
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer\windows\scripts\backup.ps1"
pause
