/**
 * EPIC01-US-006: referral rules on Lead__c (self-referral block, existing-member check,
 * attempt counter, reward record). Attribution itself is done by the
 * EPIC01_Lead_Referral_Attribution flow.
 */
trigger EPIC01_LeadReferral on Lead__c (before insert, after insert) {
    if (Trigger.isBefore) {
        EPIC01_Referral_Handler.beforeInsert(Trigger.new);
    } else {
        EPIC01_Referral_Handler.afterInsert(Trigger.new);
    }
}
