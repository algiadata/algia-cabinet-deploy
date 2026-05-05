param(
    [string]$SourceDir = ""
)

$ErrorActionPreference = "Stop"

$Root = Resolve-Path "$PSScriptRoot\..\..\.."
Set-Location $Root

function Write-Step($Message) {
    Write-Host ""
    Write-Host "=== $Message ===" -ForegroundColor Cyan
}

function New-Secret {
    -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 18 | ForEach-Object {[char]$_})
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

function Load-OfflineImages {
    param([string]$InstallerSourceDir)

    $candidates = @()

    if ($InstallerSourceDir -and (Test-Path $InstallerSourceDir)) {
        $candidates += (Join-Path $InstallerSourceDir "offline-images")
    }

    $candidates += (Join-Path $Root "offline-images")

    foreach ($dir in $candidates) {
        if (Test-Path $dir) {
            $images = @()
            $images += Get-ChildItem -Path $dir -File -Filter "*.tar" -ErrorAction SilentlyContinue
            $images += Get-ChildItem -Path $dir -File -Filter "*.tar.gz" -ErrorAction SilentlyContinue

            if ($images.Count -gt 0) {
                Write-Step "Chargement images Docker offline"
                foreach ($img in $images) {
                    Write-Host "Chargement : $($img.Name)" -ForegroundColor Yellow
                    docker load -i $img.FullName
                    if ($LASTEXITCODE -ne 0) {
                        Write-Host "Echec chargement image Docker : $($img.FullName)" -ForegroundColor Red
                        exit 1
                    }
                }
                return $true
            }
        }
    }

    return $false
}

Write-Step "Verification Docker Desktop"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "Docker Desktop n'est pas installe." -ForegroundColor Red
    Write-Host "Installe Docker Desktop puis relance l'installateur ALGIA Cabinet."
    Start-Process "https://www.docker.com/products/docker-desktop/"
    exit 1
}

cmd.exe /c "docker info >NUL 2>NUL"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker Desktop n'est pas lance." -ForegroundColor Red
    Write-Host "Lance Docker Desktop puis relance l'installateur ALGIA Cabinet."
    exit 1
}

Write-Step "Preparation configuration"

if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"

    $admin = "Admin-" + (New-Secret)
    $root = "Root-" + (New-Secret)
    $db = "Db-" + (New-Secret)

    $content = Get-Content ".env" -Raw
    $content = $content -replace "ADMIN_PASSWORD=change_me_admin", "ADMIN_PASSWORD=$admin"
    $content = $content -replace "DB_ROOT_PASSWORD=change_me_root", "DB_ROOT_PASSWORD=$root"
    $content = $content -replace "DB_PASSWORD=change_me_db", "DB_PASSWORD=$db"
    Set-Content ".env" $content -Encoding UTF8

    Write-Host "Fichier .env cree." -ForegroundColor Green
    Write-Host "Utilisateur : Administrator" -ForegroundColor Yellow
    Write-Host "Mot de passe admin: $admin" -ForegroundColor Yellow
    Write-Host "Garde ce mot de passe." -ForegroundColor Yellow
} else {
    Write-Host "Fichier .env deja present."
}

Write-Step "Validation Docker Compose"
docker compose --env-file .env config *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Configuration Docker Compose invalide." -ForegroundColor Red
    exit 1
}

$offlineLoaded = Load-OfflineImages -InstallerSourceDir $SourceDir

if (-not $offlineLoaded) {
    Write-Step "Telechargement des images Docker"
    docker compose --env-file .env pull
} else {
    Write-Step "Images offline chargees"
}

Write-Step "Demarrage infrastructure"
docker compose --env-file .env up -d db redis-cache redis-queue redis-socketio

Write-Step "Configuration du site"
docker compose --env-file .env run --rm configurator

Write-Step "Creation ou migration du site"
docker compose --env-file .env run --rm create-site

Write-Step "Synchronisation mot de passe Administrator"

$Site = Get-EnvValue "SITE_NAME" "cabinet.local"
$AdminPassword = Get-EnvValue "ADMIN_PASSWORD" ""

if ([string]::IsNullOrWhiteSpace($AdminPassword)) {
    Write-Host "ADMIN_PASSWORD introuvable dans .env." -ForegroundColor Red
    exit 1
}

docker compose --env-file .env run --rm backend bash -lc "cd /home/frappe/frappe-bench && bench --site '$Site' set-admin-password '$AdminPassword'"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Synchronisation du mot de passe Administrator echouee." -ForegroundColor Red
    exit 1
}

Write-Host "Mot de passe Administrator synchronise avec le fichier .env." -ForegroundColor Green

Write-Step "Demarrage ALGIA Cabinet"
docker compose --env-file .env up -d backend websocket queue-short queue-long scheduler frontend

Write-Step "Etat des conteneurs"
docker compose --env-file .env ps

$port = Get-EnvValue "HTTP_PORT" "8080"
$url = "http://localhost:$port"
$adminPasswordFinal = Get-EnvValue "ADMIN_PASSWORD" "non recupere"

Write-Step "Ouverture navigateur"
Start-Process $url

Write-Host ""
Write-Host "ALGIA Cabinet est lance : $url" -ForegroundColor Green
Write-Host "Utilisateur : Administrator"
Write-Host "Mot de passe admin: $adminPasswordFinal"
Write-Host "Installation terminee"
exit 0
