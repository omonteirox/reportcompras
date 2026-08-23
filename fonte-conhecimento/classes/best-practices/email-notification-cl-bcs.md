# Email Notification: CL_BCS_MAIL_MESSAGE para Envio de Email em ABAP Cloud

> Domínio: `classes` | Fonte: Loyalty Hub — Category Update Job Email Notification

## Visão Geral

No S/4HANA Cloud Public Edition, emails são enviados via `CL_BCS_MAIL_MESSAGE` (nova API Cloud-ready). A classe clássica `CL_BCS` ainda existe mas `CL_BCS_MAIL_MESSAGE` é a abordagem recomendada no ABAP Cloud.

### Quando usar
- Notificações automáticas de processos batch (Application Jobs)
- Alertas de eventos de negócio (upgrades de categoria, aprovações, etc.)
- Confirmações de operações importantes

---

## CL_BCS_MAIL_MESSAGE — API Principal

### Fluxo completo de envio
```abap
-- 1. Criar instância da mensagem:
DATA(mail) = cl_bcs_mail_message=>create_instance( ).

-- 2. Adicionar destinatário(s):
DATA: recipient TYPE cl_bcs_mail_message=>ty_address.
recipient = 'usuario@empresa.com'.
mail->add_recipient( recipient ).

-- 3. Definir assunto:
mail->set_subject( 'Loyalty Program - Category Upgrade' ).

-- 4. Construir corpo HTML:
DATA(html_body) = '<html><body>...' .

-- 5. Definir o corpo como HTML:
mail->set_main( cl_bcs_mail_textpart=>create_text_html( html_body ) ).

-- 6. Enviar:
DATA(mail_status) = mail->send( ).

-- 7. (Opcional) Verificar status de envio:
mail_status->get_email_status(
  IMPORTING
    es_mail_status         = DATA(status_result)
    et_recipients_statuses = DATA(recipients_status)
).
```

---

## Exemplo Completo — Email de Upgrade de Categoria

```abap
METHOD send_notifications.
  DATA(current_date) = cl_abap_context_info=>get_system_date( ).

  LOOP AT upgrades INTO DATA(upgrade).
    -- Pular se não há email cadastrado:
    CHECK upgrade-email_address IS NOT INITIAL.

    TRY.
        DATA(mail) = cl_bcs_mail_message=>create_instance( ).
        DATA: recipient TYPE cl_bcs_mail_message=>ty_address.
        recipient = upgrade-email_address.
        mail->add_recipient( recipient ).
        mail->set_subject( 'Loyalty Program - Category Upgrade' ).

        -- Construir HTML body com string templates (||):
        DATA(html) =
          |<!DOCTYPE html>| &&
          |<html><head>| &&
          |<style>| &&
          |  body { font-family: Arial, sans-serif; }| &&
          |  .header { background-color: #0070f3; color: white; padding: 20px; }| &&
          |  .badge-new { background-color: #28a745; color: white; padding: 5px 15px; }| &&
          |</style>| &&
          |</head><body>| &&
          |<div class="header"><h1>Congratulations!</h1></div>| &&
          |<div>| &&
          |  <h2>Your Category Has Been Upgraded</h2>| &&
          |  <p>Previous Category: { upgrade-old_category }</p>| &&
          |  <p>New Category: <span class="badge-new">{ upgrade-new_category }</span></p>| &&
          |  <p>Membership ID: { upgrade-membership_id }</p>| &&
          |  <p>Thank you for your loyalty.</p>| &&
          |</div>| &&
          |<footer><p>&copy; { current_date+0(4) } Loyalty Hub</p></footer>| &&
          |</body></html>|.

        mail->set_main( cl_bcs_mail_textpart=>create_text_html( html ) ).

        -- Enviar (não bloqueia; retorna objeto de status):
        DATA(status) = mail->send( ).

      CATCH cx_bcs_mail INTO DATA(lx_mail).
        -- Logar erro de email mas CONTINUAR o job:
        add_log_msg( text = |Email error for { upgrade-membership_id }: { lx_mail->get_text( ) }|
                     ty   = if_bali_constants=>c_severity_warning ).
    ENDTRY.
  ENDLOOP.
ENDMETHOD.
```

---

## Corpo do Email: Texto Simples vs HTML

### Texto simples
```abap
mail->set_main( cl_bcs_mail_textpart=>create_text_plain( 'Simple text body.' ) ).
```

### HTML (recomendado para notificações profissionais)
```abap
mail->set_main( cl_bcs_mail_textpart=>create_text_html( html_string ) ).
```

### Múltiplos destinatários
```abap
mail->add_recipient( 'user1@company.com' ).
mail->add_recipient( 'user2@company.com' ).

-- CC:
mail->add_recipient( i_address = 'cc@company.com'
                     i_copy    = cl_bcs_mail_message=>co_copy_cc ).

-- BCC:
mail->add_recipient( i_address   = 'bcc@company.com'
                     i_copy      = cl_bcs_mail_message=>co_copy_bcc ).
```

---

## Configuração de SMTP no S/4HANA Cloud

### Sender (remetente) padrão
O endereço padrão é configurado pelo sistema:
```
do.not.reply@my<tenant>.mail.s4hana.ondemand.com
```

Para um endereço customizado, configurar **DKIM** via SAP Output Management (processo 1LQ no SAP Signavio Process Navigator).

