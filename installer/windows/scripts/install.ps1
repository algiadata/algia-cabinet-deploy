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
    $content = $content -replace "ADMIN_PASSWORD=admin", "ADMIN_PASSWORD=$admin"
    $content = $content -replace "DB_ROOT_PASSWORD=admin", "DB_ROOT_PASSWORD=$root"
    $content = $content -replace "DB_PASSWORD=admin", "DB_PASSWORD=$db"
    Set-Content ".env" $content -Encoding UTF8

    Write-Host "Fichier .env cree." -ForegroundColor Green
    Write-Host "Utilisateur : Administrator" -ForegroundColor Yellow
    Write-Host "Mot de passe : $admin" -ForegroundColor Yellow
    Write-Host "Garde ce mot de passe." -ForegroundColor Yellow
} else {
    Write-Host "Fichier .env deja present."
}

Write-Step "Telechargement des images Docker"
docker compose --env-file .env pull

Write-Step "Demarrage ALGIA Cabinet"
docker compose --env-file .env up -d

Write-Step "Etat des conteneurs"
docker compose --env-file .env ps

Write-Step "Ouverture navigateur"
Start-Process "http://localhost:8080"

Write-Host ""
Write-Host "ALGIA Cabinet est lance : http://localhost:8080" -ForegroundColor Green
Write-Host "Utilisateur : Administrator"
Write-Host "Mot de passe : voir le fichier .env"
