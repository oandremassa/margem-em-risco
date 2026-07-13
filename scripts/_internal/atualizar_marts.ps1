param
(
    [string]$ServerInstance = "localhost"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$sqlRoot = Join-Path $projectRoot "sql\marts"

function Invoke-Step
{
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$FileName
    )

    $filePath = Join-Path $sqlRoot $FileName

    if (-not (Test-Path $filePath))
    {
        throw "Arquivo nao encontrado: $filePath"
    }

    Write-Host ""
    Write-Host ("Executando {0}" -f $FileName)

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
        throw "A instalacao parou no arquivo: $FileName"
    }
}

Write-Host ""
Write-Host "Margem em Risco - substituicao da camada analitica"
Write-Host "Servidor: $ServerInstance"
Write-Host "Projeto:  $projectRoot"
Write-Host ""
Write-Host "Os dados raw, staging e dw serao preservados."
Write-Host "Somente a camada mart sera reconstruida."
Write-Host ""

$steps = @(
    "600_cleanup_old_analytics.sql",
    "601_base.sql",
    "602_performance.sql",
    "603_loss.sql",
    "604_risk.sql",
    "605_drivers.sql",
    "606_action_monthly.sql",
    "607_action_current.sql",
    "608_executive.sql",
    "609_portfolio.sql",
    "610_create_refresh_procedure.sql",
    "611_validate_and_review.sql"
)

foreach ($step in $steps)
{
    Invoke-Step -FileName $step
}

Write-Host ""
Write-Host "Camada analitica reconstruida com tabelas materializadas."
Write-Host "Nenhuma cadeia profunda de views permanece nas consultas do Power BI."
