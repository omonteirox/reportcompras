# Processamento de Mensagens em SAP CPI

> Headers, Properties, Exchange Patterns, Externalized Parameters e Message Mapping.  
> Fonte: [apibusinesshub-integration-recipes](https://github.com/SAP/apibusinesshub-integration-recipes)

---

## Modelo de Dados da Mensagem

```
Message (Camel Exchange)
├── Body (payload)
├── Headers (HTTP headers + Camel headers)
│   └── Escopo: vive durante a execução do iflow
├── Properties (exchange properties)
│   └── Escopo: vive durante a execução do iflow
└── Attachments
```

> ⚠️ **Diferença Headers vs Properties:**  
> - **Headers** são propagados ao receiver (se configurado em "Allowed Headers")  
> - **Properties** são internos ao iflow — não propagados automaticamente

---

## 1. Acesso em Groovy Script

```groovy
def Message processData(Message message) {
    // Ler body
    String body = message.getBody(String)
    byte[] bytes = message.getBody(byte[])   // mais eficiente — usa menos memória
    
    // Ler headers
    def headers = message.getHeaders()
    String myHeader = headers.get("MyHeader")
    
    // Ler properties
    def props = message.getProperties()
    String myProp = props.get("MyProperty")
    
    // Definir header
    message.setHeader("ResponseCode", "200")
    
    // Definir property
    message.setProperty("ProcessingStatus", "SUCCESS")
    
    // Limpar header (liberar memória)
    message.setHeader("LargeHeader", null)
    
    return message
}
```

---

## 2. Acesso em XPATH (Content Modifier / Router)

| Expressão | Resultado |
|-----------|-----------|
| `${header.OrderId}` | Valor do header `OrderId` |
| `${property.Status}` | Valor da property `Status` |
| `${header.CamelHttpResponseCode}` | HTTP response code |
| `${date:now:yyyy-MM-dd'T'HH:mm:ss.SSS'Z'}` | Timestamp atual formatado |
| `${in.body}` | Body da mensagem de entrada |
| `${exchangeId}` | ID único da exchange atual |

---

## 3. XPATH com Headers em Expressões XPath

Para filtrar mensagens XML usando valor de header:

```xpath
/School/Grade/Student[Age >= $AgeLimit]
```

> No Content Modifier, configure o header `AgeLimit = 14` e use `$AgeLimit` no XPATH.

---

## 4. Acesso em XSLT Mapping

```xml
<!-- 1. Definir namespace SAP CPI -->
<xsl:stylesheet version="2.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:hci="http://sap.com/it/">

<!-- 2. Incluir exchange como parâmetro -->
<xsl:param name="exchange"/>

<!-- 3. Ler header/property (auto-binding pelo nome) -->
<xsl:param name="OrderId"/>  <!-- recebe valor do header/property 'OrderId' automaticamente -->

<!-- 4. Definir header ou property -->
<xsl:value-of select="hci:setHeader($exchange, 'ProcessedBy', 'XSLT')"/>
<xsl:value-of select="hci:setProperty($exchange, 'Status', 'OK')"/>
```

---

## 5. Acesso em Message Mapping (Custom Functions)

Crie script `.gsh` com `MappingContext`:

```groovy
import com.sap.it.api.mapping.MappingContext

// Lê property pelo nome
def String getProperty(String propName, MappingContext context) {
    return context.getProperty(propName)
}

// Lê header pelo nome
def String getHeader(String headerName, MappingContext context) {
    return context.getProperty(headerName)
}
```

**Para Externalized Parameters:**
1. No Content Modifier: atribua o externalized parameter a uma property/header
2. Use `getProperty` ou `getHeader` no script do Message Mapping
3. Adicione a *Custom Function* no Message Mapping e use-a no canvas

---

## 6. Externalized Parameters

Permitem parametrizar iflows sem editar o código. Definidos via `{{parametro}}` em configurações:

```
Receiver URL: {{ReceiverURL}}
```

**Acesso via script** (via property intermediária):
```groovy
// No Content Modifier: set Property "MyURL" = "${exchangeProperty.ReceiverURL}"
// No Groovy:
def url = message.getProperties().get("MyURL")
```

---

## 7. Camel Headers Importantes

| Header | Descrição |
|--------|-----------|
| `CamelHttpResponseCode` | Código HTTP de resposta do receiver |
| `CamelHttpMethod` | Método HTTP da requisição (GET, POST, etc.) |
| `CamelSplitIndex` | Índice da mensagem dividida pelo Splitter |
| `CamelSplitSize` | Total de mensagens geradas pelo Splitter |
| `CamelSplitComplete` | `true` se é a última mensagem do Splitter |
| `CamelFileName` | Nome do arquivo (para adaptadores de arquivo) |
| `SAP_Sender` | ID do sender configurado no iflow |
| `SAP_Receiver` | ID do receiver configurado no iflow |
| `SAP_MessageProcessingLogID` | ID do MPL (Message Processing Log) |

---

## 8. Boas Práticas de Memória

```groovy
// ✅ Use byte[] quando o próximo passo não precisa de String
byte[] body = message.getBody(byte[])

// ✅ Libere headers grandes após uso
message.setHeader("LargeDataHeader", null)

// ✅ Libere a lista de headers da variável local após extrair o necessário
def headers = message.getHeaders()
String needed = headers.get("OnlyThis")
headers = null  // libera referência

// ✅ Resete local variables no início do flow
// (para evitar resquícios de execuções anteriores com falha)
```

---

## Referências

- Receitas base: `Accessing header or exchange property in XPATH expressions`, `Accessing and setting Header and Property in XSLT Mappings`, `Accessing header or property or externalized parameter from Message Mapping`, `Externalizing additional parameters`
- [SAP Help — Message Processing Log](https://help.sap.com/docs/cloud-integration)
