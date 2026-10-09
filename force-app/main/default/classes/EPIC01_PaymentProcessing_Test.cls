/**
 * EPIC01-US-004: payment processing — gate, drop-in, cash, recurring task, receipt.
 */
@isTest
private class EPIC01_PaymentProcessing_Test {

    @testSetup
    static void setupData() {
        Franchise_Location__c loc = EPIC01_TestDataFactory.createLocation('Lexington HQ');
        EPIC01_TestDataFactory.createWaiverTemplate();
        EPIC01_TestDataFactory.createSession(loc.Id);
    }

    private static Id locId() {
        return [SELECT Id FROM Franchise_Location__c WHERE Name = 'Lexington HQ'].Id;
    }

    private static Id tmplId() {
        return [SELECT Id FROM Waiver_Template__c LIMIT 1].Id;
    }

    private static Member__c prospect(String first, String last, String tier) {
        Member__c m = new Member__c(
            Name = first + '_' + last, First_Name__c = first, Last_Name__c = last,
            Email__c = first.toLowerCase() + '.' + last.toLowerCase() + '@email.com',
            Home_Location__c = locId(), Status__c = 'Prospect', Membership_Tier__c = tier
        );
        insert m;
        EPIC01_TestDataFactory.createValidWaiver(m.Id, locId(), tmplId());
        return m;
    }

    @isTest
    static void dropInActivatesWithoutDatesOrClasses() {
        Member__c m = prospect('Maya', 'Dropin', EPIC01_MemberOnboarding_Service.TIER_DROPIN);

        Test.startTest();
        System.assertEquals(true, EPIC01_MemberOnboarding_Service.processPayment(m.Id, '20.00', 'Credit Card'));
        Test.stopTest();

        Member__c check = [
            SELECT Status__c, Start_Date__c, Expiry_Date__c, Classes_Remaining__c
            FROM Member__c WHERE Id = :m.Id
        ];
        System.assertEquals('Active', check.Status__c);
        System.assertEquals(null, check.Start_Date__c);
        System.assertEquals(null, check.Expiry_Date__c);
        System.assertEquals(0, check.Classes_Remaining__c, 'Drop-in uses field default 0, not a class pack');
        System.assert(EPIC01_MemberOnboarding_Service.receiptBodiesForTest[0].contains('Drop-In'));
        System.assert(EPIC01_MemberOnboarding_Service.receiptBodiesForTest[0].contains('$20.00'));
    }

    @isTest
    static void cashPaidInPersonCompletesWithoutDecline() {
        Member__c m = prospect('Sam', 'Cash', EPIC01_MemberOnboarding_Service.TIER_PUNCH);
        EPIC01_MemberOnboarding_Service.simulatePaymentFailure = true;

        System.assertEquals(true, EPIC01_MemberOnboarding_Service.processPayment(m.Id, '150.00', 'Cash'));

        Payment_Transaction__c txn = [
            SELECT Amount__c, Transaction_Method__c, Status__c, Is_Recurring__c
            FROM Payment_Transaction__c WHERE Member__c = :m.Id
        ];
        System.assertEquals(150.00, txn.Amount__c);
        System.assertEquals('Cash', txn.Transaction_Method__c);
        System.assertEquals('Completed', txn.Status__c);
        System.assertEquals(false, txn.Is_Recurring__c);
        System.assertEquals('Active', [SELECT Status__c FROM Member__c WHERE Id = :m.Id].Status__c);
    }

    @isTest
    static void monthlySetsRecurringFlagAndFollowUpTask() {
        Member__c m = prospect('Riley', 'Month', EPIC01_MemberOnboarding_Service.TIER_MONTHLY);
        System.assertEquals(true, EPIC01_MemberOnboarding_Service.processPayment(m.Id, '129.00', 'Credit Card'));

        Member__c check = [
            SELECT Status__c, Start_Date__c, Expiry_Date__c FROM Member__c WHERE Id = :m.Id
        ];
        System.assertEquals('Active', check.Status__c);
        System.assertEquals(Date.today(), check.Start_Date__c);
        System.assertEquals(Date.today().addDays(30), check.Expiry_Date__c);

        Payment_Transaction__c txn = [
            SELECT Is_Recurring__c FROM Payment_Transaction__c WHERE Member__c = :m.Id
        ];
        System.assertEquals(true, txn.Is_Recurring__c);

        Task t = [
            SELECT Subject, ActivityDate FROM Task
            WHERE WhatId = :m.Id AND Subject = 'Process recurring payment for Riley Month'
        ];
        System.assertEquals(Date.today().addDays(30), t.ActivityDate);
        System.assert(EPIC01_MemberOnboarding_Service.receiptBodiesForTest[0].contains('Expiry date: ' + String.valueOf(Date.today().addDays(30))));
    }

    @isTest
    static void missingWaiverDoesNotCreateTransaction() {
        Member__c m = new Member__c(
            Name = 'No_Waiver', First_Name__c = 'No', Last_Name__c = 'Waiver',
            Email__c = 'no.waiver@email.com', Home_Location__c = locId(),
            Status__c = 'Prospect', Membership_Tier__c = EPIC01_MemberOnboarding_Service.TIER_PUNCH
        );
        insert m;

        try {
            EPIC01_MemberOnboarding_Service.processPayment(m.Id, '150.00', 'Credit Card');
            System.assert(false, 'Expected PaymentException');
        } catch (EPIC01_MemberOnboarding_Service.PaymentException e) {
            System.assertEquals(EPIC01_MemberOnboarding_Service.MSG_WAIVER_MISSING, e.getMessage());
        }
        System.assertEquals(0, [SELECT COUNT() FROM Payment_Transaction__c WHERE Member__c = :m.Id]);
        System.assertEquals('Prospect', [SELECT Status__c FROM Member__c WHERE Id = :m.Id].Status__c);
    }

    @isTest
    static void invocableReturnsGateMessageWhenBlocked() {
        Member__c m = new Member__c(
            Name = 'Gate_Block', First_Name__c = 'Gate', Last_Name__c = 'Block',
            Email__c = 'gate.block@email.com', Home_Location__c = locId(),
            Status__c = 'Prospect'
        );
        insert m;

        EPIC01_ProcessPayment_Action.Request req = new EPIC01_ProcessPayment_Action.Request();
        req.memberId = m.Id;
        req.amount = '129.00';
        req.paymentMethod = 'Credit Card';

        EPIC01_ProcessPayment_Action.Result result =
            EPIC01_ProcessPayment_Action.pay(new List<EPIC01_ProcessPayment_Action.Request>{ req })[0];

        System.assertEquals(false, result.success);
        System.assertEquals(EPIC01_MemberOnboarding_Service.MSG_NO_TIER, result.message);
    }

    @isTest
    static void invocableCompletesHappyPath() {
        Member__c m = prospect('Drew', 'Pay', EPIC01_MemberOnboarding_Service.TIER_PUNCH);
        EPIC01_ProcessPayment_Action.Request req = new EPIC01_ProcessPayment_Action.Request();
        req.memberId = m.Id;
        req.amount = '150.00';
        req.paymentMethod = 'Credit Card';

        EPIC01_ProcessPayment_Action.Result result =
            EPIC01_ProcessPayment_Action.pay(new List<EPIC01_ProcessPayment_Action.Request>{ req })[0];

        System.assertEquals(true, result.success);
        System.assertEquals(EPIC01_MemberOnboarding_Service.MSG_PAYMENT_OK, result.message);
        System.assertEquals('Active', [SELECT Status__c FROM Member__c WHERE Id = :m.Id].Status__c);
    }
}
