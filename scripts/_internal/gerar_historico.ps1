param
(
    [string]$ServerInstance = "localhost"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$sqlRoot = Join-Path $projectRoot "sql\history"

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
        throw "Arquivo SQL nao encontrado: $filePath"
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
Write-Host "Margem em Risco - Fase 04"
Write-Host "Servidor: $ServerInstance"
Write-Host "Projeto:  $projectRoot"
Write-Host ""
Write-Host "Esta fase substitui os fatos sinteticos iniciais por 24 meses de historico."
Write-Host "Raw, staging, dimensoes e configuracoes serao preservados."
Write-Host ""

$files = @(
    ".\08_history\801_create_seed_objects.sql",
    ".\08_history\802_build_contract_month_plan.sql",
    ".\08_history\803_rebuild_history_facts.sql",
    ".\04_marts\612_create_phase04_marts.sql",
    ".\06_tests\604_phase04_history_tests.sql",
    ".\07_analysis\703_review_phase04_history.sql"
)

foreach ($file in $files)
{
    Invoke-ProjectSql $file
}

Write-Host ""
Write-Host "Fase 04 concluida."
Write-Host "Periodo carregado: julho de 2024 a junho de 2026."
Write-Host "Os testes ficaram registrados em etl.test_result com o grupo PHASE_04."
