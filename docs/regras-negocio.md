# Regras de negócio

## Pergunta central

Quais contratos de alta receita estão perdendo margem, por que isso acontece e
qual ação deve ser priorizada?

## Margem

A margem de contribuição é calculada por contrato e competência:

```text
margem de contribuição = receita líquida - custo total
margem % = margem de contribuição / receita líquida
```

O gap compara a margem realizada com a meta contratual.

## Perdas de margem

A ponte de perdas separa valores observados de estimativas.

**Perdas observadas**

- horas adicionais acima do orçamento;
- cobertura emergencial;
- multas e glosas;
- descontos;
- custos extraordinários.

**Estimativas**

- exposição por reajuste atrasado;
- execução de escopo sem faturamento adicional.

A coluna de estimativa impede que os dois grupos sejam tratados com o mesmo grau
de certeza.

## Score de risco

O score é determinístico e permanece entre 0 e 100.

| Pilar | Peso |
|---|---:|
| Financeiro | 35% |
| Operacional | 25% |
| Qualidade | 15% |
| Contratual | 15% |
| Pessoas | 10% |

Os componentes ficam disponíveis por contrato. O objetivo é explicar a nota,
não apenas classificá-la.

O score **não é machine learning**, não prevê inadimplência e não substitui a
decisão do gestor.

## Receita em risco

A Central Executiva usa um horizonte de 90 dias:

```text
receita em risco = receita mensal dos contratos com score >= 60 × 3
```

## Valor recuperável

O valor recuperável aplica taxas de recuperação por causa de perda. As taxas
ficam documentadas na planilha de premissas e nas regras do SQL.

É um cenário gerencial, não uma promessa de recuperação.

## Fila de ação

A recomendação principal é definida por precedência de regras. A prioridade
combina:

- criticidade;
- impacto financeiro;
- urgência contratual;
- possibilidade de recuperação.

| Situação | Recomendação |
|---|---|
| cobertura baixa e pressão de horas extras | reforçar cobertura |
| reajuste atrasado | cobrar retroatividade ou solicitar reajuste |
| escopo executado sem faturamento | formalizar escopo |
| reincidência de SLA | plano de recuperação |
| margem negativa próxima da renovação | avaliar não renovação |
| contrato saudável | manter ou avaliar expansão |

## Efeito das ações

Para ações concluídas, o projeto compara até três meses antes do início com até
três meses depois da conclusão.

A diferença é tratada como resultado observado. O case não afirma causalidade
estatística.
