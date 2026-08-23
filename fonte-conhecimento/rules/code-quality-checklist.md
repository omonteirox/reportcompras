# Code Quality Checklist — SAP Public Cloud Edition

> **Obrigatório**: Aplicar em TODO desenvolvimento antes de solicitar review ou transportar.

## Clean Core

- [ ] Nenhum objeto SAP standard modificado diretamente
- [ ] Toda extensão via ponto de extensão oficial (BAdI, RAP extension, CDS extension)
- [ ] Solução testada para sobreviver ao próximo upgrade semestral
- [ ] Apenas APIs liberadas (`Released` ou `#MIGRATION_DEVELOPMENT`) utilizadas

## Código ABAP

### Obrigatório ✅
- [ ] ABAP OO — classes e interfaces (sem programas procedurais para lógica de negócio)
- [ ] Exception classes (`ZCX_*`) para erros de negócio
- [ ] `IN LOCAL MODE` em validations/determinations RAP
- [ ] SELECT com campos explícitos (sem `SELECT *`)
- [ ] WHERE clause em todos os SELECTs (sem full table scan sem justificativa)
- [ ] Variáveis inline (`DATA(lv_x) = ...`) onde apropriado
- [ ] String templates (`|texto { lv_var }|`) ao invés de concatenação

### Proibido ❌
- [ ] `SELECT *` sem necessidade documentada
- [ ] SELECT dentro de LOOP (N+1 problem)
- [ ] `CALL FUNCTION` de módulos não liberados no ABAP Cloud
- [ ] Hard-coded credentials, IPs, ou configurações de ambiente
- [ ] `WRITE` statement (usar SALV/ALV)
- [ ] Modificação de tabelas standard SAP (Update/Delete em tabelas sem namespace Z)
- [ ] `COMMIT WORK` / `ROLLBACK WORK` em BAdIs (o framework controla)

## Performance

- [ ] Tabelas internas com tipo correto:
  - `STANDARD TABLE` para processamento sequencial
  - `SORTED TABLE` para buscas parciais
  - `HASHED TABLE` para lookups por chave exata (leitura O(1))
- [ ] Índices secundários criados para campos de busca frequente (tabelas Z grandes)
- [ ] `PARALLEL CURSOR` technique para JOINs em memória quando necessário
- [ ] `cl_progress_indicator` para operações longas (> 5 segundos)
- [ ] Paginação (`UP TO N ROWS` / `OFFSET`) para listas grandes

## Tratamento de Erros

```abap
" ✅ PADRÃO CORRETO
TRY.
  " operação que pode falhar
  DATA(lv_result) = lo_service->process( iv_input ).
CATCH zcx_my_business_error INTO DATA(lx_biz).
  " tratar erro de negócio esperado
  MESSAGE lx_biz->get_text( ) TYPE 'E'.
CATCH cx_root INTO DATA(lx_unexpected).
  " log de erro inesperado
  cl_bali_log=>...
  RAISE EXCEPTION TYPE zcx_my_business_error
    EXPORTING previous = lx_unexpected.
ENDTRY.
```

## Testes

- [ ] Unit tests (`ABAP Unit`) para toda lógica de negócio crítica
- [ ] Test doubles para dependências externas (banco de dados, serviços externos)
- [ ] Cobertura mínima de 80% para classes de negócio
- [ ] Testes de integração documentados (casos de teste manuais se não automatizados)

```abap
" Template de classe de teste
CLASS ztest_mm_po_processor DEFINITION FINAL
  FOR TESTING RISK LEVEL HARMLESS DURATION SHORT.
  PRIVATE SECTION.
    DATA mo_cut TYPE REF TO zcl_mm_po_processor.  " Class Under Test
    METHODS:
      setup,          " executado antes de cada teste
      test_valid_po   FOR TESTING,
      test_invalid_po FOR TESTING.
ENDCLASS.
```

## Documentação

- [ ] Métodos públicos documentados com ABAP Doc (`"! <p>Descrição</p>`)
- [ ] Constantes e enumerações com nomes autoexplicativos
- [ ] Lógica complexa comentada (o **porquê**, não o **o quê**)
- [ ] `fonte-conhecimento/index.json` atualizado se novo padrão foi estabelecido

## Segurança

- [ ] Authorization check implementado (DCL para CDS, `AUTHORITY-CHECK` quando necessário)
- [ ] Inputs externos validados antes do uso (nunca confie em dados externos sem validação)
- [ ] Sem exposição de dados sensíveis em logs
- [ ] CSRF protection ativa em OData services (padrão SAP)

## Review Final

Antes de submeter para review:
1. Execute ATC completo — zero findings Prio 1 e 2
2. Rode todos os unit tests — 100% passing
3. Teste manual com dados representativos
4. Verifique que o naming segue `naming-conventions.md`
5. Verifique que o workflow seguiu `development-workflow.md`
