# Data Modeling RAP: Arquitetura 3 Camadas (R/I/C), BDEF e OData Service

> Domínio: `rap` | Fonte: Loyalty Hub Partner Reference Application

## Arquitetura de 3 Camadas

O modelo RAP usa três camadas de CDS views, cada uma com responsabilidade distinta:

```
[Database Table]
      ↓
[R_ — Base/Reuse View]         → Lógica de negócio, BDEF, draft, associações
      ↓
[I_ — Interface View]          → APIs públicas, value helps, textos
      ↓
[C_ — Consumption/Projection]  → OData service, redirecionamento, UI annotations
```

### Camada Base — `R_` (Reuse / Restricted)

**Responsabilidade**: Modelo de dados central; contém lógica de negócio, associações de composição, e é referenciada pelo BDEF.

- Naming: `ZLH_R_<Entidade>`
- `@AccessControl.authorizationCheck: #NOT_REQUIRED` (gerenciado por DCLS na camada superior)
- `@Metadata.ignorePropagatedAnnotations: true`
- Define `COMPOSITION OF` e `association to parent`
- É a view usada no `define behavior for ...` do BDEF

**Exemplo — ZLH_R_Membership:**
```cds
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Loyality Hub Membership'
@Metadata.ignorePropagatedAnnotations: true
define view entity ZLH_R_Membership
  as select from zlh_membership
  association to parent ZLH_R_BusinessPartner as _BP
    on $projection.BusinessPartner = _BP.SoldToParty
  composition [0..*] of ZLH_R_CATEGORY as _Category
{
  key membershipid       as MembershipID,
      business_partner   as BusinessPartner,
      member_since       as MemberSince,
      membership_enddate as MembershipEndDate,
      membership_status  as MembershipStatus,
      created_by         as CreatedBy,
      created_on         as CreatedOn,
      last_changedat     as LastChangedat,
      last_changedby     as LastChangedby,
      _BP,
      _Category
}
```

### Camada Interface — `I_` (Interface/Value Help)

**Responsabilidade**: APIs públicas, value helps, views para consumo externo (sem UI direta).

- Naming: `ZLH_I_<Entidade>`
- Pode usar `DDCDS_CUSTOMER_DOMAIN_VALUE_T` para expor valores de domínio como value help

**Exemplo — ZLH_I_MembershipStatusVH:**
```cds
@AbapCatalog.viewEnhancementCategory: [#NONE]
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Membership Status Value Help'
define view entity ZLH_I_MembershipStatusVH
  as select from DDCDS_CUSTOMER_DOMAIN_VALUE_T( p_domain_name : 'ZLH_MEMBERSHIP_STATUS' )
{
  key domain_name,
  key value_position,
  @Semantics.language: true
  key language,
  @EndUserText.label: 'Membership Status'
  value_low,
  @EndUserText.label: 'Description'
  @Semantics.text: true
  text
}
where language = $session.system_language
```

### Camada Consumption — `C_` (Projection)

**Responsabilidade**: Expõe dados ao OData service; redireciona associações para o nível C; suporta metadata extensions.

- Naming: `ZLH_C_<Entidade>`
- Usa `as projection on ZLH_R_<Entidade>`
- Redireciona associações com `redirected to parent` e `redirected to composition child`
- Habilitar extensões: `@Metadata.allowExtensions: true`

**Exemplo — ZLH_C_Membership:**
```cds
@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Loyality Hub Membership'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define view entity ZLH_C_Membership
  as projection on ZLH_R_Membership
{
  key MembershipID,
      BusinessPartner,
      MemberSince,
      CreatedBy,
      CreatedOn,
      LastChangedat,
      LastChangedby,
      _BP       : redirected to parent ZLH_C_BusinessPartner,
      _Category : redirected to composition child ZLH_C_CATEGORY
}
```

---

## Composição e Agregação em CDS

### COMPOSITION OF — relação pai-filho forte
```cds
-- No pai (root entity):
composition [0..*] of ZLH_R_CATEGORY as _Category
-- [0..*] = zero ou muitos filhos; [1] = exatamente um filho
```

