# Clean Core & BAdI: Extensões RAP, CDS e BAdI sem tocar no Standard SAP

> Domínio: `badis` | Fonte: Loyalty Hub Gift Card Extension + BAdIs Fundamentals

## Princípio Clean Core

### O que significa
Clean Core é a capacidade de manter o núcleo do S/4HANA Cloud **sem modificações diretas no código SAP standard**, garantindo que cada upgrade semestral seja aplicado sem quebras.

### Por que importa no S/4HANA Cloud
- Upgrades automáticos semestrais sobrescrevem qualquer modificação ao standard
- Código custom misturado ao standard bloqueia novos recursos e correções
- SAP certifica apenas extensões via pontos de extensão oficiais

### Os três pilares do Clean Core
1. **Nunca modificar** código SAP padrão (tabelas, classes, views, BDEFs)
2. **Usar apenas APIs Released** (check via `@AbapCatalog.sqlViewAppendName` ou ABAP Test Cockpit)
3. **Sobreviver ao upgrade**: toda extensão deve funcionar após o upgrade semestral

---

## Hierarquia de Extensibilidade

```
┌─────────────────────────────────────────────────────────┐
│  1. Key User Tools (Low-code/no-code)                   │
│     • Custom Fields & Logic App                         │
│     • Business Rules                                    │
│     • Adaptation Transport Organizer                    │
├─────────────────────────────────────────────────────────┤
│  2. In-App Extensibility (Developer/ABAP Cloud)         │
│     • BAdI Implementations                             │
│     • RAP Extensions (BDEF Extension)                  │
│     • CDS Extensions (DDLX / extend view)              │
│     • Append Structures                                 │
├─────────────────────────────────────────────────────────┤
│  3. Side-by-Side Extensibility (BTP)                    │
│     • Apps no BTP/CAP                                   │
│     • APIs de integração                               │
│     • Event-driven via SAP Event Mesh                  │
└─────────────────────────────────────────────────────────┘
```

**Regra**: usar sempre a camada mais baixa possível. BAdI antes de side-by-side.

---

## Como Implementar um BAdI

### Passo 1: Encontrar o Enhancement Spot
1. No ADT, ir em **Project Explorer → ABAP Repository** 
2. Buscar pelo Enhancement Spot no contexto do processo de negócio
3. Usar transação `SE18` (on-premise) ou ADT BAdI Enhancement Spot no Cloud

### Passo 2: Criar BAdI Enhancement Implementation (SIA*)
Tipos de SIA conforme o BAdI:

| Tipo de objeto | Sigla | Uso                                      |
|----------------|-------|------------------------------------------|
| BAdI Implementation (classic) | `SIA1` | Business Catalogs customizados    |
| BAdI Enhancement Implementation | `SIA2` | Implementação de BAdI standard    |
| BAdI Implementation Class | `SIA3` | Classe de implementação             |
| BAdI RAP Extension | `SIA5` | RAP BO extensions                   |
| IAM App BAdI | `SIA6` | App-level BAdIs                         |

### Passo 3: Implementar a classe

```abap
-- Classe que implementa o BAdI:
CLASS zcl_my_badi_impl DEFINITION PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_badi_interface.
    INTERFACES zif_my_badi.  -- interface do BAdI
ENDCLASS.

CLASS zcl_my_badi_impl IMPLEMENTATION.
  METHOD zif_my_badi~my_method.
    -- Lógica de extensão aqui:
    -- NÃO usar MODIFY em tabelas standard
    -- NÃO fazer SELECT em tabelas sem API Released
    result = VALUE #( ... ).
  ENDMETHOD.
ENDCLASS.
```

### Passo 4: Chamar o BAdI em código custom
```abap
-- Obter instância do BAdI:
DATA(badi_obj) = cl_badi_resolver=>create_badi_instance( badi_name = 'MY_BADI' ).

-- Chamar método:
CALL BADI badi_obj->my_method
  EXPORTING input_data = my_data
  IMPORTING result     = my_result.
```

---

## RAP Extension: Estender um BO Standard

