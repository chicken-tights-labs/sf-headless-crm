/**
 * EPIC04-US-F002: convert-and-pay compose path.
 * Why Apex test: the screen flow cannot be unit-tested; this asserts the same
 * invocable sequence the flow runs (convert → tier → pay → Active).
 */
@isTest
private class EPIC04_ConvertAndPay_Test {
  @testSetup
  static void setupData() {
    Franchise_Location__c loc = EPIC01_TestDataFactory.createLocation(
      'Lexington HQ'
    );
    EPIC01_TestDataFactory.createWaiverTemplate();
    EPIC01_TestDataFactory.createSession(loc.Id);
  }

  private static Id locId() {
    return [SELECT Id FROM Franchise_Location__c WHERE Name = 'Lexington HQ']
    .Id;
  }

  private static Id tmplId() {
    return [SELECT Id FROM Waiver_Template__c LIMIT 1].Id;
  }

  private static Lead__c walkInLead(String first, String last, String email) {
    Lead__c lead = new Lead__c(
      Name = first + '_' + last,
      First_Name__c = first,
      Last_Name__c = last,
      Email__c = email,
      Phone__c = '336-555-0199',
      Lead_Status__c = 'Walk-In',
      Lead_Source__c = 'In Person',
      Franchise_Location__c = locId()
    );
    insert lead;
    return lead;
  }

  @isTest
  static void walkInConvertThenCashPaymentActivatesMember() {
    Lead__c lead = walkInLead('John', 'Walker', 'john.walker@email.com');
    EPIC01_TestDataFactory.createValidWaiverForLead(lead.Id, locId(), tmplId());

    Test.startTest();
    EPIC01_LeadConversion_Action.Request convertReq = new EPIC01_LeadConversion_Action.Request();
    convertReq.leadId = lead.Id;
    EPIC01_LeadConversion_Action.Result convertResult = EPIC01_LeadConversion_Action.convert(
      new List<EPIC01_LeadConversion_Action.Request>{ convertReq }
    )[0];
    System.assertEquals(true, convertResult.success, convertResult.message);
    System.assertNotEquals(null, convertResult.memberId);

    Member__c afterConvert = [
      SELECT Status__c, Membership_Tier__c
      FROM Member__c
      WHERE Id = :convertResult.memberId
    ];
    System.assertEquals('Prospect', afterConvert.Status__c);

    afterConvert.Membership_Tier__c = EPIC01_MemberOnboarding_Service.TIER_MONTHLY;
    update afterConvert;

    EPIC01_ProcessPayment_Action.Request payReq = new EPIC01_ProcessPayment_Action.Request();
    payReq.memberId = convertResult.memberId;
    payReq.amount = '129.00';
    payReq.paymentMethod = 'Cash';
    EPIC01_ProcessPayment_Action.Result payResult = EPIC01_ProcessPayment_Action.pay(
      new List<EPIC01_ProcessPayment_Action.Request>{ payReq }
    )[0];
    Test.stopTest();

    System.assertEquals(true, payResult.success, payResult.message);

    Member__c active = [
      SELECT Status__c, Membership_Tier__c
      FROM Member__c
      WHERE Id = :convertResult.memberId
    ];
    System.assertEquals('Active', active.Status__c);
    System.assertEquals(
      EPIC01_MemberOnboarding_Service.TIER_MONTHLY,
      active.Membership_Tier__c
    );

    Lead__c converted = [
      SELECT Lead_Status__c, Converted_Member__c
      FROM Lead__c
      WHERE Id = :lead.Id
    ];
    System.assertEquals('Converted', converted.Lead_Status__c);
    System.assertEquals(convertResult.memberId, converted.Converted_Member__c);

    System.assertEquals(
      1,
      [
        SELECT COUNT()
        FROM Payment_Transaction__c
        WHERE Member__c = :convertResult.memberId AND Status__c = 'Completed'
      ]
    );
  }

  @isTest
  static void convertWithoutWaiverStaysProspectUntilGatePasses() {
    Lead__c lead = walkInLead('No', 'Waiver', 'no.waiver@email.com');

    EPIC01_LeadConversion_Action.Request convertReq = new EPIC01_LeadConversion_Action.Request();
    convertReq.leadId = lead.Id;
    EPIC01_LeadConversion_Action.Result convertResult = EPIC01_LeadConversion_Action.convert(
      new List<EPIC01_LeadConversion_Action.Request>{ convertReq }
    )[0];
    System.assertEquals(true, convertResult.success, convertResult.message);

    EPIC01_PaymentGate_Action.Request gateReq = new EPIC01_PaymentGate_Action.Request();
    gateReq.memberId = convertResult.memberId;
    EPIC01_PaymentGate_Action.Result gate = EPIC01_PaymentGate_Action.check(
      new List<EPIC01_PaymentGate_Action.Request>{ gateReq }
    )[0];

    System.assertEquals(false, gate.canProceed);
    System.assertEquals(
      'Prospect',
      [SELECT Status__c FROM Member__c WHERE Id = :convertResult.memberId]
      .Status__c
    );
  }
}
