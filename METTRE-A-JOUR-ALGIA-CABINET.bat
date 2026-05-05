@echo off
title Mise a jour ALGIA Cabinet
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer\windows\scripts\update.ps1"
pause
