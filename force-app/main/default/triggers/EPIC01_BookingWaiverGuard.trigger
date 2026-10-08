/**
 * EPIC01-US-007: block Booking__c inserts when the member has no valid signed waiver.
 * A trigger (not a validation rule) because the check queries another object, and it
 * must hold for every entry path: UI, API, data loader, flows.
 * Rules are shared with the payment gate via EPIC01_MemberOnboarding_Service.
 */
trigger EPIC01_BookingWaiverGuard on Booking__c (before insert) {
    EPIC01_BookingWaiver_Handler.validate(Trigger.new);
}
