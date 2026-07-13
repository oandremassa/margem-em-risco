USE margem_em_risco;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
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
    CONCAT(
        CONVERT(char(10), reference_date, 103),
        N' · ',
        event_title,
        CASE
            WHEN NULLIF(LTRIM(RTRIM(event_detail)), N'') IS NULL
                THEN N''
            ELSE CONCAT(N' — ', event_detail)
        END
    ) AS evento_resumo,
    impact_amount AS impacto_financeiro,
    source_key AS chave_origem
FROM mart.vw_contract_timeline;
GO

PRINT N'View bi.vw_linha_tempo atualizada para o Contrato 360.';
GO
