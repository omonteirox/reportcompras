# Naming Conventions — SAP Public Cloud Edition

> **Obrigatório**: Todo objeto criado deve seguir estas convenções. Objetos fora do padrão serão rejeitados no code review.

## Namespaces

| Namespace | Uso |
|-----------|-----|
| `Z` | Objetos custom do cliente (padrão principal) |
| `Y` | Alternativo ao Z (menos comum) |
| `Z<NS>_` | Adicione sigla de 2-3 letras do módulo/área (ex: `ZMM_`, `ZSD_`, `ZFI_`, `ZHR_`) |

## Tabelas de Banco de Dados

```
Z<MÓDULO>_<ENTIDADE>
Exemplos:
  ZMM_PURCHASE_REQ        ← Purchase Requisition (MM)
  ZSD_CUSTOMER_DISCOUNT   ← Customer Discount (SD)
  ZFI_COST_CENTER_NOTE    ← Cost Center Note (FI)
```

**Campos obrigatórios em toda tabela transacional:**
```abap
  key mandt          TYPE mandt,         " Cliente SAP (mandante)
  key <entidade>_uuid TYPE sysuuid_x16,  " UUID como chave primária
      <entidade>_id   TYPE char20,        " ID legível (numeração gerenciada pelo RAP)
      created_by      TYPE abp_creation_user,
      created_at      TYPE abp_creation_tstmpl,
      last_changed_by TYPE abp_locinst_lastchange_user,
      last_changed_at TYPE abp_lastchange_tstmpl,
      local_last_changed_at TYPE abp_locinst_lastchange_tstmpl,
```

## CDS Views

| Tipo | Padrão | Exemplo |
|------|--------|---------|
| Interface (base) | `ZI_<Entidade>` | `ZI_PurchaseReq` |
| Projection (consumo/UI) | `ZC_<Entidade>` | `ZC_PurchaseReq` |
| View auxiliar/restrita | `ZR_<Entidade>` | `ZR_PurchaseReqHelper` |
| Extension view | `ZE_<Entidade>` | `ZE_SalesOrder` |
| Value Help | `ZVH_<Entidade>` | `ZVH_Material` |

## Behavior Definitions & Implementations

| Objeto | Padrão | Exemplo |
|--------|--------|---------|
| BDEF interface | `ZI_<Entidade>` | (mesmo nome da CDS) |
| BDEF projection | `ZC_<Entidade>` | (mesmo nome da CDS) |
| Behavior Impl. Class | `ZBP_<Entidade>` | `ZBP_PurchaseReq` |

## Classes ABAP

| Tipo | Padrão | Exemplo |
|------|--------|---------|
| Classe de negócio | `ZCL_<NS>_<Descricao>` | `ZCL_MM_PO_PROCESSOR` |
| Classe de report | `ZCL_<NS>R_<Descricao>` | `ZCL_MMR_OPEN_PO` |
| Classe de exception | `ZCX_<NS>_<Descricao>` | `ZCX_MM_PO_ERROR` |
| Interface | `ZIF_<NS>_<Descricao>` | `ZIF_MM_PO_HANDLER` |
| Classe de teste | `ZTEST_<NS>_<Descricao>` | `ZTEST_MM_PO_PROCESSOR` |

## BAdI Implementations

| Objeto | Padrão | Exemplo |
|--------|--------|---------|
| Enhancement Implementation | `ZENH_<NS>_<Processo>` | `ZENH_SD_SALES_ORDER` |
| BAdI Implementation | `ZIMPL_<BADI_NAME>` | `ZIMPL_SD_SALES_ORDER_SAVE` |
| Classe de Impl. BAdI | `ZCL_IMPL_<BADI_NAME>` | `ZCL_IMPL_SD_ORDER_SAVE` |

## Reports

| Objeto | Padrão | Exemplo |
|--------|--------|---------|
| Report executável | `Z<NS>R_<Descricao>` | `ZMMR_OPEN_PO_LIST` |

## Service Definitions & Bindings

| Objeto | Padrão | Exemplo |
|--------|--------|---------|
| Service Definition | `ZUI_<Entidade>_O[2\|4]` | `ZUI_PurchaseReq_O4` |
| Service Binding (UI) | `ZUI_<Entidade>_O[2\|4]` | `ZUI_PurchaseReq_O4` |
| Service Binding (API) | `ZAPI_<Entidade>_O[2\|4]` | `ZAPI_PurchaseReq_O4` |

## Regras Gerais

1. **Sempre maiúsculas** para objetos ABAP (tabelas, classes, programas)
2. **CamelCase** para nomes de campos em CDS views
3. **snake_case** para campos de tabelas de banco de dados
4. **Máximo 30 caracteres** para nomes de objetos (limitação do ABAP Dictionary)
5. **Sem abreviações ambíguas** — prefira nomes descritivos mesmo que mais longos
6. **Não use o namespace do objeto standard** (ex: nunca `ZI_SalesOrder` se já existe `I_SalesOrder`)
