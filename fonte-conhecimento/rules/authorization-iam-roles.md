# Autorização e IAM: Authorization Objects, Access Control CDS, IAM Apps e Business Catalogs

> Domínio: `rules` | Fonte: Loyalty Hub Authorization Implementation

## Visão Geral do Modelo de Autorização

```
Authorization Object (ZLOYLTYHUB)
        ↓
Access Control CDS (DCLS) — filtra dados via PFCG
        ↓
IAM App (ZLOYALTYHUB_IAM_EXT) — define permissões Fiori
        ↓
Business Catalog (ZLOYALTYHUB_BUS_CATALOG)
        ↓
Business Role (ZLH_EXT_BR_LOYALTYHUB_ADMIN)
        ↓
Business User
```

---

## Authorization Object

### O que é
Um Authorization Object define os campos (dimensões) de controle de acesso. Por exemplo: qual tipo de usuário pode fazer qual operação.

### Como criar no ADT
1. Criar **Data Element** `ZLH_USERTYPE` (CHAR, 6 caracteres)
2. Criar **Authorization Field** `ZLH_USER` com Data Element `ZLH_USERTYPE`
3. Criar **Authorization Object** `ZLOYLTYHUB`:
   - Campos: `ZLH_USER` + `ACTVT`
   - Activities: `01` (Create), `02` (Change), `03` (Display), `06` (Delete)
4. Criar **Restriction Field** `ZLH_USERTYPE` (para Business Catalogs)
5. Criar **Restriction Type** `ZLH_USERTYPE`
6. **Marcar como C1 Released** (obrigatório para uso em BDEF Extension)

### Uso em ABAP (AUTHORITY-CHECK)
```abap
-- Verificar se usuário tem perfil ADMIN:
AUTHORITY-CHECK OBJECT 'ZLOYLTYHUB'
  ID 'ZLH_USER' FIELD 'ADMIN'
  ID 'ACTVT'    FIELD '01'.
IF sy-subrc = 0.
  DATA(has_admin_auth) = abap_true.
ENDIF.

-- Verificar se usuário pode exibir (Display = '03'):
AUTHORITY-CHECK OBJECT 'ZLOYLTYHUB'
  ID 'ZLH_USER' FIELD 'USER'
  ID 'ACTVT'    FIELD '03'.
```

> **Regra Cloud**: Em ABAP Cloud, usar `AUTHORITY-CHECK OBJECT` apenas com objetos Released (marcados C1). Verificar via ATC antes de transportar.

---

## Access Control CDS (DCLS)

### O que é
Uma DCLS (Data Control Language Statement) define **regras de acesso a nível de dados** para CDS views. Funciona como um filtro WHERE aplicado automaticamente a todas as leituras da view.

### Sintaxe básica

```cds
@EndUserText.label: 'Business Partner Details'
@MappingRole: true
define role ZLH_R_BUSINESSPARTNER {
  grant
    select
      on ZLH_R_BusinessPartner
        where
          -- Usuário USER: só vê seus próprios dados
          () = aspect pfcg_auth( ZLOYLTYHUB, ZLH_USER = 'USER', ACTVT = '03' )
            and UserID = $session.user
          -- OU Admin: vê todos
          or () = aspect pfcg_auth( ZLOYLTYHUB, ZLH_USER = 'ADMIN', ACTVT = '03' );
}
```

### `@MappingRole: true`
Indica que a DCLS usa os valores de autorização do perfil (PFCG) do usuário logado. Obrigatório para integração com Business Roles.

### `aspect pfcg_auth`
Verifica se o usuário tem o authorization object com os valores especificados:
```cds
() = aspect pfcg_auth( <auth_object>, <field1> = <valor1>, <field2> = <valor2> )
```

