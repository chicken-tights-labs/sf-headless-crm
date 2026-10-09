/**
 * EPIC01-US-007 / US-004: block Booking__c inserts when the member has no valid
 * signed waiver or is not Active. After a successful insert, punch-card
 * Classes_Remaining__c decrements. A trigger (not a validation rule) because
 * the check queries another object, and it must hold for every entry path.
 */
trigger EPIC01_BookingWaiverGuard on Booking__c (before insert, after insert) {
    if (Trigger.isBefore) {
        EPIC01_BookingWaiver_Handler.validate(Trigger.new);
    } else {
        EPIC01_BookingWaiver_Handler.decrementClasses(Trigger.new);
    }
}