### Cenário real: Gift Card em Sales Order
O Loyalty Hub estende o Sales Order standard para suportar resgate de gift cards — sem tocar numa linha do código SAP.

### Camadas da extensão RAP (E/R/I/C)

```
E_SalesDocumentBasic  ← Append Structure (persistência)
      ↓
R_SalesOrderTP        ← extend view (camada R)
      ↓
I_SalesOrderTP        ← extend view (camada I)
      ↓
C_SalesOrderManage    ← extend view (camada C, com UI)
      ↓
ZLH_GIFTCARD_EXT      ← BDEF extension (behavior)
```

### 1. Append Structure (persistência)
```abap
@EndUserText.label : 'Sales Order Extension for Gift Card Fields'
@AbapCatalog.enhancement.category : #NOT_EXTENSIBLE
extend type sdsalesdoc_incl_eew_ps with zlh_salesorder_append {
  @Semantics.amount.currencyCode : 'zlh_salesorder_append.zzlh_giftcardcurrency_sdh'
  zzlh_giftcardamount_sdh   : zlh_giftcardamt;
  zzlh_giftcardcurrency_sdh : abap.cuky;
}
```

### 2. CDS Extension — extend view
```cds
-- Estender view E (base/persistência):
extend view entity E_SalesDocumentBasic
  with association [0..1] to I_Currency as _zz_giftcardcurrency_sdh
    on $projection.zz_giftcardcurrency_sdh = _zz_giftcardcurrency_sdh.Currency {
  @Semantics.amount.currencyCode: 'zz_giftcardcurrency_sdh'
  Persistence.zzlh_giftcardamount_sdh  as zz_giftcardamount_sdh,
  Persistence.zzlh_giftcardcurrency_sdh as zz_giftcardcurrency_sdh,
  _zz_giftcardcurrency_sdh
}

-- Estender view R (camada RAP):
extend view entity R_SalesOrderTP with {
  _Extension.zz_giftcardamount_sdh   as zz_giftcardamount_sdh,
  _Extension.zz_giftcardcurrency_sdh as zz_giftcardcurrency_sdh
}

-- Estender view I (interface pública):
extend view entity I_SalesOrderTP with {
  SalesOrder.zz_giftcardamount_sdh   as zz_giftcardamount_sdh,
  SalesOrder.zz_giftcardcurrency_sdh as zz_giftcardcurrency_sdh
}
```

### 3. BDEF Extension — Estender o Behavior
```abap
extension using interface i_salesordertp
implementation in class zcl_lh_giftcard_ext unique;

-- Estender autorização:
extend own authorization context {
  'ZLOYLTYHUB';
}

extend behavior for SalesOrder {
  -- Adicionar action customizada:
  action ( authorization : update, features : instance ) zz_use_gift_card
    parameter ZLH_D_AssignGiftCardToSO result [0..1] $self;

  -- Campos readonly (display-only, preenchidos pela action):
  field(readonly) zz_giftcardamount_sdh, zz_giftcardcurrency_sdh;

  -- Side effects da action:
  side effects {
    action zz_use_gift_card affects entity _Item, entity _PricingElement;
  }
}
```

### 4. Projection Extension — UI com botão
```cds
@EndUserText.label: 'Sales Order Projection View Extension'
extend view C_SalesOrderManage with ZLH_C_SALESORDERMANAGE_EXT
  association [0..1] to I_Currency as _zz_giftcardcurrency_sdh
    on $projection.zz_giftcardcurrency_sdh = _zz_giftcardcurrency_sdh.Currency {
  @UI.identification: [{ type: #FOR_ACTION, dataAction: 'zz_use_gift_card',
                         label: 'Use Gift Card' }]
  @UI.lineItem: [{ position: 65, importance: #HIGH }]
  SalesOrder.zz_giftcardamount_sdh   as zz_giftcardamount_sdh,
  SalesOrder.zz_giftcardcurrency_sdh as zz_giftcardcurrency_sdh,
  _zz_giftcardcurrency_sdh
}
```

---

## Checklist Clean Core

