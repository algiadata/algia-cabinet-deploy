# ALGIA Cabinet Deploy

Ce dépôt contient la future base d'installation locale de **ALGIA Cabinet**.

Objectif : permettre une installation simple chez un cabinet, en local, avec Docker.

## Principe

- Installation locale
- Données chez l'utilisateur
- Déploiement Docker
- Sauvegarde documentée
- Restauration documentée
- Scripts Windows prévus

## Dépôt applicatif associé

```text
algiadata/algia-cabinet
```

## Structure cible

```text
algia-cabinet-deploy/
├── README.md
├── docker-compose.yml
├── .env.example
├── installer/
│   └── windows/
│       ├── install.ps1
│       ├── start.ps1
│       ├── stop.ps1
│       └── backup.ps1
├── docs/
│   ├── installation-windows.md
│   ├── docker-desktop.md
│   ├── sauvegarde.md
│   └── depannage.md
└── releases/
```

## Statut

Phase actuelle : cadrage déploiement.

Aucun script d'installation ne doit être ajouté avant validation de l'architecture produit dans le dépôt `algia-cabinet`.
