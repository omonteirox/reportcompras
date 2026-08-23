# Segurança e Credenciais em SAP CPI

> Keystore, credentials, criptografia AES-GCM, assinatura AWS4-HMAC-SHA256.  
> Fonte: [apibusinesshub-integration-recipes](https://github.com/SAP/apibusinesshub-integration-recipes)

---

## Gerenciamento de Segurança no CPI

**Operations View → Security Material:**
- **Credentials (User/Password):** aliases para credenciais de sistemas externos
- **Keystore:** certificados e pares de chaves (keystores JKS)
- **OAuth2 Client Credentials:** tokens OAuth para receivers

---

## 1. Acessando Credenciais via Script

```groovy
import com.sap.it.api.ITApiFactory
import com.sap.it.api.securestore.SecureStoreService
import com.sap.it.api.securestore.UserCredential

def service = ITApiFactory.getApi(SecureStoreService.class, null)
if (service == null) throw new IllegalStateException("SecureStoreService not available")

def credential = service.getUserCredential("MySystemCredentialAlias")
if (credential == null) throw new IllegalStateException("Credential 'MySystemCredentialAlias' not found")

String user = credential.getUsername()
String pass = new String(credential.getPassword())
```

> 🔐 Nunca logue `user` ou `pass` em MPL em produção.

---

## 2. Acessando Keystore via Script

```groovy
import com.sap.it.api.ITApiFactory
import com.sap.it.api.securestore.KeyStoreService
import java.security.PrivateKey
import java.security.cert.X509Certificate

def service = ITApiFactory.getApi(KeystoreService.class, null)
if (service == null) throw new IllegalStateException("KeystoreService not available")

String alias = "sap_cloudintegrationcertificate"

// Chave privada
PrivateKey privateKey = (PrivateKey) service.getKey(alias)
if (privateKey == null) throw new IllegalStateException("Private key not found: ${alias}")

// Certificado público
X509Certificate cert = (X509Certificate) service.getCertificate(alias)
if (cert == null) throw new IllegalStateException("Certificate not found: ${alias}")

// Verificar validade (lança CertificateExpiredException se expirado)
cert.checkValidity()
```

**Gerenciar Keystore (Operations View → Manage Security → Keystore):**
1. Clique em **Add**
2. Selecione o certificado (`.cer`, `.crt`, `.pem`)
3. Clique em **Add**

---

## 3. Criptografia AES-256-GCM com iaik

O componente padrão de Encryptor do CPI não suporta AES-256-GCM nativamente. Use a biblioteca **iaik** (provider padrão do CPI — NÃO use BouncyCastle que requer registro como security provider).

**Algoritmo:** AES-256-GCM (Galois/Counter Mode — authenticated encryption)

### Fluxo de Criptografia:
```groovy
import iaik.cms.*
import iaik.security.ec.provider.ECCelerate
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import java.security.SecureRandom
import javax.crypto.spec.GCMParameterSpec

// 1. Definir algoritmo
AlgorithmID contentEA = (AlgorithmID) AlgorithmID.aes256_GCM.clone()

// 2. Gerar IV (Initialization Vector) — 12 bytes para GCM
SecureRandom random = SecRandom.getDefault()
byte[] iv = new byte[12]
random.nextBytes(iv)

// 3. Gerar Content Encryption Key (CEK) — AES 128-bit block
KeyGenerator keyGen = KeyGenerator.getInstance("AES")
keyGen.init(128)
SecretKey secretKey = keyGen.generateKey()

// 4. Parâmetros GCM
GCMParameterSpec params = new GCMParameterSpec(128, iv)

// 5. RecipientInfo — criptografar CEK com RSA public key do destinatário
KeyTransRecipientInfo[] recipients = new KeyTransRecipientInfo[1]
recipients[0] = new KeyTransRecipientInfo(cert, (AlgorithmID) AlgorithmID.rsaEncryption.clone())
recipients[0].encryptKey(secretKey)
```

### Fluxo de Descriptografia:
- Acessa o keystore para obter a chave privada
- Descriptografa a CEK com a chave privada RSA
- Descriptografa o payload com AES-256-GCM

---

## 4. Assinatura AWS4-HMAC-SHA256

Para autenticar chamadas REST à AWS (DynamoDB, S3, etc.), a AWS exige assinatura **AWS4-HMAC-SHA256** como Authorization header.

### Processo de 4 etapas:

**Etapa 1 — Canonical Request:**
```
METHOD\n
URI\n
QueryString\n
Headers\n
SignedHeaders\n
SHA256(body)
```

**Etapa 2 — String to Sign:**
```
AWS4-HMAC-SHA256\n
timestamp\n
scope (date/region/service/aws4_request)\n
SHA256(CanonicalRequest)
```

**Etapa 3 — Signing Key:**
```groovy
byte[] sign(byte[] key, String data) {
    Mac mac = Mac.getInstance("HmacSHA256")
    mac.init(new SecretKeySpec(key, "HmacSHA256"))
    return mac.doFinal(data.bytes)
}

byte[] signingKey = sign(
    sign(sign(sign("AWS4${secretKey}".bytes, dateStamp), region), service),
    "aws4_request"
)
```

**Etapa 4 — Authorization Header:**
```groovy
String authHeader = "AWS4-HMAC-SHA256 " +
    "Credential=${accessKey}/${scope}, " +
    "SignedHeaders=${signedHeaders}, " +
    "Signature=${signature}"

message.setHeader("Authorization", authHeader)
message.setHeader("X-Amz-Date", amzDate)
```

> 💡 Use o **iFlow reutilizável** `Generate_AWS4-HMAC-SHA256_Authorization_Header.zip` como sub-flow chamado via ProcessDirect Adapter — evite reimplementar.

---

## 5. Corrigir "Unable to find valid certification path"

Erro ao conectar a sistemas externos via HTTPS:

**Causa:** Certificado do sistema externo não está no keystore do CPI.

**Solução:**
1. *Operations View → Connectivity Tests → HTTPS*: faça um teste de conexão
2. Na resposta, baixe o certificado mostrado no rodapé
3. *Operations View → Manage Security → Keystore → Add*: importe o certificado
4. Reprocesse a mensagem

---

## 6. Corrigir "Fixing bad request when calling a CPI endpoint from another iflow"

Ao chamar um endpoint de outro iFlow via HTTP:
- Certifique-se de que o `Content-Type` header está correto
- Se usar ProcessDirect Adapter internamente, não há autenticação necessária
- Para HTTP externo: configure OAuth2 Client Credentials ou Basic Auth

---

## Boas Práticas de Segurança

| ✅ Faça | ❌ Evite |
|---------|---------|
| Use aliases no Security Material para credenciais | Hardcode de user/password em scripts |
| Use `iaik` para AES-GCM (provider padrão CPI) | Registrar BouncyCastle como security provider |
| Utilize o iFlow reutilizável para AWS4-HMAC | Reimplementar geração de assinatura AWS do zero |
| Valide certificados com `checkValidity()` | Ignorar expiração de certificados |
| Importe certificados externos no Keystore | Desabilitar SSL verification |

---

## Referências

- Receitas: `Encryption_using_AES_GCM_iaik`, `Decryption_using_AES_GCM_iaik`, `AccessTenantKeystoreusingScript`, `Accessing credentails from a script`, `GenerateAWS4_HMAC_SHA256`, `Fix- Unable to find valid certification path to requested target`
- [Galois/Counter Mode — Wikipedia](https://en.wikipedia.org/wiki/Galois/Counter_Mode)
- [AWS Signature Version 4](https://docs.aws.amazon.com/general/latest/gr/signature-version-4.html)
