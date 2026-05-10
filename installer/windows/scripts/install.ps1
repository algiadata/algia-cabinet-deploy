param(
    [string]$SourceDir = ""
)

$ErrorActionPreference = "Stop"

$Root = Resolve-Path "$PSScriptRoot\..\..\.."
Set-Location $Root

$script:DockerDesktopInstalledNow = $false

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
        (Join-Path $Root "docker-program\Docker Desktop.exe"),
        (Join-Path $Root "docker-program\Docker\Docker Desktop.exe"),
        "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe",
        "${env:ProgramFiles(x86)}\Docker\Docker\Docker Desktop.exe",
        "$env:LOCALAPPDATA\Docker\Docker Desktop.exe"
    )

    foreach ($p in $paths) {
        if ($p -and (Test-Path $p)) {
            return $p
        }
    }

    $customRoot = Join-Path $Root "docker-program"

    if (Test-Path $customRoot) {
        $found = Get-ChildItem -Path $customRoot -Recurse -File -Filter "Docker Desktop.exe" -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty FullName -First 1

        if ($found) {
            return $found
        }
    }

    return ""
}

function Test-DockerReady {
    cmd.exe /c "docker info >NUL 2>NUL"
    return ($LASTEXITCODE -eq 0)
}

function Invoke-DockerDesktopWindowHider {
    New-Item -ItemType Directory -Force -Path (Join-Path $Root "state") | Out-Null

    $scriptPath = Join-Path $Root "state\hide-docker-desktop-windows.ps1"

    $contentLines = @(
        'Add-Type @"',
        'using System;',
        'using System.Runtime.InteropServices;',
        '',
        'public class Win32WindowTools {',
        '    [DllImport("user32.dll")]',
        '    public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);',
        '}',
        '"@',
        '',
        '$deadline = (Get-Date).AddSeconds(240)',
        '',
        'while ((Get-Date) -lt $deadline) {',
        '    Get-Process -ErrorAction SilentlyContinue | Where-Object {',
        '        $_.ProcessName -like "Docker Desktop*" -or $_.MainWindowTitle -like "*Docker Desktop*"',
        '    } | ForEach-Object {',
        '        try {',
        '            if ($_.MainWindowHandle -ne [IntPtr]::Zero) {',
        '                [Win32WindowTools]::ShowWindowAsync($_.MainWindowHandle, 0) | Out-Null',
        '            }',
        '        } catch {}',
        '    }',
        '',
        '    Start-Sleep -Seconds 2',
        '}'
    )

    Set-Content -Path $scriptPath -Value $contentLines -Encoding UTF8

    Start-Process `
        -FilePath "powershell.exe" `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" `
        -WindowStyle Hidden
}

function Start-DockerDesktopMinimized {
    $exe = Get-DockerDesktopExe

    if (-not $exe) {
        return $false
    }

    Write-Host "Demarrage Docker Desktop en mode discret / systray..." -ForegroundColor Yellow

    try {
        Start-Process -FilePath $exe -ArgumentList @("--minimized", "--unattended") -WindowStyle Minimized
    } catch {
        Start-Process -FilePath $exe -ArgumentList "--minimized" -WindowStyle Minimized
    }

    Invoke-DockerDesktopWindowHider

    return $true
}



function Convert-ToPowerShellSingleQuotedString {
    param([string]$Value)

    return "'" + ($Value -replace "'", "''") + "'"
}

