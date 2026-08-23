# Application Job: IF_APJ_RT_RUN, Job Catalog, Job Template e Application Log

> Domínio: `classes` | Fonte: Loyalty Hub — Category Update Job

## O que é Application Job no S/4HANA Cloud

Um **Application Job** é o substituto dos jobs batch clássicos (SM37) no S/4HANA Cloud Public Edition. É executado em background, agendado via Fiori Launchpad (app **Application Jobs**), e integrado com Application Log para monitoramento.

### Diferenças do batch clássico

| Aspecto | Batch Clássico (SM36/SM37) | Application Job |
|---------|---------------------------|-----------------|
| Criação | Transações SM36/SM37 | App Fiori "Application Jobs" |
| Definição | Programa ABAP + variante | Job Catalog Entry + Interface |
| Interface | ABAP program | Classe implementando `IF_APJ_RT_RUN` |
| Log | Spool / SM21 | Application Log (BALI) integrado |
| Agendamento | Usuário BASIS | Usuário de negócio com autorização |
| Cloud-ready | ❌ | ✅ |

---

## Objetos do Repositório

| Tipo | Nome | Descrição |
|------|------|-----------|
| `IF_APJ_RT_RUN` | — | Interface obrigatória para o job |
| `CLAS` | `ZCL_LH_CATEGORY_UPDATE_JOB` | Implementação do job |
| `SAJC` | `ZLH_CATEG_UPDATE_CATALOG_ENTRY` | Job Catalog Entry |
| `SAJT` | `ZLH_CATEG_UPDATE_TEMPLATE` | Job Template |
| `APLO` | `ZLH_APPLICATION_LOG` | Application Log Object |
| `SIA6` | `ZLH_CATEG_UPDATE_CATALOG_ENTRY_SAJC` | IAM App para o catalog entry |
| `SIA1` | `ZLH_CATEGORY_UPDATE_JOB` | Business Catalog |

---

## Interface `IF_APJ_RT_RUN`

### O que é
Toda classe de Application Job **deve** implementar esta interface. O método `EXECUTE` é chamado pelo framework quando o job é executado.

### Declaração da classe
```abap
CLASS zcl_lh_category_update_job DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_apj_rt_run.  -- obrigatório
    -- Declarar atributos privados para o log:
  PRIVATE SECTION.
    DATA mo_log TYPE REF TO if_bali_log.
ENDCLASS.
```

### Implementação do método EXECUTE
```abap
METHOD if_apj_rt_run~execute.
  -- 1. Inicializar o log:
  init_log( ).
  add_log_msg( 'Job started: Loyalty Category Upgrade Process' ).

  -- 2. Executar a lógica de negócio:
  DATA(upgrades) = process_category_upgrades( ).

  IF upgrades IS INITIAL.
    add_log_msg( 'No eligible upgrades found.' ).
    RETURN.
  ENDIF.

  add_log_msg( |Found { lines( upgrades ) } eligible memberships for upgrade.| ).

  -- 3. Criar novas categorias:
  create_new_categories( upgrades ).

  -- 4. Enviar notificações por email:
  send_notifications( upgrades ).

  add_log_msg( 'Job completed successfully.' ).
ENDMETHOD.
```

---

## Application Log com `CL_BALI_LOG`

O Application Log é o mecanismo oficial de logging no S/4HANA Cloud. Os logs aparecem na aba **Application Logs** do job no app Fiori.

### Criar Log Object (APLO) no ADT
1. Right-click no pacote → New → **Application Log Object**
2. Name: `ZLH_APPLICATION_LOG`
3. Definir **Object** e **Subobject** (usados para filtrar logs)

### Inicializar o log
```abap
METHOD init_log.
  TRY.
      mo_log = cl_bali_log=>create_with_header(
                 header = cl_bali_header_setter=>create(
                            object    = 'ZLH_APPLICATION_LOG'
                            subobject = 'ZLH_CATEGORY_UPDATE' ) ).
    CATCH cx_bali_runtime.
      CLEAR mo_log.  -- log não disponível; continuar sem log
  ENDTRY.
ENDMETHOD.
```

### Escrever mensagens no log
```abap
METHOD add_log_msg.
  -- iv_text = texto da mensagem
  -- iv_ty   = severidade (default: if_bali_constants=>c_severity_status)
  TRY.
      DATA(free_text) = cl_bali_free_text_setter=>create(
                          severity = iv_ty    -- #STATUS, #WARNING, #ERROR
                          text     = |{ iv_text }| ).
      IF mo_log IS BOUND.
        mo_log->add_item( item = free_text ).
        -- Salvar e associar ao job corrente:
        cl_bali_log_db=>get_instance( )->save_log(
          log                        = mo_log
          assign_to_current_appl_job = abap_true ).
      ENDIF.
    CATCH cx_bali_runtime.
      -- Ignorar erros de log — não bloquear execução principal
  ENDTRY.
ENDMETHOD.
```

### Severidades do log
```abap
if_bali_constants=>c_severity_status   -- ✅ informação normal
if_bali_constants=>c_severity_warning  -- ⚠️ aviso
if_bali_constants=>c_severity_error    -- ❌ erro (não bloqueia execução)
```

---

## Como criar Job Catalog Entry (SAJC)

O Catalog Entry é a **definição** do job: qual classe executar, quais parâmetros aceita.

### Campos obrigatórios