### TO PARENT — referência ao pai
```cds
-- Na view filha:
association to parent ZLH_R_BusinessPartner as _BP
  on $projection.BusinessPartner = _BP.SoldToParty
```

> **Regra inviolável**: toda view filha deve ter `association to parent`. A composição define a hierarquia do BO (root → filhos → netos). Se o pai for deletado, todos os filhos são deletados automaticamente.

---

## OData Service: SRVD + SRVB

### Service Definition (SRVD)
Define quais entidades CDS fazem parte do serviço:
```abap
@EndUserText.label: 'Loyalty Hub Manage Service'
define service ZLOYALTYHUB_MANAGE {
  expose ZLH_C_BusinessPartner;
  expose ZLH_C_MEMBERSHIP;
  expose ZLH_C_CATEGORY;
  expose ZLH_C_GIFTCARD;
  expose ZLH_C_TRANSACTIONS;
}
```

### Service Binding (SRVB)
- **OData V4 - UI**: para apps Fiori Elements
- **OData V4 - Web API**: para integrações externas/APIs
- Ao publicar o binding, o endpoint OData V4 é gerado automaticamente
- Testar via Fiori Elements Preview no ADT

### Passos para criar o serviço
1. Criar SRVD expondo as views de consumo (C_)
2. Criar SRVB apontando para o SRVD, tipo OData V4 - UI
3. Publicar o SRVB via ADT (botão "Publish")
4. Testar via SAP Gateway Client ou Fiori Preview

---

## Draft Handling

### O que é Draft?
Draft permite salvar trabalho em andamento sem persistir definitivamente. O dado fica numa "draft table" até o usuário acionar "Save" (Activate).

### Quando usar Draft?
- Transações complexas com múltiplos passos
- Objetos com múltiplas entidades filhas (cabeçalho + itens)
- Quando o usuário precisa interromper e continuar depois

### Como declarar Draft no BDEF

```abap
managed with additional save implementation in class ZCL_LH_AdditonalSave unique;
strict ( 2 );
with draft;   -- habilita draft para todo o BO

define behavior for ZLH_R_BusinessPartner
implementation in class ZCL_LH_BusinessPartner unique
with unmanaged save
lock master total etag ETag
draft table zlh_d_buspartner   -- tabela draft dedicada
authorization master ( instance )
{
  -- Ações obrigatórias do draft:
  draft action ( authorization : update, features : instance ) Edit;
  draft determine action Prepare
  {
    validation ZLH_R_TRANSACTIONS~validate_transaction_data;
    validation ZLH_R_GIFTCARD~validateGiftCardFields;
    validation ZLH_R_GIFTCARD~validateGiftcardBalance;
  }
  draft action Activate;
  draft action Resume;
  draft action Discard;

  association _Category { with draft; }
  association _MemberShip { create; with draft; }
}

define behavior for ZLH_R_Membership
persistent table zlh_membership
draft table zlh_d_membership   -- cada entidade filha tem sua draft table
lock dependent by _BP
authorization dependent by _BP
{
  update;
  delete;
  association _BP { with draft; }
  association _Category { create; with draft; }
}
```

### Tabelas Draft
- Devem ser criadas no dicionário ABAP antes de ativar o BDEF
- Convenção de naming: prefixo `ZLH_D_` (ex: `ZLH_D_Membership`)
- O RAP Framework adiciona campos de controle automaticamente

---

## BDEF Managed Scenario — Exemplo Completo (ZLH_R_BusinessPartner)

