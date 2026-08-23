# Padrões de Integração EIP em SAP CPI

> Enterprise Integration Patterns (EIP) implementados em SAP Cloud Integration.  
> Fonte: [apibusinesshub-integration-recipes](https://github.com/SAP/apibusinesshub-integration-recipes)

---

## Visão Geral dos EIPs Disponíveis

| Padrão | Descrição | Step CPI |
|--------|-----------|----------|
| **Splitter** | Divide mensagem em partes menores | Splitter |
| **Aggregator** | Coleta mensagens até condição ser satisfeita | Aggregator |
| **Filter** | Extrai parte da mensagem | Filter |
| **Content Enricher** | Enriquece mensagem com dados externos | Content Enricher |
| **Command Message** | Invoca operação em sistema externo | SOAP/OData/BAPI receiver |
| **Correlation Identifier** | Correlaciona mensagens relacionadas | Content Modifier (header) |
| **Document Message** | Transfere documento de dados | HTTP/SFTP/AS2 |
| **Event Message** | Notifica sobre ocorrência de evento | Message broker / JMS |
| **Request-Reply** | Padrão síncrono requisição-resposta | HTTP receiver |
| **Return Address** | Sender especifica onde enviar resposta | `SAP_Sender` / `ReplyTo` header |

---

## 1. Splitter

Divide uma mensagem com múltiplos registros em mensagens individuais.

### Tipos de Splitter:

**General Splitter** — preserva contexto do nó raiz com cada mensagem dividida:
```
Configuração:
- Expression Type: XPath
- XPath Expression: /Orders/Order
- Parallel Processing: true/false
- Stop on Exception: true/false
- Streaming: true (para grandes volumes — divide antes de carregar em memória)
```

**Iterating Splitter** — considera apenas o nó dividido, sem contexto raiz:
```
Expression Type: Token (divide por elemento XML específico)
```

**PKCS Splitter** — separa payload de sua assinatura digital.

**IDoc Splitter** — processa pacotes IDoc.

### Verificar quando todos os splits foram processados:
```groovy
// Header automático do Camel:
def isLast = message.getHeaders().get("CamelSplitComplete") // "true" se último
def index  = message.getHeaders().get("CamelSplitIndex")    // índice atual
def total  = message.getHeaders().get("CamelSplitSize")     // total de splits
```

**Com Gather:** use Splitter + Gather para coletar todos os splits antes de prosseguir. O Splitter e o Gather são sincronizados internamente — o Gather aguarda até receber todos os splits.

---

## 2. Aggregator

Coleta mensagens de múltiplas execuções até que uma condição seja satisfeita.

```
Configuração (abas):
1. General: nome do step
2. Correlation: campo XPath que correlaciona as mensagens
3. Aggregation Strategy: combinar com Combine, Append, etc.
4. Completion Condition: 
   - Last Message Condition: XPath que indica última mensagem
   - Completion Timeout: timeout em segundos/minutos
5. Data Store Name: nome do datastore interno (único por Aggregator)
```

> ⚠️ **NUNCA use Aggregator em sub-processo.** Quando o sub-processo sai, o handle ao Aggregator é perdido mas o Aggregator permanece alocado no banco — causa problemas de performance e estabilidade.

> ⚠️ **Para parar retry não-stop:** delete manualmente o Data Store com o mesmo nome do Aggregator em *Message Monitoring → Data Stores*.

---

## 3. Filter

Extrai parte da mensagem — o restante é descartado do pipeline.

```
Configuração:
- Name: identificador
- XPath Expression: XPath do dado a extrair
- Value Type: Node, Nodelist, String, etc.
```

**Exemplo:** extrair apenas `<Address>` de uma mensagem maior:
```xpath
/Customer/Address
```

---

## 4. Content Enricher

Enriquece a mensagem do pipeline com dados de um sistema externo.

```
Protocolos suportados para lookup: SuccessFactors, SOAP 1.x, OData

Modos de combinação:
1. Combine — concatena lookup ao final da mensagem original (estrutura multimap)
2. Enrich  — substitui/atualiza campos específicos na mensagem original
```

**Terminologia:**
- **Original Message:** mensagem no pipeline
- **Lookup Message:** resposta do sistema externo
- **Enriched Message:** resultado final

---

## 5. Command Message (EIPinCPI)

Invoca operação específica em sistema externo. Variantes:

| Tipo | Adapter |
|------|---------|
| SOAP Operation | SOAP receiver |
| OData Function Import | OData receiver |
| BAPI | RFC/IDOC receiver |

```groovy
// Logar resposta no MPL
messageLog.addAttachmentAsString("Response", message.getBody(String), "application/xml")
```

---

## 6. Correlation Identifier (EIPinCPI)

Marca mensagens com ID único para correlação em fluxos assíncronos:

```groovy
// Gerar e definir correlation ID
import java.util.UUID
message.setHeader("CorrelationId", UUID.randomUUID().toString())
```

Em Content Modifier, use `${exchangeId}` como correlation ID automático.

---

## 7. Document Message (EIPinCPI)

Padrão para transferência de documentos de dados estruturados:
- Usar **MIME type** adequado (`application/xml`, `application/json`)
- Definir schema via XSD ou JSON Schema para validação

---

## 8. Event Message (EIPinCPI)

Notificação de evento sem dados de negócio detalhados:
- Payload mínimo (apenas dados de identificação do evento)
- Usar **Event Mesh (SAP BTP)** ou JMS para desacoplamento

---

## 9. Request-Reply (EIPinCPI)

Padrão síncrono: enviar requisição e aguardar resposta.

```
Padrão típico:
Sender → [CPI iFlow] → Receiver
              ↑____________|
              (response)
```

Use **InOut** Exchange Pattern no receiver adapter.

---

## 10. Return Address (EIPinCPI)

O sender especifica para onde a resposta deve ser enviada:

```groovy
// Ler ReplyTo do header e usar como destino dinâmico
def replyTo = message.getHeaders().get("ReplyTo")
message.setProperty("DynamicReceiverURL", replyTo)
```

---

## Boas Práticas EIP

| ✅ Faça | ❌ Evite |
|---------|---------|
| Use Gather após Splitter para sincronizar processamento | Aggregator dentro de sub-processos |
| Configure `Stop on Exception` no Splitter quando ordem importa | Parallel multicast com acesso a Data Store |
| Use `CamelSplitComplete` para detectar último split | Delete manual de Aggregator entries sem verificar o Data Store Name |
| Delete Data Store do Aggregator manualmente se retry ficar preso | Deixar Aggregator com timeout muito curto em mensagens de grande volume |

---

## Referências

- Receitas base: `Splitter`, `Aggregator`, `Filter`, `Content Enricher`, `EIP-MessageConstruction-*`, `How to determine when all split messages are processed`, `Stopping Aggregator from non-stop retry`
- [Blog EIPinCPI](https://blogs.sap.com/2019/12/22/eipincpi-command-message)
