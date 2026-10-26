@isTest
private class EPIC04_MerchandiseSale_Test {
  @isTest
  static void sellsItemsAndDecrementsStock() {
    Franchise_Location__c location = EPIC01_TestDataFactory.createLocation(
      'Lexington'
    );
    Member__c member = EPIC01_TestDataFactory.createMember(
      'Avery',
      'Johnson',
      location.Id
    );
    member.Status__c = 'Prospect';
    update member;
    Product_Category__c category = category();
    Inventory_Item__c gloves = item(
      location.Id,
      category.Id,
      'Gloves',
      'GLV',
      40,
      5
    );
    Inventory_Item__c wraps = item(
      location.Id,
      category.Id,
      'Wraps',
      'WRP',
      12,
      8
    );

    Test.startTest();
    EPIC04_MerchandiseSale_Controller.SaleResult result = EPIC04_MerchandiseSale_Controller.completeSale(
      member.Id,
      location.Id,
      'Card',
      new List<EPIC04_MerchandiseSale_Controller.LineInput>{
        line(gloves.Id, 2),
        line(wraps.Id, 1),
        line(gloves.Id, 1)
      }
    );
    Test.stopTest();

    System.assertEquals(
      132,
      result.totalAmount,
      '2+1 gloves at 40 plus one wrap at 12'
    );
    Merchandise_Sale__c sale = [
      SELECT
        Payment_Method__c,
        Total_Amount__c,
        Member__c,
        Franchise_Location__c
      FROM Merchandise_Sale__c
      WHERE Id = :result.saleId
    ];
    System.assertEquals('Card', sale.Payment_Method__c);
    System.assertEquals(member.Id, sale.Member__c);
    System.assertEquals(location.Id, sale.Franchise_Location__c);
    System.assertEquals(132, sale.Total_Amount__c);

    Map<Id, Sale_Line_Item__c> linesByItem = new Map<Id, Sale_Line_Item__c>();
    for (Sale_Line_Item__c row : [
      SELECT
        Inventory_Item__c,
        Quantity__c,
        Unit_Price_At_Time_of_Sale__c,
        Line_Total__c
      FROM Sale_Line_Item__c
      WHERE Merchandise_Sale__c = :sale.Id
    ]) {
      linesByItem.put(row.Inventory_Item__c, row);
    }
    System.assertEquals(
      2,
      linesByItem.size(),
      'duplicate glove lines collapse to one'
    );
    System.assertEquals(3, linesByItem.get(gloves.Id).Quantity__c);
    System.assertEquals(
      40,
      linesByItem.get(gloves.Id).Unit_Price_At_Time_of_Sale__c
    );
    System.assertEquals(120, linesByItem.get(gloves.Id).Line_Total__c);
    System.assertEquals(1, linesByItem.get(wraps.Id).Quantity__c);

    System.assertEquals(
      2,
      [SELECT Current_Stock__c FROM Inventory_Item__c WHERE Id = :gloves.Id]
      .Current_Stock__c
    );
    System.assertEquals(
      7,
      [SELECT Current_Stock__c FROM Inventory_Item__c WHERE Id = :wraps.Id]
      .Current_Stock__c
    );

    Payment_Transaction__c payment = [
      SELECT
        Amount__c,
        Payment_Type__c,
        Transaction_Method__c,
        Status__c,
        Is_Recurring__c,
        Member__c
      FROM Payment_Transaction__c
      WHERE Id = :result.paymentId
    ];
    System.assertEquals(132, payment.Amount__c);
    System.assertEquals('Merchandise Purchase', payment.Payment_Type__c);
    System.assertEquals('Credit Card', payment.Transaction_Method__c);
    System.assertEquals('Completed', payment.Status__c);
    System.assertEquals(false, payment.Is_Recurring__c);
    System.assertEquals(member.Id, payment.Member__c);
    System.assertEquals(
      'Prospect',
      [SELECT Status__c FROM Member__c WHERE Id = :member.Id].Status__c,
      'merchandise payment must not activate the membership'
    );
  }

  @isTest
  static void accountCreditMapsOntoThePayment() {
    Franchise_Location__c location = EPIC01_TestDataFactory.createLocation(
      'Ashland'
    );
    Member__c member = EPIC01_TestDataFactory.createMember(
      'Sam',
      'Lee',
      location.Id
    );
    Inventory_Item__c item = item(
      location.Id,
      category().Id,
      'Shirt',
      'SHR',
      25,
      2
    );

    EPIC04_MerchandiseSale_Controller.SaleResult result = EPIC04_MerchandiseSale_Controller.completeSale(
      member.Id,
      location.Id,
      'Account Credit',
      new List<EPIC04_MerchandiseSale_Controller.LineInput>{ line(item.Id, 1) }
    );

    System.assertEquals(
      'Account Credit',
      [
        SELECT Transaction_Method__c
        FROM Payment_Transaction__c
        WHERE Id = :result.paymentId
      ]
      .Transaction_Method__c
    );
  }

