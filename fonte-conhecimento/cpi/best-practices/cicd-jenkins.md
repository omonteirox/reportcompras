# CI/CD para SAP Cloud Integration com Jenkins

> Templates Jenkins reutilizáveis para automação de deploy, store, update e undeploy de artefatos CPI.  
> Fonte: [apibusinesshub-integration-recipes](https://github.com/SAP/apibusinesshub-integration-recipes) — pasta `CICD-*`

---

## Visão Geral

O repositório contém **17 Jenkinsfiles reutilizáveis** para CI/CD do SAP Integration Suite, usando a **Cloud Integration OData API** para automação.

**Referência:** [Blog CI/CD for SAP Integration Suite](https://blogs.sap.com/2021/06/02/ci-cd-for-sap-integration-suite-here-you-go/)  
**API:** [Cloud Integration OData API — SAP API Business Hub](https://api.sap.com/package/CloudIntegrationAPI?section=Artifacts)

---

## Variáveis de Ambiente Comuns

Todas as pipelines usam estas variáveis de configuração:

| Variável | Exemplo | Descrição |
|----------|---------|-----------|
| `CPIHost` | `xxxx.it-cpi001.cfapps.eu10.hana.ondemand.com` | Host do tenant CPI (sem HTTPS) |
| `CPIOAuthHost` | `xxxx.authentication.sap.hana.ondemand.com` | Host do servidor OAuth |
| `CPIOAuthCredentials` | `CPIOAuthCredentials` | Alias das credenciais OAuth no Jenkins |
| `IntegrationFlowID` | `"MyIntegrationFlow"` | ID do artefato |
| `IntegrationPackageID` | `"MyPackage"` | ID do package |

---

## Templates Disponíveis

### 1. CICD-DeployIntegrationArtefactGetEndpoint
**Função:** Deploy de iFlow + obter endpoint.

```groovy
// Variáveis específicas:
IntegrationFlowID          // ID do iFlow
GetEndpoint                // true/false — recuperar endpoint após deploy
DeploymentCheckRetryCounter // nº de retries (aguarda 3s entre cada)
```

**Fluxo típico:**
```
Upload iFlow → Deploy → [aguarda status final] → [opcionalmente] Get Endpoint
```

---

### 2. CICD-DeployRunOnceIntegrationArtefactAndCheckMpl
**Função:** Deploy + dispara execução única + verifica Message Processing Log.

```groovy
IntegrationFlowID
DeploymentCheckRetryCounter
MplCheckRetryCounter        // retries para verificar MPL
MplCheckSleepTime           // sleep entre checks (ms)
```

---

### 3. CICD-DeployRunOnceIntegrationArtefactAndCheckMplAndStoreIfSuccess
**Função:** Deploy + execução + verificação MPL + armazena artefato no Git se sucesso.

---

### 4. CICD-GetLatestMessageProcessingLog
**Função:** Recupera o MPL mais recente de um iFlow.

```groovy
IntegrationFlowID
MplCheckRetryCounter
```

---

### 5. CICD-GetSpecificMessageProcessingLog
**Função:** Recupera MPL por ID específico.

```groovy
MPLId                       // ID do MPL específico
```

---

### 6. CICD-StoreIntegrationArtefact
**Função:** Baixa iFlow do tenant CPI e armazena no Git.

```groovy
IntegrationFlowID
GitFolder                   // pasta destino no repositório
GitBranch                   // branch Git
CommitUser / CommitEmail    // autor do commit
CommitMessage               // mensagem do commit
```

---

### 7. CICD-StoreIntegrationArtefactOnNewVersion
**Função:** Armazena iFlow apenas se houver nova versão (compara versão atual vs última no Git).

---

### 8. CICD-UndeployIntegrationArtefact
**Função:** Undeploy de iFlow do runtime.

```groovy
IntegrationFlowID
```

---

### 9. CICD-UpdateIntegrationConfigurationParameter
**Função:** Atualiza externalized parameter de um iFlow deployado.

```groovy
IntegrationFlowID
ParameterKey                // nome do parâmetro
ParameterValue              // novo valor
```

---

### 10. CICD-UpdateIntegrationResourcesOnGitCommit
**Função:** Atualiza recursos de um iFlow (ex: scripts, mappings) quando há commit no Git.

---

### 11. CICD-UploadIntegrationArtefact
**Função:** Faz upload de iFlow (zip) para um package do CPI.

```groovy
IntegrationFlowID
IntegrationPackageID
Overwrite                   // true — sobrescrever se existir
```

---

### 12. CICD-StoreAllAPIProviders / StoreSingleAPIProvider
**Função:** Armazena API Providers do API Management no Git.

---

### 13. CICD-StoreSingleAPIProxy / UploadSingleAPIProxy
**Função:** Store/Upload de API Proxies do API Management.

---

### 14. CICD-StoreSingleKeyValueMap / UploadSingleKeyValueMap
**Função:** Store/Upload de Key Value Maps.

---

## Padrão de Uso — Pipeline Completa

```groovy
// Jenkinsfile exemplo: upload + deploy + verificação
pipeline {
    agent any
    environment {
        CPI_HOST       = credentials('cpi-host')
        CPI_OAUTH_HOST = credentials('cpi-oauth-host')
        CPI_OAUTH_CRED = credentials('cpi-oauth-cred')
    }
    stages {
        stage('Upload') {
            steps {
                // Chama CICD-UploadIntegrationArtefact
                build job: 'CICD-UploadIntegrationArtefact', parameters: [
                    string(name: 'IntegrationFlowID', value: 'MyFlow'),
                    string(name: 'IntegrationPackageID', value: 'MyPackage'),
                    booleanParam(name: 'Overwrite', value: true)
                ]
            }
        }
        stage('Deploy') {
            steps {
                // Chama CICD-DeployIntegrationArtefactGetEndpoint
                build job: 'CICD-DeployIntegrationArtefactGetEndpoint', parameters: [
                    string(name: 'IntegrationFlowID', value: 'MyFlow'),
                    booleanParam(name: 'GetEndpoint', value: true)
                ]
            }
        }
        stage('Verify') {
            steps {
                // Chama CICD-GetLatestMessageProcessingLog
                build job: 'CICD-GetLatestMessageProcessingLog', parameters: [
                    string(name: 'IntegrationFlowID', value: 'MyFlow')
                ]
            }
        }
    }
}
```

---

## Como Consumir os Jenkinsfiles

[Instruções oficiais](../../instructions-to-consume-the-CICD-jenkins-file/readme.md)

1. Configure as variáveis de ambiente no Jenkins (Credentials)
2. Importe o Jenkinsfile desejado como Pipeline Job
3. Configure os parâmetros específicos de cada job

---

## Autenticação OAuth2

Todas as pipelines usam OAuth2 Client Credentials:
```
Grant Type: Client Credentials
Token URL: https://{CPIOAuthHost}/oauth/token
Client ID / Secret: deployados no Jenkins como credenciais
```

---

## Referências

- Receitas: `CICD-*` (17 templates)
- [Blog CI/CD SAP Integration Suite](https://blogs.sap.com/2021/06/02/ci-cd-for-sap-integration-suite-here-you-go/)
- [Cloud Integration OData API](https://api.sap.com/package/CloudIntegrationAPI?section=Artifacts)
