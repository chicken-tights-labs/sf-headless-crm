/**
 * EPIC04-US-F008: full refund of one merchandise sale.
 * Why Apex: the sale status, stock return, and refund payment must commit
 * or roll back together. This does not call processPayment.
 */
public with sharing class EPIC04_MerchandiseRefund_Action {
  public static final String MSG_SALE = 'That merchandise sale was not found.';
  public static final String MSG_REASON = 'Enter a reason.';
  public static final String MSG_ALREADY = 'This sale is already refunded.';
  public static final String MSG_STATUS = 'Only a completed sale can be refunded.';
  public static final String MSG_AMOUNT = 'This sale has no total to refund.';
  public static final String MSG_METHOD = 'This sale has no payment method to refund.';
  public static final String MSG_ITEM = 'An item on this sale could not be restocked.';
  public static final String MSG_REASON_LENGTH = 'Reason must be 1000 characters or fewer.';
  public static final String PAYMENT_TYPE = 'Refund';
  public static final String STATUS_COMPLETED = 'Completed';
  public static final String STATUS_REFUNDED = 'Refunded';

  private static final Map<String, String> METHOD_TO_TXN = new Map<String, String>{
    'Cash' => 'Cash',
    'Card' => 'Credit Card',
    'Gift Card' => 'Gift Card',
    'Account Credit' => 'Account Credit'
  };

  public class Request {
    @InvocableVariable(required=true)
    public Id saleId;
    @InvocableVariable(required=true)
    public String reason;
  }

  public class Result {
    @InvocableVariable
    public Boolean success;
    @InvocableVariable
    public String message;
  }

  public class Outcome {
    public Id paymentId;
    public Decimal amount;
  }

  public class MerchandiseRefundException extends Exception {
  }

  @InvocableMethod(
    label='Refund Merchandise Sale'
    description='EPIC04-US-F008 full merchandise refund'
  )
  public static List<Result> refund(List<Request> requests) {
    List<Result> results = new List<Result>();
    for (Request req : requests) {
      Result result = new Result();
      try {
        refundSale(req.saleId, req.reason);
        result.success = true;
        result.message = 'Refund recorded.';
      } catch (Exception ex) {
        result.success = false;
        result.message = ex.getMessage();
      }
      results.add(result);
    }
    return results;
  }

  public static Outcome refundSale(Id saleId, String reason) {
    if (saleId == null) {
      throw new MerchandiseRefundException(MSG_SALE);
    }
    if (String.isBlank(reason)) {
      throw new MerchandiseRefundException(MSG_REASON);
    }
    String cleaned = reason.trim();
    if (cleaned.length() > 1000) {
      throw new MerchandiseRefundException(MSG_REASON_LENGTH);
    }

    List<Merchandise_Sale__c> sales = [
      SELECT
        Id,
        Member__c,
        Franchise_Location__c,
        Payment_Method__c,
        Total_Amount__c,
        Status__c
      FROM Merchandise_Sale__c
      WHERE Id = :saleId
      FOR UPDATE
    ];
    if (sales.isEmpty()) {
      throw new MerchandiseRefundException(MSG_SALE);
    }
    Merchandise_Sale__c sale = sales[0];
    if (sale.Status__c == STATUS_REFUNDED) {
      throw new MerchandiseRefundException(MSG_ALREADY);
    }
    if (sale.Status__c != null && sale.Status__c != STATUS_COMPLETED) {
      throw new MerchandiseRefundException(MSG_STATUS);
    }
    if (sale.Total_Amount__c == null) {
      throw new MerchandiseRefundException(MSG_AMOUNT);
    }
    if (
      String.isBlank(sale.Payment_Method__c) ||
      !METHOD_TO_TXN.containsKey(sale.Payment_Method__c)
    ) {
      throw new MerchandiseRefundException(MSG_METHOD);
    }

    List<Sale_Line_Item__c> lines = [
      SELECT Inventory_Item__c, Quantity__c
      FROM Sale_Line_Item__c
      WHERE Merchandise_Sale__c = :sale.Id
    ];
    Map<Id, Decimal> qtyByItem = new Map<Id, Decimal>();
    for (Sale_Line_Item__c line : lines) {
      if (line.Inventory_Item__c == null) {
        throw new MerchandiseRefundException(MSG_ITEM);
      }
      Decimal qty = line.Quantity__c == null ? 0 : line.Quantity__c;
      Decimal existing = qtyByItem.containsKey(line.Inventory_Item__c)
        ? qtyByItem.get(line.Inventory_Item__c)
        : 0;
      qtyByItem.put(line.Inventory_Item__c, existing + qty);
    }

    List<Inventory_Item__c> stockUpdates = new List<Inventory_Item__c>();
    if (!qtyByItem.isEmpty()) {
      Map<Id, Inventory_Item__c> items = new Map<Id, Inventory_Item__c>(
        [
          SELECT Id, Current_Stock__c
          FROM Inventory_Item__c
          WHERE Id IN :qtyByItem.keySet()
          FOR UPDATE
        ]
      );
      if (items.size() != qtyByItem.size()) {
        throw new MerchandiseRefundException(MSG_ITEM);
      }
      for (Id itemId : qtyByItem.keySet()) {
        Inventory_Item__c item = items.get(itemId);
        Decimal onHand = item.Current_Stock__c == null
          ? 0
          : item.Current_Stock__c;
        item.Current_Stock__c = onHand + qtyByItem.get(itemId);
        stockUpdates.add(item);
      }
    }

    sale.Status__c = STATUS_REFUNDED;
    sale.Refund_Reason__c = cleaned;
    Payment_Transaction__c payment = new Payment_Transaction__c(
      Member__c = sale.Member__c,
      Franchise_Location__c = sale.Franchise_Location__c,
      Merchandise_Sale__c = sale.Id,
      Amount__c = sale.Total_Amount__c,
      Payment_Type__c = PAYMENT_TYPE,
      Transaction_Method__c = METHOD_TO_TXN.get(sale.Payment_Method__c),
      Status__c = STATUS_COMPLETED,
      Transaction_Date__c = Datetime.now(),
      Is_Recurring__c = false
    );

    Savepoint sp = Database.setSavepoint();
    try {
      if (!stockUpdates.isEmpty()) {
        update stockUpdates;
      }
      update sale;
      insert payment;
    } catch (Exception ex) {
      Database.rollback(sp);
      throw new MerchandiseRefundException(ex.getMessage());
    }

    Outcome outcome = new Outcome();
    outcome.paymentId = payment.Id;
    outcome.amount = payment.Amount__c;
    return outcome;
  }
}