### Herdar condições de entidade pai
```cds
-- Na view filha (Consumption), herdar condições da view base:
@MappingRole: true
define role ZLH_C_BUSINESSPARTNER {
  grant select on ZLH_C_BUSINESSPARTNER
    where inheriting conditions from entity ZLH_R_BUSINESSPARTNER;
}

-- Ou herdar da projection (mais comum em C_):
define role ZLH_C_CATEGORY_HDR {
  grant select on ZLH_C_CATEGORY_HDR
    where INHERITING CONDITIONS FROM ENTITY ZLH_R_CATEGORY_HDR;
}
```

### Associar DCLS a uma CDS View
A DCLS deve ter **o mesmo nome** da CDS view correspondente:
- View: `ZLH_R_BusinessPartner` → DCLS: `ZLH_R_BUSINESSPARTNER`
- View: `ZLH_C_BusinessPartner` → DCLS: `ZLH_C_BUSINESSPARTNER`

A view CDS deve ter:
```cds
@AccessControl.authorizationCheck: #CHECK  -- ativa a DCLS correspondente
```

### Camadas de DCLS recomendadas

| Camada | DCLS necessária? | Regra |
|--------|-----------------|-------|
| R_     | ✅ Sim | Regras de negócio (quem vê o quê) |
| I_     | Opcional | Apenas se exposta externamente |
| C_     | ✅ Sim (herdar) | Herdar da R_ com `inheriting conditions` |

---

## IAM App (Identity and Access Management)

### O que é
Um IAM App define quais recursos Fiori (UI5 app, OData service) são protegidos e quais authorization objects são necessários.

### Como criar no ADT
1. Criar **IAM App** `ZLOYALTYHUB_IAM_EXT`:
   - **Fiori Launchpad App Descr Item ID**: `ZLOYALTYHUB_UI5R` (ID do tile Fiori)
   - **Service**: `ZLOYALTYHUB_MANAGE_SB` (Service Binding)
2. Aba **Authorizations**: adicionar objeto `ZLOYLTYHUB`
   - Clicar em **Synchronize** para carregar os campos
   - Definir valores padrão:
     | Field | Value |
     |-------|-------|
     | ZLH_USER | Default |
     | ACTVT | Display |
3. Ativar o IAM App

### Tipos de IAM App
- **OData V4**: para Fiori Elements apps com OData V4 binding
- **External App**: para apps UI5 standalone
- **Job App (SAJC)**: para Application Jobs — tipo especial vinculado ao catalog entry

---

## Business Catalog

### O que é
Um Business Catalog agrupa IAM Apps e define as **Restriction Types** disponíveis. É a unidade que se adiciona a um Business Role.

### Como criar
1. Criar **Business Catalog** `ZLOYALTYHUB_BUS_CATALOG`:
   - Aba **Apps**: adicionar IAM App `ZLOYALTYHUB_IAM_EXT`
   - Aba **Restriction Types**: inserir `ZLH_USERTYPE` (para personalização por role)
2. Ativar e transportar

### Catalogs do Loyalty Hub

| Business Catalog | Descrição |
|------------------|-----------|
| `ZLOYALTYHUB_BUS_CATALOG` | Acesso ao app principal Loyalty Hub |
| `ZLH_CATEGORY_MAINT_BC` | Manutenção de categorias |
| `ZLH_CATEGORY_UPDATE_JOB` | Agendamento do Application Job |

---

## Business Roles e Users

### Fluxo de atribuição
```
Business Catalog → Business Role → Business User
```

### Como criar Business Role (via Fiori)
1. Abrir app **Maintain Business Roles**
2. New → ID: `ZLH_EXT_BR_LOYALTYHUB_ADMIN`
3. Aba **Business Catalogs**: adicionar `ZLOYALTYHUB_BUS_CATALOG`
4. **Access Categories**:
   - Write, Read, Value Help: **Restricted**
   - Read, Value Help: **Unrestricted**
5. **Maintain Restrictions**: `ZLH_USERTYPE` → `ADMIN`
6. Atribuir usuários

### Dois papéis do Loyalty Hub

| Role Template | Restriction | Acesso |
|--------------|-------------|--------|
| `ZLH_EXT_BR_LOYALTYHUB_ADMIN` | USER = ADMIN | CRUD completo |
| `ZLH_EXT_BR_LOYALTYHUB` | USER = USER | Somente visualização |

