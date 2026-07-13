param
(
    [string]$ServerInstance = "localhost"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$sqlRoot = Join-Path $projectRoot "sql\powerbi"

function Invoke-ProjectSql
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    $filePath = Join-Path $sqlRoot $RelativePath

    if (-not (Test-Path $filePath))
    {
        throw "Arquivo nao encontrado: $filePath"
    }

    Write-Host ""
    Write-Host ("Executando: {0}" -f $RelativePath)

    & sqlcmd `
        -S $ServerInstance `
        -E `
        -C `
        -I `
        -f 65001 `
        -b `
        -r 1 `
        -i $filePath

    if ($LASTEXITCODE -ne 0)
    {
        throw "Falha ao executar: $RelativePath"
    }
}

Write-Host ""
Write-Host "Margem em Risco - correcao da Fase 05"
Write-Host "Servidor: $ServerInstance"
Write-Host "Projeto:  $projectRoot"
Write-Host ""

Invoke-ProjectSql ".\900_validate_source_columns.sql"
Invoke-ProjectSql ".\901_create_bi_schema_and_views.sql"
Invoke-ProjectSql ".\902_validate_bi_layer.sql"

Write-Host ""
Write-Host "Fase 05 concluida."
Write-Host "A camada bi esta pronta para conexao no Power BI."
