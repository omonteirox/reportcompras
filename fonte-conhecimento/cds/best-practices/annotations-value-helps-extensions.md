# CDS Avançado: Annotations UI, Value Helps, Extensions e Boas Práticas

> Domínio: `cds` | Fonte: Loyalty Hub + Fiori Feature Showcase

## Annotations `@UI` para Fiori Elements

As annotations `@UI` controlam como os dados aparecem em apps Fiori Elements. São definidas em **Metadata Extensions (DDLX)** — nunca diretamente na view R_.

### `@UI.headerInfo` — Título e subtítulo do Object Page
```cds
@UI.headerInfo: {
  typeName: 'Business Partner',
  typeNamePlural: 'Business Partners',
  typeImageUrl: 'sap-icon://customer',
  title: {
    value: 'SoldToParty',
    type: #STANDARD
  },
  description: {
    label: 'Partner ID',
    type: #STANDARD,
    value: 'SoldToParty'
  }
}
```

### `@UI.lineItem` — Colunas da List Report
```cds
@UI.lineItem: [
  {
    position: 10,
    importance: #HIGH,
    label: 'Business Partner'
  }
]
SoldToParty;

-- Com action button na linha:
@UI.lineItem: [
  { position: 30, importance: #HIGH },
  { type: #FOR_ACTION, dataAction: 'createMembership', label: 'Create Membership', position: 10 }
]
MembershipStatus;
```

### `@UI.selectionField` — Filtros na List Report
```cds
@UI.selectionField: [{ position: 10 }]
SoldToParty;

@UI.selectionField: [{ position: 20 }]
MembershipStatus;
```

### `@UI.fieldGroup` — Grupos de campos no Object Page
```cds
@UI.fieldGroup: [{ qualifier: 'GeneralData', position: 10, label: 'General' }]
SoldToParty;

@UI.fieldGroup: [{ qualifier: 'GeneralData', position: 20 }]
MemberSince;
```

### `@UI.facet` — Estrutura do Object Page (seções e abas)
```cds
@UI.facet: [
  -- Facet de identificação (header):
  {
    purpose: #HEADER,
    type: #FIELDGROUP_REFERENCE,
    targetQualifier: 'HeaderInfo',
    label: 'Basic Information'
  },
  -- Facet de conteúdo (aba):
  {
    purpose: #STANDARD,
    type: #FIELDGROUP_REFERENCE,
    targetQualifier: 'GeneralData',
    label: 'General',
    id: 'GeneralTab'
  },
  -- Tabela filho como facet:
  {
    purpose: #STANDARD,
    type: #LINEITEM_REFERENCE,
    targetElement: '_Membership',
    label: 'Memberships',
    id: 'MembershipTab'
  }
]
```

### `@UI.identification` — Action buttons no header do Object Page
```cds
@UI.identification: [
  { type: #FOR_ACTION, dataAction: 'createMembership', label: 'Create Membership', position: 10 },
  { type: #FOR_ACTION, dataAction: 'deleteMembership', label: 'Delete Membership', position: 20 }
]
SoldToParty;
```

---

## `@Consumption.valueHelpDefinition` — Value Helps em CDS

Define qual view de value help usar para um campo.

### Sintaxe básica
```cds
@Consumption.valueHelpDefinition: [{
  entity: {
    name:    'ZLH_I_MembershipStatusVH',
    element: 'value_low'
  },
  distinctValues: true
}]
MembershipStatus;
```

### Value Help com múltiplos campos de busca
```cds
@Consumption.valueHelpDefinition: [{
  entity: {
    name:    'ZLH_I_CategoryIDVH',
    element: 'CategoryID'
  },
  additionalBinding: [{
    localElement: 'CategoryName',
    element:      'CategoryName',
    usage:        #RESULT
  }]
}]
CategoryID;
```

### Criar view de Value Help com valores de domínio
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
  @EndUserText.label: 'Status'
  value_low,
  @Semantics.text: true
  text
}
where language = $session.system_language
```

---

## `@Search` — Pesquisa Full-Text

```cds
-- Na view (nível de entidade):
@Search.searchable: true

-- Em campos individuais:
@Search.defaultSearchElement: true
@Search.fuzzinessThreshold: 0.7
SoldToParty;

@Search.defaultSearchElement: true
FullName;
```

---

## `@ObjectModel` — Semântica de Dados

```cds
-- Texto para um ID (exibir nome em vez de código):
@ObjectModel.text.element: ['StatusText']
MembershipStatus;

-- Associação de texto:
@ObjectModel.text.association: '_StatusVH'
MembershipStatus;

-- Categoria de dados da view:
@ObjectModel.dataCategory: #VALUE_HELP  -- view de value help
@ObjectModel.dataCategory: #TEXT        -- view de textos
@ObjectModel.dataCategory: #ENUM        -- view de enumeração

