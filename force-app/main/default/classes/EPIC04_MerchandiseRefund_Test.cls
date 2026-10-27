@isTest
private class EPIC04_MerchandiseRefund_Test {
  @isTest
  static void refundsDiscountedSaleAndRestocks() {
    Franchise_Location__c location = EPIC01_TestDataFactory.createLocation(
      'Lexington'
    );
    Member__c member = EPIC01_TestDataFactory.createMember(
      'Avery',
      'Johnson',
      location.Id
    );
    Product_Category__c category = category();
    Inventory_Item__c gloves = item(
      location.Id,
      category.Id,
      'Gloves',
      'GLV',
      40,
      4
    );
    Inventory_Item__c wraps = item(
      location.Id,
      category.Id,
      'Wraps',
      'WRP',
      10,
      2
    );

    EPIC04_MerchandiseSale_Controller.SaleResult sold = EPIC04_MerchandiseSale_Controller.completeSale(
      member.Id,
      location.Id,
      'Card',
      new List<EPIC04_MerchandiseSale_Controller.LineInput>{
        line(gloves.Id, 1),
        line(wraps.Id, 1)
      },
      10,
      null,
      null
    );
    update new Merchandise_Sale__c(Id = sold.saleId, Status__c = 'Completed');

    Test.startTest();
    EPIC04_MerchandiseRefund_Action.Outcome outcome = EPIC04_MerchandiseRefund_Action.refundSale(
      sold.saleId,
      '  Damaged zipper  '
    );
    Test.stopTest();

    System.assertEquals(45, outcome.amount);
    Merchandise_Sale__c sale = [
      SELECT Status__c, Refund_Reason__c, Total_Amount__c
      FROM Merchandise_Sale__c
      WHERE Id = :sold.saleId
    ];
    System.assertEquals('Refunded', sale.Status__c);
    System.assertEquals('Damaged zipper', sale.Refund_Reason__c);
    System.assertEquals(45, sale.Total_Amount__c);

    System.assertEquals(
      4,
      [SELECT Current_Stock__c FROM Inventory_Item__c WHERE Id = :gloves.Id]
      .Current_Stock__c
    );
    System.assertEquals(
      2,
      [SELECT Current_Stock__c FROM Inventory_Item__c WHERE Id = :wraps.Id]
      .Current_Stock__c
    );

    Payment_Transaction__c refund = [
      SELECT
        Amount__c,
        Payment_Type__c,
        Transaction_Method__c,
        Status__c,
        Is_Recurring__c,
        Member__c,
        Franchise_Location__c,
        Merchandise_Sale__c
      FROM Payment_Transaction__c
      WHERE Id = :outcome.paymentId
    ];
    System.assertEquals(45, refund.Amount__c);
    System.assertEquals('Refund', refund.Payment_Type__c);
    System.assertEquals('Credit Card', refund.Transaction_Method__c);
    System.assertEquals('Completed', refund.Status__c);
    System.assertEquals(false, refund.Is_Recurring__c);
    System.assertEquals(member.Id, refund.Member__c);
    System.assertEquals(location.Id, refund.Franchise_Location__c);
    System.assertEquals(sold.saleId, refund.Merchandise_Sale__c);

    Payment_Transaction__c purchase = [
      SELECT Payment_Type__c, Status__c, Merchandise_Sale__c, Amount__c
      FROM Payment_Transaction__c
      WHERE Id = :sold.paymentId
    ];
    System.assertEquals('Merchandise Purchase', purchase.Payment_Type__c);
    System.assertEquals('Completed', purchase.Status__c);
    System.assertEquals(null, purchase.Merchandise_Sale__c);
    System.assertEquals(45, purchase.Amount__c);
    System.assertEquals(
      'Active',
      [SELECT Status__c FROM Member__c WHERE Id = :member.Id].Status__c
    );
  }

