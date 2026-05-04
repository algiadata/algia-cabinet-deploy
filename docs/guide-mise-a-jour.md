# Guide — Mise à jour ALGIA Cabinet

Ce guide explique comment publier une nouvelle version d'ALGIA Cabinet après des changements effectués sur le VPS.

## Principe général

Une modification faite sur le VPS n'est pas livrée automatiquement au client.

La livraison devient complète uniquement quand on lance le script de release :

```text
Modification VPS
→ commit/push du repo app
→ build nouvelle image Docker
→ push Docker Hub
→ mise à jour du manifest deploy
→ export des images offline
→ génération du dossier client
→ ajout du launcher Windows
→ ZIP final
```

## 1. Modifier l'application sur le VPS

Les changements se font dans le repo applicatif :

```bash
cd /home/frappe/frappe-bench/apps/algia_cabinet
```

Exemples de fichiers possibles :

```text
algia_cabinet/www/...
algia_cabinet/api/...
algia_cabinet/doctype/...
```

Vérifier les fichiers modifiés :

```bash
git status --short
```

## 2. Lancer une nouvelle release

Aller dans le repo deploy :

```bash
cd ~/algia-cabinet-deploy
```

Lancer une nouvelle version. Exemple pour passer de `v0.1.1` à `v0.1.2` :

```bash
./scripts/release-new-version.sh v0.1.2 "Description de la modification"
```

Exemple réel :

```bash
./scripts/release-new-version.sh v0.1.2 "Correction affichage patients"
```

Le script fait automatiquement :

```text
1. commit des changements dans le repo app algia-cabinet
2. push vers GitHub du repo app
3. copie de l'app dans le dossier image build
4. build Docker de la nouvelle image
5. push Docker Hub
6. mise à jour manifests/release.json
7. mise à jour .env.example
8. export des images offline
9. génération du dossier client
```

## 3. Résultat attendu côté VPS

À la fin, le script doit afficher un message de ce type :

```text
ALGIA Cabinet release image terminee
Version: v0.1.2
Image: algiadata/algia-cabinet:v0.1.2
Pack: /home/frappe/algia-cabinet-deploy/releases/ALGIA-Cabinet-Client-v0.1.2
```

La nouvelle image Docker sera disponible ici :

```text
algiadata/algia-cabinet:v0.1.2
```

Le nouveau dossier client sera ici :

```text
/home/frappe/algia-cabinet-deploy/releases/ALGIA-Cabinet-Client-v0.1.2
```

## 4. Récupérer le pack sur Windows

Sur Windows PowerShell, récupérer le dossier client depuis le VPS.

Exemple pour `v0.1.2` :

```powershell
Set-Location "C:\ALGIA\algia-cabinet-deploy"

New-Item -ItemType Directory -Force -Path ".\releases\ALGIA-Cabinet-Client-v0.1.2" | Out-Null

scp -r "frappe@72.62.25.147:/home/frappe/algia-cabinet-deploy/releases/ALGIA-Cabinet-Client-v0.1.2/*" `
  ".\releases\ALGIA-Cabinet-Client-v0.1.2\"
```

## 5. Ajouter le launcher WPF Windows

Le VPS ne compile pas le launcher Windows. Sur Windows, remplacer `A_COMPILER_SUR_WINDOWS.txt` par le launcher WPF.

Exemple pour `v0.1.2` :

```powershell
Set-Location "C:\ALGIA\algia-cabinet-deploy"

$Pack = "C:\ALGIA\algia-cabinet-deploy\releases\ALGIA-Cabinet-Client-v0.1.2"

Remove-Item "$Pack\A_COMPILER_SUR_WINDOWS.txt" -Force -ErrorAction SilentlyContinue

Copy-Item ".\releases\wpf-launcher\ALGIAMAT.Launcher.exe" "$Pack\algia-cabinet-installer-win64.exe" -Force
Copy-Item ".\releases\wpf-launcher\ALGIAMAT.Launcher.dll" "$Pack\" -Force
Copy-Item ".\releases\wpf-launcher\ALGIAMAT.Launcher.deps.json" "$Pack\" -Force
Copy-Item ".\releases\wpf-launcher\ALGIAMAT.Launcher.runtimeconfig.json" "$Pack\" -Force
```

## 6. Supprimer les fichiers interdits

Avant de créer le ZIP, ne jamais livrer `.env`, car il contient les mots de passe générés pendant les tests.

```powershell
Remove-Item "$Pack\.env" -Force -ErrorAction SilentlyContinue
Remove-Item "$Pack\A_COMPILER_SUR_WINDOWS.txt" -Force -ErrorAction SilentlyContinue
```

Le pack final ne doit pas contenir :

```text
.env
A_COMPILER_SUR_WINDOWS.txt
```

## 7. Générer le SHA256 et le ZIP final

Exemple pour `v0.1.2` :

```powershell
Set-Location "C:\ALGIA\algia-cabinet-deploy\releases"

