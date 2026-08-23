# XSLT Scripting em SAP Cloud Integration (CPI)

> Referência de XSLT 3.0, transformações JSON/XML e funções Java em iFlows.  
> Fonte: [apibusinesshub-integration-recipes](https://github.com/SAP/apibusinesshub-integration-recipes)

---

## XSLT 3.0 no CPI

O SAP CPI suporta **XSLT 3.0** (Saxonica), que adiciona recursos importantes sobre XSLT 2.0:
- Funções nativas JSON (`json-to-xml`, `xml-to-json`)
- Streaming de grandes documentos (`streamable`)
- Chamada de funções Java reflexivas
- Mapas e arrays nativos

---

## 1. Converter JSON para XML

```xml
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:math="http://www.w3.org/2005/xpath-functions/math"
    xmlns:xs="http://www.w3.org/2001/XMLSchema"
    exclude-result-prefixes="xs math"
    version="3.0">

  <xsl:mode streamable="yes"/>
  <xsl:output indent="yes"/>

  <xsl:template match="data">
    <xsl:copy>
      <xsl:apply-templates select="json-to-xml(.)/*"/>
    </xsl:copy>
  </xsl:template>

  <xsl:template match="*[@key]"
      xpath-default-namespace="http://www.w3.org/2005/xpath-functions">
    <xsl:element name="{@key}">
      <xsl:apply-templates/>
    </xsl:element>
  </xsl:template>
</xsl:stylesheet>
```

> **Função:** `json-to-xml()` — converte string JSON em documento XML estruturado conforme XPath Data Model.  
> [Referência Saxonica](https://www.saxonica.com/html/documentation/functions/fn/json-to-xml.html)

---

## 2. Invocar Funções Java a partir de XSLT

XSLT 3.0 suporta **reflexive extension functions** — chamar classes Java diretamente:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="3.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  
  <!-- Invocar java.util.Date -->
  <xsl:template match="/"
      xmlns:date="java:java.util.Date">
    <xsl:value-of select="date:new()"/>
  </xsl:template>

</xsl:stylesheet>
```

**Sintaxe geral:** `xmlns:<prefixo>="java:<fully.qualified.ClassName>"`

```xml
<!-- Exemplo: chamar método estático -->
<xsl:template match="/"
    xmlns:uuid="java:java.util.UUID">
  <id><xsl:value-of select="uuid:randomUUID()"/></id>
</xsl:template>
```

---

## 3. Construir Estruturas Map com XSLT 3.0

```xml
<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="3.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:map="http://www.w3.org/2005/xpath-functions/map">

  <xsl:template match="/">
    <xsl:variable name="myMap" select="map{'key1': 'value1', 'key2': 'value2'}"/>
    <result>
      <xsl:value-of select="map:get($myMap, 'key1')"/>
    </result>
  </xsl:template>

</xsl:stylesheet>
```

---

## 4. Acessar e Definir Headers/Properties em XSLT

### Namespace obrigatório:
```xml
<xsl:stylesheet version="2.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:hci="http://sap.com/it/">
```

### Incluir exchange como parâmetro:
```xml
<xsl:param name="exchange"/>
```

### Definir header ou property:
```xml
<xsl:template match="/">
  <!-- Setar header -->
  <xsl:value-of select="hci:setHeader($exchange, 'myHeader', 'myValue')"/>
  
  <!-- Setar property -->
  <xsl:value-of select="hci:setProperty($exchange, 'myProp', 'myValue')"/>
</xsl:template>
```

### Ler header ou property (já existentes):
```xml
<!-- Todos os parâmetros XSLT são automaticamente ligados a Camel headers -->
<!-- Se um header/property com o mesmo nome existir, seu valor é auto-atribuído -->
<xsl:param name="a1"/> <!-- recebe automaticamente o valor do header 'a1' -->
```

---

## 5. Usar XPath com Headers em Filtros

**Contexto:** Header `AgeLimit = 14`, filtrar estudantes com `Age >= AgeLimit`

```xpath
/School/Grade/Student[Age >= $AgeLimit]
```

Em Content Modifier / Router, use a sintaxe:
```
${header.AgeLimit}
```

Em XPATH dentro de passos:
```xpath
/School/Grade/Student[Age >= xs:integer($AgeLimit)]
```

---

## 6. Streaming com XSLT 3.0

Para mensagens grandes, use `streamable="yes"` no `xsl:mode`:

```xml
<xsl:mode name="main" streamable="yes"/>

<xsl:template match="/" mode="main">
  <output>
    <xsl:for-each select="//record">
      <item><xsl:value-of select="field"/></item>
    </xsl:for-each>
  </output>
</xsl:template>
```

> ⚠️ **Restrições de streaming**: evite predicados reversos, acessos múltiplos ao mesmo nó e funções que requerem toda a árvore em memória.

---

## 7. Boas Práticas XSLT em CPI

| ✅ Faça | ❌ Evite |
|---------|---------|
| Use XSLT 3.0 para transformações JSON↔XML nativas | XSLT 1.0/2.0 para JSON (sem suporte nativo) |
| Use `streamable="yes"` para datasets grandes | DOM-based processing em XMLs muito grandes |
| Use funções Java para operações de datas/UUID | Lógica complexa de negócio em XSLT — prefira Groovy |
| Use `$exchange` para acessar headers/properties | Hardcoding de valores em XSLT |
| Absolute XPATHs são mais performáticos que relativos | XPATHs relativos complexos em dados grandes |

---

## Referências

- [SAP Help — Create XSLT Mapping](https://help.sap.com/viewer/368c481cd6954bdfa5d0435479fd4eaf/Cloud/en-US/5ce1f15f54244d4aa557e9c79d93a684.html)
- [Blog — CPI XSLT 3.0](https://blogs.sap.com/2019/04/16/cloud-platform-integration-xslt-mapping-is-enriched-with-xslt-3.0-specification/)
- [Saxonica — json-to-xml](https://www.saxonica.com/html/documentation/functions/fn/json-to-xml.html)
- Receitas base: `ConvertJsonToXMLusingXSLT30`, `InvokeJavaFunctionsFromXSLT30`, `ConstructMapDataStructsUsingXSLT30`, `Accessing and setting Header and Property in XSLT Mappings`
