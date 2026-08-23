# Business Logic RAP: Validations, Determinations, Actions, Feature Control e EML

> Domínio: `rap` | Fonte: Loyalty Hub Partner Reference Application

## Visão Geral

A lógica de negócio em RAP é implementada em classes ABAP que herdam de `CL_ABAP_BEHAVIOR_HANDLER`. Cada entidade do BO tem sua própria classe handler, declarada com:
```abap
CLASS lhc_<entidade> DEFINITION INHERITING FROM cl_abap_behavior_handler.
```

---

## Validation

### O que é
Verifica a consistência dos dados do BO antes do save. Bloqueia o save se os dados são inválidos.

### Como declarar no BDEF
```abap
validation validate_transaction_data
  on save { create; update; field TransactionDate, LoyaltyPoints, PointExpiryDate; }
```

- `on save`: roda durante o save (não durante modify)
- `{ create; update; }`: triggers de operação
- `field <campos>`: também dispara quando esses campos são modificados

### Como implementar
```abap
METHOD validate_transaction_data.
  CHECK keys IS NOT INITIAL.

  READ ENTITIES OF ZLH_R_BusinessPartner IN LOCAL MODE
    ENTITY zlh_r_transactions
    ALL FIELDS WITH CORRESPONDING #( keys )
    RESULT DATA(transactions).

  LOOP AT transactions ASSIGNING FIELD-SYMBOL(<transaction>).
    IF <transaction>-LoyaltyPoints = 0.
      -- Adicionar ao failed para bloquear save:
      APPEND VALUE #( %tky = <transaction>-%tky )
        TO failed-ZLH_R_Transactions.

      -- Reportar mensagem de erro com posicionamento no campo:
      APPEND VALUE #(
        %tky              = <transaction>-%tky
        %msg              = new_message(
                              id       = 'ZPRA_LOYALTYHUB'
                              number   = '003'
                              severity = if_abap_behv_message=>severity-error )
        %element-LoyaltyPoints = if_abap_behv=>mk-on   -- destaca o campo na UI
        %path = VALUE #(
          zlh_r_businesspartner-%is_draft  = <transaction>-%is_draft
          zlh_r_businesspartner-soldtoparty = <transaction>-BusinessPartner )
      ) TO reported-zlh_r_transactions.
    ENDIF.
  ENDLOOP.
ENDMETHOD.
```

### Como reportar mensagens
- `failed-<entidade>`: adicionar instância que **falhou** (bloqueia save)
- `reported-<entidade>`: adicionar **mensagem** para a instância (aparece na UI)
- `%element-<campo> = if_abap_behv=>mk-on`: destaca o campo específico onde ocorreu o erro
- `%path`: define o caminho de navegação para a entidade pai na UI

---

## Determination

### O que é
Calcula e preenche campos derivados automaticamente. Não bloqueia o save.

### ON MODIFY vs ON SAVE

| Trigger      | Quando executa                | Uso típico                              |
|--------------|-------------------------------|-----------------------------------------|
| `ON MODIFY`  | Após cada modificação (UI)    | Recalcular campos em tempo real         |
| `ON SAVE`    | Antes do commit final         | Lógica que depende do estado completo   |

### Como declarar no BDEF
```abap
-- On modify (reativo a campos ou create):
determination LoyaltyPointCalculations on modify { create; field TransactionAmount; }
determination SetDefaultValuesOnCreate  on modify { create; }

-- On save:
determination addTransactionOnCreate on save { create; }
```

