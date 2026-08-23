# Groovy Scripting em SAP Cloud Integration (CPI)

> Referência completa de APIs e padrões Groovy para scripts em iFlows.  
> Fonte: [apibusinesshub-integration-recipes](https://github.com/SAP/apibusinesshub-integration-recipes)

---

## Estrutura Básica de um Script Groovy

```groovy
import com.sap.gateway.ip.core.customdev.util.Message
import java.util.HashMap

def Message processData(Message message) {
    // acesso ao body
    def body = message.getBody(String)
    
    // acesso a headers
    def headers = message.getHeaders()
    def myHeader = headers.get("HeaderName")
    
    // acesso a properties
    def props = message.getProperties()
    def myProp = props.get("PropertyName")
    
    // set header / property
    message.setHeader("NewHeader", "value")
    message.setProperty("NewProp", "value")
    
    // log na Message Processing Log
    def messageLog = messageLogFactory.getMessageLog(message)
    messageLog?.addAttachmentAsString("Label", "content", "text/plain")
    
    return message
}
```

---

## 1. Acessando Value Mappings

**Classes necessárias:**
- `com.sap.it.api.ITApiFactory`
- `com.sap.it.api.mapping.ValueMappingApi`

**Assinatura do método:**
```java
public String getMappedValue(String sourceAgency, String sourceIdentifier, String sourceValue,
                              String targetAgency, String targetIdentifier)
```

**Exemplo completo:**
```groovy
import com.sap.gateway.ip.core.customdev.util.Message
import com.sap.it.api.ITApiFactory
import com.sap.it.api.mapping.ValueMappingApi

def Message processData(Message message) {
    def valueMapApi = ITApiFactory.getApi(ValueMappingApi.class, null)
    def props = message.getProperties()
    
    def value = valueMapApi.getMappedValue(
        props.get("sourceAgency"),
        props.get("sourceIdentifier"),
        props.get("sourceValue"),
        props.get("targetAgency"),
        props.get("targetIdentifier")
    )
    
    def messageLog = messageLogFactory.getMessageLog(message)
    messageLog?.addAttachmentAsString("Mapped Value", value ?: "Not Found", "text/plain")
    
    return message
}
```

> ⚠️ Se `getMappedValue` retornar `null`, o valor não foi encontrado — sempre verifique.

---

## 2. Acessando Credenciais (User/Password)

**Classes necessárias:**
- `com.sap.it.api.securestore.SecureStoreService`
- `com.sap.it.api.securestore.UserCredential`

```groovy
import com.sap.it.api.ITApiFactory
import com.sap.it.api.securestore.SecureStoreService
import com.sap.it.api.securestore.UserCredential

def service = ITApiFactory.getApi(SecureStoreService.class, null)

def credential = service.getUserCredential("MyCredentialAlias")

String userName = credential.getUsername()
String password = new String(credential.getPassword())
```

> 🔐 O alias deve estar configurado em **Operations View → Security Material**.

---

## 3. Acessando o Keystore (Chaves e Certificados)

**Classe necessária:** `com.sap.it.api.securestore.KeyStoreService`

```groovy
import com.sap.it.api.ITApiFactory
import com.sap.it.api.securestore.KeyStoreService
import java.security.PrivateKey
import java.security.cert.X509Certificate

def clientSignKeyAlias = "sap_cloudintegrationcertificate"

def service = ITApiFactory.getApi(KeystoreService.class, null)
if (service == null) throw new IllegalStateException("Keystore Service not available")

// Chave privada
PrivateKey privateKey = (PrivateKey) service.getKey(clientSignKeyAlias)
if (privateKey == null) throw new IllegalStateException("Private key not found: ${clientSignKeyAlias}")

// Certificado público
X509Certificate cert = (X509Certificate) service.getCertificate(clientSignKeyAlias)
if (cert == null) throw new IllegalStateException("Certificate not found: ${clientSignKeyAlias}")

cert.checkValidity() // lança exceção se expirado
```

---

## 4. Acessando Partner Directory

**Classe necessária:** `com.sap.it.api.pd.PartnerDirectoryService`

```groovy
import com.sap.it.api.ITApiFactory
import com.sap.it.api.pd.PartnerDirectoryService

def service = ITApiFactory.getApi(PartnerDirectoryService.class, null)
if (service == null) throw new IllegalStateException("Partner Directory Service not found")

def partnerId = message.getProperties().get("PartnerId")
if (partnerId == null) throw new IllegalStateException("PartnerId property not set")

// Parâmetro String
def receiverURL = service.getParameter("ReceiverURL", partnerId, String.class)
message.setProperty("ReceiverURL", receiverURL)

// Parâmetro Binary (referência via header URI)
message.setHeader("xsltmappingname", "pd:${partnerId}:xsltmapping:Binary")
```

**Referências Partner Directory:**
- [SAP Help — Parameterizing Integration Flows Using Partner Directory](https://help.sap.com/viewer/368c481cd6954bdfa5d0435479fd4eaf/Cloud/en-US/b7812a546ab14de6aa0a7c919d8272bb.html)

---

## 5. Acessando Value Maps via Script (via Message Mapping context)

Usado em scripts `.gsh` chamados por Message Mapping:

```groovy
import com.sap.it.api.mapping.MappingContext

def String getProperty(String myProperty, MappingContext context) {
    return context.getProperty(myProperty)
}

def String getHeader(String myHeader, MappingContext context) {
    return context.getProperty(myHeader)
}
```

Para Externalized Parameters: use Content Modifier para atribuir o valor a uma property/header, depois chame `getProperty/getHeader` no script.

---

## 6. Message Processing Log (MPL)

```groovy
def messageLog = messageLogFactory.getMessageLog(message)
if (messageLog != null) {
    // Adicionar attachment texto
    messageLog.addAttachmentAsString("Nome", "conteúdo", "text/plain")
    
    // Logar como attachment XML
    messageLog.addAttachmentAsString("Request", body, "application/xml")
}
```

---

## 7. Boas Práticas Groovy em CPI

| ✅ Faça | ❌ Evite |
|---------|---------|
| Use `Byte` em vez de `String` quando possível (menos memória) | Manter headers/properties grandes em memória após uso |
| Libere headers/properties no final do script | Global variables com grandes payloads (usam headers internamente) |
| Verifique null em todas as APIs (`getApi`, `getMappedValue`, etc.) | DOM parsing em XMLs grandes — use SAX/StAX |
| Reset local variables no início do flow (evitar resquícios de execuções anteriores) | Parallel multicast com acesso a Data Store (thread safety) |

---

## 8. Padrão de Tratamento de Erros

```groovy
def service = ITApiFactory.getApi(ValueMappingApi.class, null)
if (service == null) {
    throw new IllegalStateException("ValueMappingApi not available")
}

def result = service.getMappedValue(...)
if (result == null) {
    throw new IllegalArgumentException("Mapping not found for value: ${sourceValue}")
}
```

---

## Referências

- [SAP API Business Hub — Integration Recipes](https://github.com/SAP/apibusinesshub-integration-recipes)
- Receitas base: `AccessValueMappingsDynamicallyScript`, `AccessTenantKeystoreusingScript`, `Accessing credentails from a script`, `Accessing-Partner-Directory-entries-from-within-a-script`
