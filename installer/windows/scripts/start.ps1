$ErrorActionPreference = "Stop"

$Root = Resolve-Path "$PSScriptRoot\..\..\.."
Set-Location $Root

docker compose --env-file .env up -d
docker compose --env-file .env ps
Start-Process "http://localhost:8080"
