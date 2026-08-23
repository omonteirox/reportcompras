# Erro Aprendido: Propagação de @ObjectModel em CDS Projection View sem ignorePropagatedAnnotations

---
id: "cds-err-001"
data: "2025-07-14"
dominio: "cds"
agente_que_errou: "rap-specialist"
severidade: "alta"
tags: ["cds", "projection-view", "annotation-propagation", "objectmodel", "atc", "sadl-runtime", "ignorePropagatedAnnotations"]
---

## Contexto

Ao criar uma CDS Projection View (`ZC_Supplier`) sobre uma interface view `ZI_Supplier` (que por sua
vez projeta sobre a view SAP standard `I_BusinessPartnerSupplier`), o agente não adicionou a anotação
`@Metadata.ignorePropagatedAnnotations: true` na projeção.

## O que foi feito de errado

```cds
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Supplier - Projection View'
@Metadata.allowExtensions: true
@Search.searchable: true
-- ❌ FALTOU: @Metadata.ignorePropagatedAnnotations: true

define root view entity ZC_Supplier
  provider contract transactional_query
  as projection on ZI_Supplier
{
  ...
  ReferenceAccountGroup,
  SupplierAccountGroup,
  ...
}
```

## Por que estava errado

Views SAP standard como `I_BusinessPartnerSupplier` carregam anotações de modelo como:
- `@ObjectModel.text.association`
- `@ObjectModel.foreignKey.association`

Essas anotações são **propagadas automaticamente** para toda CDS view que seleciona campos dessas
views — incluindo a cadeia `ZI_*` → `ZC_*`.

O problema: essas anotações são **válidas apenas em interface/base views**, e **não são permitidas
em PROJECTION views**. Sem `@Metadata.ignorePropagatedAnnotations: true`, o SADL runtime detecta
a propagação e lança o erro ATC:

```
Appl. Comp. Check: BC-ESI-ESF-BSA
Check Class: CL_CI_TEST_SADL_RUNTIME
Message Code: 004

Use of annotation OBJECTMODEL.TEXT.ASSOCIATION for element REFERENCEACCOUNTGROUP is not allowed for 'PROJECTION'
Use of annotation OBJECTMODEL.TEXT.ASSOCIATION for element SUPPLIERACCOUNTGROUP is not allowed for 'PROJECTION'
```

## Como fazer corretamente

```cds
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Supplier - Projection View'
@Metadata.allowExtensions: true
@Metadata.ignorePropagatedAnnotations: true   -- ✅ OBRIGATÓRIO em projeções sobre views SAP standard
@Search.searchable: true

define root view entity ZC_Supplier
  provider contract transactional_query
  as projection on ZI_Supplier
{
  ...
  ReferenceAccountGroup,
  SupplierAccountGroup,
  ...
}
```

## Regra Derivada

> ✅ **SEMPRE**: Adicionar `@Metadata.ignorePropagatedAnnotations: true` em toda CDS Projection View
> (`ZC_*`) que projeta sobre views que derivam de views SAP standard (`I_*`).
>
> ❌ **NUNCA**: Criar uma `ZC_*` sobre `ZI_*` → `I_*` sem essa anotação — a ausência propaga
> silenciosamente `@ObjectModel.text.association` e `@ObjectModel.foreignKey.association` para a
> projeção, causando falha ATC `CL_CI_TEST_SADL_RUNTIME / 004`.

### Escopo da regra

| Tipo de view | Precisa de `ignorePropagatedAnnotations`? |
|---|---|
| `ZI_*` (interface/base view sobre `I_*`) | ❌ Não — anot. de modelo são válidas aqui |
| `ZC_*` (projection view sobre `ZI_*`) | ✅ **Sim — sempre** |
| `ZC_*` (projection view puramente custom, sem `I_*` na cadeia) | ⚠️ Recomendado por precaução |

## Referências

- `fonte-conhecimento/cds/best-practices/` — boas práticas de CDS views
- Documentação SAP: `@Metadata.ignorePropagatedAnnotations` em CDS Annotations Reference
- ATC Check `CL_CI_TEST_SADL_RUNTIME` — validação de anotações em PROJECTION views