### Allowed Receiver Email Domains (obrigatório)
Para que emails sejam entregues, configurar os domínios permitidos:
1. Abrir app **Implementation Activities**
2. Navegar para **Define Allowed Email Receiver Domain for Email Outbound**
3. Adicionar domínios permitidos (ex: `@empresa.com`)
4. Para permitir todos: manter o valor `*`

> ⚠️ **Obrigatório**: sem essa configuração, nenhum email será enviado.

---

## Como obter o email do Business Partner

```abap
-- Buscar email do Business Partner via I_WorkplaceAddress:
SELECT businesspartner, defaultEmailAddress
  FROM I_WorkplaceAddress
  FOR ALL ENTRIES IN @business_partners
  WHERE BusinessPartner = @business_partners-BusinessPartner
  INTO TABLE @DATA(emails).

-- Usar o email na notificação:
READ TABLE emails ASSIGNING FIELD-SYMBOL(<email>)
  WITH KEY businesspartner = upgrade-business_partner.
IF sy-subrc = 0 AND <email>-defaultEmailAddress IS NOT INITIAL.
  upgrade-email_address = <email>-defaultEmailAddress.
ENDIF.
```

---

## Verificar Status de Envio

```abap
DATA(mail_result) = mail->send( ).

mail_result->get_email_status(
  IMPORTING
    es_mail_status         = DATA(status)
    et_recipients_statuses = DATA(recipients)
).

-- status-mail_status: 'S' = Sent, 'E' = Error, 'Q' = Queued
LOOP AT recipients INTO DATA(rcpt).
  -- rcpt-address = destinatário
  -- rcpt-status  = status de entrega por destinatário
  IF rcpt-status = 'E'.
    add_log_msg( |Email failed for: { rcpt-address }| ).
  ENDIF.
ENDLOOP.
```

---

## Integração com Application Job

O padrão recomendado é chamar `send_notifications` **após** criar os dados de negócio:

```abap
METHOD if_apj_rt_run~execute.
  init_log( ).

  -- 1. Processar lógica de negócio:
  DATA(upgrades) = process_category_upgrades( ).
  create_new_categories( upgrades ).

  -- 2. Enviar notificações (após dados criados):
  send_notifications( upgrades ).
  -- Erros de email não afetam o status geral do job
ENDMETHOD.
```

### Padrão de tratamento de erro para email
```abap
TRY.
    -- Enviar email...
    mail->send( ).
  CATCH cx_bcs_mail INTO DATA(lx).
    -- WARN no log (não ERROR) — email é best-effort
    add_log_msg( text = |Email warning: { lx->get_text( ) }|
                 ty   = if_bali_constants=>c_severity_warning ).
    -- NÃO fazer RETURN aqui — continuar processando próximos destinatários
ENDTRY.
```

---

## CL_BCS vs CL_BCS_MAIL_MESSAGE

| Aspecto | `CL_BCS` (clássico) | `CL_BCS_MAIL_MESSAGE` (Cloud) |
|---------|---------------------|-------------------------------|
| Disponibilidade | On-premise + Cloud | Cloud-first |
| API | Mais verbosa | Simplificada |
| HTML | Via `CL_DOCUMENT_BCS` | Direto via `create_text_html` |
| Status | Via `CL_BCS_SEND_REQUEST` | Integrado no objeto `mail` |
| Recomendado | On-premise legado | ✅ S/4HANA Cloud |

### CL_BCS (para referência legada)
```abap
-- Não recomendado no Cloud, mas ainda funcional:
DATA(send_request) = cl_bcs=>create_persistent( ).
DATA(document) = cl_document_bcs=>create_document(
  i_type    = 'RAW'
  i_text    = VALUE #( ( line = 'Email body text' ) )
  i_subject = 'Subject' ).
send_request->set_document( document ).
DATA(recipient_obj) = cl_cam_address_bcs=>create_internet_address( 'user@company.com' ).
send_request->add_recipient( recipient_obj ).
send_request->send( ).
COMMIT WORK.  -- necessário no CL_BCS clássico
```

---

## Boas Práticas de Email

- ✅ **Nunca bloquear** a execução principal em caso de falha de email; usar CATCH + WARN no log
- ✅ Configurar **Allowed Receiver Domains** antes de ir para produção
- ✅ Usar HTML para emails de notificação (mais profissional e legível)
- ✅ Verificar `email_address IS NOT INITIAL` antes de tentar enviar
- ✅ Em loops, fazer `CATCH` por iteração (não no loop inteiro) para continuar após falha
- ✅ Logar sucesso E falha com severidade adequada (SUCCESS/WARNING)
- ❌ Nunca usar `COMMIT WORK` após `CL_BCS_MAIL_MESSAGE->send( )` — não necessário
- ❌ Nunca enviar emails com dados sensíveis (PII) sem consentimento do usuário
- ❌ Nunca hard-codar endereços de email no código; buscar do cadastro do BP

## Referências
- [SAP Help: Sending Emails in ABAP Cloud](https://help.sap.com/docs/SAP_S4HANA_CLOUD/6aa39f1ac05441e5a23f484f31e477e7/8d1f989deca1455dabc3d81b433fbdaf.html)
- Tutorial: `Tutorials/43_Email_Notification_Category_Update.md`
- Implementação real: `objects/CLAS/ZCL_LH_CATEGORY_UPDATE_JOB/METH SEND_NOTIFICATIONS.abap`
