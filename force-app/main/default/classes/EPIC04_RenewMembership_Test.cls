/**
 * EPIC04-US-F003: renew Active membership without processPayment side effects.
 */
@isTest
private class EPIC04_RenewMembership_Test {
  @testSetup
  static void setupData() {
    Franchise_Location__c loc = EPIC01_TestDataFactory.createLocation(
      'Lexington HQ'
    );
    Waiver_Template__c tmpl = EPIC01_TestDataFactory.createWaiverTemplate();
    Member__c m = EPIC01_TestDataFactory.createMemberWithWaiver(
      'Avery',
      'Johnson',
      loc.Id,
      tmpl.Id
    );
    m.Membership_Tier__c = EPIC01_MemberOnboarding_Service.TIER_MONTHLY;
    m.Status__c = 'Active';
    m.Start_Date__c = Date.today().addDays(-40);
    m.Expiry_Date__c = Date.today().addDays(-1);
    m.Welcome_Email_Sent__c = true;
    update m;
  }

  private static Id locId() {
    return [SELECT Id FROM Franchise_Location__c WHERE Name = 'Lexington HQ']
    .Id;
  }

  private static Id tmplId() {
    return [SELECT Id FROM Waiver_Template__c LIMIT 1].Id;
  }

  private static Member__c member() {
    return [
      SELECT
        Id,
        Status__c,
        Start_Date__c,
        Expiry_Date__c,
        Membership_Tier__c,
        Welcome_Email_Sent__c,
        Classes_Remaining__c
      FROM Member__c
      WHERE First_Name__c = 'Avery'
      LIMIT 1
    ];
  }

  private static void signWaiverToday(Id memberId) {
    EPIC01_TestDataFactory.createValidWaiver(memberId, locId(), tmplId());
  }

  @isTest
  static void renewExtendsExpiryCreatesPaymentNoWelcomeFlip() {
    Member__c before = member();
    Date oldStart = before.Start_Date__c;
    signWaiverToday(before.Id);

    Test.startTest();
    EPIC04_RenewMembership_Action.Request req = new EPIC04_RenewMembership_Action.Request();
    req.memberId = before.Id;
    req.amount = '129.00';
    req.paymentMethod = 'Cash';
    EPIC04_RenewMembership_Action.Result result = EPIC04_RenewMembership_Action.renew(
      new List<EPIC04_RenewMembership_Action.Request>{ req }
    )[0];
    Test.stopTest();

    System.assertEquals(true, result.success, result.message);
    System.assertEquals(
      EPIC01_MemberOnboarding_Service.MSG_RENEW_OK,
      result.message
    );

    Member__c after = member();
    System.assertEquals('Active', after.Status__c);
    System.assertEquals(
      oldStart,
      after.Start_Date__c,
      'Start_Date must not reset'
    );
    System.assertEquals(Date.today().addDays(30), after.Expiry_Date__c);
    System.assertEquals(true, after.Welcome_Email_Sent__c);

    System.assertEquals(
      1,
      [
        SELECT COUNT()
        FROM Payment_Transaction__c
        WHERE Member__c = :before.Id AND Status__c = 'Completed'
      ]
    );
  }

  @isTest
  static void renewBlockedWithoutTodaysWaiver() {
    Member__c m = member();
    // setup waiver is older than today if Signature_Timestamp is now — createValidWaiver
    // uses DateTime.now(), so clear waivers and insert one dated yesterday.
    delete [SELECT Id FROM Waiver_Record__c WHERE Member__c = :m.Id];
    Waiver_Record__c oldWaiver = new Waiver_Record__c(
      Name = 'WR-Old',
      Franchise_Location__c = locId(),
      Member__c = m.Id,
      Waiver_Template__c = tmplId(),
      Status__c = 'Signed',
      Expiration_Date__c = Date.today().addDays(365),
      Signature_Timestamp__c = DateTime.now().addDays(-2),
      Signature_Method__c = 'Digital In-Person',
      Signer_Email__c = 'avery.johnson@email.com',
      Signer_Role__c = 'Participant'
    );
    insert oldWaiver;

    Test.startTest();
    EPIC04_RenewMembership_Action.Request req = new EPIC04_RenewMembership_Action.Request();
    req.memberId = m.Id;
    req.amount = '129.00';
    req.paymentMethod = 'Cash';
    EPIC04_RenewMembership_Action.Result result = EPIC04_RenewMembership_Action.renew(
      new List<EPIC04_RenewMembership_Action.Request>{ req }
    )[0];
    Test.stopTest();

    System.assertEquals(false, result.success);
    System.assert(result.message.contains('new signed waiver'), result.message);
    System.assertEquals(0, [SELECT COUNT() FROM Payment_Transaction__c]);
  }

  @isTest
  static void renewBlockedWhenNotDue() {
    Member__c m = member();
    m.Expiry_Date__c = Date.today().addDays(10);
    update m;
    signWaiverToday(m.Id);

    Test.startTest();
    Boolean threw = false;
    try {
      EPIC01_MemberOnboarding_Service.renewMembership(m.Id, '129.00', 'Cash');
    } catch (EPIC01_MemberOnboarding_Service.PaymentException e) {
      threw = true;
      System.assertEquals(
        EPIC01_MemberOnboarding_Service.MSG_RENEW_NOT_DUE,
        e.getMessage()
      );
    }
    Test.stopTest();
    System.assertEquals(true, threw);
  }

  @isTest
  static void punchRenewAddsClassesFromToday() {
    Member__c m = member();
    m.Membership_Tier__c = EPIC01_MemberOnboarding_Service.TIER_PUNCH;
    m.Expiry_Date__c = Date.today();
    m.Classes_Remaining__c = 2;
    update m;
    signWaiverToday(m.Id);

    Test.startTest();
    System.assertEquals(
      true,
      EPIC01_MemberOnboarding_Service.renewMembership(m.Id, '150.00', 'Cash')
    );
    Test.stopTest();

    Member__c after = member();
    System.assertEquals(Date.today().addDays(180), after.Expiry_Date__c);
    System.assertEquals(12, after.Classes_Remaining__c);
  }
}
