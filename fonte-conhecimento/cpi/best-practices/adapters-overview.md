# Adapters e Conectores em SAP CPI

> Visão geral de adapters nativos e de terceiros disponíveis no SAP Integration Suite.  
> Fonte: [apibusinesshub-integration-recipes](https://github.com/SAP/apibusinesshub-integration-recipes)

---

## Adapters Nativos CPI

| Adapter | Tipo | Protocolo |
|---------|------|-----------|
| HTTP/HTTPS | Sender/Receiver | REST/HTTP |
| SOAP | Sender/Receiver | SOAP 1.1/1.2 |
| OData | Sender/Receiver | OData V2/V4 |
| IDoc | Sender/Receiver | SAP IDoc |
| RFC/BAPI | Receiver | SAP RFC |
| SFTP | Sender/Receiver | SFTP/FTP |
| Mail (SMTP/IMAP/POP3) | Sender/Receiver | Email |
| AS2 | Sender/Receiver | B2B AS2 |
| JMS | Sender/Receiver | JMS (Event Mesh) |
| ProcessDirect | Sender/Receiver | Interno (intra-tenant) |
| SuccessFactors | Sender/Receiver | SF OData/SOAP |
| Ariba | Sender/Receiver | Ariba APIs |
| Workday | Receiver | Workday APIs |

---

## 1. Mail Adapter — Conectar ao Gmail

**Pré-requisitos:**
1. Criar credencial em *Operations View → Security Material → Add User Credential* (user/senha Gmail)
2. Fazer teste de conectividade SMTP e baixar certificados:
   - *Operations View → Manage Security → Connectivity Tests → SMTP*
   - Configure host `smtp.gmail.com`, porta `465`
   - Clique **Send** → baixe os 2 certificados do ZIP retornado
3. Importe os 2 certificados no Keystore
4. Configure conta Gmail para aceitar apps menos seguros (ou use App Password)
5. Desbloqueie captcha em `https://accounts.google.com/b/0/DisplayUnlockCaptcha`

**Configuração do Mail Receiver:**
```
Host: smtp.gmail.com
Port: 465
Transport Security: SSL
Credential Name: <alias criado no passo 1>
From: seu-email@gmail.com
```

---

## 2. Amazon DynamoDB — Conectar via REST

O CPI não tem adapter nativo para DynamoDB. Use chamada REST com autenticação **AWS4-HMAC-SHA256**:

```
1. Prepare headers e payload seguindo DynamoDB API (ex: PutItem)
2. Chame o iflow reutilizável GenerateAWS4-HMAC-SHA256 via ProcessDirect
   → Retorna header "Authorization" e "X-Amz-Date"
3. Faça POST HTTP para endpoint DynamoDB:
   https://dynamodb.{region}.amazonaws.com/

Endpoint exemplo PutItem:
Method: POST
Host: dynamodb.us-east-1.amazonaws.com
Header: Content-Type: application/x-amz-json-1.0
Header: X-Amz-Target: DynamoDB_20120810.PutItem
```

> ⚠️ Certifique-se de importar o certificado SSL da AWS no Keystore se receber erro de SSL.

**Referência:** [Amazon DynamoDB PutItem API](https://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_PutItem.html)

---

## 3. Adapters de Terceiros (Community)

Os adapters abaixo estão disponíveis como **Open Source** no repositório:

### MongoDB Integration Adapter
```
Pasta: mongodb-integration-adapter/
Operações: Find, Insert, Update, Delete, Aggregate
Configuração: connection string, database name, collection name
```

### Redis Integration Adapter
```
Pasta: redis-integration-adapter/
Operações: GET, SET, DEL, HGET, HSET
Uso comum: cache distribuído, rate limiting, pub/sub
```

### RabbitMQ Integration Adapter
```
Pasta: rabbitmq-integration-adapter/
Protocolo: AMQP
Operações: Publish, Subscribe
```

### Azure Integration Adapter
```
Pasta: azure-integration-adapter/
Serviços suportados: Azure Blob Storage, Azure Service Bus
```

### CMIS Integration Adapter
```
Pasta: cmis-integration-adapter/
Protocolo: Content Management Interoperability Services
Uso: gerenciamento de documentos (SAP OpenText, Alfresco, etc.)
```

### Pricefx Integration Adapter
```
Pasta: pricefx-integration-adapter/
Uso: integração com plataforma de pricing Pricefx
```

### Private Link Proxy
```
Pasta: privatelinkproxy/
Uso: roteamento de chamadas via SAP BTP Private Link Service
Permite conectar CPI a sistemas on-premise sem VPN exposta
```

---

## 4. Adapter ProcessDirect — Chamadas Internas

O ProcessDirect permite que um iFlow chame outro iFlow **no mesmo tenant** sem overhead HTTP:

```
Sender iFlow → [ProcessDirect Sender] → Receiver iFlow
                 Address: /MyEndpointPath

Receiver iFlow → [ProcessDirect Receiver]
                   Address: /MyEndpointPath
```

**Casos de uso:**
- iFlows de suporte reutilizáveis (ex: geração de assinatura AWS4-HMAC)
- Modularização de lógica complexa
- Sub-flows chamados por múltiplos iFlows principais

---

## 5. Exposing SOAP/HTTP Endpoint from Scheduled Flow

Para expor um endpoint em um iflow que normalmente usa Timer/Scheduler:

```
1. Adicione um Sender com adapter HTTP (ou SOAP)
2. Configure path e segurança (Basic, OAuth, Client Certificate)
3. Conecte ao mesmo processo do Timer (início)
4. O iflow pode agora ser disparado tanto por schedule quanto por chamada HTTP

Cuidado: o endpoint ficará exposto enquanto o iflow estiver deployado
Mesmo sem timer ativo, chamadas ao endpoint serão processadas
```

---

## 6. Integrações Pré-Construídas (Production-Ready)

O repositório inclui packages completos com iFlows próximos de produção:

| Pacote | Sistemas |
|--------|---------|
| `sapsuccessfactorsemployeecentralintegrationwithworkday` | SAP SF EC ↔ Workday |
| `sapconcurintegrationwithsapsuccessfactorsemployeecentral` | SAP Concur ↔ SF EC |
| `saparibaintegrationwithsaparibaapis` | SAP Ariba ↔ Ariba APIs |
| `crmintegrationwithsaps4hanacloudandsaperp` | CRM ↔ S/4HANA Cloud/ERP |
| `saperpmasterdataintegrationwithsaps4hanacloud` | SAP ERP Master Data ↔ S/4HANA Cloud |
| `saps4hanaintegrationwithbloombergbank` | S/4HANA ↔ Bloomberg (taxas de câmbio) |
| `tmforumtobrimimplementationtemplates` | TM Forum → BRIM (Billing) |
| `b2bintegrationfactory*` | B2B EDI X12/EDIFACT/AS2 completo |

---

## 7. Boas Práticas com Adapters

| ✅ Faça | ❌ Evite |
|---------|---------|
| Use ProcessDirect para sub-flows internos | HTTP calls internas (overhead desnecessário) |
| Importe certificados SSL externos no Keystore | Desabilitar SSL verification |
| Use credenciais aliases — nunca hardcode | Senhas e tokens no código |
| Configure timeouts adequados nos adapters | Timeouts muito altos (bloqueia threads) |
| Use JMS/Event Mesh para desacoplamento assíncrono | Polling excessivo em sistemas externos |

---

## Referências

- Receitas: `Connect to Gmail using the mail adapter`, `ConnectToAWSDynmoDB`, `GenerateAWS4_HMAC_SHA256`, `mongodb-integration-adapter`, `redis-integration-adapter`, `rabbitmq-integration-adapter`, `azure-integration-adapter`, `cmis-integration-adapter`, `privatelinkproxy`, `Exposing SOAP or HTTP endpoint from a Scheduled flow`
