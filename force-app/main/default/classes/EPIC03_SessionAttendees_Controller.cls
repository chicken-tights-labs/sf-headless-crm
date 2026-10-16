/**
 * EPIC03-US-T004 / US-T005 / US-T006: session attendee roster and check-in.
 * Why Apex: joins Booking__c with waiverStatusByMember; markAttended is the
 * shared attendance write for US-T002 / US-T003 later.
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

  public class AttendeeRow {
    @AuraEnabled
    public Id bookingId;
    @AuraEnabled
    public Id memberId;
    @AuraEnabled
    public String memberName;
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
   * US-T005 + US-T006: set Checked_In_At__c and Status__c = Completed after
   * waiverStatusByMember returns Signed. Called later by QR/phone check-in.
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
