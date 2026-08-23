# Erro Aprendido: SELECT dentro de LOOP em Determination

---
id: "rap-err-001"
data: "2026-03-09"
dominio: "rap"
agente_que_errou: "rap-specialist"
severidade: "alta"
tags: ["performance", "select", "loop", "determination", "boa-pratica"]
---

## Contexto

Ao implementar uma determination `SetRelatedData` em um behavior implementation RAP,
o agente usou SELECT dentro de LOOP para buscar dados relacionados de cada entidade processada.

## O que foi feito de errado

```abap
METHOD set_related_data.
  READ ENTITIES OF ZI_PurchaseReq IN LOCAL MODE
    ENTITY PurchaseReq FIELDS ( SupplierID ) WITH CORRESPONDING #( keys )
    RESULT DATA(lt_reqs).

  LOOP AT lt_reqs INTO DATA(ls_req).
    " ❌ ERRADO: SELECT dentro de LOOP — N+1 queries no banco
    SELECT SINGLE name1 FROM zi_supplier
      WHERE supplier = @ls_req-SupplierID
      INTO @DATA(lv_name).

    MODIFY ENTITIES OF ZI_PurchaseReq IN LOCAL MODE
      ENTITY PurchaseReq UPDATE FIELDS ( SupplierName )
      WITH VALUE #( ( %tky = ls_req-%tky SupplierName = lv_name ) ).
  ENDLOOP.
ENDMETHOD.
```

## Por que estava errado

Executa 1 SELECT por registro lido. Para 1.000 registros = 1.000 queries no banco.
Em determinations chamadas durante `SAVE`, isso pode causar timeout e cancelamento da transação.
Viola a regra básica de performance ABAP: **nunca SELECT dentro de LOOP**.

## Como fazer corretamente

```abap
METHOD set_related_data.
  READ ENTITIES OF ZI_PurchaseReq IN LOCAL MODE
    ENTITY PurchaseReq FIELDS ( SupplierID ) WITH CORRESPONDING #( keys )
    RESULT DATA(lt_reqs).

  " ✅ Coletar todas as chaves distintas primeiro
  DATA(lt_supplier_ids) = VALUE #(
    FOR GROUPS lv_id OF ls IN lt_reqs
    GROUP BY ls-SupplierID WITHOUT MEMBERS
    ( sign = 'I' option = 'EQ' low = lv_id ) ).

  " ✅ Um único SELECT para todos os fornecedores necessários
  SELECT supplier, supplier_full_name
    FROM zi_supplier
    WHERE supplier IN @lt_supplier_ids
    INTO TABLE @DATA(lt_suppliers).

  " ✅ Montar HASHED TABLE para lookup O(1)
  DATA: lth_suppliers TYPE HASHED TABLE OF LINE OF DATA(lt_suppliers)
                       WITH UNIQUE KEY supplier.
  lth_suppliers = lt_suppliers.

  " ✅ LOOP sem acesso ao banco
  MODIFY ENTITIES OF ZI_PurchaseReq IN LOCAL MODE
    ENTITY PurchaseReq UPDATE FIELDS ( SupplierName )
    WITH VALUE #( FOR ls_req IN lt_reqs
                  LET ls_sup = lth_suppliers[ supplier = ls_req-SupplierID ]
                               OPTIONAL
                  IN ( %tky         = ls_req-%tky
                       SupplierName = ls_sup-supplier_full_name ) )
    REPORTED DATA(lt_reported).

  reported = CORRESPONDING #( DEEP lt_reported ).
ENDMETHOD.
```

## Regra Derivada

> ✅ **SEMPRE**: Colete todas as chaves necessárias antes do LOOP, faça um único SELECT com `IN @lt_keys`, depois use HASHED TABLE para lookup dentro do LOOP.
> ❌ **NUNCA**: Execute SELECT (nem `SELECT SINGLE`) dentro de LOOP em behavior implementations — nem em validations, determinations ou actions.

## Referências

- `fonte-conhecimento/abap-fundamentos/32_Performance_Notes.md`
- `fonte-conhecimento/abap-fundamentos/01_Internal_Tables.md` — seção HASHED TABLE
- `fonte-conhecimento/abap-fundamentos/08_EML_ABAP_for_RAP.md` — READ/MODIFY ENTITIES
