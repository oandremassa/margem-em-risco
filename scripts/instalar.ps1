param(
    [string]$ServerInstance = "localhost",
    [switch]$ConfirmReset
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot

function Run-PowerShellStep {
    param([string]$Name, [string]$File)

    Write-Host ""
    Write-Host $Name

    & powershell `
        -NoProfile `
        -ExecutionPolicy Bypass `
        -File $File `
        -ServerInstance $ServerInstance

    if ($LASTEXITCODE -ne 0) {
        throw "Falha na etapa: $Name"
    }
}

function Run-SqlStep {
    param([string]$Name, [string]$File)

    Write-Host ""
    Write-Host $Name

    & sqlcmd `
        -S $ServerInstance `
        -E `
        -C `
        -I `
        -f 65001 `
        -b `
        -r 1 `
        -i $File

    if ($LASTEXITCODE -ne 0) {
        throw "Falha na etapa: $Name"
    }
}

if (-not (Get-Command sqlcmd -ErrorAction SilentlyContinue)) {
    throw "sqlcmd não foi encontrado."
}

if (-not $ConfirmReset) {
    Write-Host ""
    Write-Host "Este processo apaga e recria somente o banco margem_em_risco."
    $Answer = Read-Host "Digite RECRIAR para continuar"

    if ($Answer -ne "RECRIAR") {
        Write-Host "Instalação cancelada."
        exit 0
    }
}

Run-PowerShellStep `
    -Name "Estrutura, carga e regras iniciais" `
    -File (Join-Path $Root "scripts\_internal\instalar_base.ps1")

Run-PowerShellStep `
    -Name "Marts analíticos" `
    -File (Join-Path $Root "scripts\_internal\atualizar_marts.ps1")

Run-PowerShellStep `
    -Name "Histórico de 24 meses" `
    -File (Join-Path $Root "scripts\_internal\gerar_historico.ps1")

Run-PowerShellStep `
    -Name "Camada de consumo do Power BI" `
    -File (Join-Path $Root "scripts\_internal\criar_camada_bi.ps1")

Run-SqlStep `
    -Name "Rótulos e fila de ações" `
    -File (Join-Path $Root "sql\powerbi\903_localize_powerbi_views.sql")

Run-SqlStep `
    -Name "Linha do tempo do contrato" `
    -File (Join-Path $Root "sql\powerbi\904_extend_contract_timeline.sql")

Run-SqlStep `
    -Name "Validação final" `
    -File (Join-Path $Root "sql\tests\501_validate_portfolio.sql")

Write-Host ""
Write-Host "Instalação concluída."