  @isTest
  static void refundsASaleWhoseStatusWasNeverSet() {
    Franchise_Location__c location = EPIC01_TestDataFactory.createLocation(
      'Ashland'
    );
    Member__c member = EPIC01_TestDataFactory.createMember(
      'Sam',
      'Lee',
      location.Id
    );
    Inventory_Item__c shirt = item(
      location.Id,
      category().Id,
      'Shirt',
      'SHR',
      20,
      3
    );
    EPIC04_MerchandiseSale_Controller.SaleResult sold = EPIC04_MerchandiseSale_Controller.completeSale(
      member.Id,
      location.Id,
      'Cash',
      new List<EPIC04_MerchandiseSale_Controller.LineInput>{ line(shirt.Id, 1) }
    );
    update new Merchandise_Sale__c(Id = sold.saleId, Status__c = null);

    EPIC04_MerchandiseRefund_Action.Outcome outcome = EPIC04_MerchandiseRefund_Action.refundSale(
      sold.saleId,
      'Wrong size'
    );

    System.assertEquals(20, outcome.amount);
    System.assertEquals(
      'Cash',
      [
        SELECT Transaction_Method__c
        FROM Payment_Transaction__c
        WHERE Id = :outcome.paymentId
      ]
      .Transaction_Method__c
    );
    System.assertEquals(
      3,
      [SELECT Current_Stock__c FROM Inventory_Item__c WHERE Id = :shirt.Id]
      .Current_Stock__c
    );
    System.assertEquals(
      'Refunded',
      [SELECT Status__c FROM Merchandise_Sale__c WHERE Id = :sold.saleId]
      .Status__c
    );
  }

  @isTest
  static void refusesASecondRefund() {
    Id saleId = refundedSale();
    Decimal stock = [
      SELECT Current_Stock__c
      FROM Inventory_Item__c
      LIMIT 1
    ]
    .Current_Stock__c;

    try {
      EPIC04_MerchandiseRefund_Action.refundSale(saleId, 'Again');
      System.assert(false, 'expected already refunded');
    } catch (EPIC04_MerchandiseRefund_Action.MerchandiseRefundException ex) {
      System.assertEquals(
        EPIC04_MerchandiseRefund_Action.MSG_ALREADY,
        ex.getMessage()
      );
    }

    System.assertEquals(
      stock,
      [SELECT Current_Stock__c FROM Inventory_Item__c LIMIT 1].Current_Stock__c
    );
    System.assertEquals(
      1,
      [
        SELECT COUNT()
        FROM Payment_Transaction__c
        WHERE Payment_Type__c = 'Refund'
      ]
    );
  }

  @isTest
  static void refusesABlankReason() {
    Id saleId = soldSale();
    try {
      EPIC04_MerchandiseRefund_Action.refundSale(saleId, '   ');
      System.assert(false, 'expected reason error');
    } catch (EPIC04_MerchandiseRefund_Action.MerchandiseRefundException ex) {
      System.assertEquals(
        EPIC04_MerchandiseRefund_Action.MSG_REASON,
        ex.getMessage()
      );
    }
    System.assertEquals(
      0,
      [
        SELECT COUNT()
        FROM Payment_Transaction__c
        WHERE Payment_Type__c = 'Refund'
      ]
    );
    System.assertNotEquals(
      'Refunded',
      [SELECT Status__c FROM Merchandise_Sale__c WHERE Id = :saleId].Status__c
    );
  }

  @isTest
  static void refusesAMissingSale() {
    try {
      EPIC04_MerchandiseRefund_Action.refundSale(null, 'Lost');
      System.assert(false, 'expected missing sale');
    } catch (EPIC04_MerchandiseRefund_Action.MerchandiseRefundException ex) {
      System.assertEquals(
        EPIC04_MerchandiseRefund_Action.MSG_SALE,
        ex.getMessage()
      );
    }
  }