### Como implementar — Cálculo de Loyalty Points
```abap
METHOD LoyaltyPointCalculations.
  DATA(todaysdate) = cl_abap_context_info=>get_system_date( ).

  -- 1. Ler as entidades via EML (nunca SELECT diretamente na determination):
  READ ENTITIES OF ZLH_R_BusinessPartner IN LOCAL MODE
    ENTITY zlh_r_transactions
    ALL FIELDS WITH CORRESPONDING #( keys )
    RESULT DATA(transactions).

  -- 2. Buscar dados de suporte (um SELECT, fora do LOOP):
  SELECT businesspartner, categoryid, membershipid
    FROM zlh_r_category
    WHERE status = @zif_lh_constants=>category_status-active
    INTO TABLE @DATA(categories).

  -- 3. Preparar tabela de update:
  DATA: update_transactions TYPE TABLE FOR UPDATE zlh_r_transactions.

  -- 4. Processar no LOOP:
  LOOP AT transactions ASSIGNING FIELD-SYMBOL(<tx>).
    CHECK <tx>-ActivityType = zif_lh_constants=>activity-purchase.
    CHECK <tx>-TransactionAmount > 0.

    -- Calcular loyalty points baseado na categoria ativa:
    READ TABLE categories ASSIGNING FIELD-SYMBOL(<cat>)
      WITH KEY businesspartner = <tx>-BusinessPartner.
    CHECK sy-subrc = 0.

    DATA(loyalty_points) = <tx>-TransactionAmount * '0.10'.

    APPEND VALUE #(
      %tky          = <tx>-%tky
      LoyaltyPoints = loyalty_points
    ) TO update_transactions.
  ENDLOOP.

  -- 5. Atualizar via EML (um único MODIFY fora do LOOP):
  IF update_transactions IS NOT INITIAL.
    MODIFY ENTITIES OF ZLH_R_BusinessPartner IN LOCAL MODE
      ENTITY zlh_r_transactions
      UPDATE FIELDS ( LoyaltyPoints )
      WITH update_transactions.
  ENDIF.
ENDMETHOD.
```

---

## Action

### Tipos de Action

| Tipo       | Declaração BDEF                               | Uso                               |
|------------|-----------------------------------------------|-----------------------------------|
| Instance   | `action ( features : instance ) createMembership result [1] $self;` | Opera em instâncias específicas |
| Static     | `static action generateReport;`               | Opera no BO sem instância         |
| Factory    | `factory action create ... ;`                 | Cria novas instâncias             |

### Como declarar no BDEF
```abap
-- Action que retorna a própria entidade (resultado = $self):
action ( features : instance ) createMembership result [1] $self;

-- Action com parâmetro de entrada:
action ( features : instance ) createCategory parameter ZLH_D_LHCREATECATEGORYP;

-- Action com features globais:
action ( features : global ) approveAll;
```

### Como implementar — createMembership
```abap
METHOD createmembership.
  READ ENTITIES OF ZLH_R_BusinessPartner IN LOCAL MODE
    ENTITY ZLH_R_BusinessPartner
    ALL FIELDS WITH CORRESPONDING #( keys )
    RESULT DATA(businesspartners).

  DATA: create_memberships TYPE TABLE FOR CREATE ZLH_R_BusinessPartner\_MemberShip.

  LOOP AT businesspartners ASSIGNING FIELD-SYMBOL(<bp>).
    APPEND VALUE #(
      %tky    = <bp>-%tky
      %target = VALUE #( (
        %cid                          = 'CID_Membership'
        %is_draft                     = <bp>-%is_draft
        MemberSince                   = cl_abap_context_info=>get_system_date( )
        MembershipStatus              = zif_lh_constants=>membership_status-active
        MembershipEndDate             = zif_lh_constants=>membership_enddate
        %control-MemberSince          = if_abap_behv=>mk-on
        %control-MembershipStatus     = if_abap_behv=>mk-on
        %control-MembershipEndDate    = if_abap_behv=>mk-on
      ) )
    ) TO create_memberships.
  ENDLOOP.

  MODIFY ENTITIES OF ZLH_R_BusinessPartner IN LOCAL MODE
    ENTITY ZLH_R_BusinessPartner
    CREATE BY \_MemberShip
    FROM create_memberships
    FAILED DATA(failed)
    REPORTED DATA(reported).

  -- Retornar as instâncias atualizadas como resultado da action:
  READ ENTITIES OF ZLH_R_BusinessPartner IN LOCAL MODE
    ENTITY ZLH_R_BusinessPartner
    ALL FIELDS WITH CORRESPONDING #( keys )
    RESULT DATA(result_bps).

  result = VALUE #( FOR bp IN result_bps
    ( %tky   = bp-%tky
      %param = bp ) ).
ENDMETHOD.
```

