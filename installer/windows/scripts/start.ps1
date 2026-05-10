$ErrorActionPreference = "Stop"

$Root = Resolve-Path "$PSScriptRoot\..\..\.."
Set-Location $Root

function Write-Step($Message) {
    Write-Host ""
    Write-Host "=== $Message ===" -ForegroundColor Cyan
}

function Get-DockerDesktopExe {
    $paths = @(
        (Join-Path $Root "docker-program\Docker Desktop.exe"),
        (Join-Path $Root "docker-program\Docker\Docker Desktop.exe"),
        "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe",
        "${env:ProgramFiles(x86)}\Docker\Docker\Docker Desktop.exe",
        "$env:LOCALAPPDATA\Docker\Docker Desktop.exe"
    )

    foreach ($p in $paths) {
        if ($p -and (Test-Path $p)) {
            return $p
        }
    }

    $customRoot = Join-Path $Root "docker-program"

    if (Test-Path $customRoot) {
        $found = Get-ChildItem -Path $customRoot -Recurse -File -Filter "Docker Desktop.exe" -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty FullName -First 1

        if ($found) {
            return $found
        }
    }

    return ""
}

function Test-DockerReady {
    cmd.exe /c "docker info >NUL 2>NUL"
    return ($LASTEXITCODE -eq 0)
}

function Invoke-DockerDesktopWindowHider {
    New-Item -ItemType Directory -Force -Path (Join-Path $Root "state") | Out-Null

    $scriptPath = Join-Path $Root "state\hide-docker-desktop-windows.ps1"

    $contentLines = @(
        'Add-Type @"',
        'using System;',
        'using System.Runtime.InteropServices;',
        '',
        'public class Win32WindowTools {',
        '    [DllImport("user32.dll")]',
        '    public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);',
        '}',
        '"@',
        '',
        '$deadline = (Get-Date).AddSeconds(240)',
        '',
        'while ((Get-Date) -lt $deadline) {',
        '    Get-Process -ErrorAction SilentlyContinue | Where-Object {',
        '        $_.ProcessName -like "Docker Desktop*" -or $_.MainWindowTitle -like "*Docker Desktop*"',
        '    } | ForEach-Object {',
        '        try {',
        '            if ($_.MainWindowHandle -ne [IntPtr]::Zero) {',
        '                [Win32WindowTools]::ShowWindowAsync($_.MainWindowHandle, 0) | Out-Null',
        '            }',
        '        } catch {}',
        '    }',
        '',
        '    Start-Sleep -Seconds 2',
        '}'
    )

    Set-Content -Path $scriptPath -Value $contentLines -Encoding UTF8

    Start-Process `
        -FilePath "powershell.exe" `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" `
        -WindowStyle Hidden
}

function Start-DockerDesktopMinimized {
    $exe = Get-DockerDesktopExe

    if (-not $exe) {
        Write-Host "Docker Desktop introuvable." -ForegroundColor Red
        return $false
    }

    Write-Host "Démarrage Docker Desktop en mode discret / systray..." -ForegroundColor Yellow
    Write-Host "Docker Desktop : $exe" -ForegroundColor Yellow

    try {
        Start-Process -FilePath $exe -ArgumentList @("--minimized", "--unattended") -WindowStyle Minimized
    } catch {
        Start-Process -FilePath $exe -ArgumentList "--minimized" -WindowStyle Minimized
    }

    Invoke-DockerDesktopWindowHider
    return $true
}

function Wait-DockerReady {
    param([int]$Seconds = 420)

    $deadline = (Get-Date).AddSeconds($Seconds)
    $elapsed = 0

    while ((Get-Date) -lt $deadline) {
        if (Test-DockerReady) {
            Write-Host "Docker Desktop est prêt." -ForegroundColor Green
            return $true
        }

        Write-Host "Attente Docker Desktop... $elapsed/$Seconds secondes" -ForegroundColor Yellow
        Start-Sleep -Seconds 10
        $elapsed += 10
    }

    return $false
}

Write-Step "Démarrage ALGIA Cabinet"

if (-not (Test-Path ".env")) {
    Write-Host "ALGIA Cabinet n'est pas encore installé dans ce dossier." -ForegroundColor Red
    Write-Host "Clique d'abord sur : Installer ALGIA Cabinet" -ForegroundColor Yellow
    Write-Host "Dossier actuel : $Root" -ForegroundColor Yellow
    exit 1
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "Docker CLI introuvable. Lance l'installation ALGIA Cabinet d'abord." -ForegroundColor Red
    exit 1
}

if (-not (Test-DockerReady)) {
    Start-DockerDesktopMinimized | Out-Null
}

if (-not (Wait-DockerReady -Seconds 420)) {
    Write-Host "Docker Desktop n'est pas prêt." -ForegroundColor Red
    Write-Host "Ouvre Docker Desktop une fois, attends qu'il soit Running, puis reclique Démarrer." -ForegroundColor Yellow
    exit 1
}

Write-Step "Démarrage des conteneurs"
docker compose --env-file .env up -d

if ($LASTEXITCODE -ne 0) {
    Write-Host "Échec démarrage des conteneurs ALGIA Cabinet." -ForegroundColor Red
    exit 1
}

Write-Step "État des conteneurs"
docker compose --env-file .env ps

Write-Step "Ouverture ALGIA Cabinet"
Start-Process "http://localhost:8080"

Write-Host "ALGIA Cabinet démarré : http://localhost:8080" -ForegroundColor Green
exit 0
