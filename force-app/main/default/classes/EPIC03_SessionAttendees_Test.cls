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

  @isTest
  static void findByPhoneMatchesFormattedNumberOnThisSession() {
    Id sid = sessionId();
    Member__c avery = memberNamed('Avery');
    avery.Phone__c = '(336) 555-0100';
    update avery;
    Booking__c booking = EPIC01_TestDataFactory.newBooking(
      avery.Id,
      sid,
      locId()
    );
    insert booking;

    Test.startTest();
    EPIC03_SessionAttendees_Controller.PhoneLookupResult result = EPIC03_SessionAttendees_Controller.findByPhone(
      sid,
      '+1 336-555-0100'
    );
    Test.stopTest();

    System.assertEquals(true, result.validInput);
    System.assertEquals(1, result.matches.size());
    System.assertEquals(booking.Id, result.matches[0].bookingId);
    System.assertEquals(avery.Id, result.matches[0].memberId);
    System.assertEquals('Avery Johnson', result.matches[0].memberName);
  }

  @isTest
  static void findByPhoneIgnoresOtherSession() {
    Id sid = sessionId();
    Scheduled_Session__c other = EPIC01_TestDataFactory.createSession(locId());
    Member__c avery = memberNamed('Avery');
    Member__c sam = memberNamed('Sam');
    avery.Phone__c = '336-555-0100';
    sam.Phone__c = '336-555-0199';
    update new List<Member__c>{ avery, sam };

    insert EPIC01_TestDataFactory.newBooking(avery.Id, sid, locId());
    insert EPIC01_TestDataFactory.newBooking(sam.Id, other.Id, locId());

    Test.startTest();
    EPIC03_SessionAttendees_Controller.PhoneLookupResult result = EPIC03_SessionAttendees_Controller.findByPhone(
      sid,
      '3365550199'
    );
    Test.stopTest();

    System.assertEquals(true, result.validInput);
    System.assertEquals(0, result.matches.size());
    System.assertEquals(
      EPIC03_SessionAttendees_Controller.MSG_PHONE_NO_MATCH,
      result.message
    );
  }

  @isTest
  static void findByPhoneReturnsEveryRosterMatch() {
    Id sid = sessionId();
    Member__c avery = memberNamed('Avery');
    Member__c sam = memberNamed('Sam');
    avery.Phone__c = '336-555-0100';
    sam.Phone__c = '(336) 555-0100';
    update new List<Member__c>{ avery, sam };

    insert new List<Booking__c>{
      EPIC01_TestDataFactory.newBooking(avery.Id, sid, locId()),
      EPIC01_TestDataFactory.newBooking(sam.Id, sid, locId())
    };

    Test.startTest();
    EPIC03_SessionAttendees_Controller.PhoneLookupResult result = EPIC03_SessionAttendees_Controller.findByPhone(
      sid,
      '3365550100'
    );
    Test.stopTest();

    System.assertEquals(2, result.matches.size());
    Set<Id> memberIds = new Set<Id>();
    for (EPIC03_SessionAttendees_Controller.PhoneMatch match : result.matches) {
      memberIds.add(match.memberId);
    }
    System.assert(memberIds.contains(avery.Id));
    System.assert(memberIds.contains(sam.Id));
  }

  @isTest
  static void findByPhoneRejectsShortInputWithoutQuerying() {
    Test.startTest();
    EPIC03_SessionAttendees_Controller.PhoneLookupResult blank = EPIC03_SessionAttendees_Controller.findByPhone(
      sessionId(),
      '   '
    );
    EPIC03_SessionAttendees_Controller.PhoneLookupResult shortNum = EPIC03_SessionAttendees_Controller.findByPhone(
      sessionId(),
      '12345'
    );
    Test.stopTest();

    System.assertEquals(false, blank.validInput);
    System.assertEquals(0, blank.matches.size());
    System.assertEquals(
      EPIC03_SessionAttendees_Controller.MSG_PHONE_NEED_DIGITS,
      blank.message
    );
    System.assertEquals(false, shortNum.validInput);
    System.assertEquals(0, shortNum.matches.size());
    System.assertEquals(
      EPIC03_SessionAttendees_Controller.MSG_PHONE_NEED_DIGITS,
      shortNum.message
    );
  }

  @isTest
  static void findByCodeMatchesThisSessionIgnoringCase() {
    Id sid = sessionId();
    Member__c avery = [
      SELECT Id, Check_In_Code__c
      FROM Member__c
      WHERE First_Name__c = 'Avery'
      LIMIT 1
    ];
    Booking__c booking = EPIC01_TestDataFactory.newBooking(
      avery.Id,
      sid,
      locId()
    );
    insert booking;

    Test.startTest();
    EPIC03_SessionAttendees_Controller.PhoneLookupResult result = EPIC03_SessionAttendees_Controller.findByCode(
      sid,
      avery.Check_In_Code__c.toLowerCase()
    );
    Test.stopTest();

    System.assertEquals(true, result.validInput);
    System.assertEquals(1, result.matches.size());
    System.assertEquals(booking.Id, result.matches[0].bookingId);
    System.assertEquals('Avery Johnson', result.matches[0].memberName);
  }

  @isTest
  static void findByCodeIgnoresOtherSessionAndBlankInput() {
    Id sid = sessionId();
    Scheduled_Session__c other = EPIC01_TestDataFactory.createSession(locId());
    Member__c sam = [
      SELECT Id, Check_In_Code__c
      FROM Member__c
      WHERE First_Name__c = 'Sam'
      LIMIT 1
    ];
    insert EPIC01_TestDataFactory.newBooking(sam.Id, other.Id, locId());

    Test.startTest();
    EPIC03_SessionAttendees_Controller.PhoneLookupResult otherSession = EPIC03_SessionAttendees_Controller.findByCode(
      sid,
      sam.Check_In_Code__c
    );
    EPIC03_SessionAttendees_Controller.PhoneLookupResult blank = EPIC03_SessionAttendees_Controller.findByCode(
      sid,
      '   '
    );
    Test.stopTest();

    System.assertEquals(true, otherSession.validInput);
    System.assertEquals(0, otherSession.matches.size());
    System.assertEquals(
      EPIC03_SessionAttendees_Controller.MSG_CODE_NO_MATCH,
      otherSession.message
    );
    System.assertEquals(false, blank.validInput);
    System.assertEquals(0, blank.matches.size());
    System.assertEquals(
      EPIC03_SessionAttendees_Controller.MSG_CODE_REQUIRED,
      blank.message
    );
  }
}