### Expor action na Projection (BDEF C_)
```abap
-- Em ZLH_C_BusinessPartner BDEF:
use action createMembership;
```

### Expor action na UI (Metadata Extension)
```abap
@UI.identification:
[{ type: #FOR_ACTION,
   dataAction: 'createMembership',
   label: 'Create Membership',
   position: 10 }]
```

---

## Feature Control

### O que é
Controla dinamicamente quais operações e campos estão habilitados/desabilitados por instância.

### Declaração no BDEF
```abap
-- Instance features (por instância):
action ( features : instance ) createMembership result [1] $self;
field ( features : instance ) GiftcardValue, SapDescription, GiftcardCurrency;

-- Global features (para todos):
create ( features : global );
update ( features : global );
```

### Implementação — get_instance_features
```abap
METHOD get_instance_features.
  READ ENTITIES OF ZLH_R_BusinessPartner IN LOCAL MODE
    ENTITY ZLH_R_BusinessPartner
    ALL FIELDS WITH CORRESPONDING #( keys )
    RESULT DATA(BusinessPartners)
    BY \_MemberShip
    FIELDS ( MembershipID MembershipStatus )
    WITH CORRESPONDING #( keys )
    RESULT DATA(memberships).

  DATA(has_membership) = COND abap_bool( WHEN lines( memberships ) > 0 THEN abap_true ).

  -- Verificar autorização admin:
  AUTHORITY-CHECK OBJECT 'ZLOYLTYHUB'
    ID 'ZLH_USER' FIELD 'ADMIN'
    ID 'ACTVT'    FIELD '01'.
  DATA(has_admin_auth) = COND abap_bool( WHEN sy-subrc = 0 THEN abap_true ).

  result = VALUE #( FOR bp IN BusinessPartners
    ( %tky = bp-%tky
      -- createMembership: habilitado SOMENTE se não há membership E está em draft:
      %action-createMembership = COND #(
        WHEN lines( memberships ) = 0 AND bp-%is_draft = '01'
        THEN if_abap_behv=>fc-o-enabled
        ELSE if_abap_behv=>fc-o-disabled )
      -- Edit: habilitado SOMENTE para admin:
      %action-Edit = COND #(
        WHEN has_admin_auth = abap_true
        THEN if_abap_behv=>fc-o-enabled
        ELSE if_abap_behv=>fc-o-disabled )
    ) ).
ENDMETHOD.
```

---

## EML — Entity Manipulation Language

EML é a linguagem para manipular BOs RAP em ABAP. Substitui SELECT/INSERT/UPDATE/DELETE direto.

### READ ENTITIES
```abap
-- Ler campos específicos:
READ ENTITIES OF ZLH_R_BusinessPartner IN LOCAL MODE
  ENTITY ZLH_R_Membership
  FIELDS ( MembershipID MembershipStatus BusinessPartner )
  WITH CORRESPONDING #( keys )
  RESULT DATA(memberships).

-- Ler todos os campos:
READ ENTITIES OF ZLH_R_BusinessPartner IN LOCAL MODE
  ENTITY ZLH_R_Membership
  ALL FIELDS WITH CORRESPONDING #( keys )
  RESULT DATA(memberships).

-- Ler via associação (BY _<assoc>):
READ ENTITIES OF ZLH_R_BusinessPartner IN LOCAL MODE
  ENTITY ZLH_R_BusinessPartner
  BY \_MemberShip
  FIELDS ( MembershipID MembershipStatus )
  WITH CORRESPONDING #( keys )
  RESULT DATA(memberships).
```

### MODIFY ENTITIES — CREATE
```abap
-- Criar instâncias diretamente:
DATA: create_items TYPE TABLE FOR CREATE ZLH_R_Membership.
APPEND VALUE #(
  %cid             = 'CID_NEW'
  BusinessPartner  = 'BP001'
  MemberSince      = cl_abap_context_info=>get_system_date( )
  %control-BusinessPartner = if_abap_behv=>mk-on
  %control-MemberSince     = if_abap_behv=>mk-on
) TO create_items.

MODIFY ENTITIES OF ZLH_R_BusinessPartner IN LOCAL MODE
  ENTITY ZLH_R_Membership
  CREATE FROM create_items
  FAILED DATA(failed)
  REPORTED DATA(reported).

-- Criar via associação (CREATE BY):
DATA: create_by_assoc TYPE TABLE FOR CREATE ZLH_R_BusinessPartner\_MemberShip.
MODIFY ENTITIES OF ZLH_R_BusinessPartner IN LOCAL MODE
  ENTITY ZLH_R_BusinessPartner
  CREATE BY \_MemberShip
  FROM create_by_assoc
  FAILED DATA(failed)
  REPORTED DATA(reported).
```

