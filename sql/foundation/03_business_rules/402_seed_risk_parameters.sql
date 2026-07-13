USE margem_em_risco;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

DECLARE @parameter TABLE
(
    parameter_code  VARCHAR(60) PRIMARY KEY,
    parameter_value DECIMAL(18,6),
    parameter_unit  VARCHAR(20),
    parameter_group VARCHAR(30),
    description_pt  NVARCHAR(300)
);

INSERT INTO @parameter VALUES
('WEIGHT_FINANCIAL', 0.350000, 'PERCENT', 'WEIGHT', N'Peso do pilar financeiro no índice final.'),
('WEIGHT_OPERATIONAL', 0.250000, 'PERCENT', 'WEIGHT', N'Peso do pilar operacional no índice final.'),
('WEIGHT_QUALITY', 0.150000, 'PERCENT', 'WEIGHT', N'Peso do pilar de qualidade no índice final.'),
('WEIGHT_CONTRACTUAL', 0.150000, 'PERCENT', 'WEIGHT', N'Peso do pilar contratual no índice final.'),
('WEIGHT_PEOPLE', 0.100000, 'PERCENT', 'WEIGHT', N'Peso do pilar de continuidade de pessoas no índice final.'),
('MARGIN_GAP_WARN', 0.020000, 'PERCENT', 'FINANCIAL', N'Desvio de margem que inicia a faixa de atenção.'),
('MARGIN_GAP_HIGH', 0.060000, 'PERCENT', 'FINANCIAL', N'Desvio de margem classificado como alto.'),
('MARGIN_GAP_CRITICAL', 0.100000, 'PERCENT', 'FINANCIAL', N'Desvio de margem classificado como crítico.'),
('EXTRA_COST_WARN', 0.020000, 'PERCENT', 'FINANCIAL', N'Custo extraordinário sobre receita que inicia atenção.'),
('EXTRA_COST_HIGH', 0.050000, 'PERCENT', 'FINANCIAL', N'Custo extraordinário sobre receita classificado como alto.'),
('EXTRA_COST_CRITICAL', 0.080000, 'PERCENT', 'FINANCIAL', N'Custo extraordinário sobre receita classificado como crítico.'),
('OVERTIME_WARN', 0.030000, 'PERCENT', 'OPERATIONAL', N'Percentual de horas adicionais que inicia atenção.'),
('OVERTIME_HIGH', 0.060000, 'PERCENT', 'OPERATIONAL', N'Percentual de horas adicionais classificado como alto.'),
('OVERTIME_CRITICAL', 0.100000, 'PERCENT', 'OPERATIONAL', N'Percentual de horas adicionais classificado como crítico.'),
('COVERAGE_WARN', 0.980000, 'PERCENT', 'OPERATIONAL', N'Cobertura mínima para operação sem alerta.'),
('COVERAGE_HIGH', 0.950000, 'PERCENT', 'OPERATIONAL', N'Cobertura abaixo deste ponto indica pressão alta.'),
('COVERAGE_CRITICAL', 0.900000, 'PERCENT', 'OPERATIONAL', N'Cobertura abaixo deste ponto indica pressão crítica.'),
('SCOPE_OVERRUN_WARN', 0.020000, 'PERCENT', 'OPERATIONAL', N'Execução acima das horas contratadas que inicia atenção.'),
('SCOPE_OVERRUN_HIGH', 0.050000, 'PERCENT', 'OPERATIONAL', N'Execução acima das horas contratadas classificada como alta.'),
('SCOPE_OVERRUN_CRITICAL', 0.100000, 'PERCENT', 'OPERATIONAL', N'Execução acima das horas contratadas classificada como crítica.'),
('SLA_TARGET', 0.950000, 'PERCENT', 'QUALITY', N'Meta de ocorrências resolvidas dentro do prazo.'),
('SLA_HIGH', 0.850000, 'PERCENT', 'QUALITY', N'Limite inferior da faixa intermediária de SLA.'),
('SLA_CRITICAL', 0.700000, 'PERCENT', 'QUALITY', N'Limite inferior antes da faixa crítica de SLA.'),
('ADJUSTMENT_WARN_DAYS', 30.000000, 'DAYS', 'CONTRACTUAL', N'Dias de atraso que iniciam atenção para reajustes.'),
('ADJUSTMENT_HIGH_DAYS', 90.000000, 'DAYS', 'CONTRACTUAL', N'Dias de atraso classificados como altos.'),
('ADJUSTMENT_CRITICAL_DAYS', 180.000000, 'DAYS', 'CONTRACTUAL', N'Dias de atraso classificados como críticos.'),
('RENEWAL_WARN_DAYS', 180.000000, 'DAYS', 'CONTRACTUAL', N'Janela de atenção para renovação contratual.'),
('RENEWAL_HIGH_DAYS', 120.000000, 'DAYS', 'CONTRACTUAL', N'Janela de renovação com urgência alta.'),
('RENEWAL_CRITICAL_DAYS', 60.000000, 'DAYS', 'CONTRACTUAL', N'Janela de renovação com urgência crítica.'),
('NON_RENEWAL_REVIEW_DAYS', 365.000000, 'DAYS', 'CONTRACTUAL', N'Janela usada para avaliar não renovação de contratos deficitários.'),
('ABSENCE_WARN', 0.020000, 'PERCENT', 'PEOPLE', N'Absenteísmo que inicia atenção.'),
('ABSENCE_HIGH', 0.040000, 'PERCENT', 'PEOPLE', N'Absenteísmo classificado como alto.'),
('ABSENCE_CRITICAL', 0.060000, 'PERCENT', 'PEOPLE', N'Absenteísmo classificado como crítico.'),
('VACANCY_WARN', 0.010000, 'PERCENT', 'PEOPLE', N'Vagas abertas sobre postos previstos que iniciam atenção.'),
('VACANCY_HIGH', 0.050000, 'PERCENT', 'PEOPLE', N'Vagas abertas sobre postos previstos classificadas como altas.'),
('VACANCY_CRITICAL', 0.100000, 'PERCENT', 'PEOPLE', N'Vagas abertas sobre postos previstos classificadas como críticas.'),
('REPLACEMENT_WARN_DAYS', 15.000000, 'DAYS', 'PEOPLE', N'Tempo de reposição que inicia atenção.'),
('REPLACEMENT_HIGH_DAYS', 25.000000, 'DAYS', 'PEOPLE', N'Tempo de reposição classificado como alto.'),
('REPLACEMENT_CRITICAL_DAYS', 35.000000, 'DAYS', 'PEOPLE', N'Tempo de reposição classificado como crítico.'),
('RISK_ATTENTION_MIN', 30.000000, 'POINTS', 'CLASSIFICATION', N'Início da classificação Atenção.'),
('RISK_HIGH_MIN', 60.000000, 'POINTS', 'CLASSIFICATION', N'Início da classificação Alto.'),
('RISK_CRITICAL_MIN', 80.000000, 'POINTS', 'CLASSIFICATION', N'Início da classificação Crítico.');

