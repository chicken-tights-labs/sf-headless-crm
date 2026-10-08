/**
 * EPIC01-US-001: block Lead__c inserts whose Email__c already exists
 * (covers every entry path: REST, trainer LWC, UI, API).
 * Apex used instead of a Duplicate Rule because custom-object matching rules
 * are hard to deploy/test reliably across scratch orgs.
 */
trigger EPIC01_LeadDuplicateGuard on Lead__c (before insert) {
    Set<String> emails = new Set<String>();
    for (Lead__c l : Trigger.new) {
        if (String.isNotBlank(l.Email__c)) {
            String e = l.Email__c.toLowerCase();
            if (!emails.add(e)) {
                l.addError(EPIC01_LeadCapture_Service.MSG_DUPLICATE);
            }
        }
    }
    if (emails.isEmpty()) {
        return;
    }
    Set<String> existing = new Set<String>();
    for (Lead__c l : [SELECT Email__c FROM Lead__c WHERE Email__c IN :emails]) {
        existing.add(l.Email__c.toLowerCase());
    }
    for (Lead__c l : Trigger.new) {
        if (String.isNotBlank(l.Email__c) && existing.contains(l.Email__c.toLowerCase())) {
            l.addError(EPIC01_LeadCapture_Service.MSG_DUPLICATE);
        }
    }
}
