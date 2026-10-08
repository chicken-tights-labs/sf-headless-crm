/**
 * EPIC01-US-005: Welcome workflow — maps to the Gherkin scenarios in issue #23.
 */
@isTest
private class EPIC01_Welcome_Test {

    @testSetup
    static void setupData() {
        Franchise_Location__c loc = EPIC01_TestDataFactory.createLocation('Lexington HQ');
        loc.Phone__c = '336-555-0100';
        update loc;
        insert new Member__c(
            Name = 'Sam_Okafor', First_Name__c = 'Sam', Last_Name__c = 'Okafor',
            Email__c = 'sam.okafor@email.com', Home_Location__c = loc.Id,
            Status__c = 'Active', Referral_Code__c = 'SAM0KA00', Welcome_Email_Sent__c = true
        );
    }

    private static Id locId() {
        return [SELECT Id FROM Franchise_Location__c WHERE Name = 'Lexington HQ'].Id;
    }

    private static Member__c prospect(String first, String last, String email) {
        Member__c m = new Member__c(
            Name = first + '_' + last, First_Name__c = first, Last_Name__c = last, Email__c = email,
            Home_Location__c = locId(), Status__c = 'Prospect', Membership_Tier__c = 'Monthly Unlimited ($129)'
        );
        insert m;
        return m;
    }

    private static void activate(Member__c m) {
        m.Status__c = 'Active';
        update m;
    }

    @isTest
    static void welcomeEmailAndOrientationTaskOnActivation() {
        Member__c m = prospect('Maya', 'Rodriguez', 'maya.r@email.com');
        Test.startTest();
        activate(m);
        Integer emails = Limits.getEmailInvocations();
        Test.stopTest();

        System.assertEquals(1, emails, 'One welcome email batch should be sent');
        System.assertEquals(true, [SELECT Welcome_Email_Sent__c FROM Member__c WHERE Id = :m.Id].Welcome_Email_Sent__c);
        Task t = [SELECT Subject, ActivityDate FROM Task WHERE WhatId = :m.Id];
        System.assertEquals('Schedule facility orientation for Maya Rodriguez', t.Subject);
        System.assertEquals(Date.today().addDays(7), t.ActivityDate);
        String body = EPIC01_MemberOnboarding_Service.welcomeBodiesForTest[0];
        System.assert(body.contains('Monthly Unlimited ($129)'), body);
        System.assert(body.contains('schedule'), body);
        System.assert(!body.contains('Parent/Guardian Information'), 'Adults get no guardian section');
    }

    @isTest
    static void minorWithGuardianGetsGuardianSection() {
        Member__c m = prospect('Jordan', 'Smith', 'jordan.s@email.com');
        m.Date_of_Birth__c = Date.today().addYears(-10);
        m.Guardian_Name__c = 'Lisa Smith';
        update m;
        activate(m);
        String body = EPIC01_MemberOnboarding_Service.welcomeBodiesForTest[0];
        System.assert(body.contains('Parent/Guardian Information'), body);
        System.assert(body.contains('Hi Lisa Smith'), body);
    }

    @isTest
    static void minorWithoutGuardianNameStillGetsSection() {
        Member__c m = prospect('Kid', 'Nameless', 'kid.n@email.com');
        m.Date_of_Birth__c = Date.today().addYears(-12);
        update m;
        activate(m);
        System.assert(EPIC01_MemberOnboarding_Service.welcomeBodiesForTest[0].contains('Parent/Guardian Information'));
    }

    @isTest
    static void welcomeEmailDoesNotFireTwice() {
        Member__c m = prospect('Casey', 'Brooks', 'casey.b@email.com');
        activate(m);
        System.assertEquals(1, [SELECT COUNT() FROM Task WHERE WhatId = :m.Id]);

        m.Status__c = 'Suspended';
        update m;
        m.Status__c = 'Active';
        update m; // second transition to Active
        m.Membership_Tier__c = 'Drop-In ($20/class)';
        update m;

        System.assertEquals(1, [SELECT COUNT() FROM Task WHERE WhatId = :m.Id], 'No duplicate task');
        System.assertEquals(1, EPIC01_MemberOnboarding_Service.welcomeBodiesForTest.size(), 'No duplicate email');
    }

    @isTest
    static void sendFailureCreatesAdminTaskAndKeepsFlagFalse() {
        Member__c m = prospect('Riley', 'Chen', 'riley.chen@email.com');
        EPIC01_MemberOnboarding_Service.simulateWelcomeSendFailure = true;
        activate(m);
        System.assertEquals(false, [SELECT Welcome_Email_Sent__c FROM Member__c WHERE Id = :m.Id].Welcome_Email_Sent__c);
        List<Task> tasks = [SELECT Subject FROM Task WHERE WhatId = :m.Id];
        System.assertEquals(1, tasks.size());
        System.assertEquals('Welcome email failed for Riley Chen — verify email address', tasks[0].Subject);
    }

    @isTest
    static void referredMemberGetsThankYouAndReferrerIsNotified() {
        Member__c sam = [SELECT Id FROM Member__c WHERE Referral_Code__c = 'SAM0KA00'];
        Member__c m = prospect('Maya', 'Referred', 'maya.ref@email.com');
        m.Referred_By__c = sam.Id;
        update m;
        Test.startTest();
        activate(m);
        Integer emails = Limits.getEmailInvocations();
        Test.stopTest();
        System.assert(EPIC01_MemberOnboarding_Service.welcomeBodiesForTest[0].contains('Thanks to Sam Okafor for the referral!'));
        System.assertEquals(2, emails, 'Welcome email plus referrer notification');
    }

    @isTest
    static void waiverReminderCreatesTaskOnceAndSkipsSignedMembers() {
        Member__c unsigned = prospect('Taylor', 'Kim', 'taylor.k@email.com');
        unsigned.Waiver_Needed__c = true;
        update unsigned;
        Member__c signed = prospect('Signed', 'Already', 'signed.a@email.com');
        signed.Waiver_Needed__c = true;
        update signed;
        EPIC01_TestDataFactory.createValidWaiver(signed.Id, locId(), EPIC01_TestDataFactory.createWaiverTemplate().Id);
        Member__c recent = prospect('Too', 'Recent', 'too.r@email.com');
        recent.Waiver_Needed__c = true;
        update recent;

        Test.setCreatedDate(unsigned.Id, Datetime.now().addDays(-8));
        Test.setCreatedDate(signed.Id, Datetime.now().addDays(-8));

        new EPIC01_WaiverReminder_Job().execute(null);
        new EPIC01_WaiverReminder_Job().execute(null); // daily rerun must not duplicate

        System.assertEquals(1, [SELECT COUNT() FROM Task WHERE WhatId = :unsigned.Id AND Subject = 'Waiver reminder for Taylor Kim']);
        System.assertEquals(0, [SELECT COUNT() FROM Task WHERE WhatId = :signed.Id AND Subject LIKE 'Waiver reminder%']);
        System.assertEquals(0, [SELECT COUNT() FROM Task WHERE WhatId = :recent.Id AND Subject LIKE 'Waiver reminder%']);
    }
}
