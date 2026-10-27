/**
 * EPIC03-US-T010: substitute lookup and notice. Assigned trainer is unchanged.
 */
@isTest
private class EPIC03_SubstituteTrainer_Test {
  private static User trainer(String alias, String email) {
    Profile profile = [
      SELECT Id
      FROM Profile
      WHERE UserType = 'Standard'
      LIMIT 1
    ];
    return new User(
      Alias = alias,
      Email = email,
      EmailEncodingKey = 'UTF-8',
      LastName = alias,
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = profile.Id,
      TimeZoneSidKey = 'America/New_York',
      Username = alias + DateTime.now().getTime() + '@example.com'
    );
  }

  private static EPIC03_SubstituteTrainer_Action.Result call(Id sessionId) {
    EPIC03_SubstituteTrainer_Action.Request req = new EPIC03_SubstituteTrainer_Action.Request();
    req.sessionId = sessionId;
    return EPIC03_SubstituteTrainer_Action.substitute(
      new List<EPIC03_SubstituteTrainer_Action.Request>{ req }
    )[0];
  }

  @isTest
  static void coverSetsSubstituteAndEmailsOriginal() {
    User original = trainer('origtr', 'original.trainer@example.com');
    User cover = trainer('covertr', 'cover.trainer@example.com');
    insert new List<User>{ original, cover };

    Id sessionId;
    Datetime start = Datetime.now().addDays(1);
    System.runAs(cover) {
      Franchise_Location__c loc = EPIC01_TestDataFactory.createLocation(
        'Lexington HQ'
      );
      Scheduled_Session__c session = EPIC01_TestDataFactory.createSession(
        loc.Id
      );
      session.Name = 'Evening Boxing';
      session.Assigned_Trainer__c = original.Id;
      session.Start_Time__c = start;
      update session;
      sessionId = session.Id;

      Test.startTest();
      EPIC03_SubstituteTrainer_Action.Result result = call(sessionId);
      Integer emails = Limits.getEmailInvocations();
      Test.stopTest();

      System.assertEquals(true, result.success, result.message);
      System.assertEquals(
        EPIC03_SubstituteTrainer_Action.MSG_OK,
        result.message
      );
      System.assertEquals(1, emails);

      EPIC03_SubstituteTrainer_Action.Result again = call(sessionId);
      System.assertEquals(false, again.success);
      System.assertEquals(
        EPIC03_SubstituteTrainer_Action.MSG_ALREADY_SUBSTITUTE,
        again.message
      );
    }

    Scheduled_Session__c saved = [
      SELECT Assigned_Trainer__c, Substitute_Trainer__c, Start_Time__c
      FROM Scheduled_Session__c
      WHERE Id = :sessionId
    ];
    System.assertEquals(original.Id, saved.Assigned_Trainer__c);
    System.assertEquals(cover.Id, saved.Substitute_Trainer__c);
    System.assertEquals(start, saved.Start_Time__c);
  }

  @isTest
  static void assignedTrainerCannotCoverOwnClass() {
    User original = trainer('owntr', 'own.trainer@example.com');
    insert original;

    System.runAs(original) {
      Franchise_Location__c loc = EPIC01_TestDataFactory.createLocation(
        'Lexington HQ'
      );
      Scheduled_Session__c session = EPIC01_TestDataFactory.createSession(
        loc.Id
      );
      session.Assigned_Trainer__c = original.Id;
      update session;

      Test.startTest();
      EPIC03_SubstituteTrainer_Action.Result result = call(session.Id);
      Integer emails = Limits.getEmailInvocations();
      Test.stopTest();

      System.assertEquals(false, result.success);
      System.assertEquals(
        EPIC03_SubstituteTrainer_Action.MSG_ALREADY_ASSIGNED,
        result.message
      );
      System.assertEquals(0, emails);
      System.assertEquals(
        null,
        [
          SELECT Substitute_Trainer__c
          FROM Scheduled_Session__c
          WHERE Id = :session.Id
        ]
        .Substitute_Trainer__c
      );
    }
  }

  @isTest
  static void secondCoverIsRefused() {
    User original = trainer('orig2', 'original.two@example.com');
    User cover = trainer('cover2', 'cover.two@example.com');
    User other = trainer('other2', 'other.two@example.com');
    insert new List<User>{ original, cover, other };

    Franchise_Location__c loc;
    Id sessionId;
    System.runAs(cover) {
      loc = EPIC01_TestDataFactory.createLocation('Lexington HQ');
      Scheduled_Session__c session = EPIC01_TestDataFactory.createSession(
        loc.Id
      );
      session.Assigned_Trainer__c = original.Id;
      update session;
      sessionId = session.Id;
      System.assertEquals(true, call(sessionId).success);
    }

    System.runAs(other) {
      Test.startTest();
      EPIC03_SubstituteTrainer_Action.Result result = call(sessionId);
      Test.stopTest();
      System.assertEquals(false, result.success);
      System.assertEquals(
        EPIC03_SubstituteTrainer_Action.MSG_TAKEN,
        result.message
      );
    }

    System.assertEquals(
      cover.Id,
      [
        SELECT Substitute_Trainer__c
        FROM Scheduled_Session__c
        WHERE Id = :sessionId
      ]
      .Substitute_Trainer__c
    );
  }

  @isTest
  static void cancelledAndCompletedAreRefused() {
    User cover = trainer('stattr', 'status.trainer@example.com');
    insert cover;

    System.runAs(cover) {
      Franchise_Location__c loc = EPIC01_TestDataFactory.createLocation(
        'Lexington HQ'
      );
      Scheduled_Session__c cancelled = EPIC01_TestDataFactory.createSession(
        loc.Id
      );
      cancelled.Session_Status__c = 'Cancelled';
      update cancelled;
      Scheduled_Session__c completed = EPIC01_TestDataFactory.createSession(
        loc.Id
      );
      completed.Session_Status__c = 'Completed';
      update completed;

      System.assertEquals(
        EPIC03_SubstituteTrainer_Action.MSG_CANCELLED,
        call(cancelled.Id).message
      );
      System.assertEquals(
        EPIC03_SubstituteTrainer_Action.MSG_COMPLETED,
        call(completed.Id).message
      );
    }
  }

  @isTest
  static void classWithNoAssignedTrainerStillSaves() {
    User cover = trainer('noorig', 'no.original@example.com');
    insert cover;

    System.runAs(cover) {
      Franchise_Location__c loc = EPIC01_TestDataFactory.createLocation(
        'Lexington HQ'
      );
      Scheduled_Session__c session = EPIC01_TestDataFactory.createSession(
        loc.Id
      );

      Test.startTest();
      EPIC03_SubstituteTrainer_Action.Result result = call(session.Id);
      Integer emails = Limits.getEmailInvocations();
      Test.stopTest();

      System.assertEquals(true, result.success, result.message);
      System.assertEquals(
        EPIC03_SubstituteTrainer_Action.MSG_OK_NO_TRAINER,
        result.message
      );
      System.assertEquals(0, emails);
      System.assertEquals(
        cover.Id,
        [
          SELECT Substitute_Trainer__c
          FROM Scheduled_Session__c
          WHERE Id = :session.Id
        ]
        .Substitute_Trainer__c
      );
    }
  }
}
