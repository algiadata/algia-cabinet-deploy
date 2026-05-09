$ErrorActionPreference = "Stop"

$Root = Resolve-Path "$PSScriptRoot\..\..\.."
Set-Location $Root

function Get-DockerDesktopExe {
    $paths = @(
        "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe",
        "${env:ProgramFiles(x86)}\Docker\Docker\Docker Desktop.exe",
        "$env:LOCALAPPDATA\Docker\Docker Desktop.exe"
    )

    foreach ($p in $paths) {
        if ($p -and (Test-Path $p)) {
            return $p
        }
    }

    return ""
}

function Test-DockerReady {
    cmd.exe /c "docker info >NUL 2>NUL"
    return ($LASTEXITCODE -eq 0)
}

function Start-DockerDesktopMinimized {
    $exe = Get-DockerDesktopExe

    if ($exe) {
        Start-Process -FilePath $exe -ArgumentList "--minimized" -WindowStyle Minimized
    }
}

function Wait-DockerReady {
    param([int]$Seconds = 180)

    $deadline = (Get-Date).AddSeconds($Seconds)

    while ((Get-Date) -lt $deadline) {
        if (Test-DockerReady) {
            return $true
        }

        Start-Sleep -Seconds 5
    }

    return $false
}

if (-not (Test-DockerReady)) {
    Start-DockerDesktopMinimized
}

if (-not (Wait-DockerReady -Seconds 180)) {
    Write-Host "Docker Desktop n'est pas pret. Lance Docker Desktop puis relance ALGIA Cabinet." -ForegroundColor Red
    exit 1
}

docker compose --env-file .env up -d
docker compose --env-file .env ps
Start-Process "http://localhost:8080"
