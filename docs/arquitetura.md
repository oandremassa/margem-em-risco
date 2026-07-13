# Arquitetura

O projeto separa ingestão, tratamento, modelagem e consumo. O Power BI não lê
diretamente as tabelas fato do Data Warehouse.

![Arquitetura do projeto](../assets/arquitetura.svg)

## Camadas

| Camada | Responsabilidade |
|---|---|
| `raw` | Recebe os arquivos sem aplicar regra de negócio. |
| `staging` | Converte tipos, valida domínios e registra rejeições. |
| `dw` | Mantém dimensões e fatos com chaves substitutas. |
| `mart` | Materializa margem, perdas, risco, ações e linha do tempo. |
| `bi` | Expõe somente os campos consumidos pelo Power BI. |
| Power BI | Organiza medidas, filtros, navegação e apresentação. |

## Por que os marts são materializados

A primeira implementação usava cadeias profundas de views. No SQL Server, isso
levou ao erro 8632 por limite de complexidade de expressão. A camada analítica
foi substituída por tabelas materializadas e procedimentos explícitos de
atualização.

Essa decisão deixou o fluxo mais previsível:

- o cálculo acontece no refresh do mart;
- o Power BI consulta estruturas simples;
- os testes conseguem validar o resultado gravado;
- a lógica continua rastreável no SQL.

## Modelo de atualização

Os dados são mensais. O modo Import foi escolhido porque não existe necessidade
de consulta em tempo real e o volume do case é pequeno.

A atualização segue esta ordem:

1. fundação e carga inicial;
2. marts materializados;
3. geração do histórico;
4. atualização dos marts;
5. views `bi`;
6. refresh do modelo do Power BI.
