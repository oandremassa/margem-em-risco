# Dicionário de dados

Este documento descreve os campos expostos no modelo semântico. Campos ocultos
são mantidos para relacionamentos e ordenação.

## Calendário

**Granularidade:** Um registro por dia  
**Origem:** `vw_calendario`  
**Uso:** Filtros de tempo e cálculos temporais.

| Campo | Tipo | Coluna de origem | Visibilidade |
|---|---|---|---|
| Data | dateTime | `data` | Visível |
| Chave Data | int64 | `chave_data` | Oculto |
| Início do Mês | dateTime | `inicio_mes` | Visível |
| Número do Mês | int64 | `numero_mes` | Visível |
| Mês | string | `mes` | Visível |
| Trimestre | int64 | `trimestre` | Visível |
| Ano | int64 | `ano` | Visível |
| Ano-Mês | string | `ano_mes` | Visível |
| Dia Útil | boolean | `dia_util` | Visível |

## Contratos

**Granularidade:** Um registro por contrato vigente  
**Origem:** `vw_contratos`  
**Uso:** Dimensão conformada para cliente, serviço, gestor e atributos contratuais.

| Campo | Tipo | Coluna de origem | Visibilidade |
|---|---|---|---|
| Chave Contrato | int64 | `chave_contrato` | Oculto |
| Código Contrato | string | `codigo_contrato` | Visível |
| Cliente | string | `cliente` | Visível |
| Segmento | string | `segmento` | Visível |
| Serviço | string | `servico` | Visível |
| Gestor | string | `gestor` | Visível |
| Complexidade | string | `complexidade` | Visível |
| Data Renovação | dateTime | `data_renovacao` | Visível |
| Meta Margem % | decimal | `meta_margem_pct` | Visível |

## Desempenho Mensal

**Granularidade:** Um registro por contrato e competência  
**Origem:** `vw_desempenho_mensal`  
**Uso:** Receita, custo, margem, operação, pessoas, SLA e reajustes.

| Campo | Tipo | Coluna de origem | Visibilidade |
|---|---|---|---|
| Mês Referência | dateTime | `mes_referencia` | Visível |
| Chave Data | int64 | `chave_data` | Oculto |
| Chave Contrato | int64 | `chave_contrato` | Oculto |
| Código Contrato | string | `codigo_contrato` | Visível |
| Cliente | string | `cliente` | Visível |
| Segmento | string | `segmento` | Visível |
| Serviço | string | `servico` | Visível |
| Gestor | string | `gestor` | Visível |
| Complexidade | string | `complexidade` | Visível |
| Data Renovação | dateTime | `data_renovacao` | Visível |
| Dias para Renovação | int64 | `dias_para_renovacao` | Visível |
| Meta Margem % | decimal | `meta_margem_pct` | Visível |
| Receita Bruta | decimal | `receita_bruta` | Visível |
| Receita Líquida | decimal | `receita_liquida` | Visível |
| Custo Total | decimal | `custo_total` | Visível |
| Margem Contribuição | decimal | `margem_contribuicao` | Visível |
| Margem % | decimal | `margem_pct` | Visível |
| Gap Margem % | decimal | `gap_margem_pct` | Visível |
| Vazamento Margem | decimal | `vazamento_margem` | Visível |
| Postos Previstos | decimal | `postos_previstos` | Visível |
| Postos Ocupados | decimal | `postos_ocupados` | Visível |
| Postos Descobertos | decimal | `postos_descobertos` | Visível |
| Cobertura % | decimal | `cobertura_pct` | Visível |
| Horas Previstas | decimal | `horas_previstas` | Visível |
| Horas Regulares | decimal | `horas_regulares` | Visível |
| Horas Extras | decimal | `horas_extras` | Visível |
| Horas Extras % | decimal | `horas_extras_pct` | Visível |
| Horas Ausência | decimal | `horas_ausencia` | Visível |
| Absenteísmo % | decimal | `absenteismo_pct` | Visível |
| Vagas Abertas | int64 | `vagas_abertas` | Visível |
| Dias Reposição | decimal | `dias_reposicao` | Visível |
| Quantidade Ocorrências | int64 | `quantidade_ocorrencias` | Visível |
| Ocorrências Críticas | int64 | `ocorrencias_criticas` | Visível |
| Ocorrências Reincidentes | int64 | `ocorrencias_reincidentes` | Visível |
| SLA % | decimal | `sla_pct` | Visível |
| Reajustes Abertos | int64 | `reajustes_abertos` | Visível |
| Tendência Margem | string | `tendencia_margem` | Visível |
| Score Risco | decimal | `score_risco` | Visível |
| Classe Risco | string | `classe_risco` | Visível |

## Efeito das Ações

