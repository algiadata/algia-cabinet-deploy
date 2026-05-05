param(
    [string]$DestinationRoot = "",
    [switch]$NoPicker
)

$ErrorActionPreference = "Stop"

$Root = Resolve-Path "$PSScriptRoot\..\..\.."
Set-Location $Root

function Write-Step($Message) {
    Write-Host ""
    Write-Host "=== $Message ===" -ForegroundColor Cyan
}

function Get-EnvValue($Name, $DefaultValue) {
    if (-not (Test-Path ".env")) {
        return $DefaultValue
    }

    foreach ($line in Get-Content ".env") {
        if ($line -match "^$Name=(.+)$") {
            return $Matches[1].Trim()
        }
    }

    return $DefaultValue
}

function Select-BackupDestination {
    param([string]$DefaultPath)

    if ($NoPicker) {
        return $DefaultPath
    }

    try {
        Add-Type -AssemblyName System.Windows.Forms
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = "Choisir le dossier ou stocker les sauvegardes ALGIA Cabinet"
        $dialog.SelectedPath = $DefaultPath
        $dialog.ShowNewFolderButton = $true

        $result = $dialog.ShowDialog()
        if ($result -eq [System.Windows.Forms.DialogResult]::OK -and $dialog.SelectedPath) {
            return $dialog.SelectedPath
        }
    } catch {
        Write-Host "Selection graphique indisponible, passage en mode texte." -ForegroundColor Yellow
    }

    $answer = Read-Host "Dossier de sauvegarde [$DefaultPath]"
    if ([string]::IsNullOrWhiteSpace($answer)) {
        return $DefaultPath
    }

    return $answer.Trim()
}

Write-Step "Verification configuration"

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

$Site = Get-EnvValue "SITE_NAME" "cabinet.local"
$AppImage = Get-EnvValue "APP_IMAGE" "algiadata/algia-cabinet"
$AppVersion = Get-EnvValue "APP_VERSION" "unknown"
$DefaultBackupRoot = Join-Path $Root "backups"

if ([string]::IsNullOrWhiteSpace($DestinationRoot)) {
    $DestinationRoot = Select-BackupDestination -DefaultPath $DefaultBackupRoot
}

New-Item -ItemType Directory -Force -Path $DestinationRoot | Out-Null

$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$Dest = Join-Path $DestinationRoot "ALGIA-Cabinet-backup-$Stamp"
New-Item -ItemType Directory -Force -Path $Dest | Out-Null

Write-Step "Demarrage service backend si necessaire"
docker compose --env-file .env up -d db redis-cache redis-queue redis-socketio backend

$Backend = docker compose --env-file .env ps -q backend

if (-not $Backend) {
    Write-Host "Conteneur backend introuvable." -ForegroundColor Red
    exit 1
}

$RemoteBackupDir = "/home/frappe/frappe-bench/sites/$Site/private/backups"

Write-Step "Preparation sauvegarde"
$before = @(docker exec $Backend bash -lc "find '$RemoteBackupDir' -maxdepth 1 -type f -printf '%f\n' 2>/dev/null || true")

Write-Step "Sauvegarde base + fichiers"
docker exec $Backend bench --site $Site backup --with-files
if ($LASTEXITCODE -ne 0) {
    Write-Host "Echec de la sauvegarde bench." -ForegroundColor Red
    exit 1
}

$after = @(docker exec $Backend bash -lc "find '$RemoteBackupDir' -maxdepth 1 -type f -printf '%f\n' 2>/dev/null || true")
$newFiles = @($after | Where-Object { $before -notcontains $_ })

if ($newFiles.Count -eq 0) {
    Write-Host "Aucun nouveau fichier detecte automatiquement. Copie des derniers fichiers de sauvegarde." -ForegroundColor Yellow
    $newFiles = @(docker exec $Backend bash -lc "ls -1t '$RemoteBackupDir' 2>/dev/null | head -n 5")
}

foreach ($file in $newFiles) {
    if (-not [string]::IsNullOrWhiteSpace($file)) {
        docker cp "${Backend}:${RemoteBackupDir}/$file" "$Dest\"
    }
}

$Info = @"
ALGIA Cabinet backup
Date=$Stamp
Site=$Site
Image=$AppImage`:$AppVersion
Source=$RemoteBackupDir
"@

Set-Content -Path (Join-Path $Dest "backup-info.txt") -Value $Info -Encoding UTF8

Write-Step "Sauvegarde terminee"
Write-Host "Dossier : $Dest" -ForegroundColor Green
Write-Host "Garde ce dossier pour une restauration future." -ForegroundColor Yellow
exit 0
