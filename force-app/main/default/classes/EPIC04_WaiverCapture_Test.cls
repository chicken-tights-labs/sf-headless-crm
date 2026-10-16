/**
 * EPIC04-US-F005: digital waiver capture for Member and Lead.
 */
@isTest
private class EPIC04_WaiverCapture_Test {
  private static final String TINY_PNG_BASE64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

  @testSetup
  static void setupData() {
    Franchise_Location__c loc = EPIC01_TestDataFactory.createLocation(
      'Lexington HQ'
    );
    EPIC01_TestDataFactory.createWaiverTemplate();
    EPIC01_TestDataFactory.createMember('Avery', 'Johnson', loc.Id);
  }

  private static Id locId() {
    return [SELECT Id FROM Franchise_Location__c WHERE Name = 'Lexington HQ']
    .Id;
  }

  private static Id tmplId() {
    return [SELECT Id FROM Waiver_Template__c LIMIT 1].Id;
  }

  private static Id memberId() {
    return [
      SELECT Id
      FROM Member__c
      WHERE First_Name__c = 'Avery'
      LIMIT 1
    ]
    .Id;
  }

  private static Lead__c walkInLead() {
    Lead__c lead = new Lead__c(
      Name = 'Sam_Walker',
      First_Name__c = 'Sam',
      Last_Name__c = 'Walker',
      Email__c = 'sam.walker@email.com',
      Phone__c = '336-555-0100',
      Lead_Status__c = 'Walk-In',
      Lead_Source__c = 'In Person',
      Franchise_Location__c = locId()
    );
    insert lead;
    return lead;
  }

  @isTest
  static void captureForMemberCreatesSignedWaiverAndClearsNeeded() {
    Id mid = memberId();
    update new Member__c(Id = mid, Waiver_Needed__c = true);

    Test.startTest();
    EPIC04_WaiverCapture_Controller.CaptureResult result = EPIC04_WaiverCapture_Controller.captureWaiver(
      mid,
      'Avery Johnson',
      'avery.johnson@email.com',
      'Participant',
      tmplId(),
      TINY_PNG_BASE64
    );
    Test.stopTest();

    System.assertEquals(true, result.success, result.message);
    System.assertNotEquals(null, result.waiverId);

    Waiver_Record__c w = [
      SELECT
        Status__c,
        Member__c,
        Signature_Method__c,
        Signer_Email__c,
        Expiration_Date__c
      FROM Waiver_Record__c
      WHERE Id = :result.waiverId
    ];
    System.assertEquals('Signed', w.Status__c);
    System.assertEquals(mid, w.Member__c);
    System.assertEquals('Digital In-Person', w.Signature_Method__c);
    System.assertEquals(Date.today().addDays(365), w.Expiration_Date__c);

    Member__c m = [
      SELECT Waiver_Needed__c, Waiver_Signed__c
      FROM Member__c
      WHERE Id = :mid
    ];
    System.assertEquals(false, m.Waiver_Needed__c);
    System.assertEquals(result.waiverId, m.Waiver_Signed__c);

    System.assertEquals(
      'Signed',
      EPIC01_MemberOnboarding_Service.waiverStatusByMember(new Set<Id>{ mid })
        .get(mid)
    );

    System.assertEquals(
      1,
      [
        SELECT COUNT()
        FROM ContentDocumentLink
        WHERE LinkedEntityId = :result.waiverId
      ]
    );
  }

  @isTest
  static void captureForLeadCreatesSignedWaiver() {
    Lead__c lead = walkInLead();

    Test.startTest();
    EPIC04_WaiverCapture_Controller.CaptureResult result = EPIC04_WaiverCapture_Controller.captureWaiver(
      lead.Id,
      'Sam Walker',
      'sam.walker@email.com',
      'Participant',
      null,
      'data:image/png;base64,' + TINY_PNG_BASE64
    );
    Test.stopTest();

    System.assertEquals(true, result.success, result.message);
    Waiver_Record__c w = [
      SELECT Status__c, Lead__c, Member__c
      FROM Waiver_Record__c
      WHERE Id = :result.waiverId
    ];
    System.assertEquals('Signed', w.Status__c);
    System.assertEquals(lead.Id, w.Lead__c);
    System.assertEquals(null, w.Member__c);
  }

  @isTest
  static void captureWithoutSignatureFails() {
    Test.startTest();
    EPIC04_WaiverCapture_Controller.CaptureResult result = EPIC04_WaiverCapture_Controller.captureWaiver(
      memberId(),
      'Avery Johnson',
      'avery.johnson@email.com',
      'Participant',
      tmplId(),
      null
    );
    Test.stopTest();

    System.assertEquals(false, result.success);
    System.assert(
      result.message.contains('sign'),
      'Expected signature error, got: ' + result.message
    );
    System.assertEquals(0, [SELECT COUNT() FROM Waiver_Record__c]);
  }

  @isTest
  static void getContextForMemberPrefillsSigner() {
    Test.startTest();
    EPIC04_WaiverCapture_Controller.CaptureContext ctx = EPIC04_WaiverCapture_Controller.getCaptureContext(
      memberId()
    );
    Test.stopTest();

    System.assertEquals('Member', ctx.recordType);
    System.assertEquals('Avery Johnson', ctx.signerName);
    System.assertEquals('avery.johnson@email.com', ctx.signerEmail);
    System.assertEquals(locId(), ctx.locationId);
    System.assertNotEquals(null, ctx.defaultTemplateId);
  }
}
