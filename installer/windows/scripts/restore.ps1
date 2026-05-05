param(
    [string]$BackupDir = ""
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

function Select-BackupFolder {
    param([string]$DefaultPath)

    try {
        Add-Type -AssemblyName System.Windows.Forms
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = "Choisir le dossier de sauvegarde ALGIA Cabinet a restaurer"
        $dialog.SelectedPath = $DefaultPath
        $dialog.ShowNewFolderButton = $false

        $result = $dialog.ShowDialog()
        if ($result -eq [System.Windows.Forms.DialogResult]::OK -and $dialog.SelectedPath) {
            return $dialog.SelectedPath
        }
    } catch {
        Write-Host "Selection graphique indisponible, passage en mode texte." -ForegroundColor Yellow
    }

    $answer = Read-Host "Dossier de sauvegarde a restaurer"
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

if ([string]::IsNullOrWhiteSpace($BackupDir)) {
    $BackupDir = Select-BackupFolder -DefaultPath (Join-Path $Root "backups")
}

if ([string]::IsNullOrWhiteSpace($BackupDir) -or -not (Test-Path $BackupDir)) {
    Write-Host "Dossier de sauvegarde introuvable." -ForegroundColor Red
    exit 1
}

$DbFile = Get-ChildItem -Path $BackupDir -File -Recurse | Where-Object {
    $_.Name -match "database.*\.sql(\.gz)?$" -or $_.Name -match "\.sql(\.gz)?$"
} | Sort-Object LastWriteTime -Descending | Select-Object -First 1

$PrivateFile = Get-ChildItem -Path $BackupDir -File -Recurse | Where-Object {
    $_.Name -match "private-files.*\.tar(\.gz)?$"
} | Sort-Object LastWriteTime -Descending | Select-Object -First 1

$PublicFile = Get-ChildItem -Path $BackupDir -File -Recurse | Where-Object {
    $_.Name -match "files.*\.tar(\.gz)?$" -and $_.Name -notmatch "private-files"
} | Sort-Object LastWriteTime -Descending | Select-Object -First 1

if (-not $DbFile) {
    Write-Host "Fichier base de donnees introuvable dans la sauvegarde." -ForegroundColor Red
    exit 1
}

$Site = Get-EnvValue "SITE_NAME" "cabinet.local"

Write-Host "Site     : $Site" -ForegroundColor Yellow
Write-Host "Database : $($DbFile.FullName)" -ForegroundColor Yellow
if ($PrivateFile) { Write-Host "Private  : $($PrivateFile.FullName)" -ForegroundColor Yellow }
if ($PublicFile) { Write-Host "Public   : $($PublicFile.FullName)" -ForegroundColor Yellow }

$Confirm = Read-Host "Confirmer la restauration ? Tape OUI"
if ($Confirm -ne "OUI") {
    Write-Host "Restauration annulee." -ForegroundColor Yellow
    exit 0
}

Write-Step "Demarrage minimum"

docker compose --env-file .env up -d db redis-cache redis-queue redis-socketio backend

$Backend = docker compose --env-file .env ps -q backend
if (-not $Backend) {
    Write-Host "Conteneur backend introuvable." -ForegroundColor Red
    exit 1
}

Write-Step "Arret services applicatifs"

docker compose --env-file .env stop frontend websocket queue-short queue-long scheduler

$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$RemoteDir = "/tmp/algia-restore-$Stamp"

docker exec $Backend bash -lc "rm -rf '$RemoteDir' && mkdir -p '$RemoteDir'"

Write-Step "Copie sauvegarde dans le conteneur"

docker cp "$($DbFile.FullName)" "${Backend}:${RemoteDir}/database.sql.gz"

$RestoreCommand = "bench --site '$Site' restore '$RemoteDir/database.sql.gz' --force"

if ($PrivateFile) {
    docker cp "$($PrivateFile.FullName)" "${Backend}:${RemoteDir}/private-files.tar"
    $RestoreCommand = "$RestoreCommand --with-private-files '$RemoteDir/private-files.tar'"
}

if ($PublicFile) {
    docker cp "$($PublicFile.FullName)" "${Backend}:${RemoteDir}/public-files.tar"
    $RestoreCommand = "$RestoreCommand --with-public-files '$RemoteDir/public-files.tar'"
}

Write-Step "Restauration"

docker exec $Backend bash -lc "cd /home/frappe/frappe-bench && $RestoreCommand"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Restauration echouee." -ForegroundColor Red
    exit 1
}

Write-Step "Migration et nettoyage"

docker exec $Backend bash -lc "cd /home/frappe/frappe-bench && bench --site '$Site' migrate && bench --site '$Site' clear-cache && bench --site '$Site' clear-website-cache || true"

Write-Step "Redemarrage ALGIA Cabinet"

docker compose --env-file .env up -d backend websocket queue-short queue-long scheduler frontend

Write-Step "Etat conteneurs"

docker compose --env-file .env ps

$Port = Get-EnvValue "HTTP_PORT" "8080"
$Url = "http://localhost:$Port"

Write-Step "Restauration terminee"

Write-Host "ALGIA Cabinet restaure : $Url" -ForegroundColor Green
Start-Process $Url
exit 0