$FolderName = "ALGIA-Cabinet-Client-v0.1.2"
$Pack = "C:\ALGIA\algia-cabinet-deploy\releases\$FolderName"
$Zip = "C:\ALGIA\algia-cabinet-deploy\releases\$FolderName.zip"

Remove-Item "$Pack\SHA256.txt" -Force -ErrorAction SilentlyContinue

Get-ChildItem $Pack -Recurse -File |
  Where-Object { $_.Name -ne "SHA256.txt" } |
  Sort-Object FullName |
  ForEach-Object {
      $rel = $_.FullName.Substring($Pack.Length + 1).Replace("\", "/")
      $hash = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower()
      "$hash  $rel"
  } | Set-Content "$Pack\SHA256.txt" -Encoding UTF8

Remove-Item $Zip -Force -ErrorAction SilentlyContinue

Compress-Archive `
  -Path $Pack `
  -DestinationPath $Zip `
  -Force
```

## 8. Vérifier le ZIP final

```powershell
Get-ChildItem $Zip | Format-List Name,Length,FullName,LastWriteTime

Add-Type -AssemblyName System.IO.Compression.FileSystem

$Archive = [System.IO.Compression.ZipFile]::OpenRead($Zip)

$Archive.Entries |
  Select-Object -First 40 FullName,Length |
  Format-Table -AutoSize

$Archive.Dispose()
```

Dans le ZIP, les chemins doivent commencer par le dossier parent :

```text
ALGIA-Cabinet-Client-v0.1.2\algia-cabinet-installer-win64.exe
ALGIA-Cabinet-Client-v0.1.2\docker-compose.yml
ALGIA-Cabinet-Client-v0.1.2\manifests\release.json
ALGIA-Cabinet-Client-v0.1.2\offline-images\algia-cabinet-app-v0.1.2.tar
ALGIA-Cabinet-Client-v0.1.2\offline-images\mariadb-10.6.tar
ALGIA-Cabinet-Client-v0.1.2\offline-images\redis-7-alpine.tar
```

## 9. Commande type à retenir

À chaque nouvelle mise à jour :

```bash
cd ~/algia-cabinet-deploy
./scripts/release-new-version.sh v0.1.X "Message de la modification"
```

Puis côté Windows :

```text
1. récupérer le dossier client
2. ajouter le launcher WPF
3. supprimer .env et A_COMPILER_SUR_WINDOWS.txt
4. régénérer SHA256.txt
5. créer le ZIP final
```

## 10. Règle importante

```text
Modifier sur VPS seulement = pas encore livré.

Modifier sur VPS + lancer release-new-version.sh =
repo GitHub à jour + image Docker à jour + pack client généré.
```

Pour livrer une vraie mise à jour client, il faut toujours faire :

```text
nouvelle version
nouvelle image Docker
nouveau pack ZIP
```

## 11. Contrôles rapides avant livraison

Le ZIP final doit contenir :

```text
ALGIA-Cabinet-Client-vX.X.X\algia-cabinet-installer-win64.exe
ALGIA-Cabinet-Client-vX.X.X\ALGIAMAT.Launcher.dll
ALGIA-Cabinet-Client-vX.X.X\ALGIAMAT.Launcher.deps.json
ALGIA-Cabinet-Client-vX.X.X\ALGIAMAT.Launcher.runtimeconfig.json
ALGIA-Cabinet-Client-vX.X.X\docker-compose.yml
ALGIA-Cabinet-Client-vX.X.X\.env.example
ALGIA-Cabinet-Client-vX.X.X\INSTALLATION_CLIENT.txt
ALGIA-Cabinet-Client-vX.X.X\README.md
ALGIA-Cabinet-Client-vX.X.X\SHA256.txt
ALGIA-Cabinet-Client-vX.X.X\bootstrap\
ALGIA-Cabinet-Client-vX.X.X\docs\
ALGIA-Cabinet-Client-vX.X.X\installer\
ALGIA-Cabinet-Client-vX.X.X\manifests\
ALGIA-Cabinet-Client-vX.X.X\offline-images\
```

Le ZIP final ne doit jamais contenir :

```text
.env
A_COMPILER_SUR_WINDOWS.txt
```
