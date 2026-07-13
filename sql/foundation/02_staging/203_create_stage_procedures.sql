USE margem_em_risco;
GO

CREATE OR ALTER PROCEDURE etl.usp_stage_contract_batch
    @batch_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @reference_period DATE =
    (
        SELECT reference_period
        FROM etl.batch_control
        WHERE batch_id = @batch_id
    );

    DELETE FROM staging.stg_contract WHERE batch_id = @batch_id;
    DELETE FROM etl.rejected_record
    WHERE batch_id = @batch_id
      AND source_table = 'raw.contract_register';

    SELECT
        source_row.raw_contract_id,
        source_row.batch_id,
        source_row.source_row_number,
        NULLIF(UPPER(LTRIM(RTRIM(source_row.contract_code))), '') AS contract_code,
        NULLIF(UPPER(LTRIM(RTRIM(source_row.client_code))), '') AS client_code,
        NULLIF(LTRIM(RTRIM(source_row.client_name)), N'') AS client_name,
        NULLIF(UPPER(LTRIM(RTRIM(source_row.unit_code))), '') AS unit_code,
        NULLIF(UPPER(LTRIM(RTRIM(source_row.service_code))), '') AS service_code,
        NULLIF(UPPER(LTRIM(RTRIM(source_row.manager_code))), '') AS manager_code,
        CASE UPPER(LTRIM(RTRIM(source_row.contract_status))) COLLATE Latin1_General_100_CI_AI
            WHEN 'ATIVO' THEN 'ACTIVE'
            WHEN 'ACTIVE' THEN 'ACTIVE'
            WHEN 'INATIVO' THEN 'INACTIVE'
            WHEN 'INACTIVE' THEN 'INACTIVE'
            WHEN 'ENCERRADO' THEN 'CLOSED'
            WHEN 'CLOSED' THEN 'CLOSED'
        END AS contract_status,
        CASE UPPER(LTRIM(RTRIM(source_row.billing_model))) COLLATE Latin1_General_100_CI_AI
            WHEN 'MENSAL FIXO' THEN 'FIXED_MONTHLY'
            WHEN 'FIXED MONTHLY' THEN 'FIXED_MONTHLY'
            WHEN 'FIXED_MONTHLY' THEN 'FIXED_MONTHLY'
            WHEN 'POR POSTO' THEN 'POSITION_BASED'
            WHEN 'POSITION BASED' THEN 'POSITION_BASED'
            WHEN 'POSITION_BASED' THEN 'POSITION_BASED'
            WHEN 'POR HORA' THEN 'HOURLY'
            WHEN 'HOURLY' THEN 'HOURLY'
        END AS billing_model,
        CASE UPPER(LTRIM(RTRIM(source_row.complexity_level))) COLLATE Latin1_General_100_CI_AI
            WHEN 'BAIXA' THEN 'LOW'
            WHEN 'LOW' THEN 'LOW'
            WHEN 'MEDIA' THEN 'MEDIUM'
            WHEN 'MEDIUM' THEN 'MEDIUM'
            WHEN 'ALTA' THEN 'HIGH'
            WHEN 'HIGH' THEN 'HIGH'
        END AS complexity_level,
        etl.fn_parse_date_br(source_row.start_date) AS start_date,
        etl.fn_parse_date_br(source_row.end_date) AS end_date,
        etl.fn_parse_date_br(source_row.renewal_date) AS renewal_date,
        TRY_CONVERT(DECIMAL(18,2), etl.fn_parse_decimal_br(source_row.base_monthly_amount)) AS base_monthly_amount,
        TRY_CONVERT(DECIMAL(10,2), etl.fn_parse_decimal_br(source_row.contracted_positions)) AS contracted_positions,
        TRY_CONVERT(DECIMAL(18,2), etl.fn_parse_decimal_br(source_row.contracted_hours)) AS contracted_hours,
        etl.fn_parse_percent_br(source_row.target_margin_pct) AS target_margin_pct,
        TRY_CONVERT(TINYINT, etl.fn_parse_decimal_br(source_row.adjustment_base_month)) AS adjustment_base_month,
        NULLIF(UPPER(LTRIM(RTRIM(source_row.adjustment_index))), '') AS adjustment_index,
        NULLIF(UPPER(LTRIM(RTRIM(source_row.state_code))), '') AS state_code,
        current_contract.contract_key AS existing_contract_key,
        client.client_key,
        unit.unit_key,
        service.service_key,
        manager.manager_key,
        CASE
            WHEN current_contract.contract_key IS NULL
                THEN etl.fn_parse_date_br(source_row.start_date)
            ELSE COALESCE(@reference_period, etl.fn_parse_date_br(source_row.start_date))
        END AS valid_from
    INTO #parsed_contract
    FROM raw.contract_register AS source_row
    LEFT JOIN dw.dim_contract AS current_contract
        ON current_contract.contract_code = UPPER(LTRIM(RTRIM(source_row.contract_code)))
       AND current_contract.is_current = 1
    LEFT JOIN dw.dim_client AS client
        ON client.client_code = UPPER(LTRIM(RTRIM(source_row.client_code)))
    LEFT JOIN dw.dim_unit AS unit
        ON unit.unit_code = UPPER(LTRIM(RTRIM(source_row.unit_code)))
       AND unit.client_key = client.client_key
    LEFT JOIN dw.dim_service AS service
        ON service.service_code = UPPER(LTRIM(RTRIM(source_row.service_code)))
    LEFT JOIN dw.dim_manager AS manager
        ON manager.manager_code = UPPER(LTRIM(RTRIM(source_row.manager_code)))
    WHERE source_row.batch_id = @batch_id;

    INSERT INTO etl.rejected_record
    (
        batch_id,
        source_table,
        source_record_id,
        source_row_number,
        field_name,
        received_value,
        rejection_reason
    )
    SELECT
        @batch_id,
        'raw.contract_register',
        CONVERT(VARCHAR(100), raw_contract_id),
        source_row_number,
        NULL,
        contract_code,
        CONCAT_WS
        (
            '; ',
            CASE WHEN contract_code IS NULL THEN N'Código do contrato ausente' END,
            CASE WHEN client_code IS NULL OR client_key IS NULL THEN N'Cliente não encontrado' END,
            CASE WHEN client_name IS NULL THEN N'Nome do cliente ausente' END,
            CASE WHEN unit_code IS NULL OR unit_key IS NULL THEN N'Unidade não encontrada para o cliente' END,
            CASE WHEN service_code IS NULL OR service_key IS NULL THEN N'Serviço não cadastrado' END,
            CASE WHEN manager_code IS NULL OR manager_key IS NULL THEN N'Gestor não cadastrado' END,
            CASE WHEN contract_status IS NULL THEN N'Status do contrato inválido' END,
            CASE WHEN billing_model IS NULL THEN N'Modelo de cobrança inválido' END,
            CASE WHEN complexity_level IS NULL THEN N'Complexidade inválida' END,
            CASE WHEN start_date IS NULL THEN N'Data de início inválida' END,
            CASE WHEN end_date IS NOT NULL AND start_date IS NOT NULL AND end_date < start_date THEN N'Data final anterior à data inicial' END,
            CASE WHEN renewal_date IS NOT NULL AND start_date IS NOT NULL AND renewal_date < start_date THEN N'Data de renovação anterior à data inicial' END,
            CASE WHEN base_monthly_amount IS NULL OR base_monthly_amount <= 0 THEN N'Valor mensal inválido' END,
            CASE WHEN contracted_positions IS NULL OR contracted_positions < 0 THEN N'Quantidade de postos inválida' END,
            CASE WHEN contracted_hours IS NULL OR contracted_hours < 0 THEN N'Horas contratadas inválidas' END,
            CASE WHEN target_margin_pct IS NULL OR target_margin_pct NOT BETWEEN 0 AND 1 THEN N'Margem-alvo inválida' END,
            CASE WHEN adjustment_base_month IS NOT NULL AND adjustment_base_month NOT BETWEEN 1 AND 12 THEN N'Mês-base de reajuste inválido' END,
            CASE WHEN state_code IS NULL OR LEN(state_code) <> 2 THEN N'UF inválida' END,
            CASE WHEN valid_from IS NULL THEN N'Data de vigência da versão não definida' END
        )
    FROM #parsed_contract
    WHERE
        contract_code IS NULL
        OR client_code IS NULL OR client_key IS NULL
        OR client_name IS NULL
        OR unit_code IS NULL OR unit_key IS NULL
        OR service_code IS NULL OR service_key IS NULL
        OR manager_code IS NULL OR manager_key IS NULL
        OR contract_status IS NULL
        OR billing_model IS NULL
        OR complexity_level IS NULL
        OR start_date IS NULL
        OR (end_date IS NOT NULL AND end_date < start_date)
        OR (renewal_date IS NOT NULL AND renewal_date < start_date)
        OR base_monthly_amount IS NULL OR base_monthly_amount <= 0
        OR contracted_positions IS NULL OR contracted_positions < 0
        OR contracted_hours IS NULL OR contracted_hours < 0
        OR target_margin_pct IS NULL OR target_margin_pct NOT BETWEEN 0 AND 1
        OR (adjustment_base_month IS NOT NULL AND adjustment_base_month NOT BETWEEN 1 AND 12)
        OR state_code IS NULL OR LEN(state_code) <> 2
        OR valid_from IS NULL;

    INSERT INTO staging.stg_contract
    (
        raw_contract_id,
        batch_id,
        contract_code,
        client_code,
        client_name,
        unit_code,
        service_code,
        manager_code,
        contract_status,
        billing_model,
        complexity_level,
        start_date,
        end_date,
        renewal_date,
        base_monthly_amount,
        contracted_positions,
        contracted_hours,
        target_margin_pct,
        adjustment_base_month,
        adjustment_index,
        state_code,
        valid_from,
        row_hash,
        record_status
    )
    SELECT
        raw_contract_id,
        batch_id,
        contract_code,
        client_code,
        client_name,
        unit_code,
        service_code,
        manager_code,
        contract_status,
        billing_model,
        complexity_level,
        start_date,
        end_date,
        renewal_date,
        base_monthly_amount,
        contracted_positions,
        contracted_hours,
        target_margin_pct,
        adjustment_base_month,
        adjustment_index,
        state_code,
        valid_from,
        HASHBYTES
        (
            'SHA2_256',
            CONCAT_WS
            (
                '|',
                client_code,
                manager_code,
                service_code,
                contract_status,
                billing_model,
                complexity_level,
                CONVERT(CHAR(10), start_date, 23),
                CONVERT(CHAR(10), end_date, 23),
                CONVERT(CHAR(10), renewal_date, 23),
                CONVERT(VARCHAR(40), base_monthly_amount),
                CONVERT(VARCHAR(40), contracted_positions),
                CONVERT(VARCHAR(40), contracted_hours),
                CONVERT(VARCHAR(40), target_margin_pct),
                CONVERT(VARCHAR(10), adjustment_base_month),
                adjustment_index
            )
        ),
        'VALID'
    FROM #parsed_contract
    WHERE
        contract_code IS NOT NULL
        AND client_key IS NOT NULL
        AND client_name IS NOT NULL
        AND unit_key IS NOT NULL
        AND service_key IS NOT NULL
        AND manager_key IS NOT NULL
        AND contract_status IS NOT NULL
        AND billing_model IS NOT NULL
        AND complexity_level IS NOT NULL
        AND start_date IS NOT NULL
        AND (end_date IS NULL OR end_date >= start_date)
        AND (renewal_date IS NULL OR renewal_date >= start_date)
        AND base_monthly_amount > 0
        AND contracted_positions >= 0
        AND contracted_hours >= 0
        AND target_margin_pct BETWEEN 0 AND 1
        AND (adjustment_base_month IS NULL OR adjustment_base_month BETWEEN 1 AND 12)
        AND state_code IS NOT NULL
        AND LEN(state_code) = 2
        AND valid_from IS NOT NULL;
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_stage_measurement_batch
    @batch_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DELETE FROM staging.stg_measurement WHERE batch_id = @batch_id;
    DELETE FROM etl.rejected_record
    WHERE batch_id = @batch_id
      AND source_table = 'raw.monthly_measurements';

    SELECT
        source_row.raw_measurement_id,
        source_row.batch_id,
        source_row.source_row_number,
        NULLIF(UPPER(LTRIM(RTRIM(source_row.contract_code))), '') AS contract_code,
        etl.fn_parse_month_br(source_row.reference_period) AS reference_month,
        NULLIF(UPPER(LTRIM(RTRIM(source_row.measurement_number))), '') AS measurement_number,
        TRY_CONVERT(DECIMAL(18,2), etl.fn_parse_decimal_br(source_row.contracted_amount)) AS contracted_amount,
        TRY_CONVERT(DECIMAL(18,2), etl.fn_parse_decimal_br(source_row.additional_services)) AS additional_services,
        TRY_CONVERT(DECIMAL(18,2), etl.fn_parse_decimal_br(source_row.reimbursements)) AS reimbursements,
        TRY_CONVERT(DECIMAL(18,2), etl.fn_parse_decimal_br(source_row.commercial_discounts)) AS commercial_discounts,
        TRY_CONVERT(DECIMAL(18,2), etl.fn_parse_decimal_br(source_row.deductions)) AS deductions,
        TRY_CONVERT(DECIMAL(18,2), etl.fn_parse_decimal_br(source_row.penalties)) AS penalties,
        TRY_CONVERT(DECIMAL(18,2), etl.fn_parse_decimal_br(source_row.invoiced_amount)) AS invoiced_amount,
        TRY_CONVERT(DECIMAL(18,2), etl.fn_parse_decimal_br(source_row.received_amount)) AS received_amount,
        etl.fn_parse_date_br(source_row.invoice_date) AS invoice_date,
        etl.fn_parse_date_br(source_row.payment_date) AS payment_date,
        current_contract.contract_key,
        COUNT(*) OVER
        (
            PARTITION BY
                UPPER(LTRIM(RTRIM(source_row.contract_code))),
                etl.fn_parse_month_br(source_row.reference_period),
                UPPER(LTRIM(RTRIM(source_row.measurement_number)))
        ) AS duplicate_count
    INTO #parsed_measurement
    FROM raw.monthly_measurements AS source_row
    LEFT JOIN dw.dim_contract AS current_contract
        ON current_contract.contract_code = UPPER(LTRIM(RTRIM(source_row.contract_code)))
       AND current_contract.is_current = 1
    WHERE source_row.batch_id = @batch_id;

    INSERT INTO etl.rejected_record
    (
        batch_id,
        source_table,
        source_record_id,
        source_row_number,
        field_name,
        received_value,
        rejection_reason
    )
    SELECT
        @batch_id,
        'raw.monthly_measurements',
        CONVERT(VARCHAR(100), raw_measurement_id),
        source_row_number,
        NULL,
        measurement_number,
        CONCAT_WS
        (
            '; ',
            CASE WHEN contract_code IS NULL OR contract_key IS NULL THEN N'Contrato não encontrado' END,
            CASE WHEN reference_month IS NULL THEN N'Competência inválida' END,
            CASE WHEN measurement_number IS NULL THEN N'Número da medição ausente' END,
            CASE WHEN contracted_amount IS NULL OR contracted_amount < 0 THEN N'Valor contratado inválido' END,
            CASE WHEN additional_services IS NULL OR additional_services < 0 THEN N'Serviços adicionais inválidos' END,
            CASE WHEN reimbursements IS NULL OR reimbursements < 0 THEN N'Reembolsos inválidos' END,
            CASE WHEN commercial_discounts IS NULL OR commercial_discounts < 0 THEN N'Descontos inválidos' END,
            CASE WHEN deductions IS NULL OR deductions < 0 THEN N'Glosas inválidas' END,
            CASE WHEN penalties IS NULL OR penalties < 0 THEN N'Multas inválidas' END,
            CASE WHEN invoiced_amount IS NULL OR invoiced_amount < 0 THEN N'Valor faturado inválido' END,
            CASE WHEN received_amount IS NOT NULL AND received_amount < 0 THEN N'Valor recebido inválido' END,
            CASE WHEN payment_date IS NOT NULL AND invoice_date IS NULL THEN N'Data de pagamento sem data de emissão válida' END,
            CASE WHEN payment_date IS NOT NULL AND invoice_date IS NOT NULL AND payment_date < invoice_date THEN N'Pagamento anterior à emissão' END,
            CASE WHEN duplicate_count > 1 THEN N'Medição duplicada no arquivo' END
        )
    FROM #parsed_measurement
    WHERE
        contract_code IS NULL OR contract_key IS NULL
        OR reference_month IS NULL
        OR measurement_number IS NULL
        OR contracted_amount IS NULL OR contracted_amount < 0
        OR additional_services IS NULL OR additional_services < 0
        OR reimbursements IS NULL OR reimbursements < 0
        OR commercial_discounts IS NULL OR commercial_discounts < 0
        OR deductions IS NULL OR deductions < 0
        OR penalties IS NULL OR penalties < 0
        OR invoiced_amount IS NULL OR invoiced_amount < 0
        OR (received_amount IS NOT NULL AND received_amount < 0)
        OR (payment_date IS NOT NULL AND invoice_date IS NULL)
        OR (payment_date IS NOT NULL AND invoice_date IS NOT NULL AND payment_date < invoice_date)
        OR duplicate_count > 1;

    INSERT INTO staging.stg_measurement
    (
        raw_measurement_id,
        batch_id,
        contract_code,
        reference_month,
        measurement_number,
        contracted_amount,
        additional_services,
        reimbursements,
        commercial_discounts,
        deductions,
        penalties,
        invoiced_amount,
        received_amount,
        invoice_date,
        payment_date,
        record_status
    )
    SELECT
        raw_measurement_id,
        batch_id,
        contract_code,
        reference_month,
        measurement_number,
        contracted_amount,
        additional_services,
        reimbursements,
        commercial_discounts,
        deductions,
        penalties,
        invoiced_amount,
        received_amount,
        invoice_date,
        payment_date,
        'VALID'
    FROM #parsed_measurement
    WHERE
        contract_key IS NOT NULL
        AND reference_month IS NOT NULL
        AND measurement_number IS NOT NULL
        AND contracted_amount >= 0
        AND additional_services >= 0
        AND reimbursements >= 0
        AND commercial_discounts >= 0
        AND deductions >= 0
        AND penalties >= 0
        AND invoiced_amount >= 0
        AND (received_amount IS NULL OR received_amount >= 0)
        AND (payment_date IS NULL OR (invoice_date IS NOT NULL AND payment_date >= invoice_date))
        AND duplicate_count = 1;
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_stage_cost_batch
    @batch_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DELETE FROM staging.stg_cost WHERE batch_id = @batch_id;
    DELETE FROM etl.rejected_record
    WHERE batch_id = @batch_id
      AND source_table = 'raw.operational_costs';

    SELECT
        source_row.raw_cost_id,
        source_row.batch_id,
        source_row.source_row_number,
        NULLIF(UPPER(LTRIM(RTRIM(source_row.contract_code))), '') AS contract_code,
        NULLIF(UPPER(LTRIM(RTRIM(source_row.unit_code))), '') AS unit_code,
        etl.fn_parse_month_br(source_row.reference_period) AS reference_month,
        NULLIF(LTRIM(RTRIM(source_row.cost_group)), '') AS cost_group,
        NULLIF(LTRIM(RTRIM(source_row.cost_category)), '') AS cost_category,
        NULLIF(LTRIM(RTRIM(source_row.cost_subcategory)), '') AS cost_subcategory,
        TRY_CONVERT(DECIMAL(18,2), etl.fn_parse_decimal_br(source_row.actual_amount)) AS actual_amount,
        TRY_CONVERT(DECIMAL(18,2), etl.fn_parse_decimal_br(source_row.budget_amount)) AS budget_amount,
        NULLIF(UPPER(LTRIM(RTRIM(source_row.source_system))), '') AS source_system,
        etl.fn_parse_bit_pt(source_row.recurring_flag) AS is_recurring,
        etl.fn_parse_bit_pt(source_row.extraordinary_flag) AS is_extraordinary,
        etl.fn_parse_bit_pt(source_row.allocation_flag) AS is_allocation,
        CASE
            WHEN LEFT(UPPER(LTRIM(RTRIM(source_row.entry_type))), 1) = N'D'
                THEN 'DEBIT'
            WHEN LEFT(UPPER(LTRIM(RTRIM(source_row.entry_type))), 1) IN (N'E', N'R')
                THEN 'REVERSAL'
        END AS entry_type,
        contract.contract_key,
        unit.unit_key,
        category.cost_category_key
    INTO #parsed_cost
    FROM raw.operational_costs AS source_row
    LEFT JOIN dw.dim_contract AS contract
        ON contract.contract_code = UPPER(LTRIM(RTRIM(source_row.contract_code)))
       AND contract.is_current = 1
    LEFT JOIN dw.dim_unit AS unit
        ON unit.unit_code = UPPER(LTRIM(RTRIM(source_row.unit_code)))
       AND unit.client_key = contract.client_key
    LEFT JOIN dw.dim_cost_category AS category
        ON category.cost_group COLLATE Latin1_General_100_CI_AI =
           LTRIM(RTRIM(source_row.cost_group)) COLLATE Latin1_General_100_CI_AI
       AND category.cost_category COLLATE Latin1_General_100_CI_AI =
           LTRIM(RTRIM(source_row.cost_category)) COLLATE Latin1_General_100_CI_AI
       AND category.cost_subcategory COLLATE Latin1_General_100_CI_AI =
           LTRIM(RTRIM(source_row.cost_subcategory)) COLLATE Latin1_General_100_CI_AI
    WHERE source_row.batch_id = @batch_id;

    INSERT INTO etl.rejected_record
    (
        batch_id,
        source_table,
        source_record_id,
        source_row_number,
        field_name,
        received_value,
        rejection_reason
    )
    SELECT
        @batch_id,
        'raw.operational_costs',
        CONVERT(VARCHAR(100), raw_cost_id),
        source_row_number,
        NULL,
        contract_code,
        CONCAT_WS
        (
            '; ',
            CASE WHEN contract_key IS NULL THEN N'Contrato não encontrado' END,
            CASE WHEN unit_key IS NULL THEN N'Unidade não encontrada para o contrato' END,
            CASE WHEN reference_month IS NULL THEN N'Competência inválida' END,
            CASE WHEN cost_category_key IS NULL THEN N'Categoria de custo não cadastrada' END,
            CASE WHEN actual_amount IS NULL THEN N'Valor realizado inválido' END,
            CASE WHEN budget_amount IS NULL THEN N'Valor orçado inválido' END,
            CASE WHEN source_system IS NULL THEN N'Origem do lançamento ausente' END,
            CASE WHEN is_recurring IS NULL THEN N'Indicador de recorrência inválido' END,
            CASE WHEN is_extraordinary IS NULL THEN N'Indicador de custo extraordinário inválido' END,
            CASE WHEN is_allocation IS NULL THEN N'Indicador de rateio inválido' END,
            CASE WHEN entry_type IS NULL THEN N'Tipo de lançamento inválido' END,
            CASE WHEN entry_type = 'DEBIT' AND actual_amount < 0 THEN N'Débito com valor negativo' END,
            CASE WHEN entry_type = 'REVERSAL' AND actual_amount > 0 THEN N'Estorno com valor positivo' END
        )
    FROM #parsed_cost
    WHERE
        contract_key IS NULL
        OR unit_key IS NULL
        OR reference_month IS NULL
        OR cost_category_key IS NULL
        OR actual_amount IS NULL
        OR budget_amount IS NULL
        OR source_system IS NULL
        OR is_recurring IS NULL
        OR is_extraordinary IS NULL
        OR is_allocation IS NULL
        OR entry_type IS NULL
        OR (entry_type = 'DEBIT' AND actual_amount < 0)
        OR (entry_type = 'REVERSAL' AND actual_amount > 0);

    INSERT INTO staging.stg_cost
    (
        raw_cost_id,
        batch_id,
        contract_code,
        unit_code,
        reference_month,
        cost_group,
        cost_category,
        cost_subcategory,
        actual_amount,
        budget_amount,
        source_system,
        is_recurring,
        is_extraordinary,
        is_allocation,
        entry_type,
        record_status
    )
    SELECT
        raw_cost_id,
        batch_id,
        contract_code,
        unit_code,
        reference_month,
        cost_group,
        cost_category,
        cost_subcategory,
        actual_amount,
        budget_amount,
        source_system,
        is_recurring,
        is_extraordinary,
        is_allocation,
        entry_type,
        'VALID'
    FROM #parsed_cost
    WHERE
        contract_key IS NOT NULL
        AND unit_key IS NOT NULL
        AND reference_month IS NOT NULL
        AND cost_category_key IS NOT NULL
        AND actual_amount IS NOT NULL
        AND budget_amount IS NOT NULL
        AND source_system IS NOT NULL
        AND is_recurring IS NOT NULL
        AND is_extraordinary IS NOT NULL
        AND is_allocation IS NOT NULL
        AND entry_type IS NOT NULL
        AND
        (
            (entry_type = 'DEBIT' AND actual_amount >= 0)
            OR (entry_type = 'REVERSAL' AND actual_amount <= 0)
        );
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_stage_operation_batch
    @batch_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DELETE FROM staging.stg_operation WHERE batch_id = @batch_id;
    DELETE FROM etl.rejected_record
    WHERE batch_id = @batch_id
      AND source_table = 'raw.workforce_control';

    SELECT
        source_row.raw_operation_id,
        source_row.batch_id,
        source_row.source_row_number,
        NULLIF(UPPER(LTRIM(RTRIM(source_row.contract_code))), '') AS contract_code,
        NULLIF(UPPER(LTRIM(RTRIM(source_row.unit_code))), '') AS unit_code,
        NULLIF(UPPER(LTRIM(RTRIM(source_row.role_code))), '') AS role_code,
        etl.fn_parse_month_br(source_row.reference_period) AS reference_month,
        TRY_CONVERT(DECIMAL(10,2), etl.fn_parse_decimal_br(source_row.planned_positions)) AS planned_positions,
        TRY_CONVERT(DECIMAL(10,2), etl.fn_parse_decimal_br(source_row.filled_positions)) AS filled_positions,
        TRY_CONVERT(DECIMAL(10,2), etl.fn_parse_decimal_br(source_row.average_headcount)) AS average_headcount,
        TRY_CONVERT(DECIMAL(18,2), etl.fn_parse_decimal_br(source_row.planned_hours)) AS planned_hours,
        TRY_CONVERT(DECIMAL(18,2), etl.fn_parse_decimal_br(source_row.regular_hours)) AS regular_hours,
        TRY_CONVERT(DECIMAL(18,2), etl.fn_parse_decimal_br(source_row.overtime_hours)) AS overtime_hours,
        TRY_CONVERT(DECIMAL(18,2), etl.fn_parse_decimal_br(source_row.absence_hours)) AS absence_hours,
        TRY_CONVERT(INT, etl.fn_parse_decimal_br(source_row.leave_days)) AS leave_days,
        TRY_CONVERT(INT, etl.fn_parse_decimal_br(source_row.hires)) AS hires,
        TRY_CONVERT(INT, etl.fn_parse_decimal_br(source_row.terminations)) AS terminations,
        TRY_CONVERT(INT, etl.fn_parse_decimal_br(source_row.open_positions)) AS open_positions,
        TRY_CONVERT(DECIMAL(10,2), etl.fn_parse_decimal_br(source_row.average_replacement_days)) AS average_replacement_days,
        TRY_CONVERT(DECIMAL(18,2), etl.fn_parse_decimal_br(source_row.emergency_coverage_cost)) AS emergency_coverage_cost,
        contract.contract_key,
        unit.unit_key,
        role.role_key,
        COUNT(*) OVER
        (
            PARTITION BY
                UPPER(LTRIM(RTRIM(source_row.contract_code))),
                UPPER(LTRIM(RTRIM(source_row.unit_code))),
                UPPER(LTRIM(RTRIM(source_row.role_code))),
                etl.fn_parse_month_br(source_row.reference_period)
        ) AS duplicate_count
    INTO #parsed_operation
    FROM raw.workforce_control AS source_row
    LEFT JOIN dw.dim_contract AS contract
        ON contract.contract_code = UPPER(LTRIM(RTRIM(source_row.contract_code)))
       AND contract.is_current = 1
    LEFT JOIN dw.dim_unit AS unit
        ON unit.unit_code = UPPER(LTRIM(RTRIM(source_row.unit_code)))
       AND unit.client_key = contract.client_key
    LEFT JOIN dw.dim_role AS role
        ON role.role_code = UPPER(LTRIM(RTRIM(source_row.role_code)))
    WHERE source_row.batch_id = @batch_id;

    INSERT INTO etl.rejected_record
    (
        batch_id,
        source_table,
        source_record_id,
        source_row_number,
        field_name,
        received_value,
        rejection_reason
    )
    SELECT
        @batch_id,
        'raw.workforce_control',
        CONVERT(VARCHAR(100), raw_operation_id),
        source_row_number,
        NULL,
        contract_code,
        CONCAT_WS
        (
            '; ',
            CASE WHEN contract_key IS NULL THEN N'Contrato não encontrado' END,
            CASE WHEN unit_key IS NULL THEN N'Unidade não encontrada para o contrato' END,
            CASE WHEN role_key IS NULL THEN N'Função não cadastrada' END,
            CASE WHEN reference_month IS NULL THEN N'Competência inválida' END,
            CASE WHEN planned_positions IS NULL OR planned_positions < 0 THEN N'Postos previstos inválidos' END,
            CASE WHEN filled_positions IS NULL OR filled_positions < 0 THEN N'Postos ocupados inválidos' END,
            CASE WHEN average_headcount IS NULL OR average_headcount < 0 THEN N'Headcount médio inválido' END,
            CASE WHEN planned_hours IS NULL OR planned_hours < 0 THEN N'Horas previstas inválidas' END,
            CASE WHEN regular_hours IS NULL OR regular_hours < 0 THEN N'Horas regulares inválidas' END,
            CASE WHEN overtime_hours IS NULL OR overtime_hours < 0 THEN N'Horas adicionais inválidas' END,
            CASE WHEN absence_hours IS NULL OR absence_hours < 0 THEN N'Horas de ausência inválidas' END,
            CASE WHEN leave_days IS NULL OR leave_days < 0 THEN N'Dias de afastamento inválidos' END,
            CASE WHEN hires IS NULL OR hires < 0 THEN N'Admissões inválidas' END,
            CASE WHEN terminations IS NULL OR terminations < 0 THEN N'Desligamentos inválidos' END,
            CASE WHEN open_positions IS NULL OR open_positions < 0 THEN N'Vagas abertas inválidas' END,
            CASE WHEN average_replacement_days IS NULL OR average_replacement_days < 0 THEN N'Tempo de reposição inválido' END,
            CASE WHEN emergency_coverage_cost IS NULL OR emergency_coverage_cost < 0 THEN N'Custo de cobertura inválido' END,
            CASE WHEN duplicate_count > 1 THEN N'Registro operacional duplicado no arquivo' END
        )
    FROM #parsed_operation
    WHERE
        contract_key IS NULL
        OR unit_key IS NULL
        OR role_key IS NULL
        OR reference_month IS NULL
        OR planned_positions IS NULL OR planned_positions < 0
        OR filled_positions IS NULL OR filled_positions < 0
        OR average_headcount IS NULL OR average_headcount < 0
        OR planned_hours IS NULL OR planned_hours < 0
        OR regular_hours IS NULL OR regular_hours < 0
        OR overtime_hours IS NULL OR overtime_hours < 0
        OR absence_hours IS NULL OR absence_hours < 0
        OR leave_days IS NULL OR leave_days < 0
        OR hires IS NULL OR hires < 0
        OR terminations IS NULL OR terminations < 0
        OR open_positions IS NULL OR open_positions < 0
        OR average_replacement_days IS NULL OR average_replacement_days < 0
        OR emergency_coverage_cost IS NULL OR emergency_coverage_cost < 0
        OR duplicate_count > 1;

    INSERT INTO staging.stg_operation
    (
        raw_operation_id,
        batch_id,
        contract_code,
        unit_code,
        role_code,
        reference_month,
        planned_positions,
        filled_positions,
        average_headcount,
        planned_hours,
        regular_hours,
        overtime_hours,
        absence_hours,
        leave_days,
        hires,
        terminations,
        open_positions,
        average_replacement_days,
        emergency_coverage_cost,
        record_status
    )
    SELECT
        raw_operation_id,
        batch_id,
        contract_code,
        unit_code,
        role_code,
        reference_month,
        planned_positions,
        filled_positions,
        average_headcount,
        planned_hours,
        regular_hours,
        overtime_hours,
        absence_hours,
        leave_days,
        hires,
        terminations,
        open_positions,
        average_replacement_days,
        emergency_coverage_cost,
        'VALID'
    FROM #parsed_operation
    WHERE
        contract_key IS NOT NULL
        AND unit_key IS NOT NULL
        AND role_key IS NOT NULL
        AND reference_month IS NOT NULL
        AND planned_positions >= 0
        AND filled_positions >= 0
        AND average_headcount >= 0
        AND planned_hours >= 0
        AND regular_hours >= 0
        AND overtime_hours >= 0
        AND absence_hours >= 0
        AND leave_days >= 0
        AND hires >= 0
        AND terminations >= 0
        AND open_positions >= 0
        AND average_replacement_days >= 0
        AND emergency_coverage_cost >= 0
        AND duplicate_count = 1;
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_stage_sla_batch
    @batch_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DELETE FROM staging.stg_sla_incident WHERE batch_id = @batch_id;
    DELETE FROM etl.rejected_record
    WHERE batch_id = @batch_id
      AND source_table = 'raw.sla_incidents';

    SELECT
        source_row.raw_incident_id,
        source_row.batch_id,
        source_row.source_row_number,
        NULLIF(UPPER(LTRIM(RTRIM(source_row.incident_number))), '') AS incident_number,
        NULLIF(UPPER(LTRIM(RTRIM(source_row.contract_code))), '') AS contract_code,
        NULLIF(UPPER(LTRIM(RTRIM(source_row.unit_code))), '') AS unit_code,
        NULLIF(LTRIM(RTRIM(source_row.incident_category)), '') AS incident_category,
        NULLIF(LTRIM(RTRIM(source_row.incident_subcategory)), '') AS incident_subcategory,
        NULLIF(LTRIM(RTRIM(source_row.root_cause)), '') AS root_cause,
        etl.fn_parse_datetime_br(source_row.opened_at) AS opened_at,
        etl.fn_parse_datetime_br(source_row.closed_at) AS closed_at,
        TRY_CONVERT(DECIMAL(10,2), etl.fn_parse_decimal_br(source_row.agreed_deadline_hours)) AS agreed_deadline_hours,
        CASE UPPER(LTRIM(RTRIM(source_row.severity))) COLLATE Latin1_General_100_CI_AI
            WHEN 'BAIXA' THEN 'LOW'
            WHEN 'LOW' THEN 'LOW'
            WHEN 'MEDIA' THEN 'MEDIUM'
            WHEN 'MEDIUM' THEN 'MEDIUM'
            WHEN 'ALTA' THEN 'HIGH'
            WHEN 'HIGH' THEN 'HIGH'
            WHEN 'CRITICA' THEN 'CRITICAL'
            WHEN 'CRITICAL' THEN 'CRITICAL'
        END AS severity,
        CASE UPPER(LTRIM(RTRIM(source_row.incident_status))) COLLATE Latin1_General_100_CI_AI
            WHEN 'ABERTA' THEN 'OPEN'
            WHEN 'OPEN' THEN 'OPEN'
            WHEN 'EM ANDAMENTO' THEN 'IN_PROGRESS'
            WHEN 'IN_PROGRESS' THEN 'IN_PROGRESS'
            WHEN 'FECHADA' THEN 'CLOSED'
            WHEN 'CLOSED' THEN 'CLOSED'
            WHEN 'CANCELADA' THEN 'CANCELLED'
            WHEN 'CANCELLED' THEN 'CANCELLED'
        END AS incident_status,
        etl.fn_parse_bit_pt(source_row.recurrence_flag) AS is_recurrence,
        TRY_CONVERT(DECIMAL(18,2), etl.fn_parse_decimal_br(source_row.deduction_amount)) AS deduction_amount,
        TRY_CONVERT(DECIMAL(18,2), etl.fn_parse_decimal_br(source_row.penalty_amount)) AS penalty_amount,
        TRY_CONVERT(DECIMAL(18,2), etl.fn_parse_decimal_br(source_row.emergency_cost)) AS emergency_cost,
        contract.contract_key,
        unit.unit_key,
        incident_type.incident_type_key,
        COUNT(*) OVER (PARTITION BY UPPER(LTRIM(RTRIM(source_row.incident_number)))) AS duplicate_count
    INTO #parsed_sla
    FROM raw.sla_incidents AS source_row
    LEFT JOIN dw.dim_contract AS contract
        ON contract.contract_code = UPPER(LTRIM(RTRIM(source_row.contract_code)))
       AND contract.is_current = 1
    LEFT JOIN dw.dim_unit AS unit
        ON unit.unit_code = UPPER(LTRIM(RTRIM(source_row.unit_code)))
       AND unit.client_key = contract.client_key
    LEFT JOIN dw.dim_incident_type AS incident_type
        ON incident_type.incident_category COLLATE Latin1_General_100_CI_AI =
           LTRIM(RTRIM(source_row.incident_category)) COLLATE Latin1_General_100_CI_AI
       AND incident_type.incident_subcategory COLLATE Latin1_General_100_CI_AI =
           LTRIM(RTRIM(source_row.incident_subcategory)) COLLATE Latin1_General_100_CI_AI
       AND incident_type.root_cause COLLATE Latin1_General_100_CI_AI =
           LTRIM(RTRIM(source_row.root_cause)) COLLATE Latin1_General_100_CI_AI
    WHERE source_row.batch_id = @batch_id;

    INSERT INTO etl.rejected_record
    (
        batch_id,
        source_table,
        source_record_id,
        source_row_number,
        field_name,
        received_value,
        rejection_reason
    )
    SELECT
        @batch_id,
        'raw.sla_incidents',
        CONVERT(VARCHAR(100), raw_incident_id),
        source_row_number,
        NULL,
        incident_number,
        CONCAT_WS
        (
            '; ',
            CASE WHEN incident_number IS NULL THEN N'Número da ocorrência ausente' END,
            CASE WHEN contract_key IS NULL THEN N'Contrato não encontrado' END,
            CASE WHEN unit_key IS NULL THEN N'Unidade não encontrada para o contrato' END,
            CASE WHEN incident_type_key IS NULL THEN N'Tipo de ocorrência não cadastrado' END,
            CASE WHEN opened_at IS NULL THEN N'Data de abertura inválida' END,
            CASE WHEN closed_at IS NOT NULL AND opened_at IS NOT NULL AND closed_at < opened_at THEN N'Encerramento anterior à abertura' END,
            CASE WHEN agreed_deadline_hours IS NULL OR agreed_deadline_hours < 0 THEN N'Prazo de SLA inválido' END,
            CASE WHEN severity IS NULL THEN N'Gravidade inválida' END,
            CASE WHEN incident_status IS NULL THEN N'Status da ocorrência inválido' END,
            CASE WHEN incident_status = 'CLOSED' AND closed_at IS NULL THEN N'Ocorrência fechada sem data de encerramento' END,
            CASE WHEN is_recurrence IS NULL THEN N'Indicador de reincidência inválido' END,
            CASE WHEN deduction_amount IS NULL OR deduction_amount < 0 THEN N'Glosa inválida' END,
            CASE WHEN penalty_amount IS NULL OR penalty_amount < 0 THEN N'Multa inválida' END,
            CASE WHEN emergency_cost IS NULL OR emergency_cost < 0 THEN N'Custo emergencial inválido' END,
            CASE WHEN duplicate_count > 1 THEN N'Ocorrência duplicada no arquivo' END
        )
    FROM #parsed_sla
    WHERE
        incident_number IS NULL
        OR contract_key IS NULL
        OR unit_key IS NULL
        OR incident_type_key IS NULL
        OR opened_at IS NULL
        OR (closed_at IS NOT NULL AND closed_at < opened_at)
        OR agreed_deadline_hours IS NULL OR agreed_deadline_hours < 0
        OR severity IS NULL
        OR incident_status IS NULL
        OR (incident_status = 'CLOSED' AND closed_at IS NULL)
        OR is_recurrence IS NULL
        OR deduction_amount IS NULL OR deduction_amount < 0
        OR penalty_amount IS NULL OR penalty_amount < 0
        OR emergency_cost IS NULL OR emergency_cost < 0
        OR duplicate_count > 1;

    INSERT INTO staging.stg_sla_incident
    (
        raw_incident_id,
        batch_id,
        incident_number,
        contract_code,
        unit_code,
        incident_category,
        incident_subcategory,
        root_cause,
        opened_at,
        closed_at,
        agreed_deadline_hours,
        severity,
        incident_status,
        is_recurrence,
        deduction_amount,
        penalty_amount,
        emergency_cost,
        record_status
    )
    SELECT
        raw_incident_id,
        batch_id,
        incident_number,
        contract_code,
        unit_code,
        incident_category,
        incident_subcategory,
        root_cause,
        opened_at,
        closed_at,
        agreed_deadline_hours,
        severity,
        incident_status,
        is_recurrence,
        deduction_amount,
        penalty_amount,
        emergency_cost,
        'VALID'
    FROM #parsed_sla
    WHERE
        incident_number IS NOT NULL
        AND contract_key IS NOT NULL
        AND unit_key IS NOT NULL
        AND incident_type_key IS NOT NULL
        AND opened_at IS NOT NULL
        AND (closed_at IS NULL OR closed_at >= opened_at)
        AND agreed_deadline_hours >= 0
        AND severity IS NOT NULL
        AND incident_status IS NOT NULL
        AND (incident_status <> 'CLOSED' OR closed_at IS NOT NULL)
        AND is_recurrence IS NOT NULL
        AND deduction_amount >= 0
        AND penalty_amount >= 0
        AND emergency_cost >= 0
        AND duplicate_count = 1;
