# Integração Event-Driven: RAP Business Events e Event Binding no S/4HANA Cloud

> Domínio: `rap` | Fonte: Loyalty Hub Sales Order Integration

## O que são RAP Business Events

RAP Business Events permitem que um BO RAP **publique eventos** quando certas operações ocorrem (create, update, delete). Outros componentes podem **consumir** esses eventos de forma assíncrona, sem acoplamento direto.

### Event-Driven vs Síncrona

| Abordagem         | Quando usar                                              | Desvantagem              |
|-------------------|----------------------------------------------------------|--------------------------|
| **Síncrona (EML)**| Mesma transação, dados relacionados, consistência crítica| Acoplamento forte        |
| **Event-Driven**  | Processos independentes, cross-BO, after commit          | Eventual consistency     |

### Tipos de RAP Events

| Tipo | Descrição |
|------|-----------|
| **Local RAP Events** | Dentro do mesmo sistema ABAP; executa após commit do BO origem |
| **Remote RAP Events** | Via SAP Event Mesh para sistemas externos (BTP, etc.) |

> O Loyalty Hub usa **Local RAP Events**: a criação de Sales Order dispara uma transação de loyalty no mesmo sistema, após commit.

---

## Como Publicar Eventos a Partir de um BO RAP

### Declarar evento no BDEF
```abap
define behavior for I_SalesOrderTP {
  event created;   -- publicado automaticamente após create
  event changed;   -- publicado automaticamente após update
}
```

Os eventos `created` e `changed` são publicados automaticamente pelo RAP runtime após o commit quando declarados no BDEF.

### Evento customizado com `RAISE ENTITY EVENT`
```abap
define behavior for ZLH_R_Membership {
  event membershipActivated parameter ZLH_S_MembershipEventParam;
}
```

Implementação:
```abap
METHOD some_action.
  RAISE ENTITY EVENT ZLH_R_Membership~membershipActivated
    FROM VALUE #( (
      %key-MembershipID = '123'
      %param-BusinessPartner = 'BP001'
    ) ).
ENDMETHOD.
```

---

## Como Criar um Event Binding (APLO)

O **Event Binding** (Application Event Binding, tipo APLO) conecta um evento de um BO a um **Event Consumer** (handler class).

### Objeto APLO no repositório
No Loyalty Hub, o binding está em `objects/APLO/ZLH_APPLICATION_LOG`.

### Estrutura do Event Binding
1. **Source BO**: `I_SalesOrderTP` (BO que publica o evento)
2. **Event**: `created` ou `Changed`
3. **Consumer Class**: `ZLH_SALESORDER_INTEGRATION`

### Como criar no ADT
1. Right-click no pacote → New → Other ABAP Repository Object → **Application Event Binding**
2. Definir:
   - **Source Event**: BO + nome do evento (ex: `SalesOrder~created`)
   - **Consumer**: classe global que implementa `CL_ABAP_BEHAVIOR_EVENT_HANDLER`
3. Ativar o binding

---

## Como Implementar um Event Handler

O handler herda de `CL_ABAP_BEHAVIOR_EVENT_HANDLER` e declara métodos `FOR ENTITY EVENT`.

### Estrutura da classe handler (ZLH_SALESORDER_INTEGRATION)

```abap
-- Classe global (registra como consumer do BO I_SalesOrderTP):
CLASS ZLH_SALESORDER_INTEGRATION DEFINITION PUBLIC INHERITING FROM ...
  PUBLIC SECTION.
    -- (corpo declarativo mínimo; handler real é local)
ENDCLASS.

-- Classe local (nos local types da mesma classe):
CLASS lhe_event DEFINITION INHERITING FROM cl_abap_behavior_event_handler.
  PRIVATE SECTION.
    METHODS on_created FOR ENTITY EVENT
       created FOR SalesOrder~created.  -- evento após SO create
    METHODS on_updated FOR ENTITY EVENT
       updated FOR SalesOrder~Changed.  -- evento após SO change
ENDCLASS.
```

### Implementação do handler — on_created
```abap
CLASS lhe_event IMPLEMENTATION.
  METHOD on_created.
    -- 1. Ler dados do Sales Order para as instâncias recebidas no evento:
    SELECT SoldToParty, SalesOrder, TotalNetAmount,
           TransactionCurrency, HdrGeneralIncompletionStatus
      FROM I_SalesOrderTP
      FOR ALL ENTRIES IN @created    -- 'created' = tabela de chaves do evento
      WHERE SalesOrder = @created-SalesOrder
      INTO TABLE @DATA(sales_orders).

    -- 2. Preparar transações de loyalty a criar:
    DATA: loyalty_transactions TYPE TABLE FOR CREATE ZLH_R_BusinessPartner\_Transactions.

    LOOP AT sales_orders ASSIGNING FIELD-SYMBOL(<so>).
      -- Validar elegibilidade:
      CHECK <so>-HdrGeneralIncompletionStatus = zif_lh_constants=>sales_order_completion_status.

      -- Verificar membership ativa:
      SELECT SINGLE * FROM ZLH_R_Membership
        WHERE BusinessPartner = @<so>-SoldToParty
        INTO @DATA(membership).
      CHECK membership IS NOT INITIAL
        AND membership-MembershipEndDate = zif_lh_constants=>membership_enddate.

      -- Idempotência: evitar duplicatas:
      SELECT SINGLE @abap_true FROM zlh_r_transactions
        WHERE RefSalesorderId = @<so>-SalesOrder
        INTO @DATA(exists).
      CHECK sy-subrc <> 0.  -- só processa se NÃO existe ainda

      -- Preparar dados da transação:
      APPEND INITIAL LINE TO loyalty_transactions ASSIGNING FIELD-SYMBOL(<tx>).
      <tx>-%tky-SoldToParty = <so>-SoldToParty.
      <tx>-%target = VALUE #( (
        %cid                          = 'CID' && sy-tabix
        ActivityType                  = zif_lh_constants=>activity-purchase
        RefSalesorderId               = <so>-SalesOrder
        TransactionAmount             = <so>-TotalNetAmount
        TransactionCurrency           = <so>-TransactionCurrency
        %control-RefSalesorderId      = if_abap_behv=>mk-on
        %control-ActivityType         = if_abap_behv=>mk-on
        %control-TransactionAmount    = if_abap_behv=>mk-on
        %control-TransactionCurrency  = if_abap_behv=>mk-on
      ) ).
    ENDLOOP.

    CHECK loyalty_transactions IS NOT INITIAL.

    -- 3. Criar transações via EML (sem IN LOCAL MODE — chamada externa):
    MODIFY ENTITIES OF ZLH_R_BusinessPartner
      ENTITY ZLH_R_BusinessPartner
      CREATE BY \_Transactions
      FROM loyalty_transactions
      FAILED DATA(failed_items)
      REPORTED DATA(reported_items).

  ENDMETHOD.
ENDCLASS.
```