---

## Uso em BDEF — Authorization Instance vs Global

### Instance Authorization (por instância de dado)
```abap
-- No BDEF:
authorization master ( instance )

-- No handler (get_instance_authorizations):
METHOD get_instance_authorizations.
  READ ENTITIES OF ZLH_R_BusinessPartner IN LOCAL MODE
    ENTITY ZLH_R_BusinessPartner
    ...
  LOOP AT businesspartners ...
    -- Checar se usuário tem permissão para UPDATE nessa instância:
    IF requested_authorizations-%update = if_abap_behv=>mk-on.
      AUTHORITY-CHECK OBJECT 'ZLOYLTYHUB'
        ID 'ZLH_USER' FIELD 'ADMIN'
        ID 'ACTVT'    FIELD '02'.
      APPEND VALUE #(
        %tky    = <bp>-%tky
        %update = COND #( WHEN sy-subrc = 0
                          THEN if_abap_behv=>auth-allowed
                          ELSE if_abap_behv=>auth-unauthorized )
      ) TO result.
    ENDIF.
  ENDLOOP.
ENDMETHOD.
```

### Global Authorization (para o BO inteiro)
```abap
-- No BDEF:
authorization master ( global )

-- No handler (get_global_authorizations):
METHOD get_global_authorizations.
  IF requested_authorizations-%create = if_abap_behv=>mk-on.
    AUTHORITY-CHECK OBJECT 'ZLOYLTYHUB'
      ID 'ZLH_USER' FIELD 'ADMIN'
      ID 'ACTVT'    FIELD '01'.
    result-%create = COND #( WHEN sy-subrc = 0
                             THEN if_abap_behv=>auth-allowed
                             ELSE if_abap_behv=>auth-unauthorized ).
  ENDIF.
ENDMETHOD.
```

---

## Boas Práticas de Autorização

- ✅ Definir DCLS para **todas** as views C_ que são expostas via OData
- ✅ Usar `inheriting conditions from entity` nas views filhas para herdar da R_
- ✅ Marcar Authorization Objects como **C1 Released** antes de usar em BDEFs
- ✅ Criar IAM App para **cada** Service Binding exposto
- ✅ Granularidade adequada: usuário vê apenas seus próprios dados (filtro `$session.user`)
- ❌ Nunca fazer `AUTHORITY-CHECK` dentro de LOOP em massa (performance)
- ❌ Nunca usar `@AccessControl.authorizationCheck: #NOT_REQUIRED` em views C_ de produção
- ❌ Nunca atribuir Business Roles de ADMIN a usuários de business (end users)

---

## Estrutura de Objetos de Autorização no Repositório

```
objects/
├── AUTH/
│   └── ZLH_USER/              ← Authorization Field
├── DCLS/
│   ├── ZLH_R_BUSINESSPARTNER/ ← DCLS para view R (regras de negócio)
│   ├── ZLH_C_BUSINESSPARTNER/ ← DCLS para view C (herda da R)
│   ├── ZLH_R_CATEGORY_HDR/
│   └── ZLH_C_CATEGORY_HDR/
├── SIA1/                      ← Business Catalogs (SIA = BAdI Implementation)
│   ├── ZLH_CATEGORY_MAINT_BC/
│   ├── ZLH_CATEGORY_UPDATE_JOB/
│   └── ZLOYALTYHUB_BUS_CATALOG/
└── UIAD/
    └── ...                    ← IAM App Definitions
```

## Referências
- [SAP Help: Authorization in RAP](https://help.sap.com/docs/abap-cloud/abap-rap/authorization)
- Tutorial: `Tutorials/16_AuthorizationObject_IAM_Roles.md`
- Objeto real: `objects/DCLS/ZLH_R_BUSINESSPARTNER/`
- Fundamentals: `fonte-conhecimento/abap-fundamentos/25_Authorization_Checks.md`
