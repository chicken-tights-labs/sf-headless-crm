/**
 * EPIC01-US-007: logic for the Booking__c waiver guard trigger.
 */
public with sharing class EPIC01_BookingWaiver_Handler {

    public static final String MSG_MISSING = 'Cannot book class — member does not have a valid signed waiver';
    public static final String MSG_EXPIRED = 'Cannot book class — member\'s waiver has expired';
    public static final String MSG_PENDING = 'Cannot book class — member\'s waiver is pending signature';
    public static final String MSG_REVOKED = 'Cannot book class — member\'s waiver has been revoked';

    public static void validate(List<Booking__c> bookings) {
        Set<Id> memberIds = new Set<Id>();
        for (Booking__c b : bookings) {
            if (b.Member__c != null) {
                memberIds.add(b.Member__c);
            }
        }
        if (memberIds.isEmpty()) {
            return; // Member__c is required; the platform reports that itself
        }
        Map<Id, String> statuses = EPIC01_MemberOnboarding_Service.waiverStatusByMember(memberIds);
        for (Booking__c b : bookings) {
            if (b.Member__c == null) {
                continue;
            }
            String status = statuses.get(b.Member__c);
            if (status != 'Signed') {
                b.addError(messageFor(status));
            }
        }
    }

    @TestVisible
    private static String messageFor(String status) {
        if (status == 'Expired') {
            return MSG_EXPIRED;
        }
        if (status == 'Pending') {
            return MSG_PENDING;
        }
        if (status == 'Revoked') {
            return MSG_REVOKED;
        }
        return MSG_MISSING; // Missing, Unknown (e.g. Draft)
    }
}
