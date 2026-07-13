USE margem_em_risco;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

CREATE OR ALTER PROCEDURE seed.usp_rebuild_history_facts
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF (SELECT COUNT(*) FROM seed.contract_month_plan) <> 240
        THROW 51620, N'Execute primeiro seed.usp_build_contract_month_plan.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM dw.fact_management_action;
        DELETE FROM dw.fact_adjustment;
        DELETE FROM dw.fact_sla;
        DELETE FROM dw.fact_operation;
        DELETE FROM dw.fact_contract_cost;
        DELETE FROM dw.fact_revenue;

        DECLARE @old_phase04_batches TABLE
        (
            batch_id INT PRIMARY KEY
        );

        INSERT INTO @old_phase04_batches(batch_id)
        SELECT batch_id
        FROM etl.batch_control
        WHERE source_name LIKE 'phase04_%';

        DELETE test_result
        FROM etl.test_result AS test_result
        INNER JOIN @old_phase04_batches AS old_batch
            ON old_batch.batch_id = test_result.batch_id;

        DELETE rejected_record
        FROM etl.rejected_record AS rejected_record
        INNER JOIN @old_phase04_batches AS old_batch
            ON old_batch.batch_id = rejected_record.batch_id;

        DELETE batch_control
        FROM etl.batch_control AS batch_control
        INNER JOIN @old_phase04_batches AS old_batch
            ON old_batch.batch_id = batch_control.batch_id;

        UPDATE contract
        SET
            end_date = NULL,
            renewal_date =
                CASE contract.contract_code
                    WHEN 'CT-001' THEN CONVERT(DATE, '2027-12-31')
                    WHEN 'CT-002' THEN CONVERT(DATE, '2027-02-14')
                    WHEN 'CT-003' THEN CONVERT(DATE, '2027-06-30')
                    WHEN 'CT-004' THEN CONVERT(DATE, '2027-03-31')
                    WHEN 'CT-005' THEN CONVERT(DATE, '2026-09-09')
                    WHEN 'CT-006' THEN CONVERT(DATE, '2026-10-31')
                    WHEN 'CT-007' THEN CONVERT(DATE, '2027-02-28')
                    WHEN 'CT-008' THEN CONVERT(DATE, '2026-08-31')
                    WHEN 'CT-009' THEN CONVERT(DATE, '2027-04-30')
                    WHEN 'CT-010' THEN CONVERT(DATE, '2026-12-31')
                END,
            base_monthly_amount =
                CASE contract.contract_code
                    WHEN 'CT-001' THEN 606100.00
                    WHEN 'CT-002' THEN 219000.00
                    WHEN 'CT-003' THEN 320000.00
                    WHEN 'CT-004' THEN 480700.00
                    WHEN 'CT-005' THEN 132000.00
                    WHEN 'CT-006' THEN 193325.00
                    WHEN 'CT-007' THEN 292000.00
                    WHEN 'CT-008' THEN 410000.00
                    WHEN 'CT-009' THEN 375000.00
                    WHEN 'CT-010' THEN 718000.00
                END,
            contracted_positions =
                CASE
                    WHEN contract.contract_code = 'CT-007'
                        THEN 33.00
                    ELSE contract.contracted_positions
                END,
            contracted_hours =
                CASE
                    WHEN contract.contract_code = 'CT-007'
                        THEN 7260.00
                    ELSE contract.contracted_hours
                END
        FROM dw.dim_contract AS contract
        WHERE contract.is_current = 1
          AND contract.contract_code BETWEEN 'CT-001' AND 'CT-010';

        UPDATE contract
        SET row_hash =
            HASHBYTES
            (
                'SHA2_256',
                CONCAT_WS
                (
                    '|',
                    client.client_code,
                    manager.manager_code,
                    service.service_code,
                    contract.contract_status,
                    contract.billing_model,
                    contract.complexity_level,
                    CONVERT(CHAR(10), contract.start_date, 23),
                    CONVERT(CHAR(10), contract.end_date, 23),
                    CONVERT(CHAR(10), contract.renewal_date, 23),
                    CONVERT(VARCHAR(40), contract.base_monthly_amount),
                    CONVERT(VARCHAR(40), contract.contracted_positions),
                    CONVERT(VARCHAR(40), contract.contracted_hours),
                    CONVERT(VARCHAR(40), contract.target_margin_pct),
                    CONVERT(VARCHAR(10), contract.adjustment_base_month),
                    contract.adjustment_index
                )
            )
        FROM dw.dim_contract AS contract
        INNER JOIN dw.dim_client AS client
            ON client.client_key = contract.client_key
        INNER JOIN dw.dim_manager AS manager
            ON manager.manager_key = contract.manager_key
        INNER JOIN dw.dim_service AS service
            ON service.service_key = contract.primary_service_key
        WHERE contract.is_current = 1
          AND contract.contract_code BETWEEN 'CT-001' AND 'CT-010';

        DECLARE @revenue_batch_id INT;
        DECLARE @cost_batch_id INT;
        DECLARE @operation_batch_id INT;
        DECLARE @sla_batch_id INT;
        DECLARE @adjustment_batch_id INT;
        DECLARE @action_batch_id INT;

        INSERT INTO etl.batch_control
        (
            source_name,
            source_file,
            reference_period,
            status,
            rows_received,
            rows_loaded,
            rows_rejected
        )
        VALUES
        ('phase04_revenue_history', 'seed.contract_month_plan', '2026-06-01', 'RUNNING', 240, 0, 0);
        SET @revenue_batch_id = CONVERT(INT, SCOPE_IDENTITY());

        INSERT INTO etl.batch_control
        (
            source_name,
            source_file,
            reference_period,
            status,
            rows_received,
            rows_loaded,
            rows_rejected
        )
        VALUES
        ('phase04_cost_history', 'seed.cost_template', '2026-06-01', 'RUNNING', 1345, 0, 0);
        SET @cost_batch_id = CONVERT(INT, SCOPE_IDENTITY());

        INSERT INTO etl.batch_control
        (
            source_name,
            source_file,
            reference_period,
            status,
            rows_received,
            rows_loaded,
            rows_rejected
        )
        VALUES
        ('phase04_operation_history', 'seed.operation_template', '2026-06-01', 'RUNNING', 504, 0, 0);
        SET @operation_batch_id = CONVERT(INT, SCOPE_IDENTITY());

        INSERT INTO etl.batch_control
        (
            source_name,
            source_file,
            reference_period,
            status,
            rows_received,
            rows_loaded,
            rows_rejected
        )
        SELECT
            'phase04_sla_history',
            'seed.contract_month_plan',
            '2026-06-01',
            'RUNNING',
            SUM(incident_count),
            0,
            0
        FROM seed.contract_month_plan;
        SET @sla_batch_id = CONVERT(INT, SCOPE_IDENTITY());

        INSERT INTO etl.batch_control
        (
            source_name,
            source_file,
            reference_period,
            status,
            rows_received,
            rows_loaded,
            rows_rejected
        )
        VALUES
        ('phase04_adjustment_history', 'scripted_business_events', '2026-06-01', 'RUNNING', 7, 0, 0);
        SET @adjustment_batch_id = CONVERT(INT, SCOPE_IDENTITY());

        INSERT INTO etl.batch_control
        (
            source_name,
            source_file,
            reference_period,
            status,
            rows_received,
            rows_loaded,
            rows_rejected
        )
        VALUES
        ('phase04_management_actions', 'scripted_business_events', '2026-06-01', 'RUNNING', 8, 0, 0);
        SET @action_batch_id = CONVERT(INT, SCOPE_IDENTITY());

        /* Receita mensal. */
        INSERT INTO dw.fact_revenue
        (
            date_key,
            contract_key,
            batch_id,
            measurement_number,
            contracted_amount,
            additional_services,
            reimbursements,
            commercial_discounts,
            deductions,
            penalties,
            gross_revenue,
            net_revenue,
            invoiced_amount,
            received_amount,
            invoice_date,
            payment_date,
            payment_days
        )
        SELECT
            date_dim.date_key,
            contract.contract_key,
            @revenue_batch_id,
            CONCAT('MED-HIST-', CONVERT(CHAR(6), month_plan.reference_month, 112), '-', month_plan.contract_code),
            month_plan.contracted_amount,
            month_plan.additional_services,
            month_plan.reimbursements,
            amount.commercial_discount,
            amount.deduction_amount,
            amount.penalty_amount,
            amount.gross_revenue,
            amount.net_revenue,
            amount.net_revenue,
            amount.net_revenue,
            EOMONTH(month_plan.reference_month),
            DATEADD
            (
                DAY,
                payment.payment_days,
                EOMONTH(month_plan.reference_month)
            ),
            payment.payment_days
        FROM seed.contract_month_plan AS month_plan
        INNER JOIN dw.dim_date AS date_dim
            ON date_dim.full_date = month_plan.reference_month
        INNER JOIN dw.dim_contract AS contract
            ON contract.contract_code = month_plan.contract_code
           AND contract.is_current = 1
        CROSS APPLY
        (
            SELECT
                CONVERT
                (
                    DECIMAL(18,2),
                    month_plan.contracted_amount
                    + month_plan.additional_services
                    + month_plan.reimbursements
                ) AS gross_revenue
        ) AS gross
        CROSS APPLY
        (
            SELECT
                gross.gross_revenue,
                CONVERT
                (
                    DECIMAL(18,2),
                    gross.gross_revenue * month_plan.commercial_discount_rate
                ) AS commercial_discount,
                CONVERT
                (
                    DECIMAL(18,2),
                    month_plan.sla_financial_loss * 0.4000
                ) AS deduction_amount
        ) AS split_amount
        CROSS APPLY
        (
            SELECT
                split_amount.gross_revenue,
                split_amount.commercial_discount,
                split_amount.deduction_amount,
                CONVERT
                (
                    DECIMAL(18,2),
                    month_plan.sla_financial_loss - split_amount.deduction_amount
                ) AS penalty_amount,
                CONVERT
                (
                    DECIMAL(18,2),
                    split_amount.gross_revenue
                    - split_amount.commercial_discount
                    - month_plan.sla_financial_loss
                ) AS net_revenue
        ) AS amount
        CROSS APPLY
        (
            SELECT
                24
                + (CONVERT(INT, RIGHT(month_plan.contract_code, 3)) % 18)
                AS payment_days
        ) AS payment;

        /* Custos por categoria. */
        INSERT INTO dw.fact_contract_cost
        (
            date_key,
            contract_key,
            unit_key,
            cost_category_key,
            batch_id,
            actual_amount,
            budget_amount,
            source_system,
            is_recurring,
            is_extraordinary,
            is_allocation,
            entry_type
        )
        SELECT
            date_dim.date_key,
            contract.contract_key,
            template.unit_key,
            template.cost_category_key,
            @cost_batch_id,
            cost_value.actual_amount,
            cost_value.budget_amount,
            template.source_system,
            template.is_recurring,
            template.is_extraordinary,
            template.is_allocation,
            'DEBIT'
        FROM seed.contract_month_plan AS month_plan
        INNER JOIN seed.cost_template AS template
            ON template.contract_code = month_plan.contract_code
        INNER JOIN dw.dim_date AS date_dim
            ON date_dim.full_date = month_plan.reference_month
        INNER JOIN dw.dim_contract AS contract
            ON contract.contract_code = month_plan.contract_code
           AND contract.is_current = 1
        INNER JOIN dw.dim_cost_category AS category
            ON category.cost_category_key = template.cost_category_key
        CROSS APPLY
        (
            SELECT
                CASE YEAR(month_plan.reference_month)
                    WHEN 2024 THEN CONVERT(DECIMAL(9,4), 0.9650)
                    WHEN 2025 THEN CONVERT(DECIMAL(9,4), 1.0000)
                    ELSE CONVERT(DECIMAL(9,4), 1.0450)
                END AS year_factor
        ) AS inflation
        CROSS APPLY
        (
            SELECT
                CONVERT
                (
                    DECIMAL(18,2),
                    template.baseline_budget_amount
                    * inflation.year_factor
                    * CASE
                        WHEN category.is_labor_cost = 1
                            THEN month_plan.position_factor
                        ELSE 1
                      END
                ) AS budget_amount,
                CASE
                    WHEN category.cost_subcategory = N'Horas adicionais'
                        THEN month_plan.overtime_factor
                    WHEN category.cost_subcategory = N'Cobertura emergencial'
                        THEN month_plan.coverage_factor
                    WHEN category.cost_subcategory IN
                        (N'Salários', N'Encargos sociais', N'Benefícios')
                        THEN month_plan.labor_factor
                    WHEN category.cost_category = N'Materiais'
                        THEN month_plan.material_factor
                    ELSE month_plan.other_cost_factor
                END AS category_factor
        ) AS budget
        CROSS APPLY
        (
            SELECT
                budget.budget_amount,
                CONVERT
                (
                    DECIMAL(18,2),
                    budget.budget_amount
                    * month_plan.base_cost_factor
                    * budget.category_factor
                ) AS actual_amount
        ) AS cost_value;

        INSERT INTO dw.fact_contract_cost
        (
            date_key,
            contract_key,
            unit_key,
            cost_category_key,
            batch_id,
            actual_amount,
            budget_amount,
            source_system,
            is_recurring,
            is_extraordinary,
            is_allocation,
            entry_type
        )
        SELECT
            date_dim.date_key,
            contract.contract_key,
            profile.unit_key,
            category.cost_category_key,
            @cost_batch_id,
            month_plan.one_time_extra_cost,
            0,
            'OPERACAO',
            0,
            1,
            0,
            'DEBIT'
        FROM seed.contract_month_plan AS month_plan
        INNER JOIN seed.contract_profile AS profile
            ON profile.contract_code = month_plan.contract_code
        INNER JOIN dw.dim_contract AS contract
            ON contract.contract_code = month_plan.contract_code
           AND contract.is_current = 1
        INNER JOIN dw.dim_date AS date_dim
            ON date_dim.full_date = month_plan.reference_month
        INNER JOIN dw.dim_cost_category AS category
            ON category.cost_subcategory = N'Manutenção de equipamentos'
        WHERE month_plan.one_time_extra_cost > 0;

        /* Operação por função. */
        INSERT INTO dw.fact_operation
        (
            date_key,
            contract_key,
            unit_key,
            role_key,
            batch_id,
            planned_positions,
            filled_positions,
            uncovered_positions,
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
            emergency_coverage_cost
        )
        SELECT
            date_dim.date_key,
            contract.contract_key,
            template.unit_key,
            template.role_key,
            @operation_batch_id,
            operation_value.planned_positions,
            operation_value.filled_positions,
            operation_value.planned_positions - operation_value.filled_positions,
            operation_value.filled_positions,
            operation_value.planned_hours,
            operation_value.regular_hours,
            CONVERT
            (
                DECIMAL(18,2),
                operation_value.regular_hours * month_plan.overtime_rate
            ),
            CONVERT
            (
                DECIMAL(18,2),
                operation_value.planned_hours * month_plan.absenteeism_rate
            ),
            CONVERT
            (
                INT,
                CEILING
                (
                    operation_value.planned_hours
                    * month_plan.absenteeism_rate
                    / 160.0
                )
            ),
            CONVERT
            (
                INT,
                CEILING(operation_value.planned_positions * month_plan.vacancy_rate * 0.5000)
            ),
            CONVERT
            (
                INT,
                CEILING(operation_value.planned_positions * month_plan.vacancy_rate * 0.4500)
            ),
            CONVERT
            (
                INT,
                CEILING(operation_value.planned_positions * month_plan.vacancy_rate)
            ),
            month_plan.replacement_days,
            CONVERT
            (
                DECIMAL(18,2),
                template.baseline_emergency_coverage_cost
                * CASE YEAR(month_plan.reference_month)
                    WHEN 2024 THEN 0.9650
                    WHEN 2025 THEN 1.0000
                    ELSE 1.0450
                  END
                * month_plan.coverage_factor
            )
        FROM seed.contract_month_plan AS month_plan
        INNER JOIN seed.operation_template AS template
            ON template.contract_code = month_plan.contract_code
        INNER JOIN dw.dim_date AS date_dim
            ON date_dim.full_date = month_plan.reference_month
        INNER JOIN dw.dim_contract AS contract
            ON contract.contract_code = month_plan.contract_code
           AND contract.is_current = 1
        CROSS APPLY
        (
            SELECT
                CONVERT
                (
                    DECIMAL(10,2),
                    template.baseline_planned_positions * month_plan.position_factor
                ) AS planned_positions,
                CONVERT
                (
                    DECIMAL(18,2),
                    template.baseline_planned_hours * month_plan.position_factor
                ) AS planned_hours
        ) AS planned
        CROSS APPLY
        (
            SELECT
                planned.planned_positions,
                planned.planned_hours,
                CONVERT
                (
                    DECIMAL(10,2),
                    planned.planned_positions * month_plan.coverage_rate
                ) AS filled_positions,
                CONVERT
                (
                    DECIMAL(18,2),
                    planned.planned_hours * (1 + month_plan.execution_overrun_rate)
                ) AS regular_hours
        ) AS operation_value;

        /* Ocorrências de SLA. */
        WITH incident_number AS
        (
            SELECT incident_sequence
            FROM
            (
                VALUES (1),(2),(3),(4),(5)
            ) AS sequence_list(incident_sequence)
        ),
        incident_source AS
        (
            SELECT
                month_plan.*,
                profile.unit_key,
                CASE
                    WHEN incident_number.incident_sequence % 2 = 1
                        THEN profile.primary_incident_type_key
                    ELSE profile.secondary_incident_type_key
                END AS incident_type_key,
                incident_number.incident_sequence,
                DATEADD
                (
                    MINUTE,
                    30 * incident_number.incident_sequence,
                    DATEADD
                    (
                        DAY,
                        2 + (incident_number.incident_sequence * 6),
                        CONVERT(DATETIME2(0), month_plan.reference_month)
                    )
                ) AS opened_at,
                CASE
                    WHEN incident_number.incident_sequence <= month_plan.sla_miss_count
                        THEN 18 + (incident_number.incident_sequence * 4)
                    ELSE 4 + incident_number.incident_sequence
                END AS resolution_hours
            FROM seed.contract_month_plan AS month_plan
            INNER JOIN seed.contract_profile AS profile
                ON profile.contract_code = month_plan.contract_code
            INNER JOIN incident_number
                ON incident_number.incident_sequence <= month_plan.incident_count
        )
        INSERT INTO dw.fact_sla
        (
            opened_date_key,
            closed_date_key,
            contract_key,
            unit_key,
            incident_type_key,
            batch_id,
            incident_number,
            opened_at,
            closed_at,
            agreed_deadline_hours,
            resolution_hours,
            severity,
            incident_status,
            resolved_within_sla,
            is_recurrence,
            deduction_amount,
            penalty_amount,
            emergency_cost
        )
        SELECT
            opened_date.date_key,
            closed_date.date_key,
            contract.contract_key,
            source.unit_key,
            source.incident_type_key,
            @sla_batch_id,
            CONCAT
            (
                'INC-HIST-',
                CONVERT(CHAR(6), source.reference_month, 112),
                '-',
                source.contract_code,
                '-',
                RIGHT(CONCAT('0', source.incident_sequence), 2)
            ),
            source.opened_at,
            DATEADD(HOUR, source.resolution_hours, source.opened_at),
            8,
            source.resolution_hours,
            CASE
                WHEN source.incident_sequence <= source.critical_incident_count
                    THEN 'CRITICAL'
                WHEN source.incident_count >= 2
                    THEN 'HIGH'
                WHEN source.incident_count = 1
                    THEN 'MEDIUM'
                ELSE 'LOW'
            END,
            'CLOSED',
            CASE
                WHEN source.incident_sequence <= source.sla_miss_count
                    THEN 0
                ELSE 1
            END,
            CASE
                WHEN source.incident_sequence <= source.recurrent_incident_count
                    THEN 1
                ELSE 0
            END,
            CONVERT
            (
                DECIMAL(18,2),
                source.sla_financial_loss * 0.4000 / NULLIF(source.incident_count, 0)
            ),
            CONVERT
            (
                DECIMAL(18,2),
                source.sla_financial_loss * 0.6000 / NULLIF(source.incident_count, 0)
            ),
            CASE
                WHEN source.incident_sequence <= source.critical_incident_count
                    THEN 750.00
                ELSE 0
            END
        FROM incident_source AS source
        INNER JOIN dw.dim_contract AS contract
            ON contract.contract_code = source.contract_code
           AND contract.is_current = 1
        INNER JOIN dw.dim_date AS opened_date
            ON opened_date.full_date = CONVERT(DATE, source.opened_at)
        INNER JOIN dw.dim_date AS closed_date
            ON closed_date.full_date =
                CONVERT(DATE, DATEADD(HOUR, source.resolution_hours, source.opened_at));

        /* Reajustes, repactuações e renegociações. */
        INSERT INTO dw.fact_adjustment
        (
            expected_date_key,
            requested_date_key,
            approved_date_key,
            contract_key,
            batch_id,
            adjustment_number,
            process_type,
            requested_pct,
            approved_pct,
            previous_amount,
            approved_amount,
            is_retroactive,
            retroactive_amount,
            process_status,
            pending_reason
        )
        SELECT
            expected_date.date_key,
            requested_date.date_key,
            approved_date.date_key,
            contract.contract_key,
            @adjustment_batch_id,
            event.adjustment_number,
            event.process_type,
            event.requested_pct,
            event.approved_pct,
            event.previous_amount,
            event.approved_amount,
            event.is_retroactive,
            event.retroactive_amount,
            event.process_status,
            event.pending_reason
        FROM
        (
            VALUES
            ('AJ-HIST-CT002-2024', 'CT-002', 'ADJUSTMENT',
                CONVERT(DATE, '2024-05-15'), CONVERT(DATE, '2024-05-10'), CONVERT(DATE, '2025-01-20'),
                CONVERT(DECIMAL(9,4), 0.0650), CONVERT(DECIMAL(9,4), 0.0600),
                CONVERT(DECIMAL(18,2), 198113.21), CONVERT(DECIMAL(18,2), 210000.00),
                CONVERT(BIT, 1), CONVERT(DECIMAL(18,2), 71320.74), 'APPROVED',
                N'Aprovação concluída oito meses depois da data prevista.'),
            ('AJ-HIST-CT008-2024', 'CT-008', 'ADJUSTMENT',
                CONVERT(DATE, '2024-09-01'), CONVERT(DATE, '2024-08-20'), CONVERT(DATE, NULL),
                CONVERT(DECIMAL(9,4), 0.0710), CONVERT(DECIMAL(9,4), NULL),
                CONVERT(DECIMAL(18,2), 410000.00), CONVERT(DECIMAL(18,2), NULL),
                CONVERT(BIT, 0), CONVERT(DECIMAL(18,2), 0), 'REQUESTED',
                N'Processo ainda em análise pelo cliente.'),
            ('AJ-HIST-CT005-2025', 'CT-005', 'RENEGOTIATION',
                CONVERT(DATE, '2025-09-10'), CONVERT(DATE, '2025-08-15'), CONVERT(DATE, NULL),
                CONVERT(DECIMAL(9,4), 0.1800), CONVERT(DECIMAL(9,4), NULL),
                CONVERT(DECIMAL(18,2), 128000.00), CONVERT(DECIMAL(18,2), NULL),
                CONVERT(BIT, 0), CONVERT(DECIMAL(18,2), 0), 'PENDING',
                N'Cliente pediu revisão do escopo antes de discutir preço.'),
            ('AJ-HIST-CT007-2025', 'CT-007', 'ADJUSTMENT',
                CONVERT(DATE, '2025-03-01'), CONVERT(DATE, '2025-01-20'), CONVERT(DATE, '2025-04-05'),
                CONVERT(DECIMAL(9,4), 0.0520), CONVERT(DECIMAL(9,4), 0.0500),
                CONVERT(DECIMAL(18,2), 265000.00), CONVERT(DECIMAL(18,2), 278250.00),
                CONVERT(BIT, 1), CONVERT(DECIMAL(18,2), 13250.00), 'APPROVED',
                N'Negociação concluída sem impacto operacional.'),
            ('AJ-HIST-CT010-2025', 'CT-010', 'REPACTUATION',
                CONVERT(DATE, '2025-01-01'), CONVERT(DATE, '2024-12-02'), CONVERT(DATE, '2025-01-15'),
                CONVERT(DECIMAL(9,4), 0.0480), CONVERT(DECIMAL(9,4), 0.0450),
                CONVERT(DECIMAL(18,2), 660287.08), CONVERT(DECIMAL(18,2), 690000.00),
                CONVERT(BIT, 1), CONVERT(DECIMAL(18,2), 29712.92), 'APPROVED',
                N'Aplicação retroativa à competência de janeiro.'),
            ('AJ-HIST-CT001-2026', 'CT-001', 'REPACTUATION',
                CONVERT(DATE, '2026-01-01'), CONVERT(DATE, '2025-12-10'), CONVERT(DATE, '2026-03-15'),
                CONVERT(DECIMAL(9,4), 0.0500), CONVERT(DECIMAL(9,4), 0.0450),
                CONVERT(DECIMAL(18,2), 580000.00), CONVERT(DECIMAL(18,2), 606100.00),
                CONVERT(BIT, 1), CONVERT(DECIMAL(18,2), 52200.00), 'APPROVED',
                N'Repactuação concluída durante o plano de recuperação.'),
            ('AJ-HIST-CT003-2025', 'CT-003', 'RENEGOTIATION',
                CONVERT(DATE, '2025-07-01'), CONVERT(DATE, '2025-09-01'), CONVERT(DATE, '2025-11-20'),
                CONVERT(DECIMAL(9,4), 0.0875), CONVERT(DECIMAL(9,4), 0.0875),
                CONVERT(DECIMAL(18,2), 320000.00), CONVERT(DECIMAL(18,2), 348000.00),
                CONVERT(BIT, 0), CONVERT(DECIMAL(18,2), 0), 'APPROVED',
                N'Atividades adicionais formalizadas por termo aditivo.')
        ) AS event
        (
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
            pending_reason
        )
        INNER JOIN dw.dim_contract AS contract
            ON contract.contract_code = event.contract_code
           AND contract.is_current = 1
        INNER JOIN dw.dim_date AS expected_date
            ON expected_date.full_date = event.expected_date
        LEFT JOIN dw.dim_date AS requested_date
            ON requested_date.full_date = event.requested_date
        LEFT JOIN dw.dim_date AS approved_date
            ON approved_date.full_date = event.approved_date;

        /* Ações gerenciais usadas na análise antes/depois. */
        INSERT INTO dw.fact_management_action
        (
            recommendation_date_key,
            start_date_key,
            completion_date_key,
            contract_key,
            action_key,
            batch_id,
            action_status,
            estimated_impact_amount,
            actual_impact_amount,
            standardized_result,
            owner_area
        )
        SELECT
            recommendation_date.date_key,
            start_date.date_key,
            completion_date.date_key,
            contract.contract_key,
            action.action_key,
            @action_batch_id,
            event.action_status,
            event.estimated_impact_amount,
            event.actual_impact_amount,
            event.standardized_result,
            event.owner_area
        FROM
        (
            VALUES
            ('CT-002', 'REVIEW_RETROACTIVE',
                CONVERT(DATE, '2025-01-20'), CONVERT(DATE, '2025-01-20'), CONVERT(DATE, '2025-02-10'),
                'COMPLETED', CONVERT(DECIMAL(18,2), 71320.74), CONVERT(DECIMAL(18,2), 71320.74),
                'RECOVERED', 'COMMERCIAL'),
            ('CT-003', 'FORMALIZE_SCOPE',
                CONVERT(DATE, '2025-08-15'), CONVERT(DATE, '2025-09-01'), CONVERT(DATE, '2025-11-20'),
                'COMPLETED', CONVERT(DECIMAL(18,2), 28000.00), CONVERT(DECIMAL(18,2), 28000.00),
                'SCOPE_FORMALIZED', 'COMMERCIAL'),
            ('CT-004', 'SLA_RECOVERY_PLAN',
                CONVERT(DATE, '2025-07-20'), CONVERT(DATE, '2025-08-01'), CONVERT(DATE, '2025-11-30'),
                'COMPLETED', CONVERT(DECIMAL(18,2), 65000.00), CONVERT(DECIMAL(18,2), 51000.00),
                'IMPROVED', 'OPERATIONS'),
            ('CT-001', 'REINFORCE_COVERAGE',
                CONVERT(DATE, '2025-12-15'), CONVERT(DATE, '2026-01-01'), CONVERT(DATE, '2026-03-31'),
                'COMPLETED', CONVERT(DECIMAL(18,2), 90000.00), CONVERT(DECIMAL(18,2), 72000.00),
                'IMPROVED', 'OPERATIONS'),
            ('CT-005', 'ASSESS_NON_RENEWAL',
                CONVERT(DATE, '2026-04-15'), CONVERT(DATE, '2026-05-01'), CONVERT(DATE, NULL),
                'IN_PROGRESS', CONVERT(DECIMAL(18,2), 180000.00), CONVERT(DECIMAL(18,2), NULL),
                'UNDER_REVIEW', 'EXECUTIVE'),
            ('CT-007', 'EXPAND',
                CONVERT(DATE, '2025-11-15'), CONVERT(DATE, '2026-01-01'), CONVERT(DATE, '2026-01-31'),
                'COMPLETED', CONVERT(DECIMAL(18,2), 27000.00), CONVERT(DECIMAL(18,2), 27000.00),
                'EXPANDED', 'COMMERCIAL'),
            ('CT-008', 'REQUEST_ADJUSTMENT',
                CONVERT(DATE, '2026-01-10'), CONVERT(DATE, '2026-01-10'), CONVERT(DATE, NULL),
                'IN_PROGRESS', CONVERT(DECIMAL(18,2), 220000.00), CONVERT(DECIMAL(18,2), NULL),
                'PENDING_CLIENT', 'COMMERCIAL'),
            ('CT-009', 'REINFORCE_COVERAGE',
                CONVERT(DATE, '2026-05-10'), CONVERT(DATE, '2026-06-01'), CONVERT(DATE, NULL),
                'IN_PROGRESS', CONVERT(DECIMAL(18,2), 85000.00), CONVERT(DECIMAL(18,2), NULL),
                'STARTED', 'OPERATIONS')
        ) AS event
        (
            contract_code,
            action_code,
            recommendation_date,
            start_date,
            completion_date,
            action_status,
            estimated_impact_amount,
            actual_impact_amount,
            standardized_result,
            owner_area
        )
        INNER JOIN dw.dim_contract AS contract
            ON contract.contract_code = event.contract_code
           AND contract.is_current = 1
        INNER JOIN dw.dim_action AS action
            ON action.action_code = event.action_code
        INNER JOIN dw.dim_date AS recommendation_date
            ON recommendation_date.full_date = event.recommendation_date
        LEFT JOIN dw.dim_date AS start_date
            ON start_date.full_date = event.start_date
        LEFT JOIN dw.dim_date AS completion_date
            ON completion_date.full_date = event.completion_date;

        UPDATE etl.batch_control
        SET
            status = 'SUCCESS',
            rows_loaded = (SELECT COUNT(*) FROM dw.fact_revenue WHERE batch_id = @revenue_batch_id),
            finished_at = SYSDATETIME()
        WHERE batch_id = @revenue_batch_id;

        UPDATE etl.batch_control
        SET
            status = 'SUCCESS',
            rows_loaded = (SELECT COUNT(*) FROM dw.fact_contract_cost WHERE batch_id = @cost_batch_id),
            rows_received = (SELECT COUNT(*) FROM dw.fact_contract_cost WHERE batch_id = @cost_batch_id),
            finished_at = SYSDATETIME()
        WHERE batch_id = @cost_batch_id;

        UPDATE etl.batch_control
        SET
            status = 'SUCCESS',
            rows_loaded = (SELECT COUNT(*) FROM dw.fact_operation WHERE batch_id = @operation_batch_id),
            finished_at = SYSDATETIME()
        WHERE batch_id = @operation_batch_id;

        UPDATE etl.batch_control
        SET
            status = 'SUCCESS',
            rows_loaded = (SELECT COUNT(*) FROM dw.fact_sla WHERE batch_id = @sla_batch_id),
            rows_received = (SELECT COUNT(*) FROM dw.fact_sla WHERE batch_id = @sla_batch_id),
            finished_at = SYSDATETIME()
        WHERE batch_id = @sla_batch_id;

        UPDATE etl.batch_control
        SET
            status = 'SUCCESS',
            rows_loaded = (SELECT COUNT(*) FROM dw.fact_adjustment WHERE batch_id = @adjustment_batch_id),
            finished_at = SYSDATETIME()
        WHERE batch_id = @adjustment_batch_id;

        UPDATE etl.batch_control
        SET
            status = 'SUCCESS',
            rows_loaded = (SELECT COUNT(*) FROM dw.fact_management_action WHERE batch_id = @action_batch_id),
            finished_at = SYSDATETIME()
        WHERE batch_id = @action_batch_id;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO

EXEC seed.usp_rebuild_history_facts;
GO
