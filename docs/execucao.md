# Execução local

## Pré-requisitos

- Windows;
- SQL Server local;
- autenticação integrada do Windows;
- `sqlcmd`;
- PowerShell 5.1 ou superior;
- Power BI Desktop com suporte a PBIP/PBIR/TMDL;
- Excel para abrir o simulador.

O projeto foi configurado para:

```text
Servidor: localhost
Banco: margem_em_risco
```

## Instalação completa

Na raiz do repositório:

```powershell
powershell `
  -ExecutionPolicy Bypass `
  -File ".\scripts\instalar.ps1"
```

O script pede a palavra `RECRIAR` antes de apagar e recriar o banco do projeto.

Para execução não interativa:

```powershell
powershell `
  -ExecutionPolicy Bypass `
  -File ".\scripts\instalar.ps1" `
  -ConfirmReset
```

Nenhum outro banco da instância é alterado.

## Validação

```powershell
powershell `
  -ExecutionPolicy Bypass `
  -File ".\scripts\validar.ps1"
```

Para validar somente os arquivos do repositório:

```powershell
powershell `
  -ExecutionPolicy Bypass `
  -File ".\scripts\validar.ps1" `
  -SkipDatabase
```

## Abrir o Power BI

```powershell
powershell `
  -ExecutionPolicy Bypass `
  -File ".\scripts\abrir-powerbi.ps1"
```

Na primeira abertura:

1. selecione autenticação Windows;
2. clique em **Atualizar**;
3. aguarde a carga;
4. teste os oito itens da lateral;
5. salve o projeto.

No modo de edição, a navegação usa `Ctrl + clique`.

## Simulador Excel

Abra:

```text
excel/margem_em_risco_premissas_e_simulador.xlsx
```

A planilha é usada para revisar premissas e testar cenários. Ela não substitui
as regras oficiais do SQL.
