$ErrorActionPreference = "Stop"

$Root = Resolve-Path "$PSScriptRoot\..\..\.."
Set-Location $Root

function Write-Step($Message) {
    Write-Host ""
    Write-Host "=== $Message ===" -ForegroundColor Cyan
}

function Get-EnvValue($File, $Name, $DefaultValue) {
    if (-not (Test-Path $File)) {
        return $DefaultValue
    }

    foreach ($line in Get-Content $File) {
        if ($line -match "^$Name=(.*)$") {
            return $Matches[1].Trim()
        }
    }

    return $DefaultValue
}

function Set-EnvValue($Name, $Value) {
    if (-not (Test-Path ".env")) {
        Copy-Item ".env.example" ".env"
    }

    $content = Get-Content ".env" -Raw

    if ($content -match "(?m)^$Name=.*$") {
        $content = $content -replace "(?m)^$Name=.*$", "$Name=$Value"
    } else {
        $content = $content.TrimEnd() + "`r`n$Name=$Value`r`n"
    }

    Set-Content ".env" $content -Encoding UTF8
}

Write-Step "Verification Docker"

if (-not (Test-Path ".env")) {
    Write-Host "Fichier .env introuvable. Lance d'abord l'installation." -ForegroundColor Red
    exit 1
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "Docker Desktop n'est pas installe." -ForegroundColor Red
    exit 1
}

cmd.exe /c "docker info >NUL 2>NUL"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker Desktop n'est pas lance." -ForegroundColor Red
    exit 1
}

$CurrentImage = Get-EnvValue ".env" "APP_IMAGE" "algiadata/algia-cabinet"
$CurrentVersion = Get-EnvValue ".env" "APP_VERSION" "unknown"

$TargetImage = Get-EnvValue ".env.example" "APP_IMAGE" "algiadata/algia-cabinet"
$TargetVersion = Get-EnvValue ".env.example" "APP_VERSION" "latest"

Write-Host "Version actuelle : $CurrentImage`:$CurrentVersion" -ForegroundColor Yellow
Write-Host "Version cible    : $TargetImage`:$TargetVersion" -ForegroundColor Yellow

Write-Step "Sauvegarde de securite avant mise a jour"

$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$PreUpdateBackupRoot = Join-Path $Root "backups\pre-update-$Stamp"
New-Item -ItemType Directory -Force -Path $PreUpdateBackupRoot | Out-Null

powershell -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\backup.ps1" -DestinationRoot "$PreUpdateBackupRoot" -NoPicker
if ($LASTEXITCODE -ne 0) {
    Write-Host "Sauvegarde de securite echouee. Mise a jour annulee." -ForegroundColor Red
    exit 1
}

Write-Step "Mise a jour de la version dans .env"

Set-EnvValue "APP_IMAGE" $TargetImage
Set-EnvValue "APP_VERSION" $TargetVersion

Write-Step "Validation Docker Compose"

docker compose --env-file .env config *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Configuration Docker Compose invalide." -ForegroundColor Red
    exit 1
}

Write-Step "Telechargement nouvelle image"

docker compose --env-file .env pull
if ($LASTEXITCODE -ne 0) {
    Write-Host "Telechargement image Docker echoue." -ForegroundColor Red
    exit 1
}

Write-Step "Arret services applicatifs"

docker compose --env-file .env stop frontend websocket queue-short queue-long scheduler backend

Write-Step "Configuration"

docker compose --env-file .env run --rm configurator

Write-Step "Creation ou migration du site"

docker compose --env-file .env run --rm create-site
if ($LASTEXITCODE -ne 0) {
    Write-Host "Migration echouee." -ForegroundColor Red
    Write-Host "Sauvegarde de securite disponible dans : $PreUpdateBackupRoot" -ForegroundColor Yellow
    exit 1
}

Write-Step "Redemarrage ALGIA Cabinet"

docker compose --env-file .env up -d backend websocket queue-short queue-long scheduler frontend

Write-Step "Etat conteneurs"

docker compose --env-file .env ps

$Port = Get-EnvValue ".env" "HTTP_PORT" "8080"
$Url = "http://localhost:$Port"

Write-Step "Mise a jour terminee"

Write-Host "ALGIA Cabinet est a jour : $TargetImage`:$TargetVersion" -ForegroundColor Green
Write-Host "Sauvegarde avant mise a jour : $PreUpdateBackupRoot" -ForegroundColor Yellow

Start-Process $Url
exit 0