function Repair-DockerDesktopUninstallEntry {
    param([string]$DockerProgramDir)

    if (-not $DockerProgramDir) {
        return
    }

    $PermanentUninstallerDir = Join-Path $Root "docker-uninstaller"
    $PermanentUninstaller = Join-Path $PermanentUninstallerDir "Docker Desktop Installer.exe"

    New-Item -ItemType Directory -Force -Path $PermanentUninstallerDir | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $Root "state") | Out-Null

    $candidates = @()
    $candidates += Join-Path $DockerProgramDir "Docker Desktop Installer.exe"

    if ($SourceDir -and (Test-Path $SourceDir)) {
        $candidates += Get-ChildItem -Path (Join-Path $SourceDir "third-party") -File -Filter "Docker Desktop*.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
        $candidates += Get-ChildItem -Path (Join-Path $SourceDir "third-party") -File -Filter "DockerDesktop*.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
    }

    $candidates += Get-ChildItem -Path (Join-Path $Root "third-party") -File -Filter "Docker Desktop*.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
    $candidates += Get-ChildItem -Path (Join-Path $Root "third-party") -File -Filter "DockerDesktop*.exe" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName

    $installer = $candidates | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1

    if (-not $installer) {
        Write-Host "Installateur Docker Desktop introuvable pour reparer la desinstallation Windows." -ForegroundColor Yellow
        return
    }

    Copy-Item $installer $PermanentUninstaller -Force

    $repairScript = Join-Path $Root "state\repair-docker-uninstall.ps1"
    $permanentUninstallerLiteral = Convert-ToPowerShellSingleQuotedString $PermanentUninstaller
    $dockerProgramDirLiteral = Convert-ToPowerShellSingleQuotedString $DockerProgramDir

    $repairContent = @"
`$PermanentUninstaller = $permanentUninstallerLiteral
`$DockerProgramDir = $dockerProgramDirLiteral

