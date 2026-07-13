# Validação

O projeto possui testes em três níveis.

## 1. Carga e estrutura

A carga inicial verifica:

- schemas e objetos obrigatórios;
- chaves e restrições;
- registros válidos e rejeitados;
- reprocessamento sem duplicidade.

## 2. Regras de negócio

Os testes do SQL conferem casos controlados, incluindo:

- contrato com margem negativa;
- reajuste atrasado;
- escopo não faturado;
- falha crítica de SLA;
- contrato saudável;
- pressão operacional antes da queda de margem.

## 3. Reconciliação final

`sql/tests/501_validate_portfolio.sql` verifica:

| Verificação | Resultado esperado |
|---|---:|
| Dias de calendário | 730 |
| Contratos | 10 |
| Contrato-mês | 240 |
| Competência mais recente | 2026-06 |
| Linhas no portfólio atual | 10 |
| Duplicidade contrato-mês | 0 |
| Classes de risco fora do domínio | 0 |
| Diferença de receita entre mensal e portfólio | 0 |
| Diferença de margem entre mensal e portfólio | 0 |

O mesmo script apresenta receita, margem, receita em risco de 90 dias e valor
recuperável na competência atual.

## Testes visuais

Depois do refresh do Power BI, confira:

- oito páginas;
- menu lateral em todas as páginas;
- 24 competências nas séries temporais;
- 10 contratos nas visões de portfólio;
- filtros de serviço, gestor, cliente e contrato;
- cards sem valores vazios;
- classes de risco em português;
- tabelas sem hierarquia colapsada.
