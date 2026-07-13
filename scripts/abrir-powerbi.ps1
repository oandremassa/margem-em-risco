param(
    [string]$ServerInstance = "localhost"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot

& powershell `
    -NoProfile `
    -ExecutionPolicy Bypass `
    -File (Join-Path $Root "scripts\validar.ps1") `
    -ServerInstance $ServerInstance

if ($LASTEXITCODE -ne 0) {
    throw "O projeto não será aberto porque a validação falhou."
}

Start-Process (Join-Path $Root "powerbi\Margem em Risco.pbip")
