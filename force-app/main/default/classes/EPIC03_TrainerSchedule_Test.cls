/**
 * EPIC03-US-T001: trainer schedule for the current week.
 */
@isTest
private class EPIC03_TrainerSchedule_Test {
  @testSetup
  static void setupData() {
    Franchise_Location__c loc = EPIC01_TestDataFactory.createLocation(
      'Lexington HQ'
    );
    Waiver_Template__c tmpl = EPIC01_TestDataFactory.createWaiverTemplate();
    Member__c member = EPIC01_TestDataFactory.createMemberWithWaiver(
      'Avery',
      'Johnson',
      loc.Id,
      tmpl.Id
    );

    Datetime weekStart = DateTime.newInstance(
      Date.today().toStartOfWeek(),
      Time.newInstance(9, 0, 0, 0)
    );

    Scheduled_Session__c mine = EPIC01_TestDataFactory.createSession(loc.Id);
    mine.Name = 'My Boxing Class';
    mine.Assigned_Trainer__c = UserInfo.getUserId();
    mine.Start_Time__c = weekStart.addDays(1);
    mine.End_Time__c = weekStart.addDays(1).addHours(1);
    update mine;

    Scheduled_Session__c unassigned = EPIC01_TestDataFactory.createSession(
      loc.Id
    );
    unassigned.Name = 'Unassigned Class';
    unassigned.Start_Time__c = weekStart.addDays(2);
    unassigned.End_Time__c = weekStart.addDays(2).addHours(1);
    update unassigned;

    Scheduled_Session__c cancelled = EPIC01_TestDataFactory.createSession(
      loc.Id
    );
    cancelled.Name = 'Cancelled Class';
    cancelled.Assigned_Trainer__c = UserInfo.getUserId();
    cancelled.Start_Time__c = weekStart.addDays(3);
    cancelled.End_Time__c = weekStart.addDays(3).addHours(1);
    cancelled.Session_Status__c = 'Cancelled';
    update cancelled;

    Scheduled_Session__c nextWeek = EPIC01_TestDataFactory.createSession(
      loc.Id
    );
    nextWeek.Name = 'Next Week Class';
    nextWeek.Assigned_Trainer__c = UserInfo.getUserId();
    nextWeek.Start_Time__c = weekStart.addDays(8);
    nextWeek.End_Time__c = weekStart.addDays(8).addHours(1);
    update nextWeek;

    insert EPIC01_TestDataFactory.newBooking(member.Id, mine.Id, loc.Id);
  }

  @isTest
  static void getMyWeekSessionsReturnsAssignedThisWeekOnly() {
    Test.startTest();
    List<EPIC03_TrainerSchedule_Controller.SessionRow> rows = EPIC03_TrainerSchedule_Controller.getMyWeekSessions();
    Test.stopTest();

    System.assertEquals(
      1,
      rows.size(),
      'Only this week assigned non-cancelled'
    );
    EPIC03_TrainerSchedule_Controller.SessionRow row = rows[0];
    System.assertEquals('My Boxing Class', row.sessionName);
    System.assertEquals('Lexington HQ', row.locationName);
    System.assertEquals(1, row.bookedCount);
    System.assertEquals(20, row.capacity);
    System.assertNotEquals(null, row.startTime);
    System.assertNotEquals(null, row.sessionUrl);
    System.assert(row.sessionUrl.startsWith('/'));
  }

  @isTest
  static void getMyWeekSessionsEmptyWhenNoneAssigned() {
    List<Scheduled_Session__c> mine = [
      SELECT Id
      FROM Scheduled_Session__c
      WHERE Assigned_Trainer__c = :UserInfo.getUserId()
    ];
    for (Scheduled_Session__c session : mine) {
      session.Assigned_Trainer__c = null;
    }
    update mine;

    Test.startTest();
    List<EPIC03_TrainerSchedule_Controller.SessionRow> rows = EPIC03_TrainerSchedule_Controller.getMyWeekSessions();
    Test.stopTest();

    System.assertEquals(0, rows.size());
  }

  @isTest
  static void bookedCountIgnoresCancelledBookings() {
    Scheduled_Session__c mine = [
      SELECT Id, Franchise_Location__c
      FROM Scheduled_Session__c
      WHERE Name = 'My Boxing Class'
      LIMIT 1
    ];
    Waiver_Template__c tmpl = [SELECT Id FROM Waiver_Template__c LIMIT 1];
    Member__c other = EPIC01_TestDataFactory.createMemberWithWaiver(
      'Sam',
      'Walker',
      mine.Franchise_Location__c,
      tmpl.Id
    );

    Booking__c cancelled = EPIC01_TestDataFactory.newBooking(
      other.Id,
      mine.Id,
      mine.Franchise_Location__c
    );
    insert cancelled;
    cancelled.Status__c = 'Cancelled';
    update cancelled;

    Test.startTest();
    List<EPIC03_TrainerSchedule_Controller.SessionRow> rows = EPIC03_TrainerSchedule_Controller.getMyWeekSessions();
    Test.stopTest();

    System.assertEquals(1, rows.size());
    System.assertEquals(
      1,
      rows[0].bookedCount,
      'Cancelled booking is not counted'
    );
  }
}
