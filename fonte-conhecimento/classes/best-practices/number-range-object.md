# Number Range: NROB e CL_NUMBERRANGE_RUNTIME em ABAP Cloud com RAP

> Domínio: `classes` | Fonte: Loyalty Hub — Number Range para Membership, Category, Transaction e Gift Card

## O que é um Number Range Object (NROB)

Um **Number Range Object** define intervalos de números únicos para gerar chaves de negócio. No S/4HANA Cloud, é o mecanismo padrão para gerar IDs únicos em objetos customizados (Membership ID, Transaction ID, etc.).

### Quando usar
- Geração de IDs sequenciais únicos (ex: `0000000001`, `0000000002`, ...)
- Quando o ID deve ser gerado **antes** do save (early numbering) ou no momento do save
- Alternativa a GUID quando o usuário precisa de números legíveis

### Objetos no Loyalty Hub

| Business Object | Campo-chave | NROB |
|----------------|------------|------|
| Membership      | MembershipID   | `ZLH_MID`  |
| Category        | CategoryID     | `ZLH_CID`  |
| Transaction     | TransactionID  | `ZLH_TID`  |
| Gift Card       | Gift Card ID   | `ZLH_GCID` |

---

## Como criar o NROB (Number Range Object)

### No ADT
1. Right-click no pacote → New → Other ABAP Repository Object → **Number Range Object**
2. Campos obrigatórios:
   - **Object**: `ZLH_MID`
   - **Short Description**: Membership ID Number Range
   - **Domain**: `ZLH_MEMBERSHIP_ID` (para linkagem com o domínio)
   - **Number Length**: tamanho do número gerado (ex: 10)
   - **Year**: deixar em branco para números sem ano
3. Configurar **Interval** (após criar o objeto):
   - **Interval Nr**: `01`
   - **From Number**: `0000000001`
   - **To Number**: `9999999999`
   - **Current Number**: `0000000000`
   - **External**: deixar desmarcado (internal numbering)

### Via app SAP Fiori (em produção)
Em S/4HANA Cloud Public Edition, os intervalos são configurados via app **Maintain Number Ranges** (SNRO) pelo usuário de negócio — não hard-coded no código.

---

## Como chamar `CL_NUMBERRANGE_RUNTIME` em ABAP Cloud

### Método `NUMBER_GET` — Obter um bloco de números
```abap
TRY.
    cl_numberrange_runtime=>number_get(
      EXPORTING
        nr_range_nr       = '01'          -- intervalo (padrão '01')
        object            = 'ZLH_MID'     -- nome do NROB
        quantity          = CONV #( lines( entities_to_number ) )  -- quantos números
      IMPORTING
        number            = DATA(last_number)          -- último número do bloco
        returncode        = DATA(return_code)           -- 0 = OK
        returned_quantity = DATA(returned_quantity)     -- quantos foram retornados
    ).
  CATCH cx_number_ranges INTO DATA(lx_nr).
    -- Tratar erro: sem números disponíveis, NROB não encontrado, etc.
    LOOP AT entities_to_number INTO DATA(entity).
      APPEND VALUE #(
        %cid      = entity-%cid
        %key      = entity-%key
        %is_draft = entity-%is_draft
        %msg      = lx_nr
      ) TO reported-<entidade>.
      APPEND VALUE #(
        %cid      = entity-%cid
        %key      = entity-%key
        %is_draft = entity-%is_draft
      ) TO failed-<entidade>.
    ENDLOOP.
    RETURN.
ENDTRY.
```

### Calcular números individuais a partir do bloco
```abap
-- number_get retorna o ÚLTIMO número do bloco.
-- Para obter números individuais: começar de (last_number - returned_quantity) + 1

DATA(current_id) = last_number - returned_quantity.

LOOP AT entities_to_number INTO DATA(entity).
  current_id += 1.
  entity-MembershipID = current_id.
  -- Persistir o número atribuído:
  MODIFY entities_to_number FROM entity.
ENDLOOP.
```

---

## Integração com RAP: Early Numbering

### O que é Early Numbering
O número é gerado **antes** do save (durante o draft/modify), não no momento do commit. Assim, o usuário vê o ID já na tela antes de salvar.

### Declaração no BDEF
```abap
define behavior for ZLH_R_Membership
persistent table zlh_membership
early numbering   -- ← habilita early numbering
lock dependent by _BP
{
  ...
}
```

