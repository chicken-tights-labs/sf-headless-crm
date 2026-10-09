/**
 * EPIC01-US-003: payment gate invocable, exact messages, and waiver-confirmed notify Flow.
 */
@isTest
private class EPIC01_PaymentGate_Test {

    @testSetup
    static void setupData() {
        Franchise_Location__c loc = EPIC01_TestDataFactory.createLocation('Lexington HQ');
        EPIC01_TestDataFactory.createWaiverTemplate();
        insert new Member__c(
            Name = 'Sam_Okafor', First_Name__c = 'Sam', Last_Name__c = 'Okafor',
            Email__c = 'sam.okafor@email.com', Home_Location__c = loc.Id,
            Status__c = 'Active', Referral_Code__c = 'SAM0KA00'
        );
    }

    private static Id locId() {
        return [SELECT Id FROM Franchise_Location__c WHERE Name = 'Lexington HQ'].Id;
    }

    private static Id tmplId() {
        return [SELECT Id FROM Waiver_Template__c LIMIT 1].Id;
    }

    private static Member__c prospect(String first, String last) {
        Member__c m = new Member__c(
            Name = first + '_' + last, First_Name__c = first, Last_Name__c = last,
            Email__c = first.toLowerCase() + '.' + last.toLowerCase() + '@email.com',
            Home_Location__c = locId(), Status__c = 'Prospect',
            Membership_Tier__c = 'Punch Card (10 classes - $150)'
        );
        insert m;
        return m;
    }

    @isTest
    static void invocableMapsValidWaiverToReadyMessage() {
        Member__c m = prospect('Taylor', 'Kim');
        EPIC01_TestDataFactory.createValidWaiver(m.Id, locId(), tmplId());

        EPIC01_PaymentGate_Action.Request req = new EPIC01_PaymentGate_Action.Request();
        req.memberId = m.Id;

        Test.startTest();
        EPIC01_PaymentGate_Action.Result result =
            EPIC01_PaymentGate_Action.check(new List<EPIC01_PaymentGate_Action.Request>{ req })[0];
        Test.stopTest();

        System.assertEquals(true, result.canProceed);
        System.assertEquals('Signed', result.waiverStatus);
        System.assertEquals(EPIC01_MemberOnboarding_Service.MSG_WAIVER_VALID, result.message);
    }

    @isTest
    static void invocableMapsMissingWaiverToSignFirst() {
        Member__c m = prospect('Alex', 'Rivera');
        EPIC01_PaymentGate_Action.Request req = new EPIC01_PaymentGate_Action.Request();
        req.memberId = m.Id;

        EPIC01_PaymentGate_Action.Result result =
            EPIC01_PaymentGate_Action.check(new List<EPIC01_PaymentGate_Action.Request>{ req })[0];

        System.assertEquals(false, result.canProceed);
        System.assertEquals('Missing', result.waiverStatus);
        System.assertEquals(EPIC01_MemberOnboarding_Service.MSG_WAIVER_MISSING, result.message);
    }

    @isTest
    static void signedWaiverOnProspectCreatesConfirmationTask() {
        Member__c m = prospect('Morgan', 'Lee');

        Test.startTest();
        EPIC01_TestDataFactory.createValidWaiver(m.Id, locId(), tmplId());
        Test.stopTest();

        System.assertEquals(1, [
            SELECT COUNT() FROM Task
            WHERE WhatId = :m.Id
              AND Subject = :EPIC01_MemberOnboarding_Service.MSG_WAIVER_CONFIRMED
        ]);
        System.assertEquals(true, EPIC01_MemberOnboarding_Service.attemptProceedToPayment(m.Id).canProceed);
    }

    @isTest
    static void activeMemberSigningDoesNotCreateConfirmationTask() {
        Member__c m = EPIC01_TestDataFactory.createMember('Active', 'Signer', locId());
        EPIC01_TestDataFactory.createValidWaiver(m.Id, locId(), tmplId());
        System.assertEquals(0, [
            SELECT COUNT() FROM Task
            WHERE WhatId = :m.Id
              AND Subject = :EPIC01_MemberOnboarding_Service.MSG_WAIVER_CONFIRMED
        ]);
    }

    @isTest
    static void notifyWaiverConfirmedSendsWithoutThrowing() {
        Member__c m = prospect('Casey', 'Brooks');
        Test.startTest();
        EPIC01_WaiverConfirmed_Action.Request req = new EPIC01_WaiverConfirmed_Action.Request();
        req.memberId = m.Id;
        EPIC01_WaiverConfirmed_Action.notify(new List<EPIC01_WaiverConfirmed_Action.Request>{ req });
        Integer emails = Limits.getEmailInvocations();
        Test.stopTest();
        System.assertEquals(1, emails);
    }
}
