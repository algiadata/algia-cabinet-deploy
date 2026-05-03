$ErrorActionPreference = "Stop"

$Root = Resolve-Path "$PSScriptRoot\..\..\.."
Set-Location $Root

docker compose --env-file .env stop
docker compose --env-file .env ps
