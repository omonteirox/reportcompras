@AccessControl.authorizationCheck: #NOT_REQUIRED

@EndUserText.label: 'Purchase Cost Price - Consumption'

@Metadata.allowExtensions: true
@Metadata.ignorePropagatedAnnotations: true

@ObjectModel.supportedCapabilities: [ #SQL_DATA_SOURCE, #CDS_MODELING_DATA_SOURCE, #CDS_MODELING_ASSOCIATION_TARGET ]
@ObjectModel.usageType: { dataClass: #MIXED, sizeCategory: #XL, serviceQuality: #D }

@VDM.viewType: #CONSUMPTION

define view entity ZC_PurchCostPriceCube
  as select from ZI_PurchCostPrice

{
      // =========================================================================
      // KEYS
      // =========================================================================
  key PurchaseOrder,
  key PurchaseOrderItem,

      // =========================================================================
      // DIMENSIONS - Organizacional
      // =========================================================================
      PurchaseOrderType,

      @ObjectModel.foreignKey.association: '_Supplier'
      @ObjectModel.text.element: [ 'SupplierName' ]
      Supplier,

      @EndUserText.label: 'Nome do Fornecedor'
      @Semantics.text: true
      _Supplier.SupplierName                             as SupplierName,

      @ObjectModel.foreignKey.association: '_PurchasingOrganization'
      @ObjectModel.text.element: [ 'PurchasingOrganizationName' ]
      PurchasingOrganization,

      @Semantics.text: true
      _PurchasingOrganization.PurchasingOrganizationName as PurchasingOrganizationName,

      @ObjectModel.foreignKey.association: '_PurchasingGroup'
      @ObjectModel.text.element: [ 'PurchasingGroupName' ]
      PurchasingGroup,

      @Semantics.text: true
      _PurchasingGroup.PurchasingGroupName               as PurchasingGroupName,

      @ObjectModel.foreignKey.association: '_CompanyCode'
      CompanyCode,

      // =========================================================================
      // DIMENSIONS - Material / Plant
      // =========================================================================
      @ObjectModel.foreignKey.association: '_Product'
      @ObjectModel.text.element: [ 'MaterialDescription' ]
      Material,

      @Semantics.text: true
      MaterialDescription,

      @ObjectModel.foreignKey.association: '_ProductGroup'
      MaterialGroup,

      @ObjectModel.foreignKey.association: '_Plant'
      Plant,

      StorageLocation,

      PurchaseOrderItemCategory,
      AccountAssignmentCategory,

      // =========================================================================
      // DIMENSIONS - Classificação
      // =========================================================================
      @EndUserText.label: 'Controle de Preço'
      PriceControl,

      @EndUserText.label: 'Classe de Avaliação'
      ValuationClass,

      IsCompletelyDelivered,
      IsFinallyInvoiced,
      IsReturnsItem,

      PurchaseContract,
      PurchaseContractItem,
      SupplierMaterialNumber,

      CreatedByUser,

      // =========================================================================
      // DIMENSIONS - Temporal
      // =========================================================================
      PurchaseOrderDate,

      CalendarYear,
      CalendarQuarter,
      CalendarMonth,
      CalendarWeek,

      CreationDate,

      // =========================================================================
      // CURRENCY / UOM
      // =========================================================================
      @ObjectModel.foreignKey.association: '_DocumentCurrency'
      DocumentCurrency,

      @ObjectModel.foreignKey.association: '_CostCurrency'
      CostCurrency,

      @ObjectModel.foreignKey.association: '_OrderQuantityUnit'
      PurchaseOrderQuantityUnit,

      @ObjectModel.foreignKey.association: '_BaseUnit'
      BaseUnit,

      @ObjectModel.foreignKey.association: '_OrderPriceUnit'
      OrderPriceUnit,

      // =========================================================================
      // MEASURES - Quantidades
      // =========================================================================
      @EndUserText.label: 'Quantidade Pedida'
      @Semantics.quantity.unitOfMeasure: 'PurchaseOrderQuantityUnit'
      OrderQuantity,

      @EndUserText.label: 'Qtd na Unid. de Preço'
      @Semantics.quantity.unitOfMeasure: 'OrderPriceUnit'
      NetPriceQuantity,

      // =========================================================================
      // MEASURES - Preço de Compra (Preço Líquido)
      // =========================================================================
      @EndUserText.label: 'Preço Líq. (Unid. Preço)'
      @Semantics.amount.currencyCode: 'DocumentCurrency'
      NetPriceAmount,

      @EndUserText.label: 'Valor Líquido Total'
      @Semantics.amount.currencyCode: 'DocumentCurrency'
      NetAmount,

      @EndUserText.label: 'Preço Unitário Real'
      @Semantics.amount.currencyCode: 'DocumentCurrency'
      UnitPrice,

      // =========================================================================
      // MEASURES - Preço de Custo
      // =========================================================================
      @EndUserText.label: 'Preço Padrão (Standard)'
      @Semantics.amount.currencyCode: 'CostCurrency'
      StandardPrice,

      @EndUserText.label: 'Preço Médio Móvel (MAP)'
      @Semantics.amount.currencyCode: 'CostCurrency'
      MovingAveragePrice,

      @EndUserText.label: 'Preço de Custo (PMP0)'
      @Semantics.amount.currencyCode: 'DocumentCurrency'
      CostPrice,

      @EndUserText.label: 'Unid. Preço Valorização'
      @Semantics.quantity.unitOfMeasure: 'BaseUnit'
      PriceUnitQty,

      @EndUserText.label: 'Preço Anterior'
      @Semantics.amount.currencyCode: 'CostCurrency'
      PrevInvtryPriceInCoCodeCrcy,

      // =========================================================================
      // MEASURES - Variação de Preço
      // =========================================================================
      @EndUserText.label: 'Variação de Preço'
      @Semantics.amount.currencyCode: 'DocumentCurrency'
      PriceVarianceAmount,

      // =========================================================================
      // MEASURES - Contadores
      // =========================================================================
      @EndUserText.label: 'Nº de Pedidos'
      cast(1 as abap.int4)                               as NumberOfPurchaseOrders,

      @EndUserText.label: 'Nº de Itens'
      cast(1 as abap.int4)                               as NumberOfItems,

      // =========================================================================
      // ASSOCIATIONS (re-exposed from Basic View)
      // =========================================================================
      _Supplier,
      _Product,
      _ProductGroup,
      _Plant,
      _CompanyCode,
      _PurchasingOrganization,
      _PurchasingGroup,
      _PurchaseOrderType,
      _CalendarDate,
      _DocumentCurrency,
      _CostCurrency,
      _OrderQuantityUnit,
      _BaseUnit,
      _OrderPriceUnit
}