  @isTest
  static void refusesASaleWithNoTotal() {
    Franchise_Location__c location = EPIC01_TestDataFactory.createLocation(
      'Pikeville'
    );
    Member__c member = EPIC01_TestDataFactory.createMember(
      'Jo',
      'Ng',
      location.Id
    );
    Inventory_Item__c gloves = item(
      location.Id,
      category().Id,
      'Gloves',
      'GLV',
      40,
      3
    );
    Merchandise_Sale__c sale = new Merchandise_Sale__c(
      Name = 'MS-no-total',
      Member__c = member.Id,
      Franchise_Location__c = location.Id,
      Payment_Method__c = 'Cash',
      Sale_Date__c = Datetime.now(),
      Status__c = 'Completed'
    );
    insert sale;
    insert new Sale_Line_Item__c(
      Name = 'Line',
      Merchandise_Sale__c = sale.Id,
      Inventory_Item__c = gloves.Id,
      Quantity__c = 1,
      Unit_Price_At_Time_of_Sale__c = 40,
      Line_Total__c = 40
    );

    try {
      EPIC04_MerchandiseRefund_Action.refundSale(sale.Id, 'No total');
      System.assert(false, 'expected amount error');
    } catch (EPIC04_MerchandiseRefund_Action.MerchandiseRefundException ex) {
      System.assertEquals(
        EPIC04_MerchandiseRefund_Action.MSG_AMOUNT,
        ex.getMessage()
      );
    }

    System.assertEquals(
      3,
      [SELECT Current_Stock__c FROM Inventory_Item__c WHERE Id = :gloves.Id]
      .Current_Stock__c
    );
    System.assertEquals(
      'Completed',
      [SELECT Status__c FROM Merchandise_Sale__c WHERE Id = :sale.Id].Status__c
    );
  }

  @isTest
  static void invocableReportsTheFailure() {
    EPIC04_MerchandiseRefund_Action.Request req = new EPIC04_MerchandiseRefund_Action.Request();
    req.saleId = soldSale();
    req.reason = '';
    EPIC04_MerchandiseRefund_Action.Result result = EPIC04_MerchandiseRefund_Action.refund(
      new List<EPIC04_MerchandiseRefund_Action.Request>{ req }
    )[0];
    System.assertEquals(false, result.success);
    System.assertEquals(
      EPIC04_MerchandiseRefund_Action.MSG_REASON,
      result.message
    );
  }

  private static Id soldSale() {
    Franchise_Location__c location = EPIC01_TestDataFactory.createLocation(
      'Richmond'
    );
    Member__c member = EPIC01_TestDataFactory.createMember(
      'Pat',
      'Kim',
      location.Id
    );
    Inventory_Item__c hat = item(
      location.Id,
      category().Id,
      'Hat',
      'HAT',
      15,
      6
    );
    return EPIC04_MerchandiseSale_Controller.completeSale(
        member.Id,
        location.Id,
        'Gift Card',
        new List<EPIC04_MerchandiseSale_Controller.LineInput>{ line(hat.Id, 1) }
      )
      .saleId;
  }

  private static Id refundedSale() {
    Id saleId = soldSale();
    EPIC04_MerchandiseRefund_Action.refundSale(saleId, 'Changed mind');
    return saleId;
  }

  private static Product_Category__c category() {
    Product_Category__c category = new Product_Category__c(Name = 'Apparel');
    insert category;
    return category;
  }

  private static Inventory_Item__c item(
    Id locationId,
    Id categoryId,
    String name,
    String sku,
    Decimal price,
    Integer stock
  ) {
    Inventory_Item__c row = new Inventory_Item__c(
      Name = name,
      SKU__c = sku,
      Unit_Price__c = price,
      Current_Stock__c = stock,
      Is_Active__c = true,
      Franchise_Location__c = locationId,
      Product_Category__c = categoryId
    );
    insert row;
    return row;
  }

  private static EPIC04_MerchandiseSale_Controller.LineInput line(
    Id itemId,
    Integer quantity
  ) {
    EPIC04_MerchandiseSale_Controller.LineInput input = new EPIC04_MerchandiseSale_Controller.LineInput();
    input.inventoryItemId = itemId;
    input.quantity = quantity;
    return input;
  }
}
