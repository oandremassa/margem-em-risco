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

CREATE OR ALTER PROCEDURE seed.usp_build_contract_month_plan
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    TRUNCATE TABLE seed.contract_month_plan;

    WITH month_number AS
    (
        SELECT month_offset
        FROM
        (
            VALUES
            (0),(1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11),
            (12),(13),(14),(15),(16),(17),(18),(19),(20),(21),(22),(23)
        ) AS value_list(month_offset)
    ),
    month_list AS
    (
        SELECT DATEADD(MONTH, month_offset, CONVERT(DATE, '2024-07-01')) AS reference_month
        FROM month_number
    )
    INSERT INTO seed.contract_month_plan
    (
        reference_month,
        contract_code,
        contracted_amount,
        additional_services,
        reimbursements,
        commercial_discount_rate,
        base_cost_factor,
        labor_factor,
        overtime_factor,
        coverage_factor,
        material_factor,
        other_cost_factor,
        position_factor,
        coverage_rate,
        overtime_rate,
        absenteeism_rate,
        vacancy_rate,
        replacement_days,
        execution_overrun_rate,
        incident_count,
        critical_incident_count,
        recurrent_incident_count,
        sla_miss_count,
        sla_financial_loss,
        one_time_extra_cost,
        event_code,
        event_note
    )
    SELECT
        month_list.reference_month,
        profile.contract_code,
        CONVERT
        (
            DECIMAL(18,2),
            contract.base_monthly_amount
            * CASE YEAR(month_list.reference_month)
                WHEN 2024 THEN 0.9600
                WHEN 2025 THEN 1.0000
                ELSE 1.0450
              END
        ),
        0,
        0,
        0,
        profile.normal_cost_factor,
        1.0000,
        1.0000,
        1.0000,
        CASE
            WHEN MONTH(month_list.reference_month) IN (1, 12) THEN 1.0400
            ELSE 1.0000
        END,
        1.0000,
        1.0000,
        0.9900,
        0.0150,
        0.0100,
        0.0000,
        10,
        0.0000,
        CASE WHEN MONTH(month_list.reference_month) IN (3, 9) THEN 1 ELSE 0 END,
        0,
        0,
        0,
        0,
        0,
        'ROUTINE',
        N'Operação dentro do comportamento esperado.'
    FROM month_list
    CROSS JOIN seed.contract_profile AS profile
    INNER JOIN dw.dim_contract AS contract
        ON contract.contract_code = profile.contract_code
       AND contract.is_current = 1;

    /* CT-001: pressão operacional, intervenção e recuperação. */
    UPDATE month_plan
    SET
        coverage_rate = 0.9700,
        overtime_rate = 0.0350,
        absenteeism_rate = 0.0200,
        vacancy_rate = 0.0300,
        replacement_days = 22,
        overtime_factor = 1.2500,
        coverage_factor = 1.5000,
        incident_count = 1,
        event_code = 'COVERAGE_PRESSURE',
        event_note = N'A operação começa a depender mais de cobertura e horas adicionais.'
    FROM seed.contract_month_plan AS month_plan
    WHERE month_plan.contract_code = 'CT-001'
      AND month_plan.reference_month BETWEEN '2024-07-01' AND '2024-12-01';

    UPDATE month_plan
    SET
        coverage_rate = 0.9300,
        overtime_rate = 0.0700,
        absenteeism_rate = 0.0450,
        vacancy_rate = 0.0800,
        replacement_days = 35,
        labor_factor = 1.0200,
        overtime_factor = 2.2000,
        coverage_factor = 3.2000,
        incident_count = 2,
        critical_incident_count = 1,
        recurrent_incident_count = 1,
        sla_miss_count = 1,
        sla_financial_loss = 8000,
        event_code = 'COVERAGE_DETERIORATION',
        event_note = N'Absenteísmo e vagas abertas passam a pressionar margem e SLA.'
    FROM seed.contract_month_plan AS month_plan
    WHERE month_plan.contract_code = 'CT-001'
      AND month_plan.reference_month BETWEEN '2025-01-01' AND '2025-04-01';

    UPDATE month_plan
    SET
        coverage_rate = 0.9000,
        overtime_rate = 0.0900,
        absenteeism_rate = 0.0550,
        vacancy_rate = 0.1000,
        replacement_days = 42,
        labor_factor = 1.0300,
        overtime_factor = 3.0000,
        coverage_factor = 4.0000,
        incident_count = 3,
        critical_incident_count = 1,
        recurrent_incident_count = 2,
        sla_miss_count = 2,
        sla_financial_loss = 12000,
        event_code = 'COVERAGE_CRITICAL',
        event_note = N'Pior trecho do contrato: cobertura baixa, horas adicionais e reincidência.'
    FROM seed.contract_month_plan AS month_plan
    WHERE month_plan.contract_code = 'CT-001'
      AND month_plan.reference_month BETWEEN '2025-05-01' AND '2025-12-01';

    UPDATE month_plan
    SET
        coverage_rate = 0.9300,
        overtime_rate = 0.0650,
        absenteeism_rate = 0.0400,
        vacancy_rate = 0.0700,
        replacement_days = 30,
        labor_factor = 1.0200,
        overtime_factor = 2.2000,
        coverage_factor = 2.8000,
        incident_count = 2,
        critical_incident_count = 1,
        recurrent_incident_count = 1,
        sla_miss_count = 1,
        sla_financial_loss = 6000,
        event_code = 'COVERAGE_ACTION',
        event_note = N'Plano de cobertura em execução. Os indicadores começam a reagir.'
    FROM seed.contract_month_plan AS month_plan
    WHERE month_plan.contract_code = 'CT-001'
      AND month_plan.reference_month BETWEEN '2026-01-01' AND '2026-03-01';

    UPDATE month_plan
    SET
        coverage_rate = 0.9650,
        overtime_rate = 0.0400,
        absenteeism_rate = 0.0250,
        vacancy_rate = 0.0400,
        replacement_days = 18,
        overtime_factor = 1.4000,
        coverage_factor = 1.8000,
        incident_count = 1,
        sla_financial_loss = 1000,
        event_code = 'COVERAGE_RECOVERY',
        event_note = N'Cobertura e margem melhoram depois da intervenção.'
    FROM seed.contract_month_plan AS month_plan
    WHERE month_plan.contract_code = 'CT-001'
      AND month_plan.reference_month BETWEEN '2026-04-01' AND '2026-06-01';

    /* CT-002: reajuste atrasado, sem deterioração operacional. */
    UPDATE month_plan
    SET
        contracted_amount =
            CASE
                WHEN month_plan.reference_month < '2025-01-01' THEN 198113.21
                WHEN month_plan.reference_month < '2026-01-01' THEN 210000.00
                ELSE 219000.00
            END,
        coverage_rate = 0.9950,
        overtime_rate = 0.0120,
        absenteeism_rate = 0.0080,
        event_code =
            CASE
                WHEN month_plan.reference_month < '2025-01-01' THEN 'ADJUSTMENT_DELAY'
                WHEN month_plan.reference_month = '2025-01-01' THEN 'ADJUSTMENT_APPROVED'
                ELSE 'ROUTINE'
            END,
        event_note =
            CASE
                WHEN month_plan.reference_month < '2025-01-01'
                    THEN N'Reajuste ainda não refletido na receita.'
                WHEN month_plan.reference_month = '2025-01-01'
                    THEN N'Reajuste aprovado com retroatividade.'
                ELSE N'Operação estável depois da correção comercial.'
            END
    FROM seed.contract_month_plan AS month_plan
    WHERE month_plan.contract_code = 'CT-002';

    /* CT-003: escopo cresce antes de ser formalizado. */
    UPDATE month_plan
    SET
        execution_overrun_rate = 0.0400,
        overtime_rate = 0.0400,
        labor_factor = 1.0200,
        overtime_factor = 1.3000,
        incident_count = CASE WHEN MONTH(month_plan.reference_month) % 2 = 0 THEN 1 ELSE 0 END,
        event_code = 'SCOPE_CREEP',
        event_note = N'Horas executadas acima do previsto, ainda sem faturamento adicional.'
    FROM seed.contract_month_plan AS month_plan
    WHERE month_plan.contract_code = 'CT-003'
      AND month_plan.reference_month BETWEEN '2024-07-01' AND '2025-06-01';

    UPDATE month_plan
    SET
        execution_overrun_rate = 0.1000,
        overtime_rate = 0.0600,
        labor_factor = 1.0800,
        overtime_factor = 1.8000,
        incident_count = 1,
        recurrent_incident_count = 1,
        event_code = 'SCOPE_CREEP_HIGH',
        event_note = N'O escopo informal passa a afetar a margem de forma material.'
    FROM seed.contract_month_plan AS month_plan
    WHERE month_plan.contract_code = 'CT-003'
      AND month_plan.reference_month BETWEEN '2025-07-01' AND '2025-11-01';

    UPDATE month_plan
    SET
        contracted_amount = 320000.00,
        additional_services = 28000.00,
        execution_overrun_rate = 0.0200,
        overtime_rate = 0.0300,
        overtime_factor = 1.1000,
        event_code = 'SCOPE_FORMALIZED',
        event_note = N'Atividades adicionais passam a ser faturadas depois do termo aditivo.'
    FROM seed.contract_month_plan AS month_plan
    WHERE month_plan.contract_code = 'CT-003'
      AND month_plan.reference_month BETWEEN '2025-12-01' AND '2026-06-01';

    /* CT-004: falhas de SLA e recuperação após ação gerencial. */
    UPDATE month_plan
    SET
        coverage_rate = 0.9700,
        overtime_rate = 0.0350,
        overtime_factor = 1.2000,
        other_cost_factor = 1.0500,
        incident_count = 1,
        event_code = 'SLA_WARNING',
        event_note = N'Atrasos pontuais começam a aparecer na manutenção.'
    FROM seed.contract_month_plan AS month_plan
    WHERE month_plan.contract_code = 'CT-004'
      AND month_plan.reference_month BETWEEN '2024-07-01' AND '2024-12-01';

    UPDATE month_plan
    SET
        coverage_rate = 0.9400,
        overtime_rate = 0.0650,
        absenteeism_rate = 0.0300,
        vacancy_rate = 0.0500,
        replacement_days = 28,
        overtime_factor = 1.8000,
        other_cost_factor = 1.6000,
        incident_count = 3,
        critical_incident_count = 2,
        recurrent_incident_count = 2,
        sla_miss_count = 2,
        sla_financial_loss = 22000,
        event_code = 'SLA_CRITICAL',
        event_note = N'Reincidência, multas e tempo de resposta acima do acordado.'
    FROM seed.contract_month_plan AS month_plan
    WHERE month_plan.contract_code = 'CT-004'
      AND month_plan.reference_month BETWEEN '2025-01-01' AND '2025-07-01';

    UPDATE month_plan
    SET
        coverage_rate = 0.9700,
        overtime_rate = 0.0400,
        absenteeism_rate = 0.0200,
        overtime_factor = 1.3000,
        other_cost_factor = 1.2000,
        incident_count = 2,
        critical_incident_count = 1,
        recurrent_incident_count = 1,
        sla_miss_count = 1,
        sla_financial_loss = 8000,
        event_code = 'SLA_ACTION',
        event_note = N'Plano de recuperação reduz ocorrências, mas ainda há pressão.'
    FROM seed.contract_month_plan AS month_plan
    WHERE month_plan.contract_code = 'CT-004'
      AND month_plan.reference_month BETWEEN '2025-08-01' AND '2025-11-01';

    UPDATE month_plan
    SET
        coverage_rate = 0.9850,
        overtime_rate = 0.0250,
        absenteeism_rate = 0.0120,
        overtime_factor = 1.0500,
        incident_count = CASE WHEN MONTH(month_plan.reference_month) % 3 = 0 THEN 1 ELSE 0 END,
        sla_financial_loss = CASE WHEN MONTH(month_plan.reference_month) % 3 = 0 THEN 1000 ELSE 0 END,
        event_code = 'SLA_RECOVERY',
        event_note = N'SLA volta ao nível esperado depois da intervenção.'
    FROM seed.contract_month_plan AS month_plan
    WHERE month_plan.contract_code = 'CT-004'
      AND month_plan.reference_month BETWEEN '2025-12-01' AND '2026-06-01';

    /* CT-005: déficit estrutural. */
    UPDATE month_plan
    SET
        contracted_amount = CASE WHEN month_plan.reference_month < '2026-01-01' THEN 128000 ELSE 132000 END,
        commercial_discount_rate = 0.0450,
        labor_factor = 1.1200,
        overtime_factor = 1.5000,
        other_cost_factor = 1.3500,
        coverage_rate = 0.9000,
        overtime_rate = 0.0700,
        absenteeism_rate = 0.0400,
        vacancy_rate = 0.0800,
        replacement_days = 30,
        incident_count = 1,
        recurrent_incident_count = CASE WHEN MONTH(month_plan.reference_month) % 2 = 0 THEN 1 ELSE 0 END,
        sla_miss_count = 1,
        sla_financial_loss = 1500,
        event_code = 'STRUCTURAL_DEFICIT',
        event_note = N'Descontos, deslocamento e cobertura mantêm o contrato abaixo do ponto de equilíbrio.'
    FROM seed.contract_month_plan AS month_plan
    WHERE month_plan.contract_code = 'CT-005';

    /* CT-006: um evento isolado não vira tendência. */
    UPDATE month_plan
    SET
        coverage_rate = 0.9900,
        overtime_rate = 0.0150,
        absenteeism_rate = 0.0100,
        incident_count = CASE WHEN MONTH(month_plan.reference_month) IN (4, 10) THEN 1 ELSE 0 END
    FROM seed.contract_month_plan AS month_plan
    WHERE month_plan.contract_code = 'CT-006';

    UPDATE month_plan
    SET
        one_time_extra_cost = 48000,
        incident_count = 1,
        critical_incident_count = 1,
        sla_miss_count = 1,
        sla_financial_loss = 3000,
        event_code = 'ONE_OFF_EVENT',
        event_note = N'Substituição emergencial de equipamento provoca queda pontual da margem.'
    FROM seed.contract_month_plan AS month_plan
    WHERE month_plan.contract_code = 'CT-006'
      AND month_plan.reference_month = '2024-11-01';

    /* CT-007: contrato de referência e expansão controlada. */
    UPDATE month_plan
    SET
        labor_factor = 0.9800,
        overtime_factor = 0.8000,
        other_cost_factor = 0.9500,
        coverage_rate = 0.9950,
        overtime_rate = 0.0100,
        absenteeism_rate = 0.0080,
        vacancy_rate = 0,
        replacement_days = 8,
        incident_count = 0,
        event_code = 'HEALTHY_REFERENCE',
        event_note = N'Margem acima da meta e operação previsível.'
    FROM seed.contract_month_plan AS month_plan
    WHERE month_plan.contract_code = 'CT-007';

    UPDATE month_plan
    SET
        contracted_amount = 292000,
        position_factor = 1.1000,
        event_code = 'CONTROLLED_EXPANSION',
        event_note = N'Escopo ampliado com preço e estrutura ajustados.'
    FROM seed.contract_month_plan AS month_plan
    WHERE month_plan.contract_code = 'CT-007'
      AND month_plan.reference_month BETWEEN '2026-01-01' AND '2026-06-01';

    /* CT-008: custos avançam, receita permanece sem reajuste. */
    UPDATE month_plan
    SET
        contracted_amount = 410000,
        labor_factor =
            CASE
                WHEN YEAR(month_plan.reference_month) = 2024 THEN 0.9800
                WHEN YEAR(month_plan.reference_month) = 2025 THEN 1.0300
                ELSE 1.0800
            END,
        coverage_rate = 0.9800,
        overtime_rate = 0.0250,
        absenteeism_rate = 0.0150,
        vacancy_rate = 0.0200,
        replacement_days = 15,
        incident_count = CASE WHEN MONTH(month_plan.reference_month) % 4 = 0 THEN 1 ELSE 0 END,
        event_code = 'ADJUSTMENT_PENDING',
        event_note = N'Reajuste pendente enquanto a folha e os benefícios aumentam.'
    FROM seed.contract_month_plan AS month_plan
    WHERE month_plan.contract_code = 'CT-008';

    /* CT-009: sinais de pessoas aparecem antes da piora financeira. */
    UPDATE month_plan
    SET
        coverage_rate = 0.9800,
        overtime_rate = 0.0300,
        absenteeism_rate = 0.0150,
        vacancy_rate = 0.0200,
        replacement_days = 14,
        overtime_factor = 1.1000,
        coverage_factor = 1.2000,
        incident_count = CASE WHEN MONTH(month_plan.reference_month) % 3 = 0 THEN 1 ELSE 0 END,
        event_code = 'WORKFORCE_STABLE',
        event_note = N'Operação ainda estável, com pequenos sinais de pressão.'
    FROM seed.contract_month_plan AS month_plan
    WHERE month_plan.contract_code = 'CT-009'
      AND month_plan.reference_month BETWEEN '2024-07-01' AND '2025-09-01';

    UPDATE month_plan
    SET
        coverage_rate = 0.9500,
        overtime_rate = 0.0550,
        absenteeism_rate = 0.0300,
        vacancy_rate = 0.0700,
        replacement_days = 28,
        labor_factor = 1.0200,
        overtime_factor = 1.8000,
        coverage_factor = 2.3000,
        incident_count = 1,
        recurrent_incident_count = 1,
        event_code = 'WORKFORCE_WARNING',
        event_note = N'Vagas abertas e horas adicionais crescem antes da margem ficar crítica.'
    FROM seed.contract_month_plan AS month_plan
    WHERE month_plan.contract_code = 'CT-009'
      AND month_plan.reference_month BETWEEN '2025-10-01' AND '2025-12-01';

    UPDATE month_plan
    SET
        contracted_amount = 375000,
        coverage_rate = 0.8900,
        overtime_rate = 0.0900,
        absenteeism_rate = 0.0500,
        vacancy_rate = 0.1200,
        replacement_days = 40,
        labor_factor = 1.0100,
        overtime_factor = 2.2000,
        coverage_factor = 3.0000,
        incident_count = 2,
        critical_incident_count = 1,
        recurrent_incident_count = 1,
        sla_miss_count = 1,
        sla_financial_loss = 5000,
        event_code = 'WORKFORCE_CRITICAL',
        event_note = N'A operação entra em pressão alta, mas o reajuste evita margem negativa.'
    FROM seed.contract_month_plan AS month_plan
    WHERE month_plan.contract_code = 'CT-009'
      AND month_plan.reference_month BETWEEN '2026-01-01' AND '2026-06-01';

    /* CT-010: grande contrato estável e repactuado. */
    UPDATE month_plan
    SET
        contracted_amount =
            CASE
                WHEN YEAR(month_plan.reference_month) = 2024 THEN 660287.08
                WHEN YEAR(month_plan.reference_month) = 2025 THEN 690000.00
                ELSE 718000.00
            END,
        coverage_rate = 0.9900,
        overtime_rate = 0.0180,
        absenteeism_rate = 0.0100,
        vacancy_rate = 0.0100,
        replacement_days = 12,
        incident_count = CASE WHEN MONTH(month_plan.reference_month) IN (3, 9) THEN 1 ELSE 0 END,
        sla_financial_loss = CASE WHEN MONTH(month_plan.reference_month) IN (3, 9) THEN 500 ELSE 0 END,
        event_code =
            CASE
                WHEN month_plan.reference_month = '2025-01-01' THEN 'REPACTUATION_APPROVED'
                ELSE 'ROUTINE'
            END,
        event_note =
            CASE
                WHEN month_plan.reference_month = '2025-01-01'
                    THEN N'Repactuação aplicada com retroatividade.'
                ELSE N'Contrato de grande porte com comportamento estável.'
            END
    FROM seed.contract_month_plan AS month_plan
    WHERE month_plan.contract_code = 'CT-010';

    IF (SELECT COUNT(*) FROM seed.contract_month_plan) <> 240
        THROW 51610, N'O plano mensal deveria conter 240 linhas.', 1;
END;
GO

EXEC seed.usp_build_contract_month_plan;
GO