---

## Exemplo Completo: Fluxo Sales Order → Loyalty Transaction

```
┌─────────────────────────────────────────────────────────────┐
│  USUÁRIO cria Sales Order no app Manage Sales Orders        │
│                                                             │
│  → SAP S/4HANA COMMIT (Sales Order salvo)                  │
│                                                             │
│  → RAP Runtime publica evento I_SalesOrderTP~created        │
│                                                             │
│  → Event Binding APLO roteia para ZLH_SALESORDER_INTEGRATION│
│                                                             │
│  → lhe_event~on_created executa (após commit)               │
│     ├── Verifica: order completa?                          │
│     ├── Verifica: BP tem membership ativa?                  │
│     ├── Verifica: transação já existe? (idempotência)       │
│     └── MODIFY ENTITIES → cria Loyalty Transaction          │
│                                                             │
│  → Usuário vê nova transação no Loyalty Hub                │
└─────────────────────────────────────────────────────────────┘
```

---

## Objetos do Repositório para Event Integration

| Tipo | Nome | Descrição |
|------|------|-----------|
| `APLO` | `ZLH_APPLICATION_LOG` | Application Event Binding |
| `CLAS` | `ZLH_SALESORDER_INTEGRATION` | Global handler class |
| Local types | `lhe_event` | Handler com métodos `on_created` / `on_updated` |
| `SCO2` | `ZLH_CATEGORY_MAINTAIN_O4_0001_G4BA` | Service Catalog (gerado automaticamente) |

---

## Boas Práticas de Event-Driven Integration

### Idempotência no handler
O handler **deve** verificar se a ação já foi executada para a mesma entrada:
```abap
-- Idempotência: verificar se já processado:
SELECT SINGLE @abap_true FROM zlh_r_transactions
  WHERE RefSalesorderId = @sales_order_id
  INTO @DATA(already_processed).
IF sy-subrc = 0.
  RETURN.  -- já foi processado; ignorar evento duplicado
ENDIF.
```

### Tratamento de erros
```abap
MODIFY ENTITIES OF ZLH_R_BusinessPartner
  ...
  FAILED DATA(failed_items)
  REPORTED DATA(reported_items).

-- Logar erros (não propagar exception):
IF failed_items IS NOT INITIAL.
  -- Usar CL_BALI_LOG para registrar o erro (não lançar exceção)
  -- O framework RAP NÃO faz rollback automático no event handler
ENDIF.
```

### Retry e tolerância a falhas
- Eventos locais RAP **não** têm retry automático
- Para processamento crítico, considerar usar Application Job como fallback
- Para eventos remotos (Event Mesh), o Event Mesh oferece retry automático

### Validação de elegibilidade antes de processar
```abap
-- Sempre verificar pre-condições ANTES de criar dados:
-- 1. Order está completa? (HdrGeneralIncompletionStatus)
-- 2. BP tem membership ativa? (status + enddate)
-- 3. Dados mínimos presentes? (SoldToParty, Amount > 0)
```

### Performance no event handler
- ✅ Fazer um único `SELECT ... FOR ALL ENTRIES` para todos os eventos recebidos
- ✅ Processar em LOOP, depois um único `MODIFY ENTITIES` fora do LOOP
- ❌ Nunca fazer SELECT dentro de LOOP
- ❌ Nunca fazer MODIFY dentro de LOOP

---

## Diferença: `IN LOCAL MODE` vs sem LOCAL MODE no Event Handler

| Contexto | `IN LOCAL MODE` | Sem LOCAL MODE |
|----------|-----------------|----------------|
| Dentro de behavior handler RAP | ✅ Usar | — |
| Dentro de event handler | ❌ Não usar | ✅ Usar |
| External API call | ❌ | ✅ |

> No event handler, **não usar `IN LOCAL MODE`** porque o evento é uma chamada externa ao BO — deve passar por autorizações normais.

## Referências
- [SAP Help: Business Event Consumption](https://help.sap.com/docs/abap-cloud/abap-rap/business-event-consumption)
- Tutorial: `Tutorials/20_Event_Based_Integration.md`
- Objeto real: `objects/CLAS/ZLH_SALESORDER_INTEGRATION/`
- Objeto real: `objects/APLO/ZLH_APPLICATION_LOG/`