END;
GO

CREATE OR ALTER PROCEDURE etl.usp_stage_adjustment_batch
    @batch_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DELETE FROM staging.stg_adjustment WHERE batch_id = @batch_id;
    DELETE FROM etl.rejected_record
    WHERE batch_id = @batch_id
      AND source_table = 'raw.contract_adjustments';

    SELECT
        source_row.raw_adjustment_id,
        source_row.batch_id,
        source_row.source_row_number,
        NULLIF(UPPER(LTRIM(RTRIM(source_row.adjustment_number))), '') AS adjustment_number,
        NULLIF(UPPER(LTRIM(RTRIM(source_row.contract_code))), '') AS contract_code,
        CASE UPPER(LTRIM(RTRIM(source_row.process_type))) COLLATE Latin1_General_100_CI_AI
            WHEN 'REAJUSTE' THEN 'ADJUSTMENT'
            WHEN 'ADJUSTMENT' THEN 'ADJUSTMENT'
            WHEN 'REPACTUACAO' THEN 'REPACTUATION'
            WHEN 'REPACTUATION' THEN 'REPACTUATION'
            WHEN 'RENEGOCIACAO' THEN 'RENEGOTIATION'
            WHEN 'RENEGOTIATION' THEN 'RENEGOTIATION'
        END AS process_type,
        etl.fn_parse_date_br(source_row.expected_date) AS expected_date,
        etl.fn_parse_date_br(source_row.requested_date) AS requested_date,
        etl.fn_parse_date_br(source_row.approved_date) AS approved_date,
        etl.fn_parse_percent_br(source_row.requested_pct) AS requested_pct,
        etl.fn_parse_percent_br(source_row.approved_pct) AS approved_pct,
        TRY_CONVERT(DECIMAL(18,2), etl.fn_parse_decimal_br(source_row.previous_amount)) AS previous_amount,
        TRY_CONVERT(DECIMAL(18,2), etl.fn_parse_decimal_br(source_row.approved_amount)) AS approved_amount,
        etl.fn_parse_bit_pt(source_row.retroactive_flag) AS is_retroactive,
        TRY_CONVERT(DECIMAL(18,2), etl.fn_parse_decimal_br(source_row.retroactive_amount)) AS retroactive_amount,
        CASE UPPER(LTRIM(RTRIM(source_row.process_status))) COLLATE Latin1_General_100_CI_AI
            WHEN 'PENDENTE' THEN 'PENDING'
            WHEN 'PENDING' THEN 'PENDING'
            WHEN 'SOLICITADO' THEN 'REQUESTED'
            WHEN 'REQUESTED' THEN 'REQUESTED'
            WHEN 'APROVADO' THEN 'APPROVED'
            WHEN 'APPROVED' THEN 'APPROVED'
            WHEN 'REJEITADO' THEN 'REJECTED'
            WHEN 'REJECTED' THEN 'REJECTED'
            WHEN 'CANCELADO' THEN 'CANCELLED'
            WHEN 'CANCELLED' THEN 'CANCELLED'
        END AS process_status,
        NULLIF(LTRIM(RTRIM(source_row.pending_reason)), N'') AS pending_reason,
        contract.contract_key,
        COUNT(*) OVER (PARTITION BY UPPER(LTRIM(RTRIM(source_row.adjustment_number)))) AS duplicate_count
    INTO #parsed_adjustment
    FROM raw.contract_adjustments AS source_row
    LEFT JOIN dw.dim_contract AS contract
        ON contract.contract_code = UPPER(LTRIM(RTRIM(source_row.contract_code)))
       AND contract.is_current = 1
    WHERE source_row.batch_id = @batch_id;

    INSERT INTO etl.rejected_record
    (
        batch_id,
        source_table,
        source_record_id,
        source_row_number,
        field_name,
        received_value,
        rejection_reason
    )
    SELECT
        @batch_id,
        'raw.contract_adjustments',
        CONVERT(VARCHAR(100), raw_adjustment_id),
        source_row_number,
        NULL,
        adjustment_number,
        CONCAT_WS
        (
            '; ',
            CASE WHEN adjustment_number IS NULL THEN N'Número do processo ausente' END,
            CASE WHEN contract_key IS NULL THEN N'Contrato não encontrado' END,
            CASE WHEN process_type IS NULL THEN N'Tipo de processo inválido' END,
            CASE WHEN expected_date IS NULL THEN N'Data prevista inválida' END,
            CASE WHEN approved_date IS NOT NULL AND requested_date IS NOT NULL AND approved_date < requested_date THEN N'Aprovação anterior à solicitação' END,
            CASE WHEN requested_pct IS NOT NULL AND requested_pct NOT BETWEEN 0 AND 1 THEN N'Percentual solicitado inválido' END,
            CASE WHEN approved_pct IS NOT NULL AND approved_pct NOT BETWEEN 0 AND 1 THEN N'Percentual aprovado inválido' END,
            CASE WHEN previous_amount IS NULL OR previous_amount <= 0 THEN N'Valor anterior inválido' END,
            CASE WHEN approved_amount IS NOT NULL AND approved_amount <= 0 THEN N'Valor aprovado inválido' END,
            CASE WHEN is_retroactive IS NULL THEN N'Indicador de retroatividade inválido' END,
            CASE WHEN retroactive_amount IS NULL OR retroactive_amount < 0 THEN N'Valor retroativo inválido' END,
            CASE WHEN process_status IS NULL THEN N'Status do processo inválido' END,
            CASE WHEN process_status = 'APPROVED' AND approved_date IS NULL THEN N'Processo aprovado sem data de aprovação' END,
            CASE WHEN duplicate_count > 1 THEN N'Processo duplicado no arquivo' END
        )
    FROM #parsed_adjustment
    WHERE
        adjustment_number IS NULL
        OR contract_key IS NULL
        OR process_type IS NULL
        OR expected_date IS NULL
        OR (approved_date IS NOT NULL AND requested_date IS NOT NULL AND approved_date < requested_date)
        OR (requested_pct IS NOT NULL AND requested_pct NOT BETWEEN 0 AND 1)
        OR (approved_pct IS NOT NULL AND approved_pct NOT BETWEEN 0 AND 1)
        OR previous_amount IS NULL OR previous_amount <= 0
        OR (approved_amount IS NOT NULL AND approved_amount <= 0)
        OR is_retroactive IS NULL
        OR retroactive_amount IS NULL OR retroactive_amount < 0
        OR process_status IS NULL
        OR (process_status = 'APPROVED' AND approved_date IS NULL)
        OR duplicate_count > 1;

    INSERT INTO staging.stg_adjustment
    (
        raw_adjustment_id,
        batch_id,
        adjustment_number,
        contract_code,
        process_type,
        expected_date,
        requested_date,
        approved_date,
        requested_pct,
        approved_pct,
        previous_amount,
        approved_amount,
        is_retroactive,
        retroactive_amount,
        process_status,
        pending_reason,
        record_status
    )
    SELECT
        raw_adjustment_id,
        batch_id,
        adjustment_number,
        contract_code,
        process_type,
        expected_date,
        requested_date,
        approved_date,
        requested_pct,
        approved_pct,
        previous_amount,
        approved_amount,
        is_retroactive,
        retroactive_amount,
        process_status,
        pending_reason,
        'VALID'
    FROM #parsed_adjustment
    WHERE
        adjustment_number IS NOT NULL
        AND contract_key IS NOT NULL
        AND process_type IS NOT NULL
        AND expected_date IS NOT NULL
        AND (approved_date IS NULL OR requested_date IS NULL OR approved_date >= requested_date)
        AND (requested_pct IS NULL OR requested_pct BETWEEN 0 AND 1)
        AND (approved_pct IS NULL OR approved_pct BETWEEN 0 AND 1)
        AND previous_amount > 0
        AND (approved_amount IS NULL OR approved_amount > 0)
        AND is_retroactive IS NOT NULL
        AND retroactive_amount >= 0
        AND process_status IS NOT NULL
        AND (process_status <> 'APPROVED' OR approved_date IS NOT NULL)
        AND duplicate_count = 1;
END;
GO
