/**
 * EPIC03-US-T002: check-in codes are random, stable, and replaced by overwrite.
 */
@isTest
private class EPIC03_CheckInCode_Test {
  @isTest
  static void insertAssignsRandomCodeThatIsNotPhoneOrEmail() {
    Franchise_Location__c loc = EPIC01_TestDataFactory.createLocation(
      'Lexington HQ'
    );
    Member__c member = EPIC01_TestDataFactory.createMember(
      'Avery',
      'Johnson',
      loc.Id
    );
    member.Phone__c = '336-555-0100';
    member.Email__c = 'avery.johnson@email.com';
    update member;

    Member__c saved = [
      SELECT Check_In_Code__c, Phone__c, Email__c
      FROM Member__c
      WHERE Id = :member.Id
    ];
    System.assertEquals(32, saved.Check_In_Code__c.length());
    System.assert(
      Pattern.matches('[0-9A-F]{32}', saved.Check_In_Code__c),
      saved.Check_In_Code__c
    );
    System.assertNotEquals(saved.Phone__c, saved.Check_In_Code__c);
    System.assertNotEquals(saved.Email__c, saved.Check_In_Code__c);
  }

  @isTest
  static void updateKeepsExistingCode() {
    Franchise_Location__c loc = EPIC01_TestDataFactory.createLocation(
      'Lexington HQ'
    );
    Member__c member = EPIC01_TestDataFactory.createMember(
      'Avery',
      'Johnson',
      loc.Id
    );
    String original = [
      SELECT Check_In_Code__c
      FROM Member__c
      WHERE Id = :member.Id
    ]
    .Check_In_Code__c;

    member.Phone__c = '336-555-0199';
    update member;

    Member__c saved = [
      SELECT Check_In_Code__c
      FROM Member__c
      WHERE Id = :member.Id
    ];
    System.assertEquals(original, saved.Check_In_Code__c);
  }

  @isTest
  static void replaceOverwritesSoTheOldCodeIsGone() {
    Franchise_Location__c loc = EPIC01_TestDataFactory.createLocation(
      'Lexington HQ'
    );
    Member__c member = EPIC01_TestDataFactory.createMember(
      'Avery',
      'Johnson',
      loc.Id
    );
    String original = [
      SELECT Check_In_Code__c
      FROM Member__c
      WHERE Id = :member.Id
    ]
    .Check_In_Code__c;

    Test.startTest();
    String next = EPIC03_CheckInCode_Service.replaceCode(member.Id);
    Test.stopTest();

    Member__c saved = [
      SELECT Check_In_Code__c
      FROM Member__c
      WHERE Id = :member.Id
    ];
    System.assertEquals(next, saved.Check_In_Code__c);
    System.assertNotEquals(original, saved.Check_In_Code__c);
    System.assertEquals(
      0,
      [SELECT COUNT() FROM Member__c WHERE Check_In_Code__c = :original]
    );
  }

  @isTest
  static void twoMembersGetDifferentCodes() {
    Franchise_Location__c loc = EPIC01_TestDataFactory.createLocation(
      'Lexington HQ'
    );
    Member__c avery = EPIC01_TestDataFactory.createMember(
      'Avery',
      'Johnson',
      loc.Id
    );
    Member__c sam = EPIC01_TestDataFactory.createMember(
      'Sam',
      'Walker',
      loc.Id
    );
    Map<Id, Member__c> saved = new Map<Id, Member__c>(
      [
        SELECT Check_In_Code__c
        FROM Member__c
        WHERE Id IN :new Set<Id>{ avery.Id, sam.Id }
      ]
    );
    System.assertNotEquals(
      saved.get(avery.Id).Check_In_Code__c,
      saved.get(sam.Id).Check_In_Code__c
    );
  }

  @isTest
  static void currentCodeAndReplaceGuardMissingMembers() {
    System.assertEquals(null, EPIC03_CheckInCode_Service.currentCode(null));
    try {
      EPIC03_CheckInCode_Service.replaceCode(null);
      System.assert(false, 'Expected member not found');
    } catch (AuraHandledException ex) {
      System.assertEquals(
        EPIC03_CheckInCode_Service.MSG_MEMBER_NOT_FOUND,
        ex.getMessage()
      );
    }
    try {
      EPIC03_CheckInCode_Service.replaceCode(UserInfo.getUserId());
      System.assert(false, 'Expected member not found');
    } catch (AuraHandledException ex) {
      System.assertEquals(
        EPIC03_CheckInCode_Service.MSG_MEMBER_NOT_FOUND,
        ex.getMessage()
      );
    }
  }

  @isTest
  static void currentCodeReturnsTheStoredValue() {
    Franchise_Location__c loc = EPIC01_TestDataFactory.createLocation(
      'Lexington HQ'
    );
    Member__c member = EPIC01_TestDataFactory.createMember(
      'Avery',
      'Johnson',
      loc.Id
    );
    String stored = [
      SELECT Check_In_Code__c
      FROM Member__c
      WHERE Id = :member.Id
    ]
    .Check_In_Code__c;
    System.assertEquals(
      stored,
      EPIC03_CheckInCode_Service.currentCode(member.Id)
    );
  }

  @isTest
  static void fillBlankSkipsNullAndExistingCodes() {
    EPIC03_CheckInCode_Service.fillBlank(null);
    Member__c existing = new Member__c(Check_In_Code__c = 'ABC');
    EPIC03_CheckInCode_Service.fillBlank(new List<Member__c>{ null, existing });
    System.assertEquals('ABC', existing.Check_In_Code__c);
    Member__c blank = new Member__c();
    EPIC03_CheckInCode_Service.fillBlank(new List<Member__c>{ blank });
    System.assertEquals(32, blank.Check_In_Code__c.length());
  }

  @isTest
  static void fillAllBlankDoesNothingWhenEveryMemberHasACode() {
    Franchise_Location__c loc = EPIC01_TestDataFactory.createLocation(
      'Lexington HQ'
    );
    EPIC01_TestDataFactory.createMember('Avery', 'Johnson', loc.Id);
    System.assertEquals(0, EPIC03_CheckInCode_Service.fillAllBlank());
  }
}
