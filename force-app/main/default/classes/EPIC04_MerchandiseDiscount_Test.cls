@isTest
private class EPIC04_MerchandiseDiscount_Test {
  @isTest
  static void tenPercentNeedsNoPin() {
    SaleFixture sale = new SaleFixture(100);
    EPIC04_MerchandiseSale_Controller.SaleResult result = sale.sell(
      10,
      null,
      null
    );

    System.assertEquals(90, result.totalAmount);
    Merchandise_Sale__c saved = sale.reload(result.saleId);
    System.assertEquals(10, saved.Discount_Percentage__c);
    System.assertEquals(UserInfo.getUserId(), saved.Discount_Approved_By__c);
    System.assertEquals('Staff discount', saved.Manager_Override_Reason__c);
    System.assertEquals(null, saved.Promo_Code__c);
    System.assertEquals(
      90,
      [
        SELECT Amount__c
        FROM Payment_Transaction__c
        WHERE Id = :result.paymentId
      ]
      .Amount__c
    );
  }

  @isTest
  static void aboveTenPercentRequiresAManagerPin() {
    SaleFixture sale = new SaleFixture(100);
    try {
      sale.sell(15, null, null);
      System.assert(false, 'expected pin error');
    } catch (AuraHandledException ex) {
      System.assertEquals(
        EPIC04_MerchandiseSale_Controller.MSG_PIN_REQUIRED,
        ex.getMessage()
      );
    }
    System.assertEquals(0, [SELECT COUNT() FROM Merchandise_Sale__c]);
    System.assertEquals(
      5,
      [SELECT Current_Stock__c FROM Inventory_Item__c WHERE Id = :sale.itemId]
      .Current_Stock__c
    );
  }

  @isTest
  static void managerPinApprovesFifteenPercent() {
    grantManagerPin('2468');
    SaleFixture sale = new SaleFixture(100);
    EPIC04_MerchandiseSale_Controller.SaleResult result = sale.sell(
      15,
      null,
      '2468'
    );

    System.assertEquals(85, result.totalAmount);
    Merchandise_Sale__c saved = sale.reload(result.saleId);
    System.assertEquals(15, saved.Discount_Percentage__c);
    System.assertEquals(UserInfo.getUserId(), saved.Discount_Approved_By__c);
    System.assertEquals('Manager PIN', saved.Manager_Override_Reason__c);
  }

  @isTest
  static void promoCodeAppliesWithoutAPinUntilItExpires() {
    Promo_Code__c code = new Promo_Code__c(
      Code__c = 'GLOVES20',
      Discount_Percentage__c = 20,
      Expiration_Date__c = Date.today(),
      Is_Active__c = true
    );
    insert code;
    SaleFixture sale = new SaleFixture(100);
    EPIC04_MerchandiseSale_Controller.SaleResult result = sale.sell(
      null,
      'gloves20',
      null
    );

    System.assertEquals(80, result.totalAmount);
    Merchandise_Sale__c saved = sale.reload(result.saleId);
    System.assertEquals(code.Id, saved.Promo_Code__c);
    System.assertEquals(20, saved.Discount_Percentage__c);
    System.assertEquals(null, saved.Discount_Approved_By__c);

    code.Expiration_Date__c = Date.today().addDays(-1);
    update code;
    try {
      sale.sell(null, 'GLOVES20', null);
      System.assert(false, 'expected expired promo');
    } catch (AuraHandledException ex) {
      System.assertEquals(
        EPIC04_MerchandiseSale_Controller.MSG_PROMO,
        ex.getMessage()
      );
    }
  }

  @isTest
  static void inactivePromoAndMixedDiscountAreRefused() {
    insert new Promo_Code__c(
      Code__c = 'OFF',
      Discount_Percentage__c = 10,
      Expiration_Date__c = Date.today().addDays(5),
      Is_Active__c = false
    );
    SaleFixture sale = new SaleFixture(40);
    try {
      sale.sell(null, 'OFF', null);
      System.assert(false, 'expected inactive promo');
    } catch (AuraHandledException ex) {
      System.assertEquals(
        EPIC04_MerchandiseSale_Controller.MSG_PROMO,
        ex.getMessage()
      );
    }
    try {
      sale.sell(10, 'OFF', null);
      System.assert(false, 'expected one discount');
    } catch (AuraHandledException ex) {
      System.assertEquals(
        EPIC04_MerchandiseSale_Controller.MSG_BOTH,
        ex.getMessage()
      );
    }
    System.assertEquals(0, [SELECT COUNT() FROM Merchandise_Sale__c]);
  }

  private static void grantManagerPin(String pin) {
    PermissionSet ps = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = 'Boxing_Gym_Manager'
      LIMIT 1
    ];
    System.runAs(new User(Id = UserInfo.getUserId())) {
      insert new PermissionSetAssignment(
        AssigneeId = UserInfo.getUserId(),
        PermissionSetId = ps.Id
      );
    }
    System.runAs(new User(Id = UserInfo.getUserId())) {
      EPIC04_ManagerPin_Service.setMyPin(pin);
    }
  }

  private class SaleFixture {
    Id memberId;
    Id locationId;
    Id itemId;

    SaleFixture(Decimal price) {
      Franchise_Location__c location = EPIC01_TestDataFactory.createLocation(
        'Lexington'
      );
      Member__c member = EPIC01_TestDataFactory.createMember(
        'Avery',
        'Johnson',
        location.Id
      );
      Product_Category__c category = new Product_Category__c(Name = 'Apparel');
      insert category;
      Inventory_Item__c item = new Inventory_Item__c(
        Name = 'Gloves',
        SKU__c = 'GLV',
        Unit_Price__c = price,
        Current_Stock__c = 5,
        Is_Active__c = true,
        Franchise_Location__c = location.Id,
        Product_Category__c = category.Id
      );
      insert item;
      memberId = member.Id;
      locationId = location.Id;
      itemId = item.Id;
    }

    EPIC04_MerchandiseSale_Controller.SaleResult sell(
      Decimal discountPercent,
      String promoCode,
      String managerPin
    ) {
      EPIC04_MerchandiseSale_Controller.LineInput line = new EPIC04_MerchandiseSale_Controller.LineInput();
      line.inventoryItemId = itemId;
      line.quantity = 1;
      return EPIC04_MerchandiseSale_Controller.completeSale(
        memberId,
        locationId,
        'Cash',
        new List<EPIC04_MerchandiseSale_Controller.LineInput>{ line },
        discountPercent,
        promoCode,
        managerPin
      );
    }

    Merchandise_Sale__c reload(Id saleId) {
      return [
        SELECT
          Discount_Percentage__c,
          Discount_Approved_By__c,
          Manager_Override_Reason__c,
          Promo_Code__c,
          Total_Amount__c
        FROM Merchandise_Sale__c
        WHERE Id = :saleId
      ];
    }
  }
}
