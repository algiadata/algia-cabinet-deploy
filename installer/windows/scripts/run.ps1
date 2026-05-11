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

function Test-AlgiaInstalled($Dir) {
    if (-not $Dir) {
        return $false
    }

    return (
        (Test-Path (Join-Path $Dir ".env")) -and
        (Test-Path (Join-Path $Dir "docker-compose.yml")) -and
        (Test-Path (Join-Path $Dir "installer\windows\scripts\start.ps1"))
    )
}

function Get-SavedInstallRoot {
    $candidates = @()

    $candidates += Join-Path $Root "state\install-root.txt"

    if ($SourceDir -and (Test-Path $SourceDir)) {
        $candidates += Join-Path $SourceDir "state\install-root.txt"
    }

    foreach ($file in $candidates) {
        if (Test-Path $file) {
            $saved = (Get-Content $file -Raw).Trim()

            if ($saved -and (Test-AlgiaInstalled $saved)) {
                return $saved
            }
        }
    }

    return ""
}

function Save-InstallRoot($Dir) {
    New-Item -ItemType Directory -Force -Path (Join-Path $Root "state") | Out-Null
    Set-Content -Path (Join-Path $Root "state\install-root.txt") -Value $Dir -Encoding UTF8

    if ($SourceDir -and (Test-Path $SourceDir)) {
        New-Item -ItemType Directory -Force -Path (Join-Path $SourceDir "state") | Out-Null
        Set-Content -Path (Join-Path $SourceDir "state\install-root.txt") -Value $Dir -Encoding UTF8
    }
}

Write-Step "ALGIA Cabinet - Installer / Lancer"

$savedRoot = Get-SavedInstallRoot

if ($savedRoot) {
    Write-Host "Installation existante détectée : $savedRoot" -ForegroundColor Green
    Save-InstallRoot $savedRoot

    $startScript = Join-Path $savedRoot "installer\windows\scripts\start.ps1"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $startScript
    exit $LASTEXITCODE
}

if (Test-AlgiaInstalled $Root) {
    Write-Host "Installation existante détectée : $Root" -ForegroundColor Green
    Save-InstallRoot $Root

    $startScript = Join-Path $Root "installer\windows\scripts\start.ps1"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $startScript
    exit $LASTEXITCODE
}

Write-Host "Aucune installation existante détectée dans le dossier courant." -ForegroundColor Yellow
Write-Host "Lancement de la première installation..." -ForegroundColor Yellow

$installScript = Join-Path $Root "installer\windows\scripts\install.ps1"

if (-not (Test-Path $installScript)) {
    Write-Host "Script d'installation introuvable : $installScript" -ForegroundColor Red
    exit 1
}

if ($SourceDir) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installScript -SourceDir $SourceDir
} else {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $installScript
}

$code = $LASTEXITCODE

if ($code -eq 0 -and (Test-AlgiaInstalled $Root)) {
    Save-InstallRoot $Root
}

exit $code
