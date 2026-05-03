$ErrorActionPreference = "Stop"

$Root = Resolve-Path "$PSScriptRoot\..\..\.."
Set-Location $Root

if (-not (Test-Path ".env")) {
    Write-Host "Fichier .env introuvable. Lance d'abord l'installation." -ForegroundColor Red
    exit 1
}

$Site = "cabinet.local"

foreach ($line in Get-Content ".env") {
    if ($line -match "^SITE_NAME=(.+)$") {
        $Site = $Matches[1].Trim()
    }
}

$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$Dest = Join-Path $Root "backups\$Stamp"
New-Item -ItemType Directory -Force -Path $Dest | Out-Null

$Backend = docker compose --env-file .env ps -q backend

if (-not $Backend) {
    Write-Host "Conteneur backend introuvable." -ForegroundColor Red
    exit 1
}

docker exec $Backend bench --site $Site backup --with-files
docker cp "${Backend}:/home/frappe/frappe-bench/sites/$Site/private/backups/." "$Dest"

Write-Host "Sauvegarde creee : $Dest" -ForegroundColor Green
