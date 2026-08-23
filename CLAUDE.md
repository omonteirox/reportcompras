# SAP Public Cloud Edition — Cérebro Central (Claude Code)

> **Contexto master:** Leia `AI_CORE.md` para identidade, protocolo obrigatório, roteamento de agentes e princípios Clean Core.

## Instruções Específicas para Claude Code

**Inicialização obrigatória:**
1. Leia `AI_CORE.md` — contexto master compartilhado com todas as IAs deste brain
2. Se existir `memory.md` no projeto, leia-o — contém o contexto da sessão atual (o que já foi feito, o que precisa fazer, problemas em andamento)
3. Siga o protocolo obrigatório definido em AI_CORE.md antes de qualquer desenvolvimento

**Manutenção de memória:**
- Após cada ação relevante (criar objeto, resolver problema, mudar abordagem), atualize `memory.md`
- Mantenha-o curto (~20 linhas): bullets concisos em cada seção
- Mova itens concluídos para "✅ Feito" e remova detalhes desnecessários

## Agentes (Claude Code)

Use `/agents <nome>` para acionar especialistas:

| Use quando... | Agente |
|---------------|--------|
| RAP, CDS custom, BDEF, OData, Fiori Elements | `/agents rap-specialist` |
| BAdI, enhancement, customer include | `/agents badi-specialist` |
| Report, ALV, SALV, selection screen | `/agents reports-specialist` |
| Arquitetura, code review, decisão técnica | `/agents tech-lead` |
| **Encontrar CDS released SAP standard** | `/agents cds-specialist` |
| Dúvida sobre qual agente usar | `/agents generalista` |
| Registrar erro ou aprendizado | `/agents aprendiz` |

## Skills (Claude Code)

Skills são workflows reutilizáveis. O Claude Code carrega automaticamente a skill relevante:

| Diga... | Skill ativada |
|---------|--------------|
| "criar RAP", "novo objeto RAP" | `criar-objeto-rap` |
| "qual BAdI", "enhancement point para..." | `buscar-badi` |
| "revisar código", "clean core check" | `revisar-clean-core` |
| "adicionar ao cérebro", "registrar aprendizado" | `adicionar-conhecimento` |

## Hooks

O Claude Code executa `hooks/post-tool-use/check-clean-core.sh` automaticamente após editar arquivos ABAP/CDS. O alerta é informativo (não-bloqueante).

## Como Adicionar Novo Conhecimento

```bash
bash fonte-conhecimento/scripts/add-knowledge.sh \
  --domain <domínio> \
  --title "Título descritivo" \
  --file "<domínio>/best-practices/arquivo.md" \
  --tags "tag1,tag2,tag3" \
  --agent "rap-specialist,tech-lead" \
  --create
```

Domínios: `cds`, `rap`, `badis`, `reports`, `behavior-definitions`, `classes`, `rules`
