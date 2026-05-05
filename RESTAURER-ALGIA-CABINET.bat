@echo off
title Restauration ALGIA Cabinet
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0installer\windows\scripts\restore.ps1"
pause
