# Erro Aprendido: `use side effects` sem bloco `{ }` em BDEF de Projeção

---
id: "behavior-definitions-err-001"
data: "2025-07-16"
dominio: "behavior-definitions"
agente_que_errou: "rap-specialist"
severidade: "alta"
tags: ["bdef", "projection", "use-side-effects", "syntax-error", "read-only"]
---

## Contexto

Ao criar um BDEF de projeção (`projection; strict(2);`) para uma entidade read-only,
o agente incluiu a instrução `use side effects;` com ponto-e-vírgula direto, sem bloco `{ }`.

## O que foi feito de errado

```abap
projection;
strict ( 2 );

use side effects;   " ❌ ERRADO: ponto-e-vírgula direto — sintaxe inválida

define behavior for ZC_Supplier alias Supplier
{
}
```

## Erro gerado no ADT (SAP)

```
"{" was expected, not ";".     line 6   ABAP Syntax Check Problem
"action | association | create | delete | event | function | key | update" was expected, not "side".   line 6   ABAP Syntax Check Problem
```

## Por que estava errado

A instrução `use side effects` **nunca aceita ponto-e-vírgula diretamente** — ela obrigatoriamente
exige um bloco `{ }` contendo pelo menos um mapeamento `field1 affects field2;`.

Além disso, para um BDEF de projeção **read-only** (sem operações CUD),
`use side effects` é completamente **desnecessária** e deve ser omitida.
`use side effects` é relevante somente quando um campo altera dinamicamente outro campo na UI
(ex: ao alterar `Country`, o campo `Region` é recalculado/resetado).

## Como fazer corretamente

**Caso 1 — BDEF projeção read-only (sem operações): omitir completamente**

```abap
projection;
strict ( 2 );

define behavior for ZC_Supplier alias Supplier
{
}
```

**Caso 2 — Quando `use side effects` é realmente necessário (sempre com bloco `{ }`)**

```abap
projection;
strict ( 2 );

use side effects        " ✅ sem ponto-e-vírgula aqui
{
  field Country affects Region;   " campo A afeta campo B na UI
}

define behavior for ZC_Supplier alias Supplier
{
  ...
}
```

## Regras Derivadas

> ❌ **NUNCA** escreva `use side effects;` com `;` direto — é **sintaxe inválida** no ABAP/BDEF.
> ✅ **SEMPRE** que usar `use side effects`, inclua o bloco `{ field X affects Y; }`.
> ✅ Em BDEF de projeção **read-only** (sem create/update/delete), **omita** `use side effects` completamente.
> 💡 `use side effects` só se justifica quando há dependência dinâmica entre campos visível na UI (Fiori Elements).

## Referências

- `fonte-conhecimento/behavior-definitions/` — exemplos de BDEFs de projeção
- SAP Help: *Behavior Definition — Side Effects* (ABAP RESTful Programming Model)