**Granularidade:** Um registro por ação concluída  
**Origem:** `vw_efeito_acoes`  
**Uso:** Comparação antes/depois de ações concluídas.

| Campo | Tipo | Coluna de origem | Visibilidade |
|---|---|---|---|
| Chave Ação | int64 | `chave_acao` | Oculto |
| Chave Contrato | int64 | `chave_contrato` | Oculto |
| Código Contrato | string | `codigo_contrato` | Visível |
| Código Ação | string | `codigo_acao` | Visível |
| Ação | string | `acao` | Visível |
| Data Início | dateTime | `data_inicio` | Visível |
| Data Conclusão | dateTime | `data_conclusao` | Visível |
| Margem Antes % | decimal | `margem_antes_pct` | Visível |
| Margem Depois % | decimal | `margem_depois_pct` | Visível |
| Variação Margem p.p. | decimal | `variacao_margem_pp` | Visível |
| Horas Extras Antes % | decimal | `horas_extras_antes_pct` | Visível |
| Horas Extras Depois % | decimal | `horas_extras_depois_pct` | Visível |
| Cobertura Antes % | decimal | `cobertura_antes_pct` | Visível |
| Cobertura Depois % | decimal | `cobertura_depois_pct` | Visível |
| SLA Antes % | decimal | `sla_antes_pct` | Visível |
| SLA Depois % | decimal | `sla_depois_pct` | Visível |
| Impacto Realizado | decimal | `impacto_realizado` | Visível |

## Fatores de Risco

**Granularidade:** Um registro por contrato, competência e fator  
**Origem:** `vw_fatores_risco`  
**Uso:** Componentes explicáveis do score.

| Campo | Tipo | Coluna de origem | Visibilidade |
|---|---|---|---|
| Mês Referência | dateTime | `mes_referencia` | Visível |
| Chave Contrato | int64 | `chave_contrato` | Oculto |
| Código Contrato | string | `codigo_contrato` | Visível |
| Pilar Risco | string | `pilar_risco` | Visível |
| Código Fator | string | `codigo_fator` | Visível |
| Fator Risco | string | `fator_risco` | Visível |
| Valor Observado | decimal | `valor_observado` | Visível |
| Valor Referência | decimal | `valor_referencia` | Visível |
| Pontuação Fator | decimal | `pontuacao_fator` | Visível |
| Impacto Estimado | decimal | `impacto_estimado` | Visível |
| Ordem Fator | int64 | `ordem_fator` | Visível |

## Fila de Ações

**Granularidade:** Um registro por contrato na fila atual  
**Origem:** `vw_fila_acoes`  
**Uso:** Recomendação principal, justificativa, impacto e prioridade.

| Campo | Tipo | Coluna de origem | Visibilidade |
|---|---|---|---|
| Mês Referência | dateTime | `mes_referencia` | Visível |
| Chave Contrato | int64 | `chave_contrato` | Oculto |
| Código Contrato | string | `codigo_contrato` | Visível |
| Cliente | string | `cliente` | Visível |
| Margem % | decimal | `margem_pct` | Visível |
| Score Risco | decimal | `score_risco` | Visível |
| Classe Risco | string | `classe_risco` | Visível |
| Código Ação | string | `codigo_acao` | Visível |
| Ação Recomendada | string | `acao_recomendada` | Visível |
| Justificativa | string | `justificativa` | Visível |
| Impacto Ação | decimal | `impacto_acao` | Visível |
| Valor Recuperável | decimal | `valor_recuperavel` | Visível |
| Score Prioridade | decimal | `score_prioridade` | Visível |
| Prioridade | int64 | `prioridade` | Visível |

## Linha do Tempo

**Granularidade:** Um registro por evento de contrato  
**Origem:** `vw_linha_tempo`  
**Uso:** Eventos operacionais, comerciais e gerenciais por contrato.

| Campo | Tipo | Coluna de origem | Visibilidade |
|---|---|---|---|
| Chave Evento | int64 | `chave_evento` | Oculto |
| Data Evento | dateTime | `data_evento` | Visível |
| Mês Referência | dateTime | `mes_referencia` | Visível |
| Chave Contrato | int64 | `chave_contrato` | Oculto |
| Código Contrato | string | `codigo_contrato` | Visível |
| Tipo Evento | string | `tipo_evento` | Visível |
| Gravidade | string | `gravidade` | Visível |
| Título Evento | string | `titulo_evento` | Visível |
| Detalhe Evento | string | `detalhe_evento` | Visível |
| Impacto Financeiro | decimal | `impacto_financeiro` | Visível |
| Chave Origem | int64 | `chave_origem` | Oculto |
| Evento Resumo | string | `evento_resumo` | Visível |

## Métricas

**Granularidade:** Tabela calculada sem granularidade física  
**Origem:** `Tabela calculada`  
**Uso:** Medidas DAX centralizadas e organizadas por pasta.