### MODIFY ENTITIES — UPDATE
```abap
DATA: update_items TYPE TABLE FOR UPDATE ZLH_R_Membership.
APPEND VALUE #(
  %tky             = keys[ 1 ]-%tky
  MembershipStatus = 'I'
  %control-MembershipStatus = if_abap_behv=>mk-on
) TO update_items.

MODIFY ENTITIES OF ZLH_R_BusinessPartner IN LOCAL MODE
  ENTITY ZLH_R_Membership
  UPDATE FIELDS ( MembershipStatus )
  WITH update_items
  FAILED DATA(failed)
  REPORTED DATA(reported).
```

### MODIFY ENTITIES — DELETE
```abap
DATA: delete_items TYPE TABLE FOR DELETE ZLH_R_Membership.
MODIFY ENTITIES OF ZLH_R_BusinessPartner IN LOCAL MODE
  ENTITY ZLH_R_Membership
  DELETE FROM delete_items
  FAILED DATA(failed).
```

### IN LOCAL MODE vs sem LOCAL MODE
- `IN LOCAL MODE`: bypass de autorização e feature control; usar dentro do behavior handler
- Sem `IN LOCAL MODE`: respeita autorização; usar em chamadas externas (event handlers, jobs)

---

## Boas Práticas de Business Logic

- ✅ **Nunca** fazer `SELECT` dentro de um `LOOP AT` em determination ou validation
- ✅ Usar `IN LOCAL MODE` dentro de behavior handlers (performance + sem loop de autorização)
- ✅ Agrupar todos os updates num único `MODIFY ENTITIES` após o LOOP
- ✅ Sempre verificar `CHECK sy-subrc = 0` ou usar `OPTIONAL` no READ TABLE
- ✅ Em determination `ON MODIFY`: usar para recálculos reativos a campos
- ✅ Em determination `ON SAVE`: usar quando depende de estado completo de múltiplas entidades
- ✅ `%control-<campo> = if_abap_behv=>mk-on` para cada campo que você quer persistir no UPDATE
- ✅ Usar `cl_abap_context_info=>get_system_date( )` (Cloud-ready) em vez de `sy-datum`
- ❌ Nunca usar `COMMIT WORK` dentro de behavior handler RAP
- ❌ Nunca usar `SELECT` em tabelas transparentes diretamente na validation; use READ ENTITIES
- ❌ Nunca lançar exceções clássicas (`RAISE EXCEPTION TYPE ...`) em behavior handlers; usar `reported`

---

## Estrutura da Classe Handler

```abap
CLASS lhc_<entidade> DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    -- Validation:
    METHODS validate_xxx FOR VALIDATE ON SAVE
      IMPORTING keys FOR <entidade>~validate_xxx.

    -- Determination:
    METHODS set_defaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR <entidade>~set_defaults.

    -- Action:
    METHODS my_action FOR MODIFY
      IMPORTING keys FOR ACTION <entidade>~my_action RESULT result.

    -- Feature Control:
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features
      FOR <entidade> RESULT result.

    -- Early Numbering:
    METHODS early_numbering FOR NUMBERING
      IMPORTING entities FOR CREATE <entidade>.
ENDCLASS.
```

## Referências
- [SAP Help: Business Logic in RAP](https://help.sap.com/docs/abap-cloud/abap-rap/business-logic)
- Tutorial: `Tutorials/14_Develop_Business_Logic.md`
- Objeto real: `objects/CLAS/ZCL_LH_BUSINESSPARTNER/`
- Objeto real: `objects/CLAS/ZCL_LH_TRANSACTIONS/`
