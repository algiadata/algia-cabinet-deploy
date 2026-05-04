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

Write-Step "Verification Docker Desktop"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "Docker Desktop n'est pas installe." -ForegroundColor Red
    Write-Host "Installe Docker Desktop puis relance INSTALLER-ALGIA-CABINET.bat"
    Start-Process "https://www.docker.com/products/docker-desktop/"
    exit 1
}

docker info *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Docker Desktop n'est pas lance." -ForegroundColor Red
    Write-Host "Lance Docker Desktop puis relance INSTALLER-ALGIA-CABINET.bat"
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
    Write-Host "Mot de passe : $admin" -ForegroundColor Yellow
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

Write-Step "Telechargement des images Docker"
docker compose --env-file .env pull

Write-Step "Demarrage infrastructure"
docker compose --env-file .env up -d db redis-cache redis-queue redis-socketio

Write-Step "Configuration du site"
docker compose --env-file .env run --rm configurator

Write-Step "Creation ou migration du site"
docker compose --env-file .env run --rm create-site

Write-Step "Demarrage ALGIA Cabinet"
docker compose --env-file .env up -d backend websocket queue-short queue-long scheduler frontend

Write-Step "Etat des conteneurs"
docker compose --env-file .env ps

Write-Step "Ouverture navigateur"
Start-Process "http://localhost:8080"

Write-Host ""
Write-Host "ALGIA Cabinet est lance : http://localhost:8080" -ForegroundColor Green
Write-Host "Utilisateur : Administrator"
Write-Host "Mot de passe : voir le fichier .env"
