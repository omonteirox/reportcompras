@AccessControl.authorizationCheck: #NOT_REQUIRED

@EndUserText.label: 'Último Preço de Custo NF-e por Material'

define view entity ZI_UltimoPrecoNFMaterial
  as select from    ZI_UltimaChaveNFMaterial       as MaxKey

    -- 1. Buscar o Item da Fatura (NF)
    inner join      I_SuplrInvcItemPurOrdRefAPI01  as Item
      on  Item.FiscalYear      = substring(MaxKey.LastInvoiceKey, 1, 4)
      and Item.SupplierInvoice = substring(MaxKey.LastInvoiceKey, 5, 10)

    -- 2. Buscar Referência do Pedido de Compras
    inner join      I_PurchaseOrderItemAPI01       as PO
      on  Item.PurchaseOrder     = PO.PurchaseOrder
      and Item.PurchaseOrderItem = PO.PurchaseOrderItem
      and PO.Material            = MaxKey.Material
      and PO.Plant               = MaxKey.Plant

    -- 3. Buscar Condição de Preço Bruto Manual do Pedido (PMP0) - 3,52 BRL
    left outer join I_PurOrdItmPricingElementAPI01 as CndPMP0
      on  PO.PurchaseOrder      = CndPMP0.PurchaseOrder
      and PO.PurchaseOrderItem  = CndPMP0.PurchaseOrderItem
      and CndPMP0.ConditionType = 'PMP0'

    -- 4. Buscar Condição de Preço Bruto Automático do Pedido (PB00) - Fallback
    left outer join I_PurOrdItmPricingElementAPI01 as CndPB00
      on  PO.PurchaseOrder      = CndPB00.PurchaseOrder
      and PO.PurchaseOrderItem  = CndPB00.PurchaseOrderItem
      and CndPB00.ConditionType = 'PB00'

{
  key MaxKey.Material,
  key MaxKey.Plant,

      -- Define Moeda (Usa a do Pedido diretamente para evitar erro CUKY no MAX)
      PO.DocumentCurrency,

      Item.PurchaseOrderQuantityUnit,

      -- Calcula Custo Unitário Real = Valor da Condição / Quantidade Base da Condição (ex: por 20 KG)
      @Semantics.amount.currencyCode: 'DocumentCurrency'
      cast(
        coalesce(
          max(
            case when CndPMP0.ConditionQuantity > 0
                 then cast(CndPMP0.ConditionRateValue as abap.dec(15,5)) / cast(CndPMP0.ConditionQuantity as abap.dec(15,5))
                 else cast(CndPMP0.ConditionRateValue as abap.dec(15,5))
            end
          ),
          coalesce(
            max(
              case when CndPB00.ConditionQuantity > 0
                   then cast(CndPB00.ConditionRateValue as abap.dec(15,5)) / cast(CndPB00.ConditionQuantity as abap.dec(15,5))
                   else cast(CndPB00.ConditionRateValue as abap.dec(15,5))
              end
            ),

            -- Fallback final: Valor Líquido (SupplierInvoiceItemAmount / Qtd)
            case
              when sum(Item.QuantityInPurchaseOrderUnit) > 0
              then cast(sum(Item.SupplierInvoiceItemAmount) as abap.dec(15,5)) / cast(sum(Item.QuantityInPurchaseOrderUnit) as abap.dec(15,5))
              else cast(0 as abap.dec(15,5))
            end

          )
        )
      as abap.curr(15,2))             as LastInvoiceUnitCost
}

group by MaxKey.Material,
         MaxKey.Plant,
         Item.DocumentCurrency,
         PO.DocumentCurrency,
         Item.PurchaseOrderQuantityUnit
