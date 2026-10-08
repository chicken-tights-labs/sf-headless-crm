/**
 * EPIC01-US-005 / US-006: runs activation work when a Member__c transitions to Active.
 * Fires only on an actual status change (not on every update) and the work is
 * idempotent (Welcome_Email_Sent__c), so repeat updates do nothing.
 */
trigger EPIC01_MemberActivation on Member__c (after update) {
    Set<Id> activated = new Set<Id>();
    for (Member__c m : Trigger.new) {
        Member__c before = Trigger.oldMap.get(m.Id);
        if (m.Status__c == 'Active' && before.Status__c != 'Active') {
            activated.add(m.Id);
        }
    }
    if (!activated.isEmpty()) {
        EPIC01_MemberOnboarding_Service.handleActivation(activated);
    }
}
