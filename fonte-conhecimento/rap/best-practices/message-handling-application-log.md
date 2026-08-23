# Message Handling em RAP: MSAG, IF_ABAP_BEHV_MSG e Application Log

> Domínio: `rap` | Fonte: Loyalty Hub — Message Handling e Log Object

## Visão Geral

O Message Handling em RAP é o mecanismo para comunicar erros, avisos e informações ao usuário e aos consumidores da API. Mensagens bem definidas guiam o usuário a resolver problemas rapidamente.

---

## Message Class (MSAG)

### O que é
Uma Message Class (`MSAG`) centraliza todas as mensagens do sistema, organizadas por número com placeholders para variáveis.

### Como criar no ADT
1. Right-click no pacote → New → Other ABAP Repository Object → **Message Class**
2. Name: `ZPRA_LOYALTYHUB`
3. Definir mensagens por número:

| Número | Tipo | Texto | Uso |
|--------|------|-------|-----|
| `001`  | E    | Gift Card value is required | Validação de criação |
| `002`  | E    | Insufficient points: &1 needed, &2 available | Validação de saldo |
| `003`  | E    | Loyalty points must be greater than 0 | Validação de transação |
| `006`  | E    | Gift Card value cannot be empty | Validação de campo |
| `013`  | E    | Gift Card value must be positive | Validação de valor |
| `014`  | E    | Operation not allowed: membership inactive | Autorização |
| `015`  | E    | Value &1 exceeds maximum allowed &2 | Validação com variáveis |

### Tipos de mensagem (Severity)

| Tipo | Constante | Behavior |
|------|-----------|----------|
| `E` | `severity-error` | Bloqueia save; aparece em vermelho |
| `W` | `severity-warning` | Não bloqueia; aparece em laranja |
| `I` | `severity-information` | Informativo; aparece em azul |
| `S` | `severity-success` | Sucesso; aparece em verde |

---

## Como usar Mensagens em RAP Validations

### Padrão básico: `new_message`
```abap
-- new_message é herdado de cl_abap_behavior_handler:
APPEND VALUE #(
  %tky = <transaction>-%tky
  %msg = new_message(
    id       = 'ZPRA_LOYALTYHUB'    -- Message Class
    number   = '003'                 -- Número da mensagem
    severity = if_abap_behv_message=>severity-error
  )
  %element-LoyaltyPoints = if_abap_behv=>mk-on  -- destaca o campo problemático
) TO reported-zlh_r_transactions.

-- Adicionar ao failed (bloqueia o save):
APPEND VALUE #( %tky = <transaction>-%tky ) TO failed-zlh_r_transactions.
```

### Mensagem com variáveis (v1, v2, v3, v4)
```abap
-- Mensagem: 'Value &1 exceeds maximum allowed &2'
APPEND VALUE #(
  %tky = key->%tky
  %msg = new_message(
    id       = 'ZPRA_LOYALTYHUB'
    number   = '015'
    severity = if_abap_behv_message=>severity-error
    v1       = |{ key->GiftcardValue DECIMALS = 2 }|   -- placeholder &1
    v2       = |{ zif_lh_constants=>max_giftcard_value DECIMALS = 2 }|  -- placeholder &2
  )
  %element-GiftcardValue = if_abap_behv=>mk-on
) TO reported-zlh_r_giftcard.
```

### Mensagem simples sem message class
```abap
-- Para protótipos ou mensagens dinâmicas:
APPEND VALUE #(
  %tky = <entity>-%tky
  %msg = new_message_with_text(
    severity = if_abap_behv_message=>severity-warning
    text = |Processing skipped for { <entity>-ID }|
  )
) TO reported-<entidade>.
```

---

## `IF_ABAP_BEHV_MSG` — Interface de Mensagem RAP

### O que é
`IF_ABAP_BEHV_MSG` é a interface base para todos os objetos de mensagem RAP. Permite criar mensagens tipadas reutilizáveis via **Message Exception Class**.

