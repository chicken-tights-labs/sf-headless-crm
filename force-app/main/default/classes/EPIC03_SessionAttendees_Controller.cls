/**
 * EPIC03-US-T004 / US-T005 / US-T006 / US-T003: session attendee roster and check-in.
 * Why Apex: joins Booking__c with waiverStatusByMember; markAttended is the
 * shared attendance write. Phone lookup normalizes Phone__c and matches this
 * session's bookings only — it does not write Booking__c.
 * Check-in does not use EPIC01_BookingWaiverGuard (that trigger is insert-only).
 */
public with sharing class EPIC03_SessionAttendees_Controller {
  public static final String CHECKIN_CHECKED_IN = 'Checked in';
  public static final String CHECKIN_NOT_CHECKED_IN = 'Not checked in';
  public static final String MSG_CHECKIN_OK = 'Checked in';
  public static final String MSG_CHECKIN_NO_WAIVER = 'Cannot check in - member does not have a valid signed waiver';
  public static final String MSG_CHECKIN_NO_BOOKING = 'Booking not found.';
  public static final String MSG_CHECKIN_CANCELLED = 'Cannot check in — this booking is Cancelled.';
  public static final String MSG_CHECKIN_NO_SHOW = 'Cannot check in — this booking is marked No-Show.';
  public static final String MSG_CHECKIN_ALREADY = 'This member is already checked in.';
  public static final String MSG_PHONE_NEED_DIGITS = 'Enter a 10-digit phone number.';
  public static final String MSG_PHONE_NO_MATCH = 'No booking on this class matches that phone.';
  public static final String MSG_CODE_REQUIRED = 'Enter a check-in code.';
  public static final String MSG_CODE_NO_MATCH = 'No booking on this class matches that code.';

  public class AttendeeRow {
    @AuraEnabled
    public Id bookingId;
    @AuraEnabled
    public Id memberId;
    @AuraEnabled
    public String memberName;
    /** Record URL for US-T007 trainer profile navigation. */
    @AuraEnabled
    public String memberUrl;
    @AuraEnabled
    public String bookingStatus;
    @AuraEnabled
    public String checkInStatus;
    @AuraEnabled
    public Datetime checkedInAt;
    @AuraEnabled
    public String waiverStatus;
  }

  public class MarkResult {
    @AuraEnabled
    public Boolean success;
    @AuraEnabled
    public String message;
  }

  public class PhoneMatch {
    @AuraEnabled
    public Id bookingId;
    @AuraEnabled
    public Id memberId;
    @AuraEnabled
    public String memberName;
  }

  public class PhoneLookupResult {
    @AuraEnabled
    public Boolean validInput;
    @AuraEnabled
    public String message;
    @AuraEnabled
    public List<PhoneMatch> matches;
  }

  @AuraEnabled(cacheable=true)
  public static List<AttendeeRow> getAttendees(Id sessionId) {
    if (sessionId == null) {
      return new List<AttendeeRow>();
    }

    List<Booking__c> bookings = [
      SELECT
        Id,
        Status__c,
        Checked_In_At__c,
        Member__c,
        Member__r.Name,
        Member__r.First_Name__c,
        Member__r.Last_Name__c
      FROM Booking__c
      WHERE Scheduled_Session__c = :sessionId
      ORDER BY
        Member__r.Last_Name__c ASC NULLS LAST,
        Member__r.First_Name__c ASC NULLS LAST
    ];

    Set<Id> memberIds = new Set<Id>();
    for (Booking__c b : bookings) {
      if (b.Member__c != null) {
        memberIds.add(b.Member__c);
      }
    }
    Map<Id, String> waiverByMember = memberIds.isEmpty()
      ? new Map<Id, String>()
      : EPIC01_MemberOnboarding_Service.waiverStatusByMember(memberIds);

    List<AttendeeRow> rows = new List<AttendeeRow>();
    for (Booking__c b : bookings) {
      AttendeeRow row = new AttendeeRow();
      row.bookingId = b.Id;
      row.memberId = b.Member__c;
      row.memberName = memberDisplayName(b);
      row.memberUrl = b.Member__c == null ? null : '/' + b.Member__c;
      row.bookingStatus = b.Status__c;
      row.checkedInAt = b.Checked_In_At__c;
      row.checkInStatus = checkInLabel(b.Status__c, b.Checked_In_At__c);
      row.waiverStatus = b.Member__c == null
        ? 'Missing'
        : waiverByMember.get(b.Member__c);
      rows.add(row);
    }
    return rows;
  }

  /**
   * US-T003: match a phone to bookings on this session. Does not check anyone in
   * and does not write Booking__c. Confirm calls markAttended.
   */
  @AuraEnabled
  public static PhoneLookupResult findByPhone(Id sessionId, String phone) {
    PhoneLookupResult result = new PhoneLookupResult();
    result.matches = new List<PhoneMatch>();
    String digits = phoneDigits(phone);
    if (digits == null) {
      result.validInput = false;
      result.message = MSG_PHONE_NEED_DIGITS;
      return result;
    }
    result.validInput = true;
    if (sessionId == null) {
      result.message = MSG_PHONE_NO_MATCH;
      return result;
    }

    List<Booking__c> bookings = [
      SELECT
        Id,
        Member__c,
        Member__r.Name,
        Member__r.First_Name__c,
        Member__r.Last_Name__c,
        Member__r.Phone__c
      FROM Booking__c
      WHERE Scheduled_Session__c = :sessionId AND Member__c != NULL
      ORDER BY
        Member__r.Last_Name__c ASC NULLS LAST,
        Member__r.First_Name__c ASC NULLS LAST
    ];

    for (Booking__c booking : bookings) {
      if (phoneDigits(booking.Member__r.Phone__c) != digits) {
        continue;
      }
      PhoneMatch match = new PhoneMatch();
      match.bookingId = booking.Id;
      match.memberId = booking.Member__c;
      match.memberName = memberDisplayName(booking);
      result.matches.add(match);
    }
    if (result.matches.isEmpty()) {
      result.message = MSG_PHONE_NO_MATCH;
    }
    return result;
  }

  /**
   * US-T002: match a scanned check-in code to bookings on this session.
   * Does not write Booking__c. One match is checked in through markAttended.
   */
  @AuraEnabled
  public static PhoneLookupResult findByCode(Id sessionId, String code) {
    PhoneLookupResult result = new PhoneLookupResult();
    result.matches = new List<PhoneMatch>();
    String normalized = normalizeCode(code);
    if (normalized == null) {
      result.validInput = false;
      result.message = MSG_CODE_REQUIRED;
      return result;
    }
    result.validInput = true;
    if (sessionId == null) {
      result.message = MSG_CODE_NO_MATCH;
      return result;
    }

    List<Booking__c> bookings = [
      SELECT
        Id,
        Member__c,
        Member__r.Name,
        Member__r.First_Name__c,
        Member__r.Last_Name__c
      FROM Booking__c
      WHERE
        Scheduled_Session__c = :sessionId
        AND Member__r.Check_In_Code__c = :normalized
      ORDER BY
        Member__r.Last_Name__c ASC NULLS LAST,
        Member__r.First_Name__c ASC NULLS LAST
    ];

    for (Booking__c booking : bookings) {
      PhoneMatch match = new PhoneMatch();
      match.bookingId = booking.Id;
      match.memberId = booking.Member__c;
      match.memberName = memberDisplayName(booking);
      result.matches.add(match);
    }
    if (result.matches.isEmpty()) {
      result.message = MSG_CODE_NO_MATCH;
    }
    return result;
  }

  /**
   * US-T005 + US-T006: set Checked_In_At__c and Status__c = Completed after
   * waiverStatusByMember returns Signed. QR and phone check-in call this.
   */
  @AuraEnabled
  public static MarkResult markAttended(Id bookingId) {
    MarkResult result = new MarkResult();
    Savepoint sp = Database.setSavepoint();
    try {
      if (bookingId == null) {
        result.success = false;
        result.message = MSG_CHECKIN_NO_BOOKING;
        return result;
      }

      List<Booking__c> bookings = [
        SELECT Id, Status__c, Checked_In_At__c, Member__c
        FROM Booking__c
        WHERE Id = :bookingId
        LIMIT 1
      ];
      if (bookings.isEmpty()) {
        result.success = false;
        result.message = MSG_CHECKIN_NO_BOOKING;
        return result;
      }

      Booking__c booking = bookings[0];
      if (booking.Status__c == 'Cancelled') {
        result.success = false;
        result.message = MSG_CHECKIN_CANCELLED;
        return result;
      }
      if (booking.Status__c == 'No-Show') {
        result.success = false;
        result.message = MSG_CHECKIN_NO_SHOW;
        return result;
      }
      if (
        booking.Checked_In_At__c != null ||
        booking.Status__c == 'Completed'
      ) {
        result.success = false;
        result.message = MSG_CHECKIN_ALREADY;
        return result;
      }
      if (booking.Member__c == null) {
        result.success = false;
        result.message = MSG_CHECKIN_NO_WAIVER;
        return result;
      }

      String waiverStatus = EPIC01_MemberOnboarding_Service.waiverStatusByMember(
          new Set<Id>{ booking.Member__c }
        )
        .get(booking.Member__c);
      if (waiverStatus != 'Signed') {
        result.success = false;
        result.message = MSG_CHECKIN_NO_WAIVER;
        return result;
      }

      booking.Checked_In_At__c = DateTime.now();
      booking.Status__c = 'Completed';
      update booking;

      result.success = true;
      result.message = MSG_CHECKIN_OK;
    } catch (Exception e) {
      Database.rollback(sp);
      result.success = false;
      result.message = e.getMessage();
    }
    return result;
  }

  /**
   * Digits only. A leading 1 on an 11-digit value is the country code.
   * Returns null unless the result is exactly 10 digits.
   */
  @TestVisible
  static String normalizeCode(String raw) {
    if (String.isBlank(raw)) {
      return null;
    }
    String code = raw.trim().toUpperCase();
    return String.isBlank(code) ? null : code;
  }

  @TestVisible
  static String phoneDigits(String raw) {
    if (String.isBlank(raw)) {
      return null;
    }
    String digits = raw.replaceAll('[^0-9]', '');
    if (digits.length() == 11 && digits.startsWith('1')) {
      digits = digits.substring(1);
    }
    return digits.length() == 10 ? digits : null;
  }

  @TestVisible
  static String checkInLabel(String bookingStatus, Datetime checkedInAt) {
    if (bookingStatus == 'Cancelled') {
      return 'Cancelled';
    }
    if (bookingStatus == 'No-Show') {
      return 'No-Show';
    }
    if (checkedInAt != null || bookingStatus == 'Completed') {
      return CHECKIN_CHECKED_IN;
    }
    return CHECKIN_NOT_CHECKED_IN;
  }

  private static String memberDisplayName(Booking__c b) {
    if (b.Member__r == null) {
      return '';
    }
    String combined = ((b.Member__r.First_Name__c == null
        ? ''
        : b.Member__r.First_Name__c.trim()) +
      ' ' +
      (b.Member__r.Last_Name__c == null ? '' : b.Member__r.Last_Name__c.trim()))
      .trim();
    return String.isBlank(combined) ? b.Member__r.Name : combined;
  }
}