### O que NUNCA fazer
- ❌ Modificar tabelas SAP standard diretamente (via SE11 ou ABAP)
- ❌ Usar includes SAP standard (MO..., MB...) com código custom
- ❌ Chamar métodos ou FMs com status `Not Released` ou `Internal Use Only`
- ❌ Acessar tabelas SAP sem API Released (`SELECT FROM MARA` sem CDS API)
- ❌ Modificar código de comportamento SAP (BDEF, classes padrão)
- ❌ Usar `ASSIGN COMPONENT` em tabelas internas de estruturas SAP não documentadas

### O que SEMPRE fazer
- ✅ Usar apenas APIs with release status `Released` ou `#MIGRATION_DEVELOPMENT`
- ✅ Usar ABAP Test Cockpit (ATC) para verificar conformidade Clean Core antes de transportar
- ✅ Usar `extend type` para adicionar campos a estruturas SAP
- ✅ Usar `extend view entity` para adicionar campos a views SAP
- ✅ Usar BDEF extension para adicionar comportamento a BOs SAP
- ✅ Usar BAdI implementations para hooks em processos standard
- ✅ Prefixar todos os objetos custom com namespace (`ZLH_`, `Z_`, `Y_`)

---

## Como usar ABAP Test Cockpit (ATC) para Clean Core

### Executar ATC no ADT
1. No ADT, selecionar o objeto ABAP
2. Right-click → **Run As → ABAP Test Cockpit**
3. Selecionar a check variant: **SAP_CLOUD_READINESS**

### Checks críticos de Clean Core
- **CL_ABAP_UNIT**: uso de APIs não released
- **CDS_EXTENSIBILITY**: acesso a campos sem release
- **ABAP_CLOUD**: sintaxe ABAP incompatível com Cloud

### Exemplo de resultado a corrigir
```
ERROR: Access to non-released API 'MARA~MATNR' is not allowed.
FIX:   Use released CDS view I_MaterialStockTP instead.
```

---

## Convenções de Naming para Extensões

| Tipo de extensão          | Padrão de nome          | Exemplo                        |
|---------------------------|-------------------------|--------------------------------|
| Append Structure          | `ZLH_<TABELA>_APPEND`  | `ZLH_SALESORDER_APPEND`        |
| CDS Extension (E layer)   | `ZLH_E_<ENTIDADE>_EXT` | `ZLH_E_SALESDOCUMENT_EXT`      |
| CDS Extension (R layer)   | `ZLH_R_<ENTIDADE>_EXT` | `ZLH_R_SALESORDERTP_EXT`       |
| BDEF Extension            | `ZLH_<BDEF>_EXT`       | `ZLH_GIFTCARD_EXT`             |
| Behavior Handler Class    | `ZCL_LH_<ENTIDADE>_EXT`| `ZCL_LH_GIFTCARD_EXT`          |
| Projection Extension      | `ZLH_C_<TELA>_EXT`     | `ZLH_C_SALESORDERMANAGE_EXT`   |

---

## Fluxo Completo de Extensão RAP

```
1. Criar Append Structure (zz_campos na tabela include)
2. Estender view E_ (expose persistência)
3. Estender view R_ (camada RAP)
4. Estender view I_ (API pública)
5. Criar BDEF Extension (action + field control)
6. Implementar handler class (ZCL_..._EXT)
7. Estender view C_ / Projection (UI + action button)
8. Criar IAM App para a extensão
9. Executar ATC - check Clean Core compliance
10. Transportar via Change Transport
```

## Referências
- [SAP Help: In-App Extensibility](https://help.sap.com/docs/SAP_S4HANA_CLOUD/6aa39f1ac05441e5a23f484f31e477e7/5b8ef11eb5c44b5e9073f38e2f28a07a.html)
- Tutorial: `Tutorials/21_Extending_sales_order_giftcard_scenario.md`
- Objeto real: `objects/BDEF/ZLH_GIFTCARD_EXT/`
- Objeto real: `objects/DDLS/ZLH_E_SALESDOCUMENT_EXT/`
- Fundamentos: `fonte-conhecimento/abap-fundamentos/35_BAdIs.md`