### Message Exception Class (padrão avançado)
```abap
-- Definição da exception class:
CLASS zcx_lh_messages DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_abap_behv_msg.

    CLASS-METHODS:
      -- Mensagem de erro de loyalty points:
      loyalty_points_zero
        RETURNING VALUE(result) TYPE REF TO if_abap_behv_msg,

      -- Mensagem com valor de gift card:
      giftcard_value_exceeded
        IMPORTING
          iv_value   TYPE zlh_giftcardamt
          iv_maximum TYPE zlh_giftcardamt
        RETURNING VALUE(result) TYPE REF TO if_abap_behv_msg.
ENDCLASS.

CLASS zcx_lh_messages IMPLEMENTATION.
  METHOD loyalty_points_zero.
    result = new_message(
      id       = 'ZPRA_LOYALTYHUB'
      number   = '003'
      severity = if_abap_behv_message=>severity-error
    ).
  ENDMETHOD.

  METHOD giftcard_value_exceeded.
    result = new_message(
      id       = 'ZPRA_LOYALTYHUB'
      number   = '015'
      severity = if_abap_behv_message=>severity-error
      v1       = |{ iv_value DECIMALS = 2 }|
      v2       = |{ iv_maximum DECIMALS = 2 }|
    ).
  ENDMETHOD.
ENDCLASS.
```

### Uso da exception class na validation:
```abap
APPEND VALUE #(
  %tky  = <giftcard>-%tky
  %msg  = zcx_lh_messages=>giftcard_value_exceeded(
            iv_value   = <giftcard>-GiftcardValue
            iv_maximum = zif_lh_constants=>max_giftcard_value )
  %element-GiftcardValue = if_abap_behv=>mk-on
) TO reported-zlh_r_giftcard.
```

---

## Tipos de Mensagens RAP: State vs Transition

### State Messages
Referem-se ao **estado atual** do BO e persistem até o estado mudar.
- Usadas em validations (ON SAVE)
- Sempre ligadas a uma entidade via `%tky`
- Requerem `%state_area` para identificar a condição

```abap
-- State message (com %state_area):
APPEND VALUE #(
  %tky         = <entity>-%tky
  %state_area  = 'VALIDATE_LOYALTY_POINTS'  -- identificador único da condição
  %msg         = new_message(
    id       = 'ZPRA_LOYALTYHUB'
    number   = '003'
    severity = if_abap_behv_message=>severity-error )
  %element-LoyaltyPoints = if_abap_behv=>mk-on
) TO reported-zlh_r_transactions.
```

### Transition Messages
Referem-se a uma **transição/request** específica e são válidas apenas durante a execução.
- Usadas em actions, determinations
- Podem ser unbound (sem %tky)

```abap
-- Transition message unbound (sem %tky):
APPEND VALUE #(
  %msg = new_message_with_text(
    severity = if_abap_behv_message=>severity-information
    text = 'Processing completed successfully.' )
) TO reported-zlh_r_businesspartner.

-- Transition message bound (com %tky):
APPEND VALUE #(
  %tky = <bp>-%tky
  %msg = new_message( id = 'ZPRA_LOYALTYHUB' number = '001'
                      severity = if_abap_behv_message=>severity-warning )
) TO reported-zlh_r_businesspartner.
```

---

## `%element` — Posicionamento em Campo Específico

Para destacar o campo problemático na UI (destaque visual vermelho):
```abap
-- Destacar campo único:
%element-GiftcardValue = if_abap_behv=>mk-on

-- Destacar múltiplos campos:
%element-LoyaltyPoints = if_abap_behv=>mk-on
%element-TransactionDate = if_abap_behv=>mk-on
```

---

## `%path` — Navegação para Entidade Pai

Quando a mensagem é de uma entidade filha mas precisa navegar até o pai na UI:
```abap
APPEND VALUE #(
  %tky  = <transaction>-%tky
  %msg  = new_message( ... )
  %path = VALUE #(
    zlh_r_businesspartner-%is_draft  = <transaction>-%is_draft
    zlh_r_businesspartner-soldtoparty = <transaction>-BusinessPartner
  )
  %element-LoyaltyPoints = if_abap_behv=>mk-on
) TO reported-zlh_r_transactions.
```

