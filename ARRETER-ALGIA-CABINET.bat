@echo off
title Arreter ALGIA Cabinet
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer\windows\scripts\stop.ps1"
pause