## Perdas de Margem

**Granularidade:** Um registro por contrato, competência e causa de perda  
**Origem:** `vw_perdas_margem`  
**Uso:** Ponte entre causas, perda identificada e recuperação possível.

| Campo | Tipo | Coluna de origem | Visibilidade |
|---|---|---|---|
| Mês Referência | dateTime | `mes_referencia` | Visível |
| Chave Contrato | int64 | `chave_contrato` | Oculto |
| Código Contrato | string | `codigo_contrato` | Visível |
| Código Perda | string | `codigo_perda` | Visível |
| Causa Perda | string | `causa_perda` | Visível |
| Natureza Perda | string | `natureza_perda` | Visível |
| Valor Perda | decimal | `valor_perda` | Visível |
| Taxa Recuperação | decimal | `taxa_recuperacao` | Visível |
| Valor Recuperável | decimal | `valor_recuperavel` | Visível |
| Observação Cálculo | string | `observacao_calculo` | Visível |

## Portfólio Atual

**Granularidade:** Um registro por contrato na competência mais recente  
**Origem:** `vw_portfolio_atual`  
**Uso:** Fotografia atual usada nos cards, dispersões e priorização.

| Campo | Tipo | Coluna de origem | Visibilidade |
|---|---|---|---|
| Mês Referência | dateTime | `mes_referencia` | Visível |
| Chave Contrato | int64 | `chave_contrato` | Oculto |
| Código Contrato | string | `codigo_contrato` | Visível |
| Cliente | string | `cliente` | Visível |
| Segmento | string | `segmento` | Visível |
| Serviço | string | `servico` | Visível |
| Gestor | string | `gestor` | Visível |
| Complexidade | string | `complexidade` | Visível |
| Receita Líquida | decimal | `receita_liquida` | Visível |
| Margem Contribuição | decimal | `margem_contribuicao` | Visível |
| Margem % | decimal | `margem_pct` | Visível |
| Meta Margem % | decimal | `meta_margem_pct` | Visível |
| Gap Margem % | decimal | `gap_margem_pct` | Visível |
| Vazamento Margem | decimal | `vazamento_margem` | Visível |
| Score Risco | decimal | `score_risco` | Visível |
| Classe Risco | string | `classe_risco` | Visível |
| Risco Financeiro | decimal | `risco_financeiro` | Visível |
| Risco Operacional | decimal | `risco_operacional` | Visível |
| Risco Qualidade | decimal | `risco_qualidade` | Visível |
| Risco Contratual | decimal | `risco_contratual` | Visível |
| Risco Pessoas | decimal | `risco_pessoas` | Visível |
| Tendência Margem | string | `tendencia_margem` | Visível |
| Data Renovação | dateTime | `data_renovacao` | Visível |
| Dias para Renovação | int64 | `dias_para_renovacao` | Visível |
| Principal Fator Risco | string | `principal_fator_risco` | Visível |
| Impacto Principal Fator | decimal | `impacto_principal_fator` | Visível |
| Código Ação | string | `codigo_acao` | Visível |
| Ação Recomendada | string | `acao_recomendada` | Visível |
| Valor Recuperável | decimal | `valor_recuperavel` | Visível |
| Prioridade | int64 | `prioridade` | Visível |

## Resumo Executivo

**Granularidade:** Um registro por competência  
**Origem:** `vw_resumo_executivo`  
**Uso:** Agregados mensais do portfólio.

| Campo | Tipo | Coluna de origem | Visibilidade |
|---|---|---|---|
| Mês Referência | dateTime | `mes_referencia` | Visível |
| Contratos Ativos | int64 | `contratos_ativos` | Visível |
| Receita Líquida | decimal | `receita_liquida` | Visível |
| Custo Total | decimal | `custo_total` | Visível |
| Margem Contribuição | decimal | `margem_contribuicao` | Visível |
| Margem % | decimal | `margem_pct` | Visível |
| Vazamento Margem | decimal | `vazamento_margem` | Visível |
| Perda Identificada | decimal | `perda_identificada` | Visível |
| Valor Recuperável | decimal | `valor_recuperavel` | Visível |
| Receita em Risco | decimal | `receita_em_risco` | Visível |
| Contratos Críticos | int64 | `contratos_criticos` | Visível |
| Contratos Alto Risco | int64 | `contratos_alto_risco` | Visível |
| Contratos com Ação | int64 | `contratos_com_acao` | Visível |

## Medidas DAX

