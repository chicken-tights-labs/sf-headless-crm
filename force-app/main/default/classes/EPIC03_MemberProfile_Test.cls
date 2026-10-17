/**
 * EPIC03-US-T007: trainer member profile (read-only, medical notes FLS-gated).
 */
@isTest
private class EPIC03_MemberProfile_Test {
  @testSetup
  static void setupData() {
    Franchise_Location__c loc = EPIC01_TestDataFactory.createLocation(
      'Lexington HQ'
    );
    Member__c m = EPIC01_TestDataFactory.createMember(
      'Avery',
      'Johnson',
      loc.Id
    );
    m.Membership_Tier__c = 'Monthly Unlimited ($129)';
    m.Expiry_Date__c = Date.today().addDays(30);
    m.Medical_Notes__c = 'Asthma — keep inhaler nearby';
    update m;
  }

  private static Member__c testMember() {
    return [
      SELECT
        Id,
        First_Name__c,
        Last_Name__c,
        Membership_Tier__c,
        Status__c,
        Expiry_Date__c,
        Medical_Notes__c
      FROM Member__c
      WHERE First_Name__c = 'Avery'
      LIMIT 1
    ];
  }

  @isTest
  static void getProfileReturnsCoreFields() {
    Member__c m = testMember();

    Test.startTest();
    EPIC03_MemberProfile_Controller.ProfileView view = EPIC03_MemberProfile_Controller.getProfile(
      m.Id
    );
    Test.stopTest();

    System.assertNotEquals(null, view);
    System.assertEquals(m.Id, view.memberId);
    System.assertEquals('Avery Johnson', view.name);
    System.assertEquals('Monthly Unlimited ($129)', view.membershipTier);
    System.assertEquals('Active', view.status);
    System.assertEquals(m.Expiry_Date__c, view.expiryDate);

    // Medical notes follow running-user FLS (US-T009 trainer permset).
    Boolean notesAccessible = Member__c.Medical_Notes__c.getDescribe()
      .isAccessible();
    System.assertEquals(notesAccessible, view.canViewMedicalNotes);
    if (notesAccessible) {
      System.assertEquals('Asthma — keep inhaler nearby', view.medicalNotes);
    } else {
      System.assertEquals(null, view.medicalNotes);
    }
  }

  @isTest
  static void getProfileNullIdReturnsNull() {
    Test.startTest();
    EPIC03_MemberProfile_Controller.ProfileView view = EPIC03_MemberProfile_Controller.getProfile(
      null
    );
    Test.stopTest();
    System.assertEquals(null, view);
  }

  @isTest
  static void getProfileUnknownIdReturnsNull() {
    // Valid Id format that does not exist in this org
    Id fakeId = (Id) (Member__c.SObjectType.getDescribe().getKeyPrefix() +
    '000000000001');

    Test.startTest();
    EPIC03_MemberProfile_Controller.ProfileView view = EPIC03_MemberProfile_Controller.getProfile(
      fakeId
    );
    Test.stopTest();
    System.assertEquals(null, view);
  }
}
