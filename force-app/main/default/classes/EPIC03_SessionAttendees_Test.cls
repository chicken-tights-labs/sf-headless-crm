/**
 * EPIC03-US-T004: session attendee roster (read-only check-in screen base).
 */
@isTest
private class EPIC03_SessionAttendees_Test {
  @testSetup
  static void setupData() {
    Franchise_Location__c loc = EPIC01_TestDataFactory.createLocation(
      'Lexington HQ'
    );
    Waiver_Template__c tmpl = EPIC01_TestDataFactory.createWaiverTemplate();
    EPIC01_TestDataFactory.createSession(loc.Id);
    EPIC01_TestDataFactory.createMemberWithWaiver(
      'Avery',
      'Johnson',
      loc.Id,
      tmpl.Id
    );
    EPIC01_TestDataFactory.createMemberWithWaiver(
      'Sam',
      'Walker',
      loc.Id,
      tmpl.Id
    );
  }

  private static Id locId() {
    return [SELECT Id FROM Franchise_Location__c WHERE Name = 'Lexington HQ']
    .Id;
  }

  private static Id sessionId() {
    return [SELECT Id FROM Scheduled_Session__c LIMIT 1].Id;
  }

  private static Member__c memberNamed(String first) {
    return [
      SELECT Id
      FROM Member__c
      WHERE First_Name__c = :first
      LIMIT 1
    ];
  }

  @isTest
  static void rosterShowsNameCheckInAndWaiver() {
    Id sid = sessionId();
    Id locationId = locId();
    Member__c avery = memberNamed('Avery');
    Member__c sam = memberNamed('Sam');

    Booking__c confirmed = EPIC01_TestDataFactory.newBooking(
      avery.Id,
      sid,
      locationId
    );
    Booking__c checkedIn = EPIC01_TestDataFactory.newBooking(
      sam.Id,
      sid,
      locationId
    );
    checkedIn.Status__c = 'Completed';
    checkedIn.Checked_In_At__c = DateTime.now();
    insert new List<Booking__c>{ confirmed, checkedIn };

    Test.startTest();
    List<EPIC03_SessionAttendees_Controller.AttendeeRow> rows = EPIC03_SessionAttendees_Controller.getAttendees(
      sid
    );
    Test.stopTest();

    System.assertEquals(2, rows.size());

    Map<Id, EPIC03_SessionAttendees_Controller.AttendeeRow> byMember = new Map<Id, EPIC03_SessionAttendees_Controller.AttendeeRow>();
    for (EPIC03_SessionAttendees_Controller.AttendeeRow row : rows) {
      byMember.put(row.memberId, row);
    }

    EPIC03_SessionAttendees_Controller.AttendeeRow averyRow = byMember.get(
      avery.Id
    );
    System.assertEquals('Avery Johnson', averyRow.memberName);
    System.assertEquals(
      EPIC03_SessionAttendees_Controller.CHECKIN_NOT_CHECKED_IN,
      averyRow.checkInStatus
    );
    System.assertEquals('Signed', averyRow.waiverStatus);

    EPIC03_SessionAttendees_Controller.AttendeeRow samRow = byMember.get(
      sam.Id
    );
    System.assertEquals('Sam Walker', samRow.memberName);
    System.assertEquals(
      EPIC03_SessionAttendees_Controller.CHECKIN_CHECKED_IN,
      samRow.checkInStatus
    );
    System.assertEquals('Signed', samRow.waiverStatus);
  }

  @isTest
  static void emptySessionReturnsNoRows() {
    Test.startTest();
    List<EPIC03_SessionAttendees_Controller.AttendeeRow> rows = EPIC03_SessionAttendees_Controller.getAttendees(
      sessionId()
    );
    Test.stopTest();
    System.assertEquals(0, rows.size());
  }

  @isTest
  static void checkInLabelCoversStatuses() {
    System.assertEquals(
      'Cancelled',
      EPIC03_SessionAttendees_Controller.checkInLabel('Cancelled', null)
    );
    System.assertEquals(
      'No-Show',
      EPIC03_SessionAttendees_Controller.checkInLabel('No-Show', null)
    );
    System.assertEquals(
      EPIC03_SessionAttendees_Controller.CHECKIN_CHECKED_IN,
      EPIC03_SessionAttendees_Controller.checkInLabel(
        'Confirmed',
        DateTime.now()
      )
    );
    System.assertEquals(
      EPIC03_SessionAttendees_Controller.CHECKIN_CHECKED_IN,
      EPIC03_SessionAttendees_Controller.checkInLabel('Completed', null)
    );
    System.assertEquals(
      EPIC03_SessionAttendees_Controller.CHECKIN_NOT_CHECKED_IN,
      EPIC03_SessionAttendees_Controller.checkInLabel('Confirmed', null)
    );
  }
}