UPDATE target
SET
    parameter_value = source.parameter_value,
    parameter_unit = source.parameter_unit,
    parameter_group = source.parameter_group,
    description_pt = source.description_pt,
    updated_at = SYSDATETIME()
FROM config.risk_parameter AS target
INNER JOIN @parameter AS source
    ON source.parameter_code = target.parameter_code;

INSERT INTO config.risk_parameter
(
    parameter_code,
    parameter_value,
    parameter_unit,
    parameter_group,
    description_pt
)
SELECT
    source.parameter_code,
    source.parameter_value,
    source.parameter_unit,
    source.parameter_group,
    source.description_pt
FROM @parameter AS source
WHERE NOT EXISTS
(
    SELECT 1
    FROM config.risk_parameter AS target
    WHERE target.parameter_code = source.parameter_code
);

DECLARE @recovery TABLE
(
    loss_code       VARCHAR(50) PRIMARY KEY,
    loss_name_pt    NVARCHAR(120),
    recovery_rate   DECIMAL(9,4),
    loss_nature     VARCHAR(20),
    description_pt  NVARCHAR(300)
);

INSERT INTO @recovery VALUES
('OVERTIME_EXCESS', N'Horas adicionais acima do orçamento', 0.5000, 'DIRECT', N'Parcela considerada recuperável com revisão de escala e cobertura.'),
('EMERGENCY_COVERAGE_EXCESS', N'Cobertura emergencial acima do orçamento', 0.4500, 'DIRECT', N'Parcela considerada recuperável com banco de cobertura e reposição mais rápida.'),
('SLA_FINANCIAL_LOSS', N'Multas e glosas de SLA', 0.3500, 'DIRECT', N'Parcela considerada recuperável com plano de correção e redução de reincidência.'),
('COMMERCIAL_DISCOUNT', N'Descontos comerciais', 0.2000, 'DIRECT', N'Parcela considerada recuperável em nova negociação comercial.'),
('OTHER_EXTRAORDINARY_COST', N'Outros custos extraordinários', 0.3000, 'DIRECT', N'Parcela estimada como controlável pela gestão operacional.'),
('ADJUSTMENT_DELAY_ESTIMATE', N'Exposição por reajuste atrasado', 0.7000, 'ESTIMATE', N'Valor estimado considerando percentual solicitado e meses de atraso.'),
('UNBILLED_SCOPE_ESTIMATE', N'Execução acima do escopo sem faturamento adicional', 0.6000, 'ESTIMATE', N'Valor estimado para horas executadas acima do contratado sem serviço adicional faturado.');