### Implementação — earlynumbering_cba_Membership (exemplo real)
```abap
CLASS lhc_BusinessPartner IMPLEMENTATION.

  METHOD earlynumbering_cba_Membership.
    DATA: current_id TYPE zlh_membership_id.

    -- Filtrar entidades que ainda não têm ID (MembershipID = 0):
    DATA(without_ids) = entities[ 1 ]-%target.
    DELETE without_ids WHERE MembershipID NE 0.

    IF lines( without_ids ) = 0.
      RETURN.  -- todas já têm ID; nada a fazer
    ENDIF.

    -- Obter bloco de números:
    TRY.
        cl_numberrange_runtime=>number_get(
          EXPORTING
            nr_range_nr       = '01'
            object            = 'ZLH_MID'
            quantity          = CONV #( lines( without_ids ) )
          IMPORTING
            number            = DATA(last_number)
            returncode        = DATA(return_code)
            returned_quantity = DATA(returned_qty)
        ).
      CATCH cx_number_ranges INTO DATA(lx_nr).
        -- Reportar erro para cada entidade:
        LOOP AT without_ids INTO DATA(entity).
          APPEND VALUE #( %cid = entity-%cid %key = entity-%key
                          %is_draft = entity-%is_draft %msg = lx_nr )
            TO reported-zlh_r_membership.
          APPEND VALUE #( %cid = entity-%cid %key = entity-%key
                          %is_draft = entity-%is_draft )
            TO failed-zlh_r_membership.
        ENDLOOP.
        RETURN.
    ENDTRY.

    -- Distribuir números para cada entidade:
    current_id = last_number - returned_qty.
    LOOP AT without_ids INTO entity.
      current_id += 1.
      entity-MembershipID = current_id.
      -- Propagar o ID atribuído de volta para o framework:
      MODIFY entities[ 1 ]-%target FROM entity.
    ENDLOOP.

  ENDMETHOD.

ENDCLASS.
```

---

## Early Numbering vs Late Numbering

| Aspecto | Early Numbering | Late Numbering (ON SAVE) |
|---------|----------------|--------------------------|
| Quando ocorre | Durante create/modify | No save/commit |
| Usuário vê ID | Antes de salvar | Apenas após salvar |
| BDEF | `early numbering` | sem declaração especial |
| Método handler | `FOR NUMBERING` | determination `ON SAVE` |
| Ideal para | IDs de negócio visíveis | IDs técnicos internos |

### Late Numbering via Determination
```abap
-- No BDEF (alternativa ao early numbering):
determination assignTransactionId on save { create; }

-- Na implementação:
METHOD assignTransactionId.
  DATA: update_items TYPE TABLE FOR UPDATE ZLH_R_TRANSACTIONS.
  LOOP AT keys INTO DATA(key).
    cl_numberrange_runtime=>number_get(
      EXPORTING nr_range_nr = '01' object = 'ZLH_TID' quantity = 1
      IMPORTING number = DATA(new_id)
    ).
    APPEND VALUE #( %tky = key-%tky TransactionId = new_id
                    %control-TransactionId = if_abap_behv=>mk-on )
      TO update_items.
  ENDLOOP.
  MODIFY ENTITIES OF ZLH_R_BusinessPartner IN LOCAL MODE
    ENTITY ZLH_R_TRANSACTIONS UPDATE FIELDS ( TransactionId )
    WITH update_items.
ENDMETHOD.
```

---

## Configurar Intervalos por Tenant no S/4HANA Cloud

Em S/4HANA Cloud Public Edition:
1. Navegar no Fiori Launchpad → **Maintain Number Ranges** (app)
2. Selecionar o NROB (ex: `ZLH_MID`)
3. Criar ou ajustar intervalos conforme o tenant
4. Cada tenant (mandante) tem seus próprios intervalos — **não se sobrepõem**

> ⚠️ **Importante**: não defina intervalos hard-coded no código. Deixe para configuração no sistema de produção.

---

## Boas Práticas de Number Range

- ✅ Usar `quantity` para obter um bloco de números (uma chamada para múltiplas entidades)
- ✅ Calcular IDs individuais a partir do bloco: `last - returned_qty + índice`
- ✅ Sempre tratar `cx_number_ranges` e reportar para `failed` e `reported`
- ✅ Usar `early numbering` quando o usuário precisa ver o ID antes de salvar
- ✅ Criar NROB no pacote do projeto com intervalo configurável por tenant
- ❌ **Nunca** fazer rollback de números (não há mecanismo de devolução)
- ❌ Nunca fazer uma chamada `number_get` por entidade dentro de LOOP (usar `quantity = N`)
- ❌ Nunca assumir que o número retornado é sequencial sem calcular corretamente
- ❌ Nunca usar `GENERATE_SUBNUMBER` em Cloud (não disponível)

## Referências
- [SAP Help: Working with Number Range Objects](https://help.sap.com/docs/abap-cloud/abap-development-tools-user-guide/working-with-number-range-objects)
- Tutorial: `Tutorials/41_NumberRange.md`
- Objeto real: `objects/NROB/ZLH_MID/`
- Implementação real: `objects/CLAS/ZCL_LH_BUSINESSPARTNER/CINC ZCL_LH_BUSINESSPARTNER========CCIMP.abap`