| Campo | Valor | Descrição |
|-------|-------|-----------|
| Name | `ZLH_CATEG_UPDATE_CATALOG_ENTRY` | Nome único |
| Class Name | `ZCL_LH_CATEGORY_UPDATE_JOB` | Classe que implementa `IF_APJ_RT_RUN` |
| Job Type | `A` | Application Job |
| Catalog Entry Type | `M` | Standard |

### Como criar no ADT
1. Right-click no pacote → New → Other ABAP Repository Object → **Application Job Catalog Entry**
2. Informar nome e classe
3. Opcional: definir **Selection Parameters** (parâmetros de entrada do usuário)

### IAM App para o Catalog Entry
Todo Catalog Entry precisa de um IAM App associado (tipo `SAJC`):
1. Criar IAM App `ZLH_CATEG_UPDATE_CATALOG_ENTRY_SAJC`
2. Tipo: **SAJC** (Job Catalog Entry)
3. Adicionar ao Business Catalog `ZLH_CATEGORY_UPDATE_JOB`

---

## Como criar Job Template (SAJT)

O Template é uma instância pré-configurada do Catalog Entry com parâmetros defaults.

### Como criar no ADT
1. Right-click no pacote → New → **Application Job Template**
2. Name: `ZLH_CATEG_UPDATE_TEMPLATE`
3. Basear no Catalog Entry: `ZLH_CATEG_UPDATE_CATALOG_ENTRY`
4. Definir valores default para seleções (se houver)

---

## Como agendar e monitorar via Fiori Launchpad

### Agendar o job
1. Abrir app **Application Jobs**
2. Clicar em **Create**
3. Selecionar template: `ZLH_CATEG_UPDATE_TEMPLATE`
4. Definir recorrência: **Daily**, **Weekly**, ou **Once**
5. Confirmar

### Monitorar execução
1. Na lista de jobs, verificar status: **Scheduled** / **Running** / **Completed** / **Failed**
2. Clicar no job → **Application Logs** para ver mensagens detalhadas
3. Filtrar por severidade (Info / Warning / Error)

---

## Lógica de Upgrade de Categorias (process_category_upgrades)

```abap
METHOD process_category_upgrades.
  DATA(today) = cl_abap_context_info=>get_system_date( ).

  -- 1. Memberships ativas:
  SELECT membershipid, business_partner FROM zlh_membership
    WHERE membership_status = @zif_lh_constants=>membership_status-active
      AND membership_enddate > @today
    INTO TABLE @DATA(active_memberships).

  CHECK active_memberships IS NOT INITIAL.

  -- 2. Total de pontos por BP:
  SELECT transactions~businesspartner, transactions~membershipid,
         SUM( loyaltypoints ) AS total_points
    FROM zlh_r_transactions AS transactions
    INNER JOIN @active_memberships AS active
      ON transactions~membershipid   = active~membershipid
     AND transactions~businesspartner = active~business_partner
    GROUP BY transactions~businesspartner, transactions~membershipid
    INTO TABLE @DATA(total_points).

  -- 3. Categorias habilitadas (ordenadas por threshold):
  SELECT * FROM zlh_i_categoryidvh
    WHERE isenabled = @abap_true
    ORDER BY Threshold ASCENDING
    INTO TABLE @DATA(category_headers).

  -- 4. Determinar upgrades:
  LOOP AT total_points INTO DATA(points).
    -- Encontrar a melhor categoria para os pontos do membro...
    -- Se categoria nova > categoria atual → registrar upgrade
  ENDLOOP.
ENDMETHOD.
```

---

## Boas Práticas de Application Job

- ✅ Inicializar o log no início do `EXECUTE` e salvar após cada passo importante
- ✅ Usar `assign_to_current_appl_job = abap_true` para vincular o log ao job
- ✅ Processar entidades em lotes (não uma por uma); usar `FOR ALL ENTRIES`
- ✅ Tratar erros por entidade individualmente e continuar processando as demais
- ✅ Idempotência: o job deve poder ser re-executado sem criar duplicatas
- ✅ Criar IAM App tipo SAJC e associar ao Business Catalog para agendamento
- ❌ Nunca usar `COMMIT WORK` explicitamente dentro do job (gerenciado pelo framework)
- ❌ Nunca fazer `CALL TRANSACTION` dentro de job (não suportado no Cloud)
- ❌ Nunca lançar exceção não tratada no `EXECUTE` (causará falha silenciosa)

---

## Estrutura Completa do Job

```
ZCL_LH_CATEGORY_UPDATE_JOB
├── IF_APJ_RT_RUN~EXECUTE         ← Entry point do framework
├── INIT_LOG                      ← Inicializa CL_BALI_LOG
├── ADD_LOG_MSG                   ← Escreve no log
├── PROCESS_CATEGORY_UPGRADES     ← Determina upgrades
├── CREATE_NEW_CATEGORIES         ← EML MODIFY ENTITIES
└── SEND_NOTIFICATIONS            ← CL_BCS_MAIL_MESSAGE emails
```

## Referências
- [SAP Help: Working with Application Jobs](https://help.sap.com/docs/abap-cloud/abap-development-tools-user-guide/working-with-application-job-objects)
- Tutorial: `Tutorials/42_Application_Job_Category_Update.md`
- Tutorial: `Tutorials/44_LogObject.md`
- Objeto real: `objects/CLAS/ZCL_LH_CATEGORY_UPDATE_JOB/`
- Objeto real: `objects/SAJC/ZLH_CATEG_UPDATE_CATALOG_ENTRY/`