  @isTest
  static void rejectsOversellWithoutWriting() {
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
      1
    );

    try {
      EPIC04_MerchandiseSale_Controller.completeSale(
        member.Id,
        location.Id,
        'Cash',
        new List<EPIC04_MerchandiseSale_Controller.LineInput>{
          line(gloves.Id, 2)
        }
      );
      System.assert(false, 'expected stock error');
    } catch (AuraHandledException ex) {
      System.assert(
        ex.getMessage().contains('Not enough stock for Gloves'),
        ex.getMessage()
      );
    }

    System.assertEquals(
      1,
      [SELECT Current_Stock__c FROM Inventory_Item__c WHERE Id = :gloves.Id]
      .Current_Stock__c
    );
    System.assertEquals(0, [SELECT COUNT() FROM Merchandise_Sale__c]);
    System.assertEquals(0, [SELECT COUNT() FROM Payment_Transaction__c]);
  }

  @isTest
  static void rejectsItemFromAnotherGym() {
    Franchise_Location__c here = EPIC01_TestDataFactory.createLocation('Here');
    Franchise_Location__c there = EPIC01_TestDataFactory.createLocation(
      'There'
    );
    Member__c member = EPIC01_TestDataFactory.createMember(
      'Pat',
      'Kim',
      here.Id
    );
    Inventory_Item__c item = item(there.Id, category().Id, 'Bag', 'BAG', 10, 4);

    try {
      EPIC04_MerchandiseSale_Controller.completeSale(
        member.Id,
        here.Id,
        'Cash',
        new List<EPIC04_MerchandiseSale_Controller.LineInput>{
          line(item.Id, 1)
        }
      );
      System.assert(false, 'expected location error');
    } catch (AuraHandledException ex) {
      System.assertEquals(
        EPIC04_MerchandiseSale_Controller.MSG_ITEM,
        ex.getMessage()
      );
    }
    System.assertEquals(
      4,
      [SELECT Current_Stock__c FROM Inventory_Item__c WHERE Id = :item.Id]
      .Current_Stock__c
    );
  }

  @isTest
  static void listsOnlyActiveInStockItemsAtTheGym() {
    Franchise_Location__c location = EPIC01_TestDataFactory.createLocation(
      'Lexington'
    );
    Franchise_Location__c other = EPIC01_TestDataFactory.createLocation(
      'Other'
    );
    other.Status__c = 'Inactive';
    update other;
    Product_Category__c category = category();
    item(location.Id, category.Id, 'Gloves', 'GLV', 40, 3);
    Inventory_Item__c soldOut = item(
      location.Id,
      category.Id,
      'Sold Out',
      'OUT',
      5,
      0
    );
    Inventory_Item__c inactive = item(
      location.Id,
      category.Id,
      'Old',
      'OLD',
      5,
      4
    );
    inactive.Is_Active__c = false;
    update inactive;
    item(other.Id, category.Id, 'Elsewhere', 'ELS', 5, 4);

    List<Inventory_Item__c> sellable = EPIC04_MerchandiseSale_Controller.getSellableInventory(
      location.Id
    );
    System.assertEquals(1, sellable.size());
    System.assertEquals('Gloves', sellable[0].Name);
    System.assertEquals(
      0,
      EPIC04_MerchandiseSale_Controller.getSellableInventory(null).size()
    );

    List<Franchise_Location__c> locations = EPIC04_MerchandiseSale_Controller.getActiveLocations();
    System.assertEquals(1, locations.size());
    System.assertEquals(location.Id, locations[0].Id);
    System.assertNotEquals(soldOut.Id, sellable[0].Id);
  }

  @isTest
  static void searchesMembersByName() {
    Franchise_Location__c location = EPIC01_TestDataFactory.createLocation(
      'Lexington'
    );
    Member__c member = EPIC01_TestDataFactory.createMember(
      'Avery',
      'Johnson',
      location.Id
    );

    List<Member__c> found = EPIC04_MerchandiseSale_Controller.searchMembers(
      'john'
    );
    System.assertEquals(1, found.size());
    System.assertEquals(member.Id, found[0].Id);
    System.assertEquals(
      0,
      EPIC04_MerchandiseSale_Controller.searchMembers('a').size()
    );
    System.assertEquals(
      0,
      EPIC04_MerchandiseSale_Controller.searchMembers(null).size()
    );
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
