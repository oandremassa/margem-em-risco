USE margem_em_risco;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.schemas
    WHERE name = N'bi'
)
BEGIN
    EXEC(N'CREATE SCHEMA bi AUTHORIZATION dbo;');
END;
GO

CREATE OR ALTER VIEW bi.vw_calendario
AS
SELECT
    full_date AS data,
    date_key AS chave_data,
    month_start_date AS inicio_mes,
    month_number AS numero_mes,
    month_name_pt AS mes,
    quarter_number AS trimestre,
    year_number AS ano,
    year_month AS ano_mes,
    CONVERT
    (
        BIT,
        CASE
            WHEN is_weekend = 0 THEN 1
            ELSE 0
        END
    ) AS dia_util
FROM dw.dim_date;
GO

CREATE OR ALTER VIEW bi.vw_contratos
AS
SELECT
    contract_key AS chave_contrato,
    contract_code AS codigo_contrato,
    client_name AS cliente,
    business_segment AS segmento,
    service_name AS servico,
    manager_name AS gestor,
    complexity_level AS complexidade,
    renewal_date AS data_renovacao,
    target_margin_pct AS meta_margem_pct
FROM mart.vw_contract_portfolio;
GO

CREATE OR ALTER VIEW bi.vw_resumo_executivo
AS
SELECT
    reference_month AS mes_referencia,
    active_contract_count AS contratos_ativos,
    net_revenue AS receita_liquida,
    total_cost AS custo_total,
    contribution_margin AS margem_contribuicao,
    contribution_margin_pct AS margem_pct,
    margin_leakage_amount AS vazamento_margem,
    identified_loss_amount AS perda_identificada,
    recoverable_amount AS valor_recuperavel,
    revenue_at_risk AS receita_em_risco,
    critical_contract_count AS contratos_criticos,
    high_risk_contract_count AS contratos_alto_risco,
    contracts_requiring_action AS contratos_com_acao
FROM mart.vw_executive_summary;
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
    risk_class AS classe_risco,
    financial_risk_score AS risco_financeiro,
    operational_risk_score AS risco_operacional,
    quality_risk_score AS risco_qualidade,
    contractual_risk_score AS risco_contratual,
    people_risk_score AS risco_pessoas,
    margin_trend AS tendencia_margem,
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
    risk.margin_trend AS tendencia_margem,
    risk.contract_risk_score AS score_risco,
    risk.risk_class AS classe_risco
FROM mart.vw_contract_monthly_performance AS performance
INNER JOIN mart.vw_contract_risk_score AS risk
    ON risk.date_key = performance.date_key
   AND risk.contract_key = performance.contract_key;
GO

CREATE OR ALTER VIEW bi.vw_perdas_margem
AS
SELECT
    reference_month AS mes_referencia,
    contract_key AS chave_contrato,
    contract_code AS codigo_contrato,
    loss_code AS codigo_perda,
    loss_name_pt AS causa_perda,
    loss_nature AS natureza_perda,
    loss_amount AS valor_perda,
    recovery_rate AS taxa_recuperacao,
    recoverable_amount AS valor_recuperavel,
    calculation_note AS observacao_calculo
FROM mart.vw_margin_loss_bridge;
GO

CREATE OR ALTER VIEW bi.vw_fatores_risco
AS
SELECT
    reference_month AS mes_referencia,
    contract_key AS chave_contrato,
    contract_code AS codigo_contrato,
    risk_pillar AS pilar_risco,
    driver_code AS codigo_fator,
    driver_name_pt AS fator_risco,
    observed_value AS valor_observado,
    reference_value AS valor_referencia,
    driver_score AS pontuacao_fator,
    estimated_impact_amount AS impacto_estimado,
    driver_rank AS ordem_fator
FROM mart.vw_contract_risk_drivers;
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
    risk_class AS classe_risco,
    recommended_action_code AS codigo_acao,
    recommended_action_name_pt AS acao_recomendada,
    action_reason_pt AS justificativa,
    action_impact_amount AS impacto_acao,
    action_recoverable_amount AS valor_recuperavel,
    action_priority_score AS score_prioridade,
    portfolio_priority_rank AS prioridade
FROM mart.vw_action_priority_queue;
GO

CREATE OR ALTER VIEW bi.vw_efeito_acoes
AS
SELECT
    management_action_key AS chave_acao,
    contract_key AS chave_contrato,
    contract_code AS codigo_contrato,
    action_code AS codigo_acao,
    action_name_pt AS acao,
    start_date AS data_inicio,
    completion_date AS data_conclusao,
    margin_before_pct AS margem_antes_pct,
    margin_after_pct AS margem_depois_pct,
    margin_delta_pp AS variacao_margem_pp,
    overtime_before_pct AS horas_extras_antes_pct,
    overtime_after_pct AS horas_extras_depois_pct,
    coverage_before_pct AS cobertura_antes_pct,
    coverage_after_pct AS cobertura_depois_pct,
    sla_before_pct AS sla_antes_pct,
    sla_after_pct AS sla_depois_pct,
    actual_impact_amount AS impacto_realizado
FROM mart.vw_management_action_effect;
GO

CREATE OR ALTER VIEW bi.vw_linha_tempo
AS
SELECT
    timeline_key AS chave_evento,
    reference_date AS data_evento,
    reference_month AS mes_referencia,
    contract_key AS chave_contrato,
    contract_code AS codigo_contrato,
    event_type AS tipo_evento,
    event_severity AS gravidade,
    event_title AS titulo_evento,
    event_detail AS detalhe_evento,
    impact_amount AS impacto_financeiro,
    source_key AS chave_origem
FROM mart.vw_contract_timeline;
GO
