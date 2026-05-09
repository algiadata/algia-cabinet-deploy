@echo off
title Generation installateur ALGIA Cabinet
setlocal
cd /d "%~dp0"

if not exist "releases" mkdir "releases"

set "ISCC=%ProgramFiles(x86)%\Inno Setup 6\ISCC.exe"
if not exist "%ISCC%" set "ISCC=%ProgramFiles%\Inno Setup 6\ISCC.exe"
if not exist "%ISCC%" set "ISCC=%LOCALAPPDATA%\Programs\Inno Setup 6\ISCC.exe"

if not exist "%ISCC%" (
  echo Inno Setup 6 est introuvable.
  echo Installe Inno Setup depuis https://jrsoftware.org/isinfo.php
  pause
  exit /b 1
)

"%ISCC%" "installer\windows\inno\algia-cabinet-installer.iss"
if errorlevel 1 (
  echo Echec generation installateur.
  pause
  exit /b 1
)

echo.
echo Installateur genere :
echo releases\ALGIA-Cabinet-Setup-v0.1.8.exe
pause




