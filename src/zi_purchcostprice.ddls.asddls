@AccessControl.authorizationCheck: #CHECK

@Analytics.dataCategory: #FACT

@EndUserText.label: 'Purchase Cost Price - Basic Interface'

@Metadata.ignorePropagatedAnnotations: true

@ObjectModel.supportedCapabilities: [ #SQL_DATA_SOURCE, #CDS_MODELING_DATA_SOURCE, #CDS_MODELING_ASSOCIATION_TARGET ]
@ObjectModel.usageType: { dataClass: #MIXED, sizeCategory: #XL, serviceQuality: #D }

@VDM.viewType: #BASIC

define veiw entity ZI_PurchCostPrice
  as select from    I_PurchaseOrderItemAPI01 as POItem

    -- Join com header do pedido
    inner join      I_PurchaseOrderAPI01     as POHeader
      on POItem.PurchaseOrder = POHeader.PurchaseOrder

    -- Join com valorização do material (preço de custo padrão)
    left outer join I_ProductValuationBasic  as Valuation
      on  POItem.Material         = Valuation.Product
      and POItem.Plant            = Valuation.ValuationArea
      and Valuation.ValuationType = ''

    -- Join com Condição de Preço PMP0 do próprio Pedido
    left outer join ZI_PurOrdItemCondPMP0    as PMP0
      on  POItem.PurchaseOrder     = PMP0.PurchaseOrder
      and POItem.PurchaseOrderItem = PMP0.PurchaseOrderItem

  -- Associations para dimensões
  association [0..1] to I_Supplier               as _Supplier
    on $projection.Supplier = _Supplier.Supplier

  association [0..1] to I_Product                as _Product
    on $projection.Material = _Product.Product

  association [0..1] to I_ProductGroup_2         as _ProductGroup
    on $projection.MaterialGroup = _ProductGroup.ProductGroup

  association [0..1] to I_Plant                  as _Plant
    on $projection.Plant = _Plant.Plant

  association [0..1] to I_CompanyCode            as _CompanyCode
    on $projection.CompanyCode = _CompanyCode.CompanyCode

  association [0..1] to I_PurchasingOrganization as _PurchasingOrganization
    on $projection.PurchasingOrganization = _PurchasingOrganization.PurchasingOrganization

  association [0..1] to I_PurchasingGroup        as _PurchasingGroup
    on $projection.PurchasingGroup = _PurchasingGroup.PurchasingGroup

  association [0..1] to I_PurchaseOrderType      as _PurchaseOrderType
    on $projection.PurchaseOrderType = _PurchaseOrderType.PurchaseOrderType

  association [0..1] to I_Currency               as _DocumentCurrency
    on $projection.DocumentCurrency = _DocumentCurrency.Currency

  association [0..1] to I_Currency               as _CostCurrency
    on $projection.CostCurrency = _CostCurrency.Currency

  association [0..1] to I_UnitOfMeasure          as _OrderQuantityUnit
    on $projection.PurchaseOrderQuantityUnit = _OrderQuantityUnit.UnitOfMeasure

  association [0..1] to I_UnitOfMeasure          as _BaseUnit
    on $projection.BaseUnit = _BaseUnit.UnitOfMeasure

  association [0..1] to I_UnitOfMeasure          as _OrderPriceUnit
    on $projection.OrderPriceUnit = _OrderPriceUnit.UnitOfMeasure

  association [0..1] to I_CalendarDate           as _CalendarDate
    on $projection.PurchaseOrderDate = _CalendarDate.CalendarDate

  association [0..1] to I_StorageLocation        as _StorageLocation
    on  $projection.Plant           = _StorageLocation.Plant
    and $projection.StorageLocation = _StorageLocation.StorageLocation

{
      // ---------------------------------------------------------------------------
      // Keys
      // ---------------------------------------------------------------------------
  key POItem.PurchaseOrder,
  key POItem.PurchaseOrderItem,

      // ---------------------------------------------------------------------------
      // PO Header Dimensions
      // ---------------------------------------------------------------------------
      @ObjectModel.foreignKey.association: '_PurchaseOrderType'
      POHeader.PurchaseOrderType,

      @ObjectModel.foreignKey.association: '_Supplier'
      POHeader.Supplier,

      @ObjectModel.foreignKey.association: '_PurchasingOrganization'
      POHeader.PurchasingOrganization,

      @ObjectModel.foreignKey.association: '_PurchasingGroup'
      POHeader.PurchasingGroup,

      @Semantics.businessDate.at: true
      POHeader.PurchaseOrderDate,

      POHeader.CreationDate,

      POHeader.CreatedByUser,

      @ObjectModel.foreignKey.association: '_DocumentCurrency'
      POHeader.DocumentCurrency,

      POHeader.ExchangeRate,

      // ---------------------------------------------------------------------------
      // PO Item Dimensions
      // ---------------------------------------------------------------------------
      @ObjectModel.foreignKey.association: '_Product'
      POItem.Material,

      @Semantics.text: true
      POItem.PurchaseOrderItemText           as MaterialDescription,

      @ObjectModel.foreignKey.association: '_ProductGroup'
      POItem.MaterialGroup,

      @ObjectModel.foreignKey.association: '_CompanyCode'
      POItem.CompanyCode,

      @ObjectModel.foreignKey.association: '_Plant'
      POItem.Plant,

      @ObjectModel.foreignKey.association: '_StorageLocation'
      POItem.StorageLocation,

      POItem.PurchaseOrderItemCategory,

      POItem.AccountAssignmentCategory,

      POItem.IsCompletelyDelivered,

      POItem.IsFinallyInvoiced,

      POItem.IsReturnsItem,

      POItem.TaxCode,

      POItem.SupplierMaterialNumber,

      POItem.PurchaseContract,
      POItem.PurchaseContractItem,

      // ---------------------------------------------------------------------------
      // Quantities
      // ---------------------------------------------------------------------------
      @Semantics.quantity.unitOfMeasure: 'PurchaseOrderQuantityUnit'
      POItem.OrderQuantity,

      @ObjectModel.foreignKey.association: '_OrderQuantityUnit'
      POItem.PurchaseOrderQuantityUnit,

      @Semantics.quantity.unitOfMeasure: 'OrderPriceUnit'
      POItem.NetPriceQuantity,

      @ObjectModel.foreignKey.association: '_OrderPriceUnit'
      POItem.OrderPriceUnit,

      @ObjectModel.foreignKey.association: '_BaseUnit'
      POItem.BaseUnit,

      // ---------------------------------------------------------------------------
      // PO Price (Net / Purchase)
      // ---------------------------------------------------------------------------
      @Semantics.amount.currencyCode: 'DocumentCurrency'
      POItem.NetPriceAmount,

      @Semantics.amount.currencyCode: 'DocumentCurrency'
      POItem.NetAmount,

      @EndUserText.label: 'Preço Unitário Real'
      @Semantics.amount.currencyCode: 'DocumentCurrency'
      cast(
        division( POItem.NetAmount, POItem.OrderQuantity, 5 )
        as abap.curr(15,5)
      )                                          as UnitPrice,

      // ---------------------------------------------------------------------------
      // Material Valuation - Preço de Custo
      // ---------------------------------------------------------------------------
      @EndUserText.label: 'Preço Padrão (Standard Price)'
      @Semantics.amount.currencyCode: 'CostCurrency'
      Valuation.StandardPrice,

      @EndUserText.label: 'Preço Médio Móvel (MAP)'
      @Semantics.amount.currencyCode: 'CostCurrency'
      Valuation.MovingAveragePrice,

      @EndUserText.label: 'Controle de Preço (V=MAP / S=Standard)'
      Valuation.InventoryValuationProcedure  as PriceControl,

      @EndUserText.label: 'Unid. Preço Valorização'
      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      Valuation.PriceUnitQty,

      Valuation.ValuationClass,

      @EndUserText.label: 'Moeda do Custo'
      @ObjectModel.foreignKey.association: '_CostCurrency'
      Valuation.Currency                     as CostCurrency,

      @EndUserText.label: 'Preço Anterior'
      @Semantics.amount.currencyCode: 'CostCurrency'
      Valuation.PrevInvtryPriceInCoCodeCrcy,

      // ---------------------------------------------------------------------------
      // Campos Calculados - Preço de Custo Efetivo (Condição PMP0 do Pedido)
      // ---------------------------------------------------------------------------
      @EndUserText.label: 'Preço de Custo (PMP0)'
      @Semantics.amount.currencyCode: 'DocumentCurrency'
      coalesce(PMP0.ConditionUnitRate,
               case Valuation.InventoryValuationProcedure
                 when 'V' then Valuation.MovingAveragePrice
                 when 'S' then Valuation.StandardPrice
                 else coalesce(Valuation.MovingAveragePrice, Valuation.StandardPrice)
               end)                          as CostPrice,

      // ---------------------------------------------------------------------------
      // Variação de Preço (Net - Custo PMP0)
      // ---------------------------------------------------------------------------
      @EndUserText.label: 'Variação de Preço (Net - Custo PMP0)'
      @Semantics.amount.currencyCode: 'DocumentCurrency'
      cast(
        POItem.NetPriceAmount -
        coalesce(PMP0.ConditionUnitRate,
                 case Valuation.InventoryValuationProcedure
                   when 'V' then Valuation.MovingAveragePrice
                   when 'S' then Valuation.StandardPrice
                   else coalesce(Valuation.MovingAveragePrice, Valuation.StandardPrice)
                 end)
        as abap.curr(15,2)
      )                                      as PriceVarianceAmount,

      // ---------------------------------------------------------------------------
      // Calendar Dimensions (derivadas do PO Date)
      // ---------------------------------------------------------------------------
      _CalendarDate.CalendarYear,
      _CalendarDate.CalendarQuarter,
      _CalendarDate.CalendarMonth,
      _CalendarDate.CalendarWeek,

      // ---------------------------------------------------------------------------
      // Associations
      // ---------------------------------------------------------------------------
      _Supplier,
      _Product,
      _ProductGroup,
      _Plant,
      _CompanyCode,
      _PurchasingOrganization,
      _PurchasingGroup,
      _PurchaseOrderType,
      _DocumentCurrency,
      _CostCurrency,
      _OrderQuantityUnit,
      _BaseUnit,
      _OrderPriceUnit,
      _CalendarDate,
      _StorageLocation
}

where POItem.PurchasingDocumentDeletionCode   = ''       -- Exclui itens deletados
  and POHeader.PurchasingDocumentDeletionCode = ''     -- Exclui POs deletados
