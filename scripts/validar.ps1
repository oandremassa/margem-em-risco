param(
    [string]$ServerInstance = "localhost",
    [switch]$SkipDatabase
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Pages = Join-Path $Root "powerbi\Margem em Risco.Report\definition\pages"
$Tables = Join-Path $Root "powerbi\Margem em Risco.SemanticModel\definition\tables"

$PageFiles = Get-ChildItem -Path $Pages -Recurse -Filter "page.json" -File
if ($PageFiles.Count -ne 8) {
    throw "O relatório deveria conter 8 páginas."
}

$ButtonCount = 0
$VisualFiles = Get-ChildItem -Path $Pages -Recurse -Filter "visual.json" -File

foreach ($File in $VisualFiles) {
    $Json = Get-Content $File.FullName -Raw | ConvertFrom-Json
    if ($Json.visual.visualType -eq "actionButton") {
        $ButtonCount++
    }
}

if ($ButtonCount -ne 64) {
    throw "A navegação deveria conter 64 botões."
}

$TmdlFiles = Get-ChildItem -Path $Tables -Filter "*.tmdl" -File
if ($TmdlFiles.Count -ne 11) {
    throw "O modelo deveria conter 11 tabelas TMDL."
}

if ($TmdlFiles | Select-String -Pattern '\[\s*Query\s*=') {
    throw "Foram encontradas consultas nativas no modelo."
}

if (-not $SkipDatabase) {
    & sqlcmd `
        -S $ServerInstance `
        -E `
        -C `
        -I `
        -f 65001 `
        -b `
        -r 1 `
        -i (Join-Path $Root "sql\tests\501_validate_portfolio.sql")

    if ($LASTEXITCODE -ne 0) {
        throw "A validação do banco falhou."
    }
}

Write-Host ""
Write-Host "Projeto validado."
Write-Host "Páginas: 8"
Write-Host "Botões: 64"
Write-Host "Tabelas do modelo: 11"
