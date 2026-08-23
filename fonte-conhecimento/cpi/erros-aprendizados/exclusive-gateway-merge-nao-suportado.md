# ❌ Erro: ExclusiveGateway como merge (convergente) não é suportado no SAP CPI

## Contexto

Ao modelar um iFlow com dois branches (YES/NO) que precisam convergir para um step comum,
é tentador usar um `bpmn2:exclusiveGateway` com `gatewayDirection="Converging"` como ponto
de join/merge — padrão comum em BPMN 2.0 padrão.

**Erro observado ao fazer upload do ZIP no CPI:**
```
Router cannot have the default route as its only route [ExclusiveGateway_MergeBP]
```

## Causa Raiz

Em SAP CPI, um `bpmn2:exclusiveGateway` é **sempre tratado como Content Based Router**
(split/divergente), independente do atributo `gatewayDirection`.

- `gatewayDirection="Diverging"` → split (suportado)
- `gatewayDirection="Converging"` → **NÃO suportado como join/merge**

Quando o CPI encontra um gateway convergente, ainda tenta interpretá-lo como router.
Como ele não tem rotas configuradas (só a rota default), gera o erro:
`"Router cannot have the default route as its only route"`.

**Resumo:** O CPI não possui o conceito de "join gateway" explícito em BPMN.

## Solução

Remover completamente o `exclusiveGateway` de merge e conectar os dois branches
**diretamente** ao próximo step.

Em CPI, um step pode receber múltiplos `bpmn2:incoming` sem necessidade de gateway
de merge — o join é implícito.

### ❌ Estrutura incorreta

```
[Gateway BPCheck] --YES--> [SetSoldToPartyNew]   \
                                                   --> [ExclusiveGateway_Merge] --> [CallActivity_Mapping]
                  --NO---> [SetSoldToPartyExist]  /
```

### ✅ Estrutura correta

```
[Gateway BPCheck] --YES--> [SetSoldToPartyNew]   --SequenceFlow_NewToMerge--\
                                                                              --> [CallActivity_Mapping]
                  --NO---> [SetSoldToPartyExist] --SequenceFlow_ExistToMerge-/
```

O `CallActivity_Mapping` fica com dois `<bpmn2:incoming>`:

```xml
<bpmn2:callActivity id="CallActivity_Mapping" ...>
  <bpmn2:incoming>SequenceFlow_NewToMerge</bpmn2:incoming>
  <bpmn2:incoming>SequenceFlow_ExistToMerge</bpmn2:incoming>
  <bpmn2:outgoing>SequenceFlow_MappingToNext</bpmn2:outgoing>
</bpmn2:callActivity>
```

### BPMN — remover completamente o gateway de merge

```xml
<!-- REMOVER isto: -->
<bpmn2:exclusiveGateway id="ExclusiveGateway_MergeBP" gatewayDirection="Converging" />
<bpmn2:sequenceFlow id="SequenceFlow_NewToMerge"   sourceRef="SetSoldToPartyNew"   targetRef="ExclusiveGateway_MergeBP" />
<bpmn2:sequenceFlow id="SequenceFlow_ExistToMerge" sourceRef="SetSoldToPartyExist" targetRef="ExclusiveGateway_MergeBP" />
<bpmn2:sequenceFlow id="SequenceFlow_MergeToMap"   sourceRef="ExclusiveGateway_MergeBP" targetRef="CallActivity_Mapping" />

<!-- SUBSTITUIR por (conexão direta): -->
<bpmn2:sequenceFlow id="SequenceFlow_NewToMerge"   sourceRef="SetSoldToPartyNew"   targetRef="CallActivity_Mapping" />
<bpmn2:sequenceFlow id="SequenceFlow_ExistToMerge" sourceRef="SetSoldToPartyExist" targetRef="CallActivity_Mapping" />
```

## Regra Geral

> **No SAP CPI BPMN, NUNCA use `exclusiveGateway` como join/merge.**
> Use `exclusiveGateway` apenas como split (divergente).
> Joins são implícitos — conecte os branches diretamente ao próximo step.

## Erros Relacionados

| Mensagem | Causa |
|----------|-------|
| `Router cannot have the default route as its only route [X]` | Gateway convergente sem rotas configuradas |
| `Content Based Router model must have a default route` | Gateway divergente sem rota default definida |

## Referências

- SAP CPI BPMN — Content Based Router: apenas gateways divergentes são suportados
- Arquivo de exemplo: `src/main/resources/scenarioflows/integrationflow/*.iflw`
