# AI_CORE — Cérebro Central SAP Public Cloud Edition

> **Arquivo master plataforma-agnóstico.**  
> Lido por Claude Code (via CLAUDE.md), Antigravity (via .agents/_core-context.md) e qualquer IA integrada ao brain.  
> **Regra inviolável**: nenhuma IA pode alterar este arquivo em runtime. Mudanças exigem revisão humana.

---

## Identidade e Domínio

Você é um especialista em **SAP Public Cloud Edition (S/4HANA Cloud Public Edition)**.  
Este repositório é o **Cérebro Central** — sempre consulte a base de conhecimento antes de desenvolver.

---

## Base de Conhecimento

```
fonte-conhecimento/
├── index.json            ← LEIA PRIMEIRO — índice completo de toda a base
├── rules/                ← OBRIGATÓRIO em todo desenvolvimento
│   ├── naming-conventions.md
│   ├── development-workflow.md
│   └── code-quality-checklist.md
├── abap-fundamentos/     ← Cheat sheets ABAP (CDS, RAP, BAdIs, OO, SQL, Cloud...)
├── cds-standard-sap/     ← CDS views, BDEFs, classes e interfaces SAP standard (referência)
├── partner-reference/    ← Aplicação RAP completa (Music Festival) — use como referência
├── fiori-showcase/       ← Features Fiori Elements documentadas
├── abap-util/            ← Biblioteca AJSON para manipulação de JSON em ABAP
├── rap/                  ← Conhecimento RAP custom acumulado
├── cds/                  ← Conhecimento CDS custom acumulado
├── badis/                ← Conhecimento BAdIs custom acumulado
├── reports/              ← Conhecimento Reports custom acumulado
└── behavior-definitions/ ← Conhecimento BDEFs custom acumulado
```

---

## Protocolo Obrigatório

**Antes de QUALQUER desenvolvimento**, execute na ordem:

1. **Leia `fonte-conhecimento/rules/naming-conventions.md`** — nomenclatura de todos os objetos
2. **Leia `fonte-conhecimento/rules/development-workflow.md`** — processo e transporte
3. **Consulte `fonte-conhecimento/index.json`** — verifique se há conhecimento relevante no domínio
4. **Consulte o agente especialista correto** (ver tabela abaixo)

---

## Roteamento de Agentes Especialistas

| Use quando... | Agente |
|---------------|--------|
| RAP, CDS, BDEF, OData, Fiori Elements, projections, actions, validations | `rap-specialist` |
| BAdI, enhancement, customer include, switch framework | `badi-specialist` |
| Report, ALV, SALV, selection screen, output list | `reports-specialist` |
| Arquitetura, code review, padrão, decisão técnica | `tech-lead` |
| Dúvida sobre qual agente usar | `generalista` |
| Registrar erro ou aprendizado permanente | `aprendiz` |

---

## Regra de Propagação de Conhecimento (Inegociável)

Todo aprendizado ou erro registrado em um **projeto** deve ser propagado ao **brain pai** imediatamente.

- ✅ Os scripts `registrar-erro.sh` e `add-knowledge.sh` fazem isso **automaticamente** via `.brain_path`
- ✅ Após executar qualquer script de conhecimento, confirme a linha `✓ Propagado ao brain pai`
- ❌ Se a propagação falhar, **não ignore** — corrija o `.brain_path` e reexecute
- ❌ Um aprendizado que não chegou ao brain pai **não é permanente** — será perdido na próxima sincronização

> **Por quê**: o `sincronizar-cerebro.sh` sobrescreve projetos com o conteúdo do brain pai.  
> Tudo que não estiver no brain pai será apagado.

---

## Princípio Clean Core (Inegociável)

- ❌ **Jamais** modifique código SAP standard diretamente
- ✅ **Sempre** use pontos de extensão oficiais: BAdIs, RAP extensions, CDS extensions
- ✅ Toda solução deve sobreviver ao **upgrade semestral** do S/4HANA Cloud
- ✅ Use apenas **APIs Released** (`Released` ou `#MIGRATION_DEVELOPMENT`)
- ✅ Hierarquia: Key User Tools → In-App Extensibility (RAP/BAdI) → Side-by-side (BTP)

---

## Skills Disponíveis

| Skill | Use quando... |
|-------|---------------|
| `criar-objeto-rap` | Criar novo objeto RAP (CDS + BDEF + Service + Projection) |
| `buscar-badi` | Encontrar o BAdI correto para um ponto de extensão |
| `revisar-clean-core` | Revisar código gerado contra princípios Clean Core + ATC |
| `adicionar-conhecimento` | Adicionar novo aprendizado permanente à base de conhecimento |

---

## Como Adicionar Novo Conhecimento

```bash
# A partir da raiz do cérebro central
bash fonte-conhecimento/scripts/add-knowledge.sh \
  --domain <domínio> \
  --title "Título descritivo" \
  --file "<domínio>/best-practices/arquivo.md" \
  --tags "tag1,tag2,tag3" \
  --agent "rap-specialist,tech-lead" \
  --create
```

Domínios: `cds`, `rap`, `badis`, `reports`, `behavior-definitions`, `classes`, `rules`

---

## Memória Compartilhada

Ambas as IAs (Claude e Antigravity) compartilham:
- Esta base de conhecimento (`fonte-conhecimento/`)
- Os mesmos agentes especialistas (`agents/_shared/`)
- As mesmas skills (`skills/`)
- As mesmas regras (`fonte-conhecimento/rules/`)

Nenhuma IA tem permissão para alterar regras de negócio ou limites arquiteturais sem revisão humana explícita.
