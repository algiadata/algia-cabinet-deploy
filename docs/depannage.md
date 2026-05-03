# Dépannage ALGIA Cabinet

## Docker non lancé

Lancer Docker Desktop, attendre le démarrage complet, puis relancer l installateur.

## Voir l état

```powershell
docker compose --env-file .env ps
```

## Voir les logs

```powershell
docker compose --env-file .env logs -f
```

## Redémarrer

```text
ARRETER-ALGIA-CABINET.bat
DEMARRER-ALGIA-CABINET.bat
```
