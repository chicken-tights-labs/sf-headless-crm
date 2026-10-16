/**
 * EPIC03-US-T004 / US-T005 / US-T006: attendee roster + mark attended with waiver block.
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

  @isTest
  static void markAttendedSetsCompletedAndTimestamp() {
    Id sid = sessionId();
    Member__c avery = memberNamed('Avery');
    Booking__c booking = EPIC01_TestDataFactory.newBooking(
      avery.Id,
      sid,
      locId()
    );
    insert booking;

    Test.startTest();
    EPIC03_SessionAttendees_Controller.MarkResult result = EPIC03_SessionAttendees_Controller.markAttended(
      booking.Id
    );
    Test.stopTest();

    System.assertEquals(true, result.success, result.message);
    Booking__c updated = [
      SELECT Status__c, Checked_In_At__c
      FROM Booking__c
      WHERE Id = :booking.Id
    ];
    System.assertEquals('Completed', updated.Status__c);
    System.assertNotEquals(null, updated.Checked_In_At__c);
  }

  @isTest
  static void markAttendedBlockedWithoutValidWaiver() {
    Id sid = sessionId();
    Member__c avery = memberNamed('Avery');
    Booking__c booking = EPIC01_TestDataFactory.newBooking(
      avery.Id,
      sid,
      locId()
    );
    insert booking;
    delete [SELECT Id FROM Waiver_Record__c WHERE Member__c = :avery.Id];

    Test.startTest();
    EPIC03_SessionAttendees_Controller.MarkResult result = EPIC03_SessionAttendees_Controller.markAttended(
      booking.Id
    );
    Test.stopTest();

    System.assertEquals(false, result.success);
    System.assertEquals(
      EPIC03_SessionAttendees_Controller.MSG_CHECKIN_NO_WAIVER,
      result.message
    );
    Booking__c unchanged = [
      SELECT Status__c, Checked_In_At__c
      FROM Booking__c
      WHERE Id = :booking.Id
    ];
    System.assertEquals('Confirmed', unchanged.Status__c);
    System.assertEquals(null, unchanged.Checked_In_At__c);
  }

  @isTest
  static void markAttendedGuardsNullCancelledNoShowAndAlreadyDone() {
    Id sid = sessionId();
    Member__c avery = memberNamed('Avery');
    Member__c sam = memberNamed('Sam');

    Booking__c cancelled = EPIC01_TestDataFactory.newBooking(
      avery.Id,
      sid,
      locId()
    );
    Booking__c noShow = EPIC01_TestDataFactory.newBooking(sam.Id, sid, locId());
    insert new List<Booking__c>{ cancelled, noShow };
    cancelled.Status__c = 'Cancelled';
    noShow.Status__c = 'No-Show';
    update new List<Booking__c>{ cancelled, noShow };

    Booking__c alreadyDone = EPIC01_TestDataFactory.newBooking(
      avery.Id,
      sid,
      locId()
    );
    // Second booking for Avery needs a distinct name; reuse factory then complete.
    alreadyDone.Name = 'Booking already done';
    insert alreadyDone;
    alreadyDone.Status__c = 'Completed';
    alreadyDone.Checked_In_At__c = DateTime.now();
    update alreadyDone;

    Test.startTest();
    EPIC03_SessionAttendees_Controller.MarkResult nullId = EPIC03_SessionAttendees_Controller.markAttended(
      null
    );
    // Wrong sObject Id → query returns no Booking rows.
    EPIC03_SessionAttendees_Controller.MarkResult missing = EPIC03_SessionAttendees_Controller.markAttended(
      UserInfo.getUserId()
    );
    EPIC03_SessionAttendees_Controller.MarkResult cancelledResult = EPIC03_SessionAttendees_Controller.markAttended(
      cancelled.Id
    );
    EPIC03_SessionAttendees_Controller.MarkResult noShowResult = EPIC03_SessionAttendees_Controller.markAttended(
      noShow.Id
    );
    EPIC03_SessionAttendees_Controller.MarkResult already = EPIC03_SessionAttendees_Controller.markAttended(
      alreadyDone.Id
    );
    List<EPIC03_SessionAttendees_Controller.AttendeeRow> empty = EPIC03_SessionAttendees_Controller.getAttendees(
      null
    );
    Test.stopTest();

    System.assertEquals(false, nullId.success);
    System.assertEquals(
      EPIC03_SessionAttendees_Controller.MSG_CHECKIN_NO_BOOKING,
      nullId.message
    );
    System.assertEquals(false, missing.success);
    System.assertEquals(
      EPIC03_SessionAttendees_Controller.MSG_CHECKIN_NO_BOOKING,
      missing.message
    );
    System.assertEquals(false, cancelledResult.success);
    System.assertEquals(
      EPIC03_SessionAttendees_Controller.MSG_CHECKIN_CANCELLED,
      cancelledResult.message
    );
    System.assertEquals(false, noShowResult.success);
    System.assertEquals(
      EPIC03_SessionAttendees_Controller.MSG_CHECKIN_NO_SHOW,
      noShowResult.message
    );
    System.assertEquals(false, already.success);
    System.assertEquals(
      EPIC03_SessionAttendees_Controller.MSG_CHECKIN_ALREADY,
      already.message
    );
    System.assertEquals(0, empty.size());
  }
}
