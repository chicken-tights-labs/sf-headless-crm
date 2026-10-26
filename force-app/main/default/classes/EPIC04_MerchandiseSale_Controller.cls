/**
 * EPIC04-US-F006: front-desk merchandise cart.
 * Why Apex: the sale header, line items, stock decrement, and payment record
 * must commit or roll back together. This does not call processPayment —
 * that path activates a membership, resets dates, and sends welcome/referral mail.
 */
public with sharing class EPIC04_MerchandiseSale_Controller {
  public static final String MSG_MEMBER = 'Choose a member.';
  public static final String MSG_LOCATION = 'Choose a gym location.';
  public static final String MSG_METHOD = 'Choose a payment method.';
  public static final String MSG_CART = 'Add at least one item.';
  public static final String MSG_STOCK = 'Not enough stock for ';
  public static final String MSG_ITEM = 'That item is not for sale at this gym.';
  public static final String MSG_QTY = 'Quantity must be a whole number greater than zero.';
  public static final String PAYMENT_TYPE = 'Merchandise Purchase';

  private static final Map<String, String> METHOD_TO_TXN = new Map<String, String>{
    'Cash' => 'Cash',
    'Card' => 'Credit Card',
    'Gift Card' => 'Gift Card',
    'Account Credit' => 'Account Credit'
  };

  public class LineInput {
    @AuraEnabled
    public Id inventoryItemId { get; set; }
    @AuraEnabled
    public Decimal quantity { get; set; }
  }

  public class SaleResult {
    @AuraEnabled
    public Id saleId { get; set; }
    @AuraEnabled
    public Id paymentId { get; set; }
    @AuraEnabled
    public Decimal totalAmount { get; set; }
  }

  @AuraEnabled(cacheable=true)
  public static List<Franchise_Location__c> getActiveLocations() {
    return [
      SELECT Id, Name
      FROM Franchise_Location__c
      WHERE Status__c = 'Active'
      ORDER BY Name
    ];
  }

  @AuraEnabled
  public static List<Inventory_Item__c> getSellableInventory(
    Id franchiseLocationId
  ) {
    if (franchiseLocationId == null) {
      return new List<Inventory_Item__c>();
    }
    return [
      SELECT Id, Name, SKU__c, Unit_Price__c, Current_Stock__c
      FROM Inventory_Item__c
      WHERE
        Franchise_Location__c = :franchiseLocationId
        AND Is_Active__c = TRUE
        AND Current_Stock__c > 0
      ORDER BY Name
    ];
  }

  @AuraEnabled
  public static List<Member__c> searchMembers(String term) {
    if (String.isBlank(term)) {
      return new List<Member__c>();
    }
    String cleaned = term.trim().replace('%', '').replace('_', '');
    if (cleaned.length() < 2) {
      return new List<Member__c>();
    }
    String likeTerm = '%' + cleaned + '%';
    return [
      SELECT Id, Name, First_Name__c, Last_Name__c
      FROM Member__c
      WHERE
        Name LIKE :likeTerm
        OR First_Name__c LIKE :likeTerm
        OR Last_Name__c LIKE :likeTerm
      ORDER BY Last_Name__c, First_Name__c
      LIMIT 20
    ];
  }

  @AuraEnabled
  public static SaleResult completeSale(
    Id memberId,
    Id franchiseLocationId,
    String paymentMethod,
    List<LineInput> lines
  ) {
    if (memberId == null) {
      throw auraError(MSG_MEMBER);
    }
    if (franchiseLocationId == null) {
      throw auraError(MSG_LOCATION);
    }
    if (
      String.isBlank(paymentMethod) || !METHOD_TO_TXN.containsKey(paymentMethod)
    ) {
      throw auraError(MSG_METHOD);
    }
    Map<Id, Integer> qtyByItem = aggregateQuantities(lines);
    if (qtyByItem.isEmpty()) {
      throw auraError(MSG_CART);
    }

    List<Member__c> members = [
      SELECT Id
      FROM Member__c
      WHERE Id = :memberId
      LIMIT 1
    ];
    if (members.isEmpty()) {
      throw auraError(MSG_MEMBER);
    }
    List<Franchise_Location__c> locations = [
      SELECT Id
      FROM Franchise_Location__c
      WHERE Id = :franchiseLocationId AND Status__c = 'Active'
      LIMIT 1
    ];
    if (locations.isEmpty()) {
      throw auraError(MSG_LOCATION);
    }

    Map<Id, Inventory_Item__c> items = new Map<Id, Inventory_Item__c>(
      [
        SELECT
          Id,
          Name,
          Unit_Price__c,
          Current_Stock__c,
          Is_Active__c,
          Franchise_Location__c
        FROM Inventory_Item__c
        WHERE Id IN :qtyByItem.keySet()
        FOR UPDATE
      ]
    );

    Decimal total = 0;
    List<Sale_Line_Item__c> lineRecords = new List<Sale_Line_Item__c>();
    List<Inventory_Item__c> stockUpdates = new List<Inventory_Item__c>();
    for (Id itemId : qtyByItem.keySet()) {
      Inventory_Item__c item = items.get(itemId);
      Integer qty = qtyByItem.get(itemId);
      if (
        item == null ||
        item.Is_Active__c != true ||
        item.Franchise_Location__c != franchiseLocationId
      ) {
        throw auraError(MSG_ITEM);
      }
      if (item.Current_Stock__c == null || item.Current_Stock__c < qty) {
        throw auraError(MSG_STOCK + item.Name);
      }
      Decimal lineTotal = item.Unit_Price__c * qty;
      total += lineTotal;
      item.Current_Stock__c = item.Current_Stock__c - qty;
      stockUpdates.add(item);
      lineRecords.add(
        new Sale_Line_Item__c(
          Inventory_Item__c = item.Id,
          Quantity__c = qty,
          Unit_Price_At_Time_of_Sale__c = item.Unit_Price__c,
          Line_Total__c = lineTotal
        )
      );
    }

    Merchandise_Sale__c sale = new Merchandise_Sale__c(
      Name = 'MS-' + String.valueOf(Datetime.now().getTime()),
      Member__c = memberId,
      Franchise_Location__c = franchiseLocationId,
      Payment_Method__c = paymentMethod,
      Sale_Date__c = Datetime.now(),
      Total_Amount__c = total
    );
    Payment_Transaction__c payment = new Payment_Transaction__c(
      Member__c = memberId,
      Franchise_Location__c = franchiseLocationId,
      Amount__c = total,
      Payment_Type__c = PAYMENT_TYPE,
      Transaction_Method__c = METHOD_TO_TXN.get(paymentMethod),
      Status__c = 'Completed',
      Transaction_Date__c = Datetime.now(),
      Is_Recurring__c = false
    );

    Savepoint sp = Database.setSavepoint();
    try {
      insert sale;
      for (Sale_Line_Item__c line : lineRecords) {
        line.Merchandise_Sale__c = sale.Id;
      }
      insert lineRecords;
      update stockUpdates;
      insert payment;
    } catch (Exception ex) {
      Database.rollback(sp);
      throw auraError(ex.getMessage());
    }

    SaleResult result = new SaleResult();
    result.saleId = sale.Id;
    result.paymentId = payment.Id;
    result.totalAmount = total;
    return result;
  }

  private static Map<Id, Integer> aggregateQuantities(List<LineInput> lines) {
    Map<Id, Integer> qtyByItem = new Map<Id, Integer>();
    if (lines == null) {
      return qtyByItem;
    }
    for (LineInput line : lines) {
      if (line == null || line.inventoryItemId == null) {
        throw auraError(MSG_ITEM);
      }
      if (
        line.quantity == null ||
        line.quantity != line.quantity.intValue() ||
        line.quantity <= 0
      ) {
        throw auraError(MSG_QTY);
      }
      Integer qty = line.quantity.intValue();
      Integer existing = qtyByItem.containsKey(line.inventoryItemId)
        ? qtyByItem.get(line.inventoryItemId)
        : 0;
      qtyByItem.put(line.inventoryItemId, existing + qty);
    }
    return qtyByItem;
  }

  private static AuraHandledException auraError(String message) {
    AuraHandledException ex = new AuraHandledException(message);
    ex.setMessage(message);
    return ex;
  }
}
