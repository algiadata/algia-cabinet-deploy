# ALGIA Cabinet Deploy

Pack de déploiement local Docker pour ALGIA Cabinet.

## Objectif

Installer ALGIA Cabinet chez un cabinet médical en local, avec un lancement simple sous Windows.

## Installation rapide Windows

1. Installer Docker Desktop.
2. Lancer Docker Desktop.
3. Double-cliquer sur :

```text
INSTALLER-ALGIA-CABINET.bat
```

4. Ouvrir :

```text
http://localhost:8080
```

## Scripts Windows

```text
INSTALLER-ALGIA-CABINET.bat
DEMARRER-ALGIA-CABINET.bat
ARRETER-ALGIA-CABINET.bat
SAUVEGARDE-ALGIA-CABINET.bat
```

## Configuration

Le fichier `.env` est créé automatiquement à partir de `.env.example`.

Image applicative attendue :

```text
algiadata/algia-cabinet:latest
```

## Données locales

Les données sont stockées dans des volumes Docker locaux :

```text
db-data
sites
logs
```

## Sauvegardes

Les sauvegardes sont créées dans :

```text
backups/
```

## Dépôt applicatif

```text
algiadata/algia-cabinet
```

## Générer un pack ZIP Windows

Depuis le dépôt `algia-cabinet-deploy` :

```bash
./scripts/build-release.sh
```

Le ZIP est généré dans :

```text
releases/
```

Le pack généré ne contient pas `.env`. Le fichier `.env` est créé automatiquement chez l’utilisateur lors de l’installation.
