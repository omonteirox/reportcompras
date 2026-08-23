# ❌ Erro: ProcessDirect Outbound — Propriedades Obrigatórias Faltando no BPMN

## Contexto

Ao criar manualmente um iFlow via edição direta do arquivo BPMN (`.iflw`), ao adicionar
um `bpmn2:messageFlow` com `ComponentType=ProcessDirect` para chamar outro iFlow via
canal ProcessDirect, o upload do ZIP no CPI retornou erros de validação.

**Erros observados:**
```
"This component ProcessDirect with version 1.1 is not supported in Cloud Integration profile"
"Enter adapter details for channel ProcessDirect [MessageFlow_CriarBP_Call]"
```

## Causa Raiz

O `messageFlow` estava com propriedades incompletas. O CPI valida um conjunto específico
de propriedades para considerar o adapter como configurado corretamente. Sem essas
propriedades o runtime interpreta o canal como inválido ou não reconhece a versão.

**Propriedades críticas que estavam faltando:**

| Propriedade | Valor obrigatório |
|-------------|-------------------|
| `TransportProtocol` | `Not Applicable` |
| `cmdVariantUri` | `ctype::AdapterVariant/cname::ProcessDirect/vendor::SAP/tp::Not Applicable/mp::Not Applicable/direction::Receiver/version::1.1.1` |
| `MessageProtocol` | `Not Applicable` |
| `MessageProtocolVersion` | `1.1.2` |
| `ComponentSWCVId` | `1.1.2` |
| `direction` | `Receiver` |

## Solução — Template Correto para MessageFlow ProcessDirect Outbound

```xml
<bpmn2:messageFlow id="MessageFlow_MinhaChamada" name="ProcessDirect" sourceRef="ServiceTask_ID" targetRef="Participant_ID">
    <bpmn2:extensionElements>
        <ifl:property><key>ComponentType</key><value>ProcessDirect</value></ifl:property>
        <ifl:property><key>Description</key><value/></ifl:property>
        <ifl:property><key>address</key><value>/meu-endereco</value></ifl:property>
        <ifl:property><key>ComponentNS</key><value>sap</value></ifl:property>
        <ifl:property><key>Vendor</key><value>SAP</value></ifl:property>
        <ifl:property><key>componentVersion</key><value>1.1</value></ifl:parameter>
        <ifl:property><key>Name</key><value>ProcessDirect</value></ifl:property>
        <ifl:property><key>TransportProtocolVersion</key><value>1.1.2</value></ifl:property>
        <ifl:property><key>ComponentSWCVName</key><value>external</value></ifl:property>
        <ifl:property><key>system</key><value>NomeSistema</value></ifl:property>
        <!-- ⬇️ Propriedades críticas que devem estar presentes -->
        <ifl:property><key>TransportProtocol</key><value>Not Applicable</value></ifl:property>
        <ifl:property><key>cmdVariantUri</key><value>ctype::AdapterVariant/cname::ProcessDirect/vendor::SAP/tp::Not Applicable/mp::Not Applicable/direction::Receiver/version::1.1.1</value></ifl:property>
        <ifl:property><key>MessageProtocol</key><value>Not Applicable</value></ifl:property>
        <ifl:property><key>MessageProtocolVersion</key><value>1.1.2</value></ifl:property>
        <ifl:property><key>ComponentSWCVId</key><value>1.1.2</value></ifl:property>
        <ifl:property><key>direction</key><value>Receiver</value></ifl:property>
    </bpmn2:extensionElements>
</bpmn2:messageFlow>
```

## Erros Relacionados a Gateway (Exclusive Gateway)

### Erro: "Content Based Router model must have a default route"
- **Causa:** O `bpmn2:exclusiveGateway` não possui o atributo `default` definido.
- **Solução:** Adicionar `default="ID_DO_SEQUENCE_FLOW_PADRAO"` no gateway de SPLIT
  e também no gateway de MERGE/CONVERGENTE (ambos precisam ter default).

```xml
<bpmn2:exclusiveGateway id="ExclusiveGateway_1" name="Tipo BP?" default="SequenceFlow_Default">
```

### Erro: "Enter a condition expression for the sequence flow null"
- **Causa:** O sequence flow de saída sem nome/condição não está marcado como `default`
  no gateway.
- **Solução:** O flow que representa o caminho padrão (sem condição) deve ser o valor
  do atributo `default` no gateway — não deve ter `conditionExpression`.

## Tipo Correto para Participant Receptor (ProcessDirect Outbound)

O `Participant` que recebe a chamada ProcessDirect OUTBOUND deve usar:

```xml
<bpmn2:participant ... ifl:type="EndpointRecevier" .../>
```

> ⚠️ **ATENÇÃO:** NÃO usar `ifl:type="ProcessDirect"` para o receiver de chamada
> outbound. O tipo `ProcessDirect` é reservado para receivers **INBOUND** (quando
> o iFlow atual é chamado por outro). Para receivers outbound, o tipo correto é
> `EndpointRecevier` (com este exato typo de escrita do SAP).

## Checklist de Validação ao Criar MessageFlow ProcessDirect Manualmente

- [ ] `ComponentType` = `ProcessDirect`
- [ ] `Vendor` = `SAP`
- [ ] `componentVersion` = `1.1`
- [ ] `TransportProtocol` = `Not Applicable`
- [ ] `MessageProtocol` = `Not Applicable`
- [ ] `MessageProtocolVersion` = `1.1.2`
- [ ] `ComponentSWCVId` = `1.1.2`
- [ ] `cmdVariantUri` completo com `direction::Receiver/version::1.1.1`
- [ ] `direction` = `Receiver`
- [ ] Participant receptor com `ifl:type="EndpointRecevier"`
- [ ] Gateway com atributo `default` apontando para o sequence flow padrão
