/**
 * EPIC03-US-T004: read-only attendee roster for a Scheduled Session.
 * Why Apex: joins Booking__c rows with waiverStatusByMember (cannot do in LWC alone).
 * This LWC is the class check-in screen; later stories add mark-attended / scan / phone.
 */
public with sharing class EPIC03_SessionAttendees_Controller {
  public static final String CHECKIN_CHECKED_IN = 'Checked in';
  public static final String CHECKIN_NOT_CHECKED_IN = 'Not checked in';

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
