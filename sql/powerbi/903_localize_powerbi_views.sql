USE margem_em_risco;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO

CREATE OR ALTER VIEW bi.vw_portfolio_atual
AS
SELECT
    reference_month AS mes_referencia,
    contract_key AS chave_contrato,
    contract_code AS codigo_contrato,
    client_name AS cliente,
    business_segment AS segmento,
    service_name AS servico,
    manager_name AS gestor,
    complexity_level AS complexidade,
    net_revenue AS receita_liquida,
    contribution_margin AS margem_contribuicao,
    contribution_margin_pct AS margem_pct,
    target_margin_pct AS meta_margem_pct,
    margin_gap_pct AS gap_margem_pct,
    margin_leakage_amount AS vazamento_margem,
    contract_risk_score AS score_risco,
    CASE risk_class
        WHEN 'LOW' THEN N'Baixo'
        WHEN 'ATTENTION' THEN N'Atenção'
        WHEN 'HIGH' THEN N'Alto'
        WHEN 'CRITICAL' THEN N'Crítico'
        ELSE risk_class
    END AS classe_risco,
    financial_risk_score AS risco_financeiro,
    operational_risk_score AS risco_operacional,
    quality_risk_score AS risco_qualidade,
    contractual_risk_score AS risco_contratual,
    people_risk_score AS risco_pessoas,
    CASE margin_trend
        WHEN 'IMPROVING' THEN N'Melhorando'
        WHEN 'STABLE' THEN N'Estável'
        WHEN 'DETERIORATING' THEN N'Deteriorando'
        WHEN 'RAPIDLY_DETERIORATING' THEN N'Deterioração rápida'
        WHEN 'INSUFFICIENT_HISTORY' THEN N'Histórico insuficiente'
        ELSE margin_trend
    END AS tendencia_margem,
    renewal_date AS data_renovacao,
    days_to_renewal AS dias_para_renovacao,
    main_risk_driver_pt AS principal_fator_risco,
    main_risk_driver_impact AS impacto_principal_fator,
    recommended_action_code AS codigo_acao,
    recommended_action_name_pt AS acao_recomendada,
    action_recoverable_amount AS valor_recuperavel,
    portfolio_priority_rank AS prioridade
FROM mart.vw_contract_portfolio;
GO

CREATE OR ALTER VIEW bi.vw_fila_acoes
AS
SELECT
    reference_month AS mes_referencia,
    contract_key AS chave_contrato,
    contract_code AS codigo_contrato,
    client_name AS cliente,
    contribution_margin_pct AS margem_pct,
    contract_risk_score AS score_risco,
    CASE risk_class
        WHEN 'LOW' THEN N'Baixo'
        WHEN 'ATTENTION' THEN N'Atenção'
        WHEN 'HIGH' THEN N'Alto'
        WHEN 'CRITICAL' THEN N'Crítico'
        ELSE risk_class
    END AS classe_risco,
    recommended_action_code AS codigo_acao,
    CONCAT(
        contract_code,
        N' · ',
        client_name,
        N' — ',
        recommended_action_name_pt
    ) AS acao_recomendada,
    action_reason_pt AS justificativa,
    action_impact_amount AS impacto_acao,
    action_recoverable_amount AS valor_recuperavel,
    action_priority_score AS score_prioridade,
    portfolio_priority_rank AS prioridade
FROM mart.vw_action_priority_queue;
GO

CREATE OR ALTER VIEW bi.vw_desempenho_mensal
AS
SELECT
    performance.reference_month AS mes_referencia,
    performance.date_key AS chave_data,
    performance.contract_key AS chave_contrato,
    performance.contract_code AS codigo_contrato,
    performance.client_name AS cliente,
    performance.business_segment AS segmento,
    performance.service_name AS servico,
    performance.manager_name AS gestor,
    performance.complexity_level AS complexidade,
    performance.renewal_date AS data_renovacao,
    performance.days_to_renewal AS dias_para_renovacao,
    performance.target_margin_pct AS meta_margem_pct,
    performance.gross_revenue AS receita_bruta,
    performance.net_revenue AS receita_liquida,
    performance.total_cost AS custo_total,
    performance.contribution_margin AS margem_contribuicao,
    performance.contribution_margin_pct AS margem_pct,
    performance.margin_gap_pct AS gap_margem_pct,
    performance.margin_leakage_amount AS vazamento_margem,
    performance.planned_positions AS postos_previstos,
    performance.filled_positions AS postos_ocupados,
    performance.uncovered_positions AS postos_descobertos,
    performance.coverage_rate AS cobertura_pct,
    performance.planned_hours AS horas_previstas,
    performance.regular_hours AS horas_regulares,
    performance.overtime_hours AS horas_extras,
    performance.overtime_rate AS horas_extras_pct,
    performance.absence_hours AS horas_ausencia,
    performance.absenteeism_rate AS absenteismo_pct,
    performance.open_positions AS vagas_abertas,
    performance.average_replacement_days AS dias_reposicao,
    performance.incident_count AS quantidade_ocorrencias,
    performance.critical_incident_count AS ocorrencias_criticas,
    performance.recurrent_incident_count AS ocorrencias_reincidentes,
    performance.sla_compliance_rate AS sla_pct,
    performance.open_adjustment_count AS reajustes_abertos,
    CASE risk.margin_trend
        WHEN 'IMPROVING' THEN N'Melhorando'
        WHEN 'STABLE' THEN N'Estável'
        WHEN 'DETERIORATING' THEN N'Deteriorando'
        WHEN 'RAPIDLY_DETERIORATING' THEN N'Deterioração rápida'
        WHEN 'INSUFFICIENT_HISTORY' THEN N'Histórico insuficiente'
        ELSE risk.margin_trend
    END AS tendencia_margem,
    risk.contract_risk_score AS score_risco,
    CASE risk.risk_class
        WHEN 'LOW' THEN N'Baixo'
        WHEN 'ATTENTION' THEN N'Atenção'
        WHEN 'HIGH' THEN N'Alto'
        WHEN 'CRITICAL' THEN N'Crítico'
        ELSE risk.risk_class
    END AS classe_risco
FROM mart.vw_contract_monthly_performance AS performance
INNER JOIN mart.vw_contract_risk_score AS risk
    ON risk.date_key = performance.date_key
   AND risk.contract_key = performance.contract_key;
GO

PRINT N'Views do Power BI atualizadas em português.';
GO
