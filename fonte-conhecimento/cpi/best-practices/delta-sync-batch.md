# Delta Sync, Data Store e Batch Processing em SAP CPI

> Padrões para sincronização incremental, persistência e processamento em lote.  
> Fonte: [apibusinesshub-integration-recipes](https://github.com/SAP/apibusinesshub-integration-recipes)

---

## 1. Data Store Operations

O **Data Store** é a persistência nativa do CPI — banco de dados gerenciado pelo runtime do SAP Integration Suite.

### Tipos de Variáveis de Persistência

| Tipo | Escopo | Retenção | Uso |
|------|--------|----------|-----|
| **Data Store** | Local ou Global | 90 dias (padrão) | Mensagens completas, filas de retry |
| **Variable (Write/Read)** | Local ou Global | 400 dias após último acesso | Timestamps, contadores, estado |

### 4 Operações do Data Store:

#### Write — Gravar entrada
```
Configurações:
- Data Store Name: máx 20 chars, sem espaços (ex: "RetryQueue_ReceiverA")
- Visibility: Integration Flow (local) ou Global
- Entry ID: chave única — use header, XPath ou GUID automático
- Retention Threshold for Alerting: dias antes de gerar alerta (padrão: 2)
- Expiration Period: dias até deleção automática (padrão: 90)
- Encrypt Stored Message: criptografar payload em repouso
- Overwrite Existing Message: substituir se Entry ID já existir
```

#### Get — Recuperar uma entrada
```
Configurações:
- Data Store Name
- Visibility
- Entry ID: se vazio, retorna a última entrada inserida
- Delete After Fetch: deletar após recuperar
```

#### Select — Recuperar múltiplas entradas (bulk)
```
Configurações:
- Data Store Name
- Visibility
- Number of Polled Messages: quantidade a recuperar
- Delete After Fetch: deletar após recuperar
```

#### Delete — Deletar entrada
```
Configurações:
- Data Store Name
- Visibility
- Entry ID: entrada específica a deletar
```

---

## 2. Implementando Delta Sync

### Problema
- Primeira execução: recuperar **todos** os registros
- Execuções seguintes: recuperar apenas **registros alterados desde a última execução** (delta)

### Solução: Variable + Timestamp

#### Opção A — Timestamp está no resultado (campo na response)
```
1. Primeira execução:
   - Use timestamp antigo (ex: "1970-01-01T00:00:00Z") para garantir que tudo seja retornado
   - Query: WHERE UpdatedAt > '1970-01-01T00:00:00Z'

2. Após recuperar os dados:
   - Extraia o timestamp MÁXIMO do resultado (via XPATH ou script)
   - Guarde num header/property

3. No FINAL do flow (após sucesso):
   - Write Variable com o timestamp máximo extraído

4. Próximas execuções:
   - Read Variable → se nulo: primeira execução → usa timestamp antigo
   - Se não nulo: usa valor da variable
   - Query: WHERE UpdatedAt > ${variable.LastTimestamp}
```

#### Opção B — Timestamp NÃO está no resultado
```
1. ANTES de buscar dados:
   - Capture timestamp ATUAL: ${date:now:yyyy-MM-dd'T'00:00:00.000'Z'}
   - Armazene em property (ex: "CurrentRunTimestamp")

2. Busque os dados com o timestamp da Variable

3. No FINAL do flow:
   - Write Variable com o valor de "CurrentRunTimestamp"
   - Próxima query: WHERE UpdatedAt BETWEEN lastTimestamp AND currentTimestamp
```

**Configuração do Timestamp Atual no Content Modifier:**
```
Property Name: CurrentRunTimestamp
Value: ${date:now:yyyy-MM-dd'T'00:00:00.000'Z'}
```

### Pontos Críticos
```
1. ✅ Sempre grave a Variable no FINAL do flow (após sucesso)
   → Se gravar antes e houver falha, registros do período atual serão perdidos

2. ✅ Variable nula = primeira execução → use data muito antiga

3. ✅ Use Local Variable se o delta é por iflow; Global Variable se compartilhado

4. ✅ Crie flow separado para primeira carga (ou use condição: if variable == null)

5. ✅ Para resiliência: recupere o timestamp logo após buscar os dados (Opção A)
   → Se o flow falhar no meio, o próximo retry reprocessará o mesmo período
```

---

## 3. Processamento em Batch (SuccessFactors)

Para processar grandes volumes de registros do SuccessFactors:

### Estratégia com Splitter + Paginação
```
1. Consulte SuccessFactors com paginação ($top, $skip)
2. Use Splitter para dividir registros individuais
3. Processe cada registro independentemente
4. Use Aggregator ou Gather para consolidar resultado se necessário
5. Use DataStore para checkpoint de paginação
```

### Controle de Paginação via DataStore
```groovy
// Lê offset atual do DataStore
def offset = message.getProperties().get("CurrentOffset") ?: "0"
def nextOffset = Integer.parseInt(offset) + batchSize

// Grava próximo offset
message.setProperty("NextOffset", nextOffset.toString())
```

---

## 4. Padrão ExactlyOnce com DataStore

Ver `error-handling.md` — seção "ExactlyOnce Handling" para o padrão completo.

**Resumo:**
```
Flow 1: Processa → Se falha → DataStore Write (por receiver)
Flow 2 (Timer): DataStore Select → Retry → Se sucesso: DataStore Delete
```

---

## 5. SimulateResponseFromWriteVariableAndDataStores

Padrão para simular resposta em testes — útil para desenvolvimento local:

```
1. Write Variable/DataStore com payload de mock
2. Read Variable/DataStore no início do flow de teste
3. Retorna o mock como se fosse resposta do sistema externo
```

---

## 6. Variables vs DataStore — Quando Usar Cada Um

| Situação | Use |
|----------|-----|
| Guardar timestamp de última execução | **Variable** (400 dias, simples) |
| Fila de retry de mensagens com falha | **DataStore** (payload completo + metadados) |
| Checkpoint de paginação | **Variable** (valor simples) |
| ExactlyOnce tracking | **DataStore** (Entry ID = message ID) |
| Compartilhar estado entre iflows do mesmo tenant | **Global Variable / Global DataStore** |

---

## Referências

- Receitas: `Implementing DeltaSync`, `Data Store Operations`, `ExactlyOnce handling in Cloud Platform Integration`, `SimulateResponseFromWriteVariableAndDataStores`, `Processing SuccessFactor records in batches in Cloud Platform Integration`