-- Chave de negócio (semântica):
@ObjectModel.businessKey.element: ['MembershipID']
```

---

## CDS Extension — DDLX (Metadata Extension)

### O que é
Uma Metadata Extension (DDLX) adiciona annotations a uma view CDS existente **sem modificar a view original**. Ideal para separar UI annotations da lógica de dados.

### Quando usar DDLX
- Adicionar `@UI` annotations a uma view C_ ou I_
- Estender uma view SAP standard com annotations customizadas
- Manter a view CDS limpa de annotations de UI

### Pré-requisito
A view CDS deve ter `@Metadata.allowExtensions: true` (na C_ ou na view que será estendida).

### Sintaxe de DDLX
```cds
@Metadata.layer: #CUSTOMER  -- Camada: #CORE, #PARTNER, #CUSTOMER, #INDUSTRY
annotate view ZLH_C_BusinessPartner with
{
  @UI.facet: [
    {
      purpose: #HEADER,
      type: #FIELDGROUP_REFERENCE,
      targetQualifier: 'HeaderGroup',
      label: 'Business Partner Details'
    },
    {
      purpose: #STANDARD,
      type: #LINEITEM_REFERENCE,
      targetElement: '_Membership',
      label: 'Memberships'
    }
  ]

  @UI.headerInfo: {
    typeName: 'Business Partner',
    typeNamePlural: 'Business Partners',
    title: { value: 'SoldToParty', type: #STANDARD }
  }

  -- Anotações por campo:
  @UI.lineItem: [{ position: 10, importance: #HIGH }]
  @UI.selectionField: [{ position: 10 }]
  @UI.fieldGroup: [{ qualifier: 'HeaderGroup', position: 10 }]
  SoldToParty;

  @UI.lineItem: [{ position: 20 }]
  @UI.fieldGroup: [{ qualifier: 'HeaderGroup', position: 20 }]
  FullName;
}
```

### Extensão de View Standard SAP via DDLX
```cds
-- Adicionar campos customizados a uma view standard (ex: Sales Order):
@Metadata.layer: #CUSTOMER
annotate view I_SalesOrderTP with
{
  -- Expor campo custom adicionado via RAP Extension:
  @UI.lineItem: [{ position: 200 }]
  ZZCustomField1;
}
```

---

## Calculated Fields em CDS

### CASE WHEN
```cds
case membership_status
  when 'A' then 'Active'
  when 'I' then 'Inactive'
  else 'Unknown'
end as StatusText,
```

### CAST — Conversão de tipos
```cds
cast(loyalty_points as abap.dec(15,2)) as LoyaltyPointsDisplay,
cast(member_since as abap.dats) as MemberSinceDate,
```

### Funções de data e hora
```cds
-- Data atual:
$session.system_date as TodayDate,

-- Diferença entre datas:
dats_days_between(member_since, membership_enddate) as DurationDays,

-- Adicionar dias:
dats_add_days(member_since, 365) as ExpiryDate,
```

### Funções de string
```cds
concat(first_name, concat(' ', last_name)) as FullName,
upper(customer_name)                        as CustomerNameUpper,
length(email_address)                       as EmailLength,
```

### Aggregate expressions
```cds
-- Em views com GROUP BY:
define view entity ZLH_I_MemberSummary
  as select from zlh_membership
    inner join zlh_transactions on ...
  group by business_partner
{
  key business_partner           as BusinessPartner,
  sum(loyalty_points)            as TotalPoints,
  count(*)                       as TransactionCount,
  max(transaction_date)          as LastTransactionDate
}
```

---

## `@AbapCatalog` Annotations

```cds
-- Tipo de enhancement aceito pela view:
@AbapCatalog.viewEnhancementCategory: [#PROJECTION_LIST]  -- permite DDLX
@AbapCatalog.viewEnhancementCategory: [#NONE]             -- não aceita extensão

-- Tipo de buffer:
@AbapCatalog.buffering.status: #ACTIVE
@AbapCatalog.buffering.type: #SINGLE
```

---

## Boas Práticas de CDS

### Performance
- ✅ Sempre usar `@AbapCatalog.viewEnhancementCategory` corretamente
- ✅ Evitar `UNION` desnecessário — prefira `CASE WHEN` para categorias simples
- ✅ Usar `LEFT OUTER JOIN` com critério bem definido; evitar produtos cartesianos
- ✅ Usar `@AccessControl.authorizationCheck: #NOT_REQUIRED` apenas em views internas (R_)
- ✅ Em views com `GROUP BY`, use apenas campos no SELECT que estejam no GROUP BY ou em aggregate functions
- ❌ Nunca usar subconsultas correlacionadas em CDS (não suportado)
- ❌ Nunca usar `SELECT *` implícito em views de consumo; liste os campos explicitamente

### Annotations
- ✅ Definir `@UI` annotations SOMENTE em Metadata Extensions (DDLX), nunca na view R_
- ✅ Usar `@EndUserText.label` em todos os campos para labels legíveis na UI
- ✅ Usar `@Semantics.amount.currencyCode` e `@Semantics.quantity.unitOfMeasure` para campos monetários
- ✅ `@Semantics.text: true` em campos de texto de value helps

### Estrutura
- ✅ View R_ = dados e lógica; View C_ = projeção e exposição
- ✅ Value helps como views I_ separadas, não inline
- ✅ Metadata Extensions com `@Metadata.layer: #CUSTOMER` para customizações

---

## Estrutura de Value Help no RAP

```
┌─────────────────────────────────────┐
│  ZLH_C_Membership (view C_)         │
│  @Consumption.valueHelpDefinition   │──────► ZLH_I_MembershipStatusVH
│    entity: ZLH_I_MembershipStatusVH │        (I_ com domínio DDCDS_...)
└─────────────────────────────────────┘
```

Passos para criar Value Help de domínio:
1. Criar domínio (`DOMA`) com fixed values
2. Criar data element (`DTEL`) apontando para o domínio
3. Criar view `ZLH_I_<Entity>VH` usando `DDCDS_CUSTOMER_DOMAIN_VALUE_T`
4. Referenciar na view C_ com `@Consumption.valueHelpDefinition`

## Referências
- [Fiori Feature Showcase](fonte-conhecimento/fiori-showcase/)
- [SAP Help: CDS Annotations](https://help.sap.com/doc/abapdocu_cp_index_htm/CLOUD/en-US/index.htm?file=abencds_annotations_ktd_docu.htm)
- Tutorial: `Tutorials/15_Core_Data_Services.md`
- Objeto real: `objects/DDLS/ZLH_I_MEMBERSHIPSTATUSVH/`
- Objeto real: `objects/DDLX/ZLH_E_BUSINESSPARTNER/`
