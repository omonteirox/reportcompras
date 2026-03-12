@AccessControl.authorizationCheck: #NOT_REQUIRED

@EndUserText.label: 'Última Chave NFE por Material'

define view entity ZI_UltimaChaveNFMaterial
  as select from I_SupplierInvoiceAPI01        as Header

    inner join   I_SuplrInvcItemPurOrdRefAPI01 as Item
      on  Header.SupplierInvoice = Item.SupplierInvoice
      and Header.FiscalYear      = Item.FiscalYear

    inner join   I_PurchaseOrderItemAPI01      as PO
      on  Item.PurchaseOrder     = PO.PurchaseOrder
      and Item.PurchaseOrderItem = PO.PurchaseOrderItem

{
  key PO.Material,
  key PO.Plant,

      max(concat(Header.FiscalYear, Header.SupplierInvoice)) as LastInvoiceKey
}

where Header.ReverseDocument  = ''
  and PO.Material            is not initial

group by PO.Material,
         PO.Plant