UPDATE target
SET
    loss_name_pt = source.loss_name_pt,
    recovery_rate = source.recovery_rate,
    loss_nature = source.loss_nature,
    description_pt = source.description_pt,
    updated_at = SYSDATETIME()
FROM config.loss_recovery_rate AS target
INNER JOIN @recovery AS source
    ON source.loss_code = target.loss_code;

INSERT INTO config.loss_recovery_rate
(
    loss_code,
    loss_name_pt,
    recovery_rate,
    loss_nature,
    description_pt
)
SELECT
    source.loss_code,
    source.loss_name_pt,
    source.recovery_rate,
    source.loss_nature,
    source.description_pt
FROM @recovery AS source
WHERE NOT EXISTS
(
    SELECT 1
    FROM config.loss_recovery_rate AS target
    WHERE target.loss_code = source.loss_code
);
GO

CREATE OR ALTER VIEW config.vw_current_risk_parameters
AS
SELECT
    MAX(CASE WHEN parameter_code = 'WEIGHT_FINANCIAL' THEN parameter_value END) AS weight_financial,
    MAX(CASE WHEN parameter_code = 'WEIGHT_OPERATIONAL' THEN parameter_value END) AS weight_operational,
    MAX(CASE WHEN parameter_code = 'WEIGHT_QUALITY' THEN parameter_value END) AS weight_quality,
    MAX(CASE WHEN parameter_code = 'WEIGHT_CONTRACTUAL' THEN parameter_value END) AS weight_contractual,
    MAX(CASE WHEN parameter_code = 'WEIGHT_PEOPLE' THEN parameter_value END) AS weight_people,
    MAX(CASE WHEN parameter_code = 'MARGIN_GAP_WARN' THEN parameter_value END) AS margin_gap_warn,
    MAX(CASE WHEN parameter_code = 'MARGIN_GAP_HIGH' THEN parameter_value END) AS margin_gap_high,
    MAX(CASE WHEN parameter_code = 'MARGIN_GAP_CRITICAL' THEN parameter_value END) AS margin_gap_critical,
    MAX(CASE WHEN parameter_code = 'EXTRA_COST_WARN' THEN parameter_value END) AS extra_cost_warn,
    MAX(CASE WHEN parameter_code = 'EXTRA_COST_HIGH' THEN parameter_value END) AS extra_cost_high,
    MAX(CASE WHEN parameter_code = 'EXTRA_COST_CRITICAL' THEN parameter_value END) AS extra_cost_critical,
    MAX(CASE WHEN parameter_code = 'OVERTIME_WARN' THEN parameter_value END) AS overtime_warn,
    MAX(CASE WHEN parameter_code = 'OVERTIME_HIGH' THEN parameter_value END) AS overtime_high,
    MAX(CASE WHEN parameter_code = 'OVERTIME_CRITICAL' THEN parameter_value END) AS overtime_critical,
    MAX(CASE WHEN parameter_code = 'COVERAGE_WARN' THEN parameter_value END) AS coverage_warn,
    MAX(CASE WHEN parameter_code = 'COVERAGE_HIGH' THEN parameter_value END) AS coverage_high,
    MAX(CASE WHEN parameter_code = 'COVERAGE_CRITICAL' THEN parameter_value END) AS coverage_critical,
    MAX(CASE WHEN parameter_code = 'SCOPE_OVERRUN_WARN' THEN parameter_value END) AS scope_overrun_warn,
    MAX(CASE WHEN parameter_code = 'SCOPE_OVERRUN_HIGH' THEN parameter_value END) AS scope_overrun_high,
    MAX(CASE WHEN parameter_code = 'SCOPE_OVERRUN_CRITICAL' THEN parameter_value END) AS scope_overrun_critical,
    MAX(CASE WHEN parameter_code = 'SLA_TARGET' THEN parameter_value END) AS sla_target,
    MAX(CASE WHEN parameter_code = 'SLA_HIGH' THEN parameter_value END) AS sla_high,
    MAX(CASE WHEN parameter_code = 'SLA_CRITICAL' THEN parameter_value END) AS sla_critical,
    MAX(CASE WHEN parameter_code = 'ADJUSTMENT_WARN_DAYS' THEN parameter_value END) AS adjustment_warn_days,
    MAX(CASE WHEN parameter_code = 'ADJUSTMENT_HIGH_DAYS' THEN parameter_value END) AS adjustment_high_days,
    MAX(CASE WHEN parameter_code = 'ADJUSTMENT_CRITICAL_DAYS' THEN parameter_value END) AS adjustment_critical_days,
    MAX(CASE WHEN parameter_code = 'RENEWAL_WARN_DAYS' THEN parameter_value END) AS renewal_warn_days,
    MAX(CASE WHEN parameter_code = 'RENEWAL_HIGH_DAYS' THEN parameter_value END) AS renewal_high_days,
    MAX(CASE WHEN parameter_code = 'RENEWAL_CRITICAL_DAYS' THEN parameter_value END) AS renewal_critical_days,
    MAX(CASE WHEN parameter_code = 'NON_RENEWAL_REVIEW_DAYS' THEN parameter_value END) AS non_renewal_review_days,
    MAX(CASE WHEN parameter_code = 'ABSENCE_WARN' THEN parameter_value END) AS absence_warn,
    MAX(CASE WHEN parameter_code = 'ABSENCE_HIGH' THEN parameter_value END) AS absence_high,
    MAX(CASE WHEN parameter_code = 'ABSENCE_CRITICAL' THEN parameter_value END) AS absence_critical,
    MAX(CASE WHEN parameter_code = 'VACANCY_WARN' THEN parameter_value END) AS vacancy_warn,
    MAX(CASE WHEN parameter_code = 'VACANCY_HIGH' THEN parameter_value END) AS vacancy_high,
    MAX(CASE WHEN parameter_code = 'VACANCY_CRITICAL' THEN parameter_value END) AS vacancy_critical,
    MAX(CASE WHEN parameter_code = 'REPLACEMENT_WARN_DAYS' THEN parameter_value END) AS replacement_warn_days,
    MAX(CASE WHEN parameter_code = 'REPLACEMENT_HIGH_DAYS' THEN parameter_value END) AS replacement_high_days,
    MAX(CASE WHEN parameter_code = 'REPLACEMENT_CRITICAL_DAYS' THEN parameter_value END) AS replacement_critical_days,
    MAX(CASE WHEN parameter_code = 'RISK_ATTENTION_MIN' THEN parameter_value END) AS risk_attention_min,
    MAX(CASE WHEN parameter_code = 'RISK_HIGH_MIN' THEN parameter_value END) AS risk_high_min,
    MAX(CASE WHEN parameter_code = 'RISK_CRITICAL_MIN' THEN parameter_value END) AS risk_critical_min
FROM config.risk_parameter;
GO

IF NOT EXISTS (SELECT 1 FROM dw.dim_action WHERE action_code = 'REVIEW_RETROACTIVE')
BEGIN
    INSERT INTO dw.dim_action
    (
        action_code,
        action_name_pt,
        action_category,
        default_owner_area,
        action_status
    )
    VALUES
    ('REVIEW_RETROACTIVE', 'Cobrar retroatividade do reajuste', 'COMMERCIAL', 'COMMERCIAL', 'ACTIVE');
END;
GO
