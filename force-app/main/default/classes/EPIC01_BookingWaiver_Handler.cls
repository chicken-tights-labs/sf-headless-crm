/**
 * EPIC01-US-007 / US-004: Booking__c insert guards.
 * Waiver rule is shared with the payment gate. Active-status and punch-card
 * class decrement are US-004.
 */
public with sharing class EPIC01_BookingWaiver_Handler {

    public static final String MSG_MISSING = 'Cannot book class — member does not have a valid signed waiver';
    public static final String MSG_EXPIRED = 'Cannot book class — member\'s waiver has expired';
    public static final String MSG_PENDING = 'Cannot book class — member\'s waiver is pending signature';
    public static final String MSG_REVOKED = 'Cannot book class — member\'s waiver has been revoked';
    public static final String MSG_NOT_ACTIVE = 'Membership not active — please complete payment';

    public static void validate(List<Booking__c> bookings) {
        Set<Id> memberIds = memberIdsFrom(bookings);
        if (memberIds.isEmpty()) {
            return; // Member__c is required; the platform reports that itself
        }
        Map<Id, Member__c> members = new Map<Id, Member__c>([
            SELECT Id, Status__c FROM Member__c WHERE Id IN :memberIds
        ]);
        Map<Id, String> statuses = EPIC01_MemberOnboarding_Service.waiverStatusByMember(memberIds);
        for (Booking__c b : bookings) {
            if (b.Member__c == null) {
                continue;
            }
            Member__c member = members.get(b.Member__c);
            if (member == null || member.Status__c != 'Active') {
                b.addError(MSG_NOT_ACTIVE);
                continue;
            }
            String status = statuses.get(b.Member__c);
            if (status != 'Signed') {
                b.addError(messageFor(status));
            }
        }
    }

    public static void decrementClasses(List<Booking__c> bookings) {
        Set<Id> memberIds = memberIdsFrom(bookings);
        if (memberIds.isEmpty()) {
            return;
        }
        Map<Id, Integer> used = new Map<Id, Integer>();
        for (Booking__c b : bookings) {
            if (b.Member__c == null) {
                continue;
            }
            Integer n = used.containsKey(b.Member__c) ? used.get(b.Member__c) : 0;
            used.put(b.Member__c, n + 1);
        }
        List<Member__c> updates = new List<Member__c>();
        for (Member__c m : [
            SELECT Id, Membership_Tier__c, Classes_Remaining__c
            FROM Member__c WHERE Id IN :used.keySet()
        ]) {
            if (m.Membership_Tier__c != EPIC01_MemberOnboarding_Service.TIER_PUNCH
                || m.Classes_Remaining__c == null || m.Classes_Remaining__c <= 0) {
                continue;
            }
            Integer next = (Integer) m.Classes_Remaining__c - used.get(m.Id);
            m.Classes_Remaining__c = next < 0 ? 0 : next;
            updates.add(m);
        }
        if (!updates.isEmpty()) {
            update updates;
        }
    }

    private static Set<Id> memberIdsFrom(List<Booking__c> bookings) {
        Set<Id> memberIds = new Set<Id>();
        for (Booking__c b : bookings) {
            if (b.Member__c != null) {
                memberIds.add(b.Member__c);
            }
        }
        return memberIds;
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
