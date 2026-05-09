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

    if (-not $exe) {
        return $false
    }

    Write-Host "Demarrage Docker Desktop en mode reduit..." -ForegroundColor Yellow
    Start-Process -FilePath $exe -ArgumentList "--minimized" -WindowStyle Minimized
    return $true
}

function Install-DockerDesktopIfMissing {
    if (Get-Command docker -ErrorAction SilentlyContinue) {
        return
    }

    Write-Step "Installation Docker Desktop"

    $DockerProgramDir = Join-Path $Root "docker-program"
    $DockerDataDir = Join-Path $Root "docker-data"
    $DockerWslDataDir = Join-Path $DockerDataDir "wsl"
    $DockerHyperVDataDir = Join-Path $DockerDataDir "hyper-v"
    $DockerWindowsContainersDataDir = Join-Path $DockerDataDir "windows-containers"

    New-Item -ItemType Directory -Force -Path $DockerProgramDir | Out-Null
    New-Item -ItemType Directory -Force -Path $DockerDataDir | Out-Null
    New-Item -ItemType Directory -Force -Path $DockerWslDataDir | Out-Null
    New-Item -ItemType Directory -Force -Path $DockerHyperVDataDir | Out-Null
    New-Item -ItemType Directory -Force -Path $DockerWindowsContainersDataDir | Out-Null

    Write-Host "Dossier Docker programme : $DockerProgramDir" -ForegroundColor Yellow
    Write-Host "Dossier Docker donnees   : $DockerDataDir" -ForegroundColor Yellow

    $localInstallers = @()

    if ($SourceDir -and (Test-Path $SourceDir)) {
        $localInstallers += Get-ChildItem -Path (Join-Path $SourceDir "third-party") -File -Filter "Docker Desktop*.exe" -ErrorAction SilentlyContinue
        $localInstallers += Get-ChildItem -Path (Join-Path $SourceDir "third-party") -File -Filter "DockerDesktop*.exe" -ErrorAction SilentlyContinue
    }

    $localInstallers += Get-ChildItem -Path (Join-Path $Root "third-party") -File -Filter "Docker Desktop*.exe" -ErrorAction SilentlyContinue
    $localInstallers += Get-ChildItem -Path (Join-Path $Root "third-party") -File -Filter "DockerDesktop*.exe" -ErrorAction SilentlyContinue

    $localInstallers = @($localInstallers | Where-Object { $_ -and (Test-Path $_.FullName) } | Select-Object -Unique)

    foreach ($installer in $localInstallers) {
        Write-Host "Installateur Docker Desktop trouve : $($installer.FullName)" -ForegroundColor Yellow

        $advancedArgs = @(
            "install",
            "--quiet",
            "--accept-license",
            "--installation-dir", "`"$DockerProgramDir`"",
            "--wsl-default-data-root", "`"$DockerWslDataDir`"",
            "--hyper-v-default-data-root", "`"$DockerHyperVDataDir`"",
            "--windows-containers-default-data-root", "`"$DockerWindowsContainersDataDir`""
        ) -join " "

        Write-Host "Tentative installation Docker avec dossier donnees personnalise..." -ForegroundColor Yellow
        $p = Start-Process -FilePath $installer.FullName -ArgumentList $advancedArgs -Verb RunAs -Wait -PassThru

        if ($p.ExitCode -eq 0) {
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            Write-Host "Docker Desktop installe avec dossiers personnalises." -ForegroundColor Green
            return
        }

        Write-Host "Installation avancee Docker echouee. Tentative installation standard..." -ForegroundColor Yellow
        $fallbackArgs = "install --quiet --accept-license"
        $p = Start-Process -FilePath $installer.FullName -ArgumentList $fallbackArgs -Verb RunAs -Wait -PassThru

        if ($p.ExitCode -eq 0) {
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            Write-Host "Docker Desktop installe en mode standard." -ForegroundColor Green
            Write-Host "Si les donnees Docker restent sur C:, configure Docker Desktop > Settings > Resources > Advanced > Disk image location vers : $DockerDataDir" -ForegroundColor Yellow
            return
        }
    }

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "Installation Docker Desktop via winget..." -ForegroundColor Yellow
        winget install --id Docker.DockerDesktop -e --accept-source-agreements --accept-package-agreements
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        Write-Host "Docker Desktop installe via winget." -ForegroundColor Green
        Write-Host "Configure Docker Desktop > Settings > Resources > Advanced > Disk image location vers : $DockerDataDir" -ForegroundColor Yellow
        return
    }

    Write-Host "Docker Desktop n'est pas installe et aucun installateur Docker local utilisable n'a ete trouve." -ForegroundColor Red
    Write-Host "Place Docker Desktop Installer.exe dans le dossier third-party puis relance l'installation." -ForegroundColor Yellow
    exit 1
}

function Wait-DockerReady {
    param([int]$Seconds = 300)

    $deadline = (Get-Date).AddSeconds($Seconds)

    while ((Get-Date) -lt $deadline) {
        if (Test-DockerReady) {
            Write-Host "Docker Desktop est pret." -ForegroundColor Green
            return $true
        }

        Start-Sleep -Seconds 5
    }

    return $false
}

Write-Step "Verification Docker Desktop"

Install-DockerDesktopIfMissing

if (-not (Test-DockerReady)) {
    Start-DockerDesktopMinimized | Out-Null
}

if (-not (Wait-DockerReady -Seconds 300)) {
    Write-Host "Docker Desktop n'est pas encore pret." -ForegroundColor Red
    Write-Host "Si Docker Desktop vient d'etre installe, redemarre Windows puis relance ALGIA Cabinet." -ForegroundColor Yellow
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
