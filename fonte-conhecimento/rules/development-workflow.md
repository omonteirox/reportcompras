# Development Workflow — SAP Public Cloud Edition

> **Obrigatório**: Seguir este workflow em TODOS os desenvolvimentos. Não há exceções.

## Ciclo de Desenvolvimento

```
1. ANÁLISE
   └── Entender o requisito + verificar se há BAdI/ponto de extensão oficial
       └── Se sim → implementar via extensão
       └── Se não → verificar Key User Tools primeiro
           └── Se Key User não atende → desenvolvimento custom RAP/Report

2. DESIGN
   └── Definir objetos a criar (tabelas, CDS, BDEFs, classes)
   └── Verificar naming conventions (naming-conventions.md)
   └── Documentar decisão de arquitetura (consultar tech-lead)

3. DESENVOLVIMENTO (ADT — ABAP Development Tools)
   └── Criar todos os objetos no pacote correto
   └── Associar ao Transport Request correto
   └── Executar ATC checks localmente

4. QUALIDADE
   └── ATC (ABAP Test Cockpit) — zero findings críticos
   └── Unit tests para lógica crítica
   └── Code review (aplicar code-quality-checklist.md)

5. TESTE
   └── Ambiente de desenvolvimento/sandbox
   └── Teste de integração em ambiente QA

6. TRANSPORTE
   └── Release do Transport Request
   └── Import sequencial: DEV → QA → PROD
```

## Pacotes (Packages)

Todo objeto deve estar em um pacote estruturado:

```
Z<CLIENTE>_ROOT              ← Pacote raiz do cliente
├── Z<CLIENTE>_BASIS         ← Objetos base/utilitários
├── Z<CLIENTE>_MM            ← Materials Management
│   ├── Z<CLIENTE>_MM_RAP    ← Objetos RAP de MM
│   ├── Z<CLIENTE>_MM_BADI   ← BAdIs de MM
│   └── Z<CLIENTE>_MM_RPT    ← Reports de MM
├── Z<CLIENTE>_SD            ← Sales & Distribution
└── Z<CLIENTE>_FI            ← Finance
```

**Nunca use o pacote `$TMP` (local, não transportável) para objetos de produção.**

## Transport Requests

- Um Transport Request por **feature/história**
- Nomenclatura da descrição: `[MÓDULO] Descrição curta do que foi feito`
  - Exemplo: `[MM] BAdI de validação de pedido de compra Z001`
- **Nunca misture** objetos de features diferentes no mesmo TR
- Objetos de customizing (SPRO) em TR **separado** dos objetos de desenvolvimento

## ATC Checks — Obrigatório

Execute antes de qualquer transporte:

```abap
" Via ADT: Clique direito no objeto → Run As → ABAP Test Cockpit (ATC)
" Via código: verifique as findings
```

**Findings que BLOQUEIAM o transporte:**
- Critical (Prio 1): sempre corrigir
- High (Prio 2): sempre corrigir
- Medium (Prio 3): corrigir ou documentar exceção aprovada pelo Tech Lead

**Checks importantes:**
- `SLIN` (Extended Program Check): sem erros de sintaxe
- `CODE_INSPECTOR`: sem performance issues críticos
- `CLOUD_READINESS`: compatibilidade com ABAP Cloud

## Git / Version Control (se disponível via abapGit)

```bash
# Estrutura de branches (se usando abapGit)
main          ← código em produção
develop       ← integração contínua
feature/<id>  ← desenvolvimento de feature
hotfix/<id>   ← correções urgentes em prod
```

## Checklist Pré-Transporte

- [ ] ATC checks executados e findings críticos resolvidos
- [ ] Unit tests passando
- [ ] Code review realizado (tech-lead aprovado se mudança arquitetural)
- [ ] Documentação atualizada em `fonte-conhecimento/` se novo padrão criado
- [ ] Objetos no pacote correto (não em $TMP)
- [ ] Descrição do TR preenchida corretamente
- [ ] Testado em DEV com dados representativos
- [ ] QA informado sobre o transporte e procedimentos de teste

## Após Transporte para Produção

- [ ] Smoke test no sistema produtivo
- [ ] Monitorar logs de erro (SLG1 / Application Log) por 24h após go-live
- [ ] Atualizar `fonte-conhecimento/index.json` se novo conhecimento foi gerado
