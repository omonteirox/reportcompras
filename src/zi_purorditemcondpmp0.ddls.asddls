@AccessControl.authorizationCheck: #NOT_REQUIRED

@EndUserText.label: 'Condição PMP0 por Item do Pedido'

define view entity ZI_PurOrdItemCondPMP0
  as select from I_PurOrdItmPricingElementAPI01

{
  key PurchaseOrder,
  key PurchaseOrderItem,

      TransactionCurrency,

      @Semantics.amount.currencyCode: 'TransactionCurrency'
      cast(
        max(case when ConditionQuantity > 0
                 then cast(ConditionRateValue as abap.dec(15,5)) / cast(ConditionQuantity as abap.dec(15,5))
                 else cast(ConditionRateValue as abap.dec(15,5))
            end)
      as abap.curr(15,2))  as ConditionUnitRate
}

where ConditionType = 'PMP0'

group by PurchaseOrder,
         PurchaseOrderItem,
         TransactionCurrency