---

## Application Log — Log Object (TOBJ)

### O que é
Um **Log Object** (`TOBJ`) define a categoria de log para filtrar e organizar Application Logs no Fiori.

### Como criar no ADT
1. Right-click no pacote → New → Other ABAP Repository Object → **Application Log Object**
2. Name: `ZLH_APPLICATION_LOG`
3. Definir subobjects (ex: `ZLH_CATEGORY_UPDATE` para o job de categoria)

### Criar e escrever log
```abap
-- Criar log com header:
DATA(mo_log) = cl_bali_log=>create_with_header(
                 header = cl_bali_header_setter=>create(
                            object    = 'ZLH_APPLICATION_LOG'
                            subobject = 'ZLH_CATEGORY_UPDATE' ) ).

-- Escrever mensagem livre:
DATA(free_text) = cl_bali_free_text_setter=>create(
                    severity = if_bali_constants=>c_severity_status
                    text     = 'Job started successfully' ).
mo_log->add_item( item = free_text ).

-- Escrever mensagem de warning:
DATA(warn_msg) = cl_bali_free_text_setter=>create(
                   severity = if_bali_constants=>c_severity_warning
                   text     = |Skipped BP: { bp_id } — no membership| ).
mo_log->add_item( item = warn_msg ).

-- Salvar log (e vincular ao job se em execução):
cl_bali_log_db=>get_instance( )->save_log(
  log                        = mo_log
  assign_to_current_appl_job = abap_true ).
```

### `CL_BALI_LOG` vs `CL_BALI_HEADER_SETTER`

| Classe | Papel |
|--------|-------|
| `CL_BALI_LOG` | Objeto principal do log; contém itens |
| `CL_BALI_HEADER_SETTER` | Define o cabeçalho do log (object, subobject) |
| `CL_BALI_FREE_TEXT_SETTER` | Item de texto livre no log |
| `CL_BALI_LOG_DB` | Persiste/recupera logs no banco de dados |
| `IF_BALI_LOG` | Interface do log (para referência tipada) |

---

## Exibir Logs no Fiori

1. Abrir app **Application Jobs** → Selecionar execução do job
2. Aba **Application Logs** mostra os logs com severidade e texto
3. Ou: Abrir app **Application Logs** (standalone) e filtrar por Object/Subobject

---

## Boas Práticas de Message Handling

- ✅ Criar Message Class `MSAG` com todas as mensagens do projeto centralizada
- ✅ Usar `new_message(id = 'MSAG' number = '###' severity = ...)` com variáveis para contexto
- ✅ Usar `%element-<campo>` para destacar o campo problemático na UI
- ✅ Usar `%state_area` em state messages para evitar acúmulo de mensagens duplicadas
- ✅ Sempre popular `failed` E `reported` em validations que bloqueiam save
- ✅ Usar `%path` quando mensagem é de entidade filha mas exibida no pai
- ✅ Para logs de Application Job: salvar após cada passo crítico
- ❌ Nunca usar mensagens técnicas de sistema (dumps, erros ABAP) para usuário final
- ❌ Nunca esquecer o `failed` — mensagem sem `failed` não bloqueia o save
- ❌ Nunca usar `MESSAGE ... TYPE 'E'` dentro de behavior handler RAP (não suportado)

## Referências
- [SAP Help: Messages in RAP](https://help.sap.com/docs/abap-cloud/abap-rap/messages)
- [SAP Help: State Messages](https://help.sap.com/docs/abap-cloud/abap-rap/state-messages)
- Tutorial: `Tutorials/17_Message_Handling.md`
- Tutorial: `Tutorials/44_LogObject.md`
- Implementação real: `objects/CLAS/ZCL_LH_TRANSACTIONS/`
- Implementação real: `objects/CLAS/ZCL_LH_GIFTCARD/`
- Message Class: `objects/MSAG/ZPRA_LOYALTYHUB/`
- Log Object: `objects/TOBJ/ZLH_TO_CATEGORYT/`