```abap
managed with additional save implementation in class ZCL_LH_AdditonalSave unique;
strict ( 2 );
with draft;

define behavior for ZLH_R_BusinessPartner
implementation in class ZCL_LH_BusinessPartner unique
with unmanaged save
lock master total etag ETag
draft table zlh_d_buspartner
authorization master ( instance )
{
  create ( features : global );
  update ( features : global );
  delete ( features : global );
  field ( readonly ) SoldToParty, ETag;

  association _Category    { with draft; }
  association _MemberShip  { create; with draft; }
  association _GiftCard    { create(precheck){ default function GetDefaultsForGiftCard; } with draft; }
  association _Transactions{ create(precheck); with draft; }

  action ( features : instance ) createMembership result [1] $self;
  action ( features : instance ) deleteMembership result [1] $self;
  action ( features : instance ) createCategory parameter ZLH_D_LHCREATECATEGORYP;

  side effects {
    action createMembership affects entity _Category;
    action createCategory   affects entity _Category;
    action deleteMembership affects entity _GiftCard, entity _Category;
  }

  draft action ( authorization : update, features : instance ) Edit;
  draft determine action Prepare
  {
    validation ZLH_R_TRANSACTIONS~validate_transaction_data;
    validation ZLH_R_GIFTCARD~validateGiftCardFields;
    validation ZLH_R_GIFTCARD~validateGiftcardBalance;
  }
  draft action Activate;
  draft action Resume;
  draft action Discard;
}

define behavior for ZLH_R_Membership
implementation in class ZCl_LH_Membership unique
persistent table zlh_membership
draft table zlh_d_membership
early numbering
lock dependent by _BP
authorization dependent by _BP
{
  update;
  delete;
  field ( readonly ) MembershipID, BusinessPartner;
  association _BP { with draft; }
  association _Category { create; with draft; }
  determination SetDefaultValuesOnCreate on modify { create; }
  side effects { field MembershipID affects entity _Category; }
  mapping for zlh_membership corresponding
  {
    BusinessPartner   = business_partner;
    MembershipID      = membershipid;
    MembershipStatus  = membership_status;
    MemberSince       = member_since;
    MembershipEndDate = membership_enddate;
    CreatedBy         = created_by;
    CreatedOn         = created_on;
    LastChangedat     = last_changedat;
    LastChangedby     = last_changedby;
  }
}
```

---

## Convenções de Naming (padrão ZLH_)

| Tipo de objeto    | Padrão              | Exemplo                   |
|-------------------|---------------------|---------------------------|
| View Base         | `ZLH_R_<Entidade>`  | `ZLH_R_Membership`        |
| View Interface    | `ZLH_I_<Entidade>`  | `ZLH_I_MembershipStatusVH`|
| View Consumption  | `ZLH_C_<Entidade>`  | `ZLH_C_Membership`        |
| BDEF              | mesmo da view base  | `ZLH_R_BusinessPartner`   |
| Draft Table       | `ZLH_D_<Entidade>`  | `ZLH_D_Membership`        |
| Impl. Class       | `ZCL_LH_<Entidade>` | `ZCL_LH_Membership`       |
| Service Def       | `Z<APP>_MANAGE`     | `ZLOYALTYHUB_MANAGE`      |
| Service Binding   | `Z<APP>_MANAGE_SB`  | `ZLOYALTYHUB_MANAGE_SB`   |

---

## Boas Práticas

- ✅ Sempre usar 3 camadas: R_ → (I_ se necessário) → C_
- ✅ Usar `@Metadata.allowExtensions: true` na C_ para permitir metadata extensions
- ✅ `@Metadata.ignorePropagatedAnnotations: true` na R_ para controlar herança de anotações
- ✅ Draft table deve existir no dicionário antes de ativar o BDEF
- ✅ Usar `early numbering` quando o número de chave é gerado antes do save (ex: via number range)
- ✅ Usar `lock dependent by _BP` em todas as entidades filhas
- ✅ Mapping explícito (`mapping for ... corresponding`) garante consistência entre campos CDS e tabela
- ❌ Nunca definir anotações `@UI` na camada R_; usar Metadata Extension (DDLX) na C_
- ❌ Nunca usar `#CHECK` no AccessControl sem DCLS correspondente implementado

## Referências
- [SAP Help: ABAP RAP](https://help.sap.com/docs/abap-cloud/abap-rap/abap-restful-application-programming-model)
- Tutorial: `Tutorials/13_Develop_ABAP_RAP_Application.md`
- Objeto real: `objects/BDEF/ZLH_R_BUSINESSPARTNER/`
- View real: `objects/DDLS/ZLH_R_MEMBERSHIP/`