| Medida | Pasta | Formato |
|---|---|---|
| Receita Líquida Atual | Executivo | `R$ #,##0;[Red]-R$ #,##0` |
| Margem Atual | Executivo | `0.0%` |
| Receita em Risco Atual | Executivo | `R$ #,##0;[Red]-R$ #,##0` |
| Valor Recuperável Atual | Executivo | `R$ #,##0;[Red]-R$ #,##0` |
| Contratos Críticos | Executivo | `0` |
| Contratos com Ação | Executivo | `0` |
| Receita Líquida | Financeiro | `R$ #,##0;[Red]-R$ #,##0` |
| Custo Total | Financeiro | `R$ #,##0;[Red]-R$ #,##0` |
| Margem de Contribuição | Financeiro | `R$ #,##0;[Red]-R$ #,##0` |
| Margem % | Financeiro | `0.0%` |
| Meta Margem Ponderada | Financeiro | `0.0%` |
| Gap de Margem p.p. | Financeiro | `0.0` |
| Vazamento de Margem | Financeiro | `R$ #,##0;[Red]-R$ #,##0` |
| Perda Identificada | Financeiro | `R$ #,##0;[Red]-R$ #,##0` |
| Valor Recuperável | Financeiro | `R$ #,##0;[Red]-R$ #,##0` |
| Score de Risco Ponderado | Risco | `0.0` |
| Cobertura % | Operação | `0.0%` |
| Horas Extras % | Operação | `0.0%` |
| Absenteísmo % | Operação | `0.0%` |
| SLA % | Operação | `0.0%` |
| Margem % Mês Anterior | Tempo | `0.0%` |
| Variação Margem p.p. | Tempo | `0.0` |
| Receita Líquida 12M | Tempo | `R$ #,##0;[Red]-R$ #,##0` |
| Período Selecionado | Contexto | `padrão` |
| Margem Contrato Atual | Visualizações\Portfólio | `0.0%` |
| Score Risco Atual | Visualizações\Portfólio | `0.0` |
| Receita Contrato Atual | Visualizações\Portfólio | `R$ #,##0;[Red]-R$ #,##0` |
| Margem Fila | Visualizações\Fila de Ações | `0.0%` |
| Score Risco Fila | Visualizações\Fila de Ações | `0.0` |
| Valor Recuperável Fila | Visualizações\Fila de Ações | `R$ #,##0;[Red]-R$ #,##0` |
| Impacto Ação Fila | Visualizações\Fila de Ações | `R$ #,##0;[Red]-R$ #,##0` |
| Dias para Renovação Atual | Contrato 360 | `0` |
| Pontuação Fator Atual | Contrato 360 | `0.0` |
| Impacto Fator Atual | Contrato 360 | `R$ #,##0;[Red]-R$ #,##0` |
| Impacto Evento | Contrato 360 | `R$ #,##0;[Red]-R$ #,##0` |
| Cobertura Atual | Eficiência Operacional | `0.0%` |
| Horas Extras Atual | Eficiência Operacional | `0.0%` |
| Absenteísmo Atual | Eficiência Operacional | `0.0%` |
| Postos Descobertos Atual | Eficiência Operacional | `0` |
| Vagas Abertas Atual | Eficiência Operacional | `0` |
| SLA Atual | Qualidade e SLA | `0.0%` |
| Ocorrências Atual | Qualidade e SLA | `0` |
| Ocorrências Críticas Atual | Qualidade e SLA | `0` |
| Ocorrências Reincidentes Atual | Qualidade e SLA | `0` |
| Risco Qualidade Atual | Qualidade e SLA | `0.0` |
| Meta SLA | Qualidade e SLA | `0.0%` |
| Contratos Renovação 90d | Reajustes e Renovação | `0` |
| Receita Renovação 90d | Reajustes e Renovação | `R$ #,##0;[Red]-R$ #,##0` |
| Reajustes Abertos Atual | Reajustes e Renovação | `0` |
| Contratos com Reajuste Aberto Atual | Reajustes e Renovação | `0` |
| Valor Recuperável Renovação 90d | Reajustes e Renovação | `R$ #,##0;[Red]-R$ #,##0` |
| Reajustes Abertos | Reajustes e Renovação | `0` |
| Contratos com Reajuste Aberto | Reajustes e Renovação | `0` |
| Dias Renovação Contrato | Reajustes e Renovação | `0` |
| Valor Recuperável Contrato | Reajustes e Renovação | `R$ #,##0;[Red]-R$ #,##0` |
| Ações Concluídas | Efeito das Ações | `0` |
| Impacto Realizado | Efeito das Ações | `R$ #,##0;[Red]-R$ #,##0` |
| Margem Antes Média | Efeito das Ações | `0.0%` |
| Margem Depois Média | Efeito das Ações | `0.0%` |
| Ganho Margem p.p. | Efeito das Ações | `0.0` |
| Ganho SLA p.p. | Efeito das Ações | `0.0` |
| Ganho Cobertura p.p. | Efeito das Ações | `0.0` |
| Redução Horas Extras p.p. | Efeito das Ações | `0.0` |
