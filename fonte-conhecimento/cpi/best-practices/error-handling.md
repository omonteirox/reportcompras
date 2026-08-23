# Tratamento de Erros e Pitfalls em SAP CPI

> ExactlyOnce, erros comuns, retry patterns e pitfalls de desenvolvimento.  
> Fonte: [apibusinesshub-integration-recipes](https://github.com/SAP/apibusinesshub-integration-recipes)

---

## 1. ExactlyOnce Handling

### Problema
O CPI não suporta Quality of Service "Exactly Once" (EO) nativamente — mensagens com falha não são reprocessadas automaticamente. Em cenários com múltiplos receivers, a mensagem pode ser parcialmente entregue.

### Solução por Modelagem

**Flow 1 — Processamento Principal:**
1. Processe a mensagem normalmente
2. Para cada receiver, crie um **sub-processo**
3. O **exception sub-process** de cada sub-processo grava a mensagem no DataStore correspondente
4. Use DataStores com **nomes diferentes** por receiver

```
Flow 1:
[Start] → [Process] → [SubProcess Receiver A]
                    → [SubProcess Receiver B]
                    → [SubProcess Receiver C]

SubProcess Exception Handler:
[Exception] → [DataStore Write: "FailedForReceiverA"]
```

**Flow 2 — Retry Agendado (a cada 5-60 min):**
1. Para cada receiver, verifique se há entradas no DataStore correspondente
2. Se houver: tente reenviar
3. Se sucesso: delete a entrada do DataStore
4. Se falha: mantenha no DataStore para próximo retry

```
Flow 2 (Scheduler):
[Timer] → [DS Select: FailedForReceiverA]
        → [If entries exist: send to Receiver A]
        → [If success: DS Delete]
```

> 💡 DataStores retêm dados por até **90 dias** (padrão). Variables retêm por **400 dias** após último acesso.

---

## 2. Common Pitfalls

### 2.1 Allowed Headers `*` — Evite!
```
❌ Allowed Headers: *  (passa TODOS os HTTP headers ao receiver)
✅ Especifique apenas os headers necessários
```

### 2.2 Byte vs String — Use Byte quando possível
```groovy
// ❌ String — maior consumo de memória
String body = message.getBody(String)

// ✅ Byte — mais eficiente, se o próximo step suporta byte[]
byte[] body = message.getBody(byte[])
```

### 2.3 Parallel Multicast com DataStore — PROIBIDO
```
❌ Parallel Multicast → [DataStore Write]
   (threads paralelas não compartilham transação DB)

✅ Sequential Multicast → [DataStore Write]
```

### 2.4 Global Variables com Headers Grandes
```groovy
// Global variables usam headers internamente para persistência no DB
// Se o header for grande → falha no iflow

// ✅ Libere o header após uso
message.setHeader("GlobalVarName", null)
```

### 2.5 Local Variables — Reset no Início do Flow
```groovy
// Local variables persistem APÓS fim da execução do iflow
// Se o flow encerrou com falha, a variable pode ter valor inválido
// ✅ Sempre reset no início:
message.setProperty("MyLocalVar", null)
```

### 2.6 Aggregator em Sub-Processo — NUNCA
```
❌ Sub-Processo → [Aggregator]
   (handle perdido ao sair do sub-processo; DataStore persiste; performance degradada)

✅ Aggregator apenas no processo principal
```

---

## 3. Parar Aggregator em Retry Não-Stop

**Sintoma:** iFlow com Aggregator falhou; mesmo após undeploy, continua tentando processar (retry infinito no Message Monitoring).

**Causa:** O Aggregator usa um DataStore interno. Undeploy não limpa o DataStore.

**Solução:**
1. *Message Monitoring → Data Stores*
2. Localize o DataStore com o mesmo nome do campo **Data Store Name** do Aggregator
3. Haverá **2 entradas** por Aggregator
4. Selecione cada entrada → aba Properties → **Delete Entry**
5. O retry para

---

## 4. Erros de Certificado

### "Unable to find valid certification path to requested target"
```
Solução:
1. Operations View → Connectivity Tests → HTTPS
2. Configure o host externo e clique em Send
3. Baixe o certificado exibido na resposta
4. Operations View → Manage Security → Keystore → Add
5. Importe o certificado
6. Reprocesse a mensagem
```

### "Fixing Unexpected character in prolog expected error"
**Causa:** BOM (Byte Order Mark) no início do payload XML ou encoding incorreto.

```groovy
// Remover BOM em Groovy
def body = message.getBody(String)
if (body.startsWith("\uFEFF")) {
    body = body.substring(1)
}
message.setBody(body)
```

### "Fixing bad request when calling CPI endpoint from another iflow"
- Verifique `Content-Type` header
- Use ProcessDirect Adapter para chamadas internas (sem autenticação)
- Para HTTP externo: configure OAuth2 ou Basic Auth corretamente

---

## 5. Padrões de Retry com DataStore

```groovy
// Verificar se entry já foi processada (ExactlyOnce check)
// No início do flow, antes de processar:
import com.sap.gateway.ip.core.customdev.util.Message

def processId = message.getHeaders().get("MessageId") ?: message.getHeaders().get("SAP_MessageProcessingLogID")

// Se o DataStore já tiver uma entrada para este ID, ignorar (já processado)
// Use Write + Get pattern:
// 1. DS Get com Entry ID = processId
// 2. Se encontrado → skip
// 3. Se não encontrado → processa + DS Write com Entry ID = processId
```

---

## 6. Monitoramento e Debugging

| Item | Localização |
|------|-------------|
| Message Processing Logs | *Operations View → Monitor Message Processing* |
| DataStore entries | *Operations View → Monitor → Data Stores* |
| Deployed iFlows | *Operations View → Manage Integration Content* |
| Security Material | *Operations View → Manage Security* |
| Connectivity Tests | *Operations View → Manage Security → Connectivity Tests* |

> ⚠️ **Tracing** adiciona overhead significativo — mantenha desligado em produção. Ligue apenas para troubleshooting pontual.

---

## 7. Boas Práticas de Performance

| Recomendação | Motivo |
|--------------|--------|
| Use Splitter para grandes volumes | Processa em chunks; evita OOM |
| DOM parsing apenas para XMLs pequenos | DOM carrega toda a árvore em memória |
| SAX/StAX para XMLs grandes | Stream — não carrega tudo em memória |
| XPATHs absolutos | XPATHs relativos complexos são caros |
| Evite datatype conversion desnecessária | Conversão tem custo de processamento |
| Mantenha tracing desligado em produção | Cada step é persistido — alta sobrecarga |
| Evite multicasts desnecessários | Multiplica dados em memória |

---

## Referências

- Receitas: `ExactlyOnce handling in Cloud Platform Integration`, `Common Pitfalls`, `Stopping Aggregator from non-stop retry`, `Fix- Unable to find valid certification path to requested target`, `Fixing Unexpected character in prolog expected error`, `Optimizing-memory-footprint`
