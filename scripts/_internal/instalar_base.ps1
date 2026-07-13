param
(
    [string]$ServerInstance = "localhost"
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$sqlRoot = Join-Path $projectRoot "sql\foundation"
$dataRoot = Join-Path $projectRoot "data\input\phase_02"
$connectionString = "Server=$ServerInstance;Database=margem_em_risco;Integrated Security=True;TrustServerCertificate=True;"

function Invoke-SqlFile
{
    param([Parameter(Mandatory = $true)][string]$FileName)

    Push-Location $sqlRoot
    try
    {
        & sqlcmd `
            -S $ServerInstance `
            -E `
            -C `
            -I `
            -f 65001 `
            -b `
            -r 1 `
            -i $FileName

        if ($LASTEXITCODE -ne 0)
        {
            throw "Falha ao executar $FileName"
        }
    }
    finally
    {
        Pop-Location
    }
}

function New-Batch
{
    param
    (
        [System.Data.SqlClient.SqlConnection]$Connection,
        [string]$SourceName,
        [string]$SourceFile,
        [datetime]$ReferencePeriod
    )

    $command = $Connection.CreateCommand()
    $command.CommandText = @"
INSERT INTO etl.batch_control
(
    source_name,
    source_file,
    reference_period,
    status,
    rows_received
)
OUTPUT INSERTED.batch_id
VALUES
(
    @source_name,
    @source_file,
    @reference_period,
    'RUNNING',
    0
);
"@

    $null = $command.Parameters.Add("@source_name", [System.Data.SqlDbType]::VarChar, 100)
    $null = $command.Parameters.Add("@source_file", [System.Data.SqlDbType]::VarChar, 255)
    $null = $command.Parameters.Add("@reference_period", [System.Data.SqlDbType]::Date)

    $command.Parameters["@source_name"].Value = $SourceName
    $command.Parameters["@source_file"].Value = $SourceFile
    $command.Parameters["@reference_period"].Value = $ReferencePeriod.Date

    return [int]$command.ExecuteScalar()
}

function Set-BatchFailed
{
    param
    (
        [System.Data.SqlClient.SqlConnection]$Connection,
        [int]$BatchId,
        [string]$Message
    )

    $command = $Connection.CreateCommand()
    $command.CommandText = @"
UPDATE etl.batch_control
SET
    status = 'FAILED',
    finished_at = SYSDATETIME(),
    error_message = @error_message
WHERE batch_id = @batch_id;
"@

    $null = $command.Parameters.Add("@batch_id", [System.Data.SqlDbType]::Int)
    $null = $command.Parameters.Add("@error_message", [System.Data.SqlDbType]::NVarChar, 2000)
    $command.Parameters["@batch_id"].Value = $BatchId
    $command.Parameters["@error_message"].Value =
        $Message.Substring(0, [Math]::Min(2000, $Message.Length))
    $null = $command.ExecuteNonQuery()
}

function Import-RawCsv
{
    param
    (
        [string]$FileName,
        [string]$SourceName,
        [string]$DestinationTable,
        [string[]]$Columns,
        [datetime]$ReferencePeriod
    )

    $filePath = Join-Path $dataRoot $FileName
    if (-not (Test-Path $filePath))
    {
        throw "Arquivo nao encontrado: $filePath"
    }

    $rows = @(Import-Csv -Path $filePath -Delimiter ";" -Encoding UTF8)
    if ($rows.Count -eq 0)
    {
        throw "Arquivo vazio: $filePath"
    }

    $connection = New-Object System.Data.SqlClient.SqlConnection $connectionString
    $connection.Open()
    $batchId = 0
    $transaction = $null

    try
    {
        $batchId = New-Batch `
            -Connection $connection `
            -SourceName $SourceName `
            -SourceFile $FileName `
            -ReferencePeriod $ReferencePeriod

        $table = New-Object System.Data.DataTable
        $null = $table.Columns.Add("batch_id", [int])
        foreach ($columnName in $Columns)
        {
            $null = $table.Columns.Add($columnName, [string])
        }
        $null = $table.Columns.Add("source_row_number", [int])

        $rowNumber = 1
        foreach ($sourceRow in $rows)
        {
            $dataRow = $table.NewRow()
            $dataRow["batch_id"] = $batchId
            $dataRow["source_row_number"] = $rowNumber

            foreach ($columnName in $Columns)
            {
                $value = $sourceRow.$columnName
                if ([string]::IsNullOrWhiteSpace([string]$value))
                {
                    $dataRow[$columnName] = [DBNull]::Value
                }
                else
                {
                    $dataRow[$columnName] = [string]$value
                }
            }

            $table.Rows.Add($dataRow)
            $rowNumber++
        }

        $transaction = $connection.BeginTransaction()
        $bulkCopy = [System.Data.SqlClient.SqlBulkCopy]::new(
            $connection,
            [System.Data.SqlClient.SqlBulkCopyOptions]::KeepNulls,
            $transaction
        )

        $bulkCopy.DestinationTableName = $DestinationTable
        $bulkCopy.BatchSize = 5000
        $bulkCopy.BulkCopyTimeout = 120

        $null = $bulkCopy.ColumnMappings.Add("batch_id", "batch_id")
        foreach ($columnName in $Columns)
        {
            $null = $bulkCopy.ColumnMappings.Add($columnName, $columnName)
        }
        $null = $bulkCopy.ColumnMappings.Add("source_row_number", "source_row_number")

        $bulkCopy.WriteToServer($table)
        $bulkCopy.Close()

        $updateCommand = $connection.CreateCommand()
        $updateCommand.Transaction = $transaction
        $updateCommand.CommandText = @"
UPDATE etl.batch_control
SET rows_received = @rows_received
WHERE batch_id = @batch_id;
"@
        $null = $updateCommand.Parameters.Add("@rows_received", [System.Data.SqlDbType]::Int)
        $null = $updateCommand.Parameters.Add("@batch_id", [System.Data.SqlDbType]::Int)
        $updateCommand.Parameters["@rows_received"].Value = $rows.Count
        $updateCommand.Parameters["@batch_id"].Value = $batchId
        $null = $updateCommand.ExecuteNonQuery()

        $transaction.Commit()
        Write-Host ("Importado: {0} | lote {1} | {2} linhas" -f $FileName, $batchId, $rows.Count)
    }
    catch
    {
        if ($transaction -ne $null)
        {
            try { $transaction.Rollback() } catch {}
        }
        if ($batchId -gt 0)
        {
            Set-BatchFailed -Connection $connection -BatchId $batchId -Message $_.Exception.Message
        }
        throw
    }
    finally
    {
        if ($connection.State -eq [System.Data.ConnectionState]::Open)
        {
            $connection.Close()
        }
    }
}

Write-Host ""
Write-Host "Margem em Risco - instalacao limpa ate a Fase 03"
Write-Host "Servidor: $ServerInstance"
Write-Host "Projeto:  $projectRoot"
Write-Host ""
Write-Host "O banco margem_em_risco sera recriado."

Invoke-SqlFile -FileName ".\run_clean_prepare.sql"

$referencePeriod = [datetime]"2025-01-01"

$imports = @(
    @{
        FileName = "contract_register.csv"
        SourceName = "contract_register"
        DestinationTable = "raw.contract_register"
        Columns = @(
            "contract_code", "client_code", "client_name", "unit_code", "service_code",
            "manager_code", "contract_status", "billing_model", "complexity_level",
            "start_date", "end_date", "renewal_date", "base_monthly_amount",
            "contracted_positions", "contracted_hours", "target_margin_pct",
            "adjustment_base_month", "adjustment_index", "state_code"
        )
    },
    @{
        FileName = "monthly_measurements.csv"
        SourceName = "monthly_measurements"
        DestinationTable = "raw.monthly_measurements"
        Columns = @(
            "contract_code", "reference_period", "measurement_number", "contracted_amount",
            "additional_services", "reimbursements", "commercial_discounts", "deductions",
            "penalties", "invoiced_amount", "received_amount", "invoice_date", "payment_date"
        )
    },
    @{
        FileName = "operational_costs.csv"
        SourceName = "operational_costs"
        DestinationTable = "raw.operational_costs"
        Columns = @(
            "contract_code", "unit_code", "reference_period", "cost_group", "cost_category",
            "cost_subcategory", "actual_amount", "budget_amount", "source_system",
            "recurring_flag", "extraordinary_flag", "allocation_flag", "entry_type"
        )
    },
    @{
        FileName = "workforce_control.csv"
        SourceName = "workforce_control"
        DestinationTable = "raw.workforce_control"
        Columns = @(
            "contract_code", "unit_code", "role_code", "reference_period", "planned_positions",
            "filled_positions", "average_headcount", "planned_hours", "regular_hours",
            "overtime_hours", "absence_hours", "leave_days", "hires", "terminations",
            "open_positions", "average_replacement_days", "emergency_coverage_cost"
        )
    },
    @{
        FileName = "sla_incidents.csv"
        SourceName = "sla_incidents"
        DestinationTable = "raw.sla_incidents"
        Columns = @(
            "incident_number", "contract_code", "unit_code", "incident_category",
            "incident_subcategory", "root_cause", "opened_at", "closed_at",
            "agreed_deadline_hours", "severity", "incident_status", "recurrence_flag",
            "deduction_amount", "penalty_amount", "emergency_cost"
        )
    },
    @{
        FileName = "contract_adjustments.csv"
        SourceName = "contract_adjustments"
        DestinationTable = "raw.contract_adjustments"
        Columns = @(
            "adjustment_number", "contract_code", "process_type", "expected_date",
            "requested_date", "approved_date", "requested_pct", "approved_pct",
            "previous_amount", "approved_amount", "retroactive_flag",
            "retroactive_amount", "process_status", "pending_reason"
        )
    }
)

foreach ($import in $imports)
{
    Import-RawCsv `
        -FileName $import.FileName `
        -SourceName $import.SourceName `
        -DestinationTable $import.DestinationTable `
        -Columns $import.Columns `
        -ReferencePeriod $referencePeriod
}

Invoke-SqlFile -FileName ".\run_clean_process_to_phase03.sql"

Write-Host ""
Write-Host "Instalacao concluida ate a Fase 03."