`$RegistryRoots = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
)

foreach (`$RegistryRoot in `$RegistryRoots) {
    if (-not (Test-Path `$RegistryRoot)) {
        continue
    }

    Get-ChildItem `$RegistryRoot -ErrorAction SilentlyContinue | ForEach-Object {
        `$Key = `$_.PSPath
        `$Props = Get-ItemProperty `$Key -ErrorAction SilentlyContinue

        if (`$Props.DisplayName -like "Docker Desktop*") {
            Set-ItemProperty -Path `$Key -Name "UninstallString" -Value "`"`$PermanentUninstaller`" uninstall" -ErrorAction SilentlyContinue
            Set-ItemProperty -Path `$Key -Name "QuietUninstallString" -Value "`"`$PermanentUninstaller`" uninstall --quiet" -ErrorAction SilentlyContinue
            Set-ItemProperty -Path `$Key -Name "InstallLocation" -Value `$DockerProgramDir -ErrorAction SilentlyContinue
        }
    }
}
"@

    Set-Content -Path $repairScript -Value $repairContent -Encoding UTF8

    Write-Host "Reparation entree Windows de desinstallation Docker..." -ForegroundColor Yellow

    $args = '-NoProfile -ExecutionPolicy Bypass -File "' + $repairScript + '"'
    $p = Start-Process -FilePath "powershell.exe" -ArgumentList $args -Verb RunAs -Wait -PassThru

    if ($p.ExitCode -eq 0) {
        Write-Host "Entree Windows de desinstallation Docker reparee." -ForegroundColor Green
        Write-Host "UninstallString Docker => `"$PermanentUninstaller`" uninstall" -ForegroundColor Yellow
    } else {
        Write-Host "Reparation de la desinstallation Docker non confirmee." -ForegroundColor Yellow
    }
}


function Get-LauncherExeForResume {
    $candidates = @()

    if ($SourceDir -and (Test-Path $SourceDir)) {
        $candidates += (Join-Path $SourceDir "launcher\ALGIA-Cabinet-Launcher.exe")
    }

    $candidates += (Join-Path $Root "launcher\ALGIA-Cabinet-Launcher.exe")

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path $candidate)) {
            return $candidate
        }
    }

    return ""
}

function Register-LauncherResumeAfterReboot {
    $launcher = Get-LauncherExeForResume

    if (-not $launcher) {
        Write-Host "Launcher introuvable pour reprise automatique apres redemarrage." -ForegroundColor Yellow
        return
    }

    $runOncePath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
    New-Item -Path $runOncePath -Force | Out-Null
    New-ItemProperty `
        -Path $runOncePath `
        -Name "ALGIA Cabinet - Reprise installation" `
        -Value "`"$launcher`"" `
        -PropertyType String `
        -Force | Out-Null

    Write-Host "Reprise automatique programmee apres redemarrage : $launcher" -ForegroundColor Green
}

function Request-DockerRebootAndExit {
    Write-Step "Redemarrage requis"

    Register-LauncherResumeAfterReboot

    Write-Host "Docker Desktop vient d'etre installe avec succes." -ForegroundColor Green
    Write-Host "Windows doit redemarrer pour activer Docker/WSL correctement." -ForegroundColor Yellow
    Write-Host "Apres redemarrage, ALGIA Cabinet Launcher se relancera automatiquement." -ForegroundColor Yellow

    try {
        Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue
        $result = [System.Windows.MessageBox]::Show(
            "Docker Desktop a ete installe avec succes.`n`nWindows doit redemarrer pour activer Docker correctement.`n`nALGIA Cabinet Launcher se relancera automatiquement apres le redemarrage.`n`nRedemarrer maintenant ?",
            "ALGIA Cabinet - Redemarrage requis",
            "YesNo",
            "Information"
        )

        if ($result -eq "Yes") {
            Start-Process "shutdown.exe" -ArgumentList '/r /t 10 /c "ALGIA Cabinet : reprise automatique apres redemarrage."'
        }
    } catch {
        Write-Host "Message graphique indisponible. Redemarre Windows manuellement." -ForegroundColor Yellow
    }

    exit 0
}


function Install-DockerDesktopIfMissing {
    if (Get-Command docker -ErrorAction SilentlyContinue) {
        $existingDocker = Get-DockerDesktopExe

        if ($existingDocker) {
            Write-Host "Docker Desktop deja installe : $existingDocker" -ForegroundColor Yellow

            $rootDrive = ([System.IO.Path]::GetPathRoot($Root)).TrimEnd("\")
            $dockerDrive = ([System.IO.Path]::GetPathRoot($existingDocker)).TrimEnd("\")

            if ($rootDrive -ne $dockerDrive) {
                Write-Host "ATTENTION : Docker Desktop est deja installe sur $dockerDrive alors que ALGIA Cabinet est dans $rootDrive." -ForegroundColor Yellow
                Write-Host "L'installateur ne peut pas deplacer automatiquement un Docker Desktop deja installe." -ForegroundColor Yellow
                Write-Host "Pour mettre Docker sur $rootDrive, desinstalle Docker Desktop puis relance l'installation ALGIA Cabinet." -ForegroundColor Yellow
            }

            $expectedDockerProgramDir = Join-Path $Root "docker-program"

            if (Test-Path $expectedDockerProgramDir) {
                Repair-DockerDesktopUninstallEntry -DockerProgramDir $expectedDockerProgramDir
            }
        }

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
            "--installation-dir=`"$DockerProgramDir`"",
            "--wsl-default-data-root=`"$DockerWslDataDir`"",
            "--hyper-v-default-data-root=`"$DockerHyperVDataDir`"",
            "--windows-containers-default-data-root=`"$DockerWindowsContainersDataDir`""
        )

        Write-Host "Tentative installation Docker avec dossiers personnalises..." -ForegroundColor Yellow
        Write-Host "Programme Docker : $DockerProgramDir" -ForegroundColor Yellow
        Write-Host "Donnees Docker   : $DockerDataDir" -ForegroundColor Yellow

        $p = Start-Process -FilePath $installer.FullName -ArgumentList $advancedArgs -Verb RunAs -Wait -PassThru

        if ($p.ExitCode -eq 0) {
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            $script:DockerDesktopInstalledNow = $true
            Write-Host "Docker Desktop installe avec dossiers personnalises." -ForegroundColor Green
            Repair-DockerDesktopUninstallEntry -DockerProgramDir $DockerProgramDir
            return
        }

        Write-Host "Installation Docker personnalisee echouee." -ForegroundColor Red
        Write-Host "Installation standard bloquee pour eviter une installation Docker sur C:." -ForegroundColor Yellow
        Write-Host "Verifie l'installateur Docker Desktop local dans third-party, puis relance." -ForegroundColor Yellow
        exit 1
    }

    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "Winget detecte, mais installation Docker via winget bloquee." -ForegroundColor Yellow
        Write-Host "Raison : winget installe Docker Desktop sur C: par defaut." -ForegroundColor Yellow
        Write-Host "Place Docker Desktop Installer.exe dans third-party puis relance l'installation." -ForegroundColor Yellow
        exit 1
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
    if ($script:DockerDesktopInstalledNow) {
        Request-DockerRebootAndExit
    }

    Write-Host "Docker Desktop n'est pas encore pret." -ForegroundColor Red
    Write-Host "Ouvre Docker Desktop, attends qu'il soit pret, puis relance l'installation." -ForegroundColor Yellow
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
