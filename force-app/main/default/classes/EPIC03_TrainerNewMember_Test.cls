/**
 * EPIC03-US-T008: trainer New Member uses the existing walk-in and convert
 * actions. Payment is not part of this path; Active still comes from
 * EPIC01_ProcessPayment_Action.
 */
@isTest
private class EPIC03_TrainerNewMember_Test {
  @isTest
  static void walkInConvertsToProspectWithoutPayment() {
    Franchise_Location__c location = EPIC01_TestDataFactory.createLocation(
      'Lexington HQ'
    );

    Test.startTest();
    Id leadId = EPIC04_LeadRegistration_Controller.createLead(
      'John',
      'Smith',
      '555-123-4567',
      'john.t008@example.com',
      location.Id
    );
    EPIC01_LeadConversion_Action.Result result = EPIC01_LeadConversion_Action.convertForScreen(
      leadId
    );
    Test.stopTest();

    System.assertEquals(true, result.success, result.message);
    Member__c member = [
      SELECT Status__c, Original_Lead__c, Home_Location__c
      FROM Member__c
      WHERE Id = :result.memberId
    ];
    System.assertEquals('Prospect', member.Status__c);
    System.assertEquals(leadId, member.Original_Lead__c);
    System.assertEquals(location.Id, member.Home_Location__c);
    System.assertEquals(
      'Converted',
      [SELECT Lead_Status__c FROM Lead__c WHERE Id = :leadId].Lead_Status__c
    );
    System.assertEquals(
      0,
      [SELECT COUNT() FROM Payment_Transaction__c WHERE Member__c = :member.Id]
    );
  }

  @isTest
  static void screenConvertReturnsTheGuardInsteadOfThrowing() {
    Franchise_Location__c location = EPIC01_TestDataFactory.createLocation(
      'Lexington HQ'
    );
    Id leadId = EPIC04_LeadRegistration_Controller.createLead(
      'Ada',
      'Already',
      '555-123-4567',
      'ada.t008@example.com',
      location.Id
    );
    System.assertEquals(
      true,
      EPIC01_LeadConversion_Action.convertForScreen(leadId).success
    );

    EPIC01_LeadConversion_Action.Result again = EPIC01_LeadConversion_Action.convertForScreen(
      leadId
    );

    System.assertEquals(false, again.success);
    System.assertEquals(
      'Member already exists for this lead — view existing Member record',
      again.message
    );
    System.assertEquals(null, again.memberId);
  }
}
