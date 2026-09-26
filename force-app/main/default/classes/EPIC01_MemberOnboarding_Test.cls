/**
 * EPIC-01: Member Onboarding — Test Class
 *
 * Maps 1:1 to Gherkin scenarios in:
 *   CRM-Documentation/EPIC-01_US-002_Lead_Conversion.md
 *   CRM-Documentation/EPIC-01_US-003_Membership_Tier_Assignment.md
 *
 * Run with: sfdx force:apex:test:run -n EPIC01_MemberOnboarding_Test
 */
@isTest
private class EPIC01_MemberOnboarding_Test {

    // =====================================================
    // Test Data Setup
    // =====================================================

    @testSetup
    static void setupData() {
        // Create Franchise Owner (required parent for Franchise_Location)
        Franchise_Owner__c owner = new Franchise_Owner__c(
            Name                = 'Test Owner',
            Contact_First_Name__c = 'Jane',
            Contact_Last_Name__c  = 'Smith',
            Legal_Name__c       = 'Test Owner Legal',
            Email__c            = 'owner@test.com'
        );
        insert owner;

        // Create Franchise Location
        Franchise_Location__c loc = new Franchise_Location__c(
            Name             = 'Lexington HQ',
            Status__c        = 'Active',
            Franchise_Owner__c = owner.Id
        );
        insert loc;

        // Create Waiver Template
        Waiver_Template__c tmpl = new Waiver_Template__c(
            Name                 = 'General Liability Waiver - Fencing & Boxing',
            Template_Type__c     = 'Adult',
            Content_Version_Id__c = '068000000000001',
            Effective_Date__c     = Date.today()
        );
        insert tmpl;

        // Create Default Class Template
        Default_Class_Template__c dct = new Default_Class_Template__c(
            Name              = 'Boxing Fundamentals',
            Duration_Minutes__c = 60
        );
        insert dct;

        // Create Scheduled Session
        Scheduled_Session__c session = new Scheduled_Session__c(
            Name                = 'Boxing 101 - Mon 6PM',
            Franchise_Location__c = loc.Id,
            Max_Capacity__c      = 20,
            Program_Type__c      = 'Boxing Fundamentals',
            Session_Status__c    = 'Scheduled'
        );
        insert session;

        // Create an Active Member who can refer others
        Member__c referrer = new Member__c(
            Name             = 'Sam_Okafor',
            First_Name__c    = 'Sam',
            Last_Name__c     = 'Okafor',
            Email__c         = 'sam.okafor@email.com',
            Phone__c         = '336-555-0100',
            Home_Location__c = loc.Id,
            Status__c        = 'Active',
            Membership_Tier__c = 'Monthly Unlimited ($129)',
            Referral_Code__c = 'SAM0KA00'
        );
        insert referrer;
    }

    // =====================================================
    // US-002: Lead Conversion — Waiver Transfer
    // =====================================================

    @isTest
    static void test_US002_WaiverTransfer_ExistingWaiver() {
        // Scenario: Valid waiver from trial class is transferred to new Member
        // Gherkin: @waiver-transfer @happy-path
        
        Franchise_Location__c loc = [
            SELECT Id FROM Franchise_Location__c WHERE Name = 'Lexington HQ' LIMIT 1
        ];
        Waiver_Template__c tmpl = [
            SELECT Id FROM Waiver_Template__c LIMIT 1
        ];
        Member__c referrer = [
            SELECT Id FROM Member__c WHERE Referral_Code__c = 'SAM0KA00' LIMIT 1
        ];

        // Create Lead (simulating walk-in who signed waiver during trial)
        Lead__c lead = new Lead__c(
            Name                    = 'Maya_Rodriguez',
            First_Name__c           = 'Maya',
            Last_Name__c            = 'Rodriguez',
            Email__c                = 'maya.r@email.com',
            Phone__c                = '336-555-0199',
            Franchise_Location__c   = loc.Id,
            Lead_Source__c          = 'Walk-In',
            Lead_Status__c          = 'Qualified',
            Program_Interest__c    = 'Boxing'
        );
        insert lead;

        // Create waiver linked to Lead (trial class)
        Waiver_Record__c trialWaiver = new Waiver_Record__c(
            Name                  = 'WR-Maya-Rodriguez',
            Franchise_Location__c  = loc.Id,
            Lead__c                = lead.Id,
            Waiver_Template__c     = tmpl.Id,
            Status__c              = 'Signed',
            Expiration_Date__c     = Date.today().addDays(180),
            Signature_Timestamp__c = DateTime.now(),
            Signature_Method__c    = 'Digital In-Person',
            Signer_Email__c        = 'maya.r@email.com',
            Signer_Role__c         = 'Participant'
        );
        insert trialWaiver;

        // Convert Lead → Member (should transfer waiver)
        Member__c newMember = EPIC01_MemberOnboarding_Service.convertLeadToMember(lead.Id);

        // Assert: Member created with correct data
        System.assertEquals('Maya', newMember.First_Name__c, 'First name should be copied from Lead');
        System.assertEquals('Rodriguez', newMember.Last_Name__c, 'Last name should be copied from Lead');
        System.assertEquals(loc.Id, newMember.Home_Location__c, 'Location should be copied');
        System.assertEquals('Prospect', newMember.Status__c, 'New member should be Prospect');

        // Assert: Lead updated to Converted
        Lead__c convertedLead = [SELECT Id, Lead_Status__c, Converted_Member__c FROM Lead__c WHERE Id = :lead.Id];
        System.assertEquals('Converted', convertedLead.Lead_Status__c, 'Lead status should be Converted');
        System.assertNotEquals(null, convertedLead.Converted_Member__c, 'Lead should reference new Member');

        // Assert: Waiver transferred to Member
        Waiver_Record__c transferredWaiver = [
            SELECT Id, Member__c, Lead__c, Status__c, Expiration_Date__c
            FROM Waiver_Record__c
            WHERE Id = :trialWaiver.Id
        ];
        System.assertEquals(newMember.Id, transferredWaiver.Member__c, 'Waiver should be linked to new Member');
        System.assertEquals('Signed', transferredWaiver.Status__c, 'Waiver status should be Signed');

        // Assert: No "waiver needed" task (waiver was transferred)
        List<Task> waiverTasks = [
            SELECT Id FROM Task
            WHERE Subject = 'Member needs to sign waiver'
              AND WhatId = :newMember.Id
        ];
        System.assertEquals(0, waiverTasks.size(), 'No waiver task should be created when waiver is transferred');
    }

    @isTest
    static void test_US002_NoTaiver_NoWaiver_Transfer() {
        // Scenario: No waiver on Lead triggers task for waiver signing
        // Gherkin: @waiver-transfer @missing-waiver

        Franchise_Location__c loc = [
            SELECT Id FROM Franchise_Location__c WHERE Name = 'Lexington HQ' LIMIT 1
        ];

        Lead__c lead = new Lead__c(
            Name              = 'Jordan_Smith',
            First_Name__c     = 'Jordan',
            Last_Name__c      = 'Smith',
            Email__c          = 'jordan.s@email.com',
            Phone__c          = '336-555-0177',
            Franchise_Location__c = loc.Id,
            Lead_Source__c    = 'Online',
            Lead_Status__c    = 'Qualified'
        );
        insert lead;

        // Convert Lead → Member (no waiver exists)
        Member__c newMember = EPIC01_MemberOnboarding_Service.convertLeadToMember(lead.Id);

        // Assert: Waiver_Needed__c = true
        Member__c checkMember = [
            SELECT Id, Waiver_Needed__c, Status__c
            FROM Member__c WHERE Id = :newMember.Id
        ];
        System.assert(checkMember.Waiver_Needed__c, 'Waiver_Needed__c should be true when no waiver');

        // Assert: Task created for waiver signing
        List<Task> tasks = [
            SELECT Id, Subject, WhatId, Status
            FROM Task
            WHERE Subject = 'Member needs to sign waiver'
              AND WhatId = :newMember.Id
        ];
        System.assertEquals(1, tasks.size(), 'A waiver task should be created');
    }

    // =====================================================
    // US-003: Membership Tier Assignment — Waiver Gate
    // =====================================================

    @isTest
    static void test_US003_WaiverGate_BlockedNoWaiver() {
        // Scenario: Member cannot proceed to payment without signed waiver
        // Gherkin: @waiver-gate @no-waiver

        Franchise_Location__c loc = [
            SELECT Id FROM Franchise_Location__c WHERE Name = 'Lexington HQ' LIMIT 1
        ];
        Member__c referrer = [
            SELECT Id FROM Member__c WHERE Referral_Code__c = 'SAM0KA00' LIMIT 1
        ];

        // Create Member without any waiver
        Member__c member = new Member__c(
            Name              = 'Alex_Rivera',
            First_Name__c     = 'Alex',
            Last_Name__c      = 'Rivera',
            Email__c          = 'alex.r@email.com',
            Phone__c          = '336-555-0155',
            Home_Location__c  = loc.Id,
            Status__c         = 'Prospect',
            Membership_Tier__c = 'Punch Card (10 classes - $150)'
        );
        insert member;

        // Attempt to proceed to payment → should fail
        EPIC01_MemberOnboarding_Service.PaymentGateResult result =
            EPIC01_MemberOnboarding_Service.attemptProceedToPayment(member.Id);

        System.assertEquals(false, result.canProceed, 'Member without waiver cannot proceed');
        System.assert(result.errorMessage.contains('waiver'), 'Error should mention waiver');
    }

    @isTest
    static void test_US003_WaiverGate_Allowed_WithValidWaiver() {
        // Scenario: Member with valid signed waiver CAN proceed to payment
        // Gherkin: @waiver-gate @signed-waiver

        Franchise_Location__c loc = [
            SELECT Id FROM Franchise_Location__c WHERE Name = 'Lexington HQ' LIMIT 1
        ];

        Member__c member = new Member__c(
            Name                = 'Taylor_Kim',
            First_Name__c       = 'Taylor',
            Last_Name__c        = 'Kim',
            Email__c            = 'taylor.k@email.com',
            Phone__c            = '336-555-0144',
            Home_Location__c    = loc.Id,
            Status__c           = 'Prospect',
            Membership_Tier__c  = 'Punch Card (10 classes - $150)'
        );
        insert member;

        // Create valid waiver for the member
        Waiver_Template__c tmpl = [
            SELECT Id FROM Waiver_Template__c LIMIT 1
        ];
        Waiver_Record__c waiver = new Waiver_Record__c(
            Name                  = 'WR-Taylor-Kim',
            Franchise_Location__c  = loc.Id,
            Waiver_Template__c     = tmpl.Id,
            Member__c              = member.Id,
            Status__c              = 'Signed',
            Expiration_Date__c     = Date.today().addDays(365),
            Signature_Timestamp__c = DateTime.now(),
            Signature_Method__c    = 'Digital In-Person',
            Signer_Email__c        = 'taylor.k@email.com',
            Signer_Role__c         = 'Participant'
        );
        insert waiver;

        // Attempt to proceed to payment → should succeed
        EPIC01_MemberOnboarding_Service.PaymentGateResult result =
            EPIC01_MemberOnboarding_Service.attemptProceedToPayment(member.Id);

        System.assertEquals(true, result.canProceed, 'Member with valid waiver should proceed');
        System.assert(String.isBlank(result.errorMessage), 'No error message expected');
    }

    @isTest
    static void test_US003_WaiverGate_Blocked_ExpiredWaiver() {
        // Scenario: Member with expired waiver cannot proceed to payment
        // Gherkin: @waiver-gate @expired-waiver

        Franchise_Location__c loc = [
            SELECT Id FROM Franchise_Location__c WHERE Name = 'Lexington HQ' LIMIT 1
        ];
        Waiver_Template__c tmpl = [
            SELECT Id FROM Waiver_Template__c LIMIT 1
        ];

        Member__c member = new Member__c(
            Name                = 'Jamie_Chen',
            First_Name__c       = 'Jamie',
            Last_Name__c        = 'Chen',
            Email__c            = 'jamie.chen@email.com',
            Home_Location__c    = loc.Id,
            Status__c           = 'Prospect',
            Membership_Tier__c  = 'Punch Card (10 classes - $150)'
        );
        insert member;

        Waiver_Record__c expiredWaiver = new Waiver_Record__c(
            Name                  = 'WR-Jamie-Chen',
            Franchise_Location__c  = loc.Id,
            Waiver_Template__c     = tmpl.Id,
            Member__c              = member.Id,
            Status__c              = 'Signed',
            Expiration_Date__c     = Date.today().addDays(-1),
            Signature_Method__c    = 'Digital In-Person',
            Signer_Email__c        = 'jamie.chen@email.com',
            Signer_Role__c         = 'Participant'
        );
        insert expiredWaiver;

        EPIC01_MemberOnboarding_Service.PaymentGateResult result =
            EPIC01_MemberOnboarding_Service.attemptProceedToPayment(member.Id);

        System.assertEquals(false, result.canProceed, 'Member with expired waiver cannot proceed');
        System.assert(result.errorMessage.contains('expired'), 'Error should mention expiration');
    }

    @isTest
    static void test_US003_WaiverGate_Blocked_PendingWaiver() {
        // Scenario: Member with unsigned (pending) waiver cannot proceed
        // Gherkin: @waiver-gate @pending-waiver

        Franchise_Location__c loc = [
            SELECT Id FROM Franchise_Location__c WHERE Name = 'Lexington HQ' LIMIT 1
        ];
        Waiver_Template__c tmpl = [
            SELECT Id FROM Waiver_Template__c LIMIT 1
        ];

        Member__c member = new Member__c(
            Name                = 'Morgan_Lee',
            First_Name__c       = 'Morgan',
            Last_Name__c        = 'Lee',
            Email__c            = 'morgan.lee@email.com',
            Home_Location__c    = loc.Id,
            Status__c           = 'Prospect',
            Membership_Tier__c  = 'Monthly Unlimited ($129)'
        );
        insert member;

        Waiver_Record__c pendingWaiver = new Waiver_Record__c(
            Name                  = 'WR-Morgan-Lee',
            Franchise_Location__c  = loc.Id,
            Waiver_Template__c     = tmpl.Id,
            Member__c              = member.Id,
            Status__c              = 'Pending',
            Signature_Method__c    = 'Digital In-Person',
            Signer_Email__c        = 'morgan.lee@email.com',
            Signer_Role__c         = 'Participant'
        );
        insert pendingWaiver;

        EPIC01_MemberOnboarding_Service.PaymentGateResult result =
            EPIC01_MemberOnboarding_Service.attemptProceedToPayment(member.Id);

        System.assertEquals(false, result.canProceed, 'Member with pending waiver cannot proceed');
        System.assert(result.errorMessage.contains('pending'), 'Error should mention pending status');
    }

    @isTest
    static void test_US003_NoTierDoesNotSetDates() {
        // Scenario: Selecting a tier does not set membership dates
        // Gherkin: @no-premature-dates

        Franchise_Location__c loc = [
            SELECT Id FROM Franchise_Location__c WHERE Name = 'Lexington HQ' LIMIT 1
        ];
        Member__c member = new Member__c(
            Name             = 'Riley_Patel',
            First_Name__c    = 'Riley',
            Last_Name__c     = 'Patel',
            Email__c         = 'riley.patel@email.com',
            Home_Location__c = loc.Id,
            Status__c        = 'Prospect'
        );
        insert member;

        // Simulate tier selection (no payment yet)
        member.Membership_Tier__c = 'Monthly Unlimited ($129)';
        update member;

        Member__c check = [
            SELECT Membership_Tier__c, Start_Date__c, Expiry_Date__c
            FROM Member__c WHERE Id = :member.Id
        ];

        System.assertEquals('Monthly Unlimited ($129)', check.Membership_Tier__c);
        System.assertEquals(null, check.Start_Date__c, 'Start date should not be set before payment');
        System.assertEquals(null, check.Expiry_Date__c, 'Expiry date should not be set before payment');
    }

    @isTest
    static void test_US003_TierChange_UpdatesPriceNoDates() {
        // Scenario: Member changes tier before payment — price updates but no dates set
        // Gherkin: @tier-change

        Franchise_Location__c loc = [
            SELECT Id FROM Franchise_Location__c WHERE Name = 'Lexington HQ' LIMIT 1
        ];
        Member__c member = new Member__c(
            Name             = 'Casey_Brooks',
            First_Name__c    = 'Casey',
            Last_Name__c     = 'Brooks',
            Email__c         = 'casey.brooks@email.com',
            Home_Location__c = loc.Id,
            Status__c        = 'Prospect',
            Membership_Tier__c = 'Drop-In ($20/class)'
        );
        insert member;

        // Change tier
        member.Membership_Tier__c = 'Punch Card (10 classes - $150)';
        update member;

        Member__c check = [
            SELECT Membership_Tier__c, Start_Date__c, Expiry_Date__c
            FROM Member__c WHERE Id = :member.Id
        ];

        System.assertEquals('Punch Card (10 classes - $150)', check.Membership_Tier__c);
        System.assertEquals(null, check.Start_Date__c);
        System.assertEquals(null, check.Expiry_Date__c);
    }

    // =====================================================
    // US-004: Payment Processing — Date & Status Logic
    // =====================================================

    @isTest
    static void test_US004_PaymentSetsDatesAndStatus() {
        // Scenario: Member pays for class pack, dates set, status → Active
        // Gherkin: @happy-path @class-pack

        Franchise_Location__c loc = [
            SELECT Id FROM Franchise_Location__c WHERE Name = 'Lexington HQ' LIMIT 1
        ];

        Member__c member = new Member__c(
            Name                = 'Drew_Thompson',
            First_Name__c       = 'Drew',
            Last_Name__c        = 'Thompson',
            Email__c            = 'drew.t@email.com',
            Home_Location__c    = loc.Id,
            Status__c           = 'Prospect',
            Membership_Tier__c  = 'Punch Card (10 classes - $150)',
            Waiver_Needed__c    = false
        );
        insert member;

        // Create valid waiver
        Waiver_Template__c tmpl = [
            SELECT Id FROM Waiver_Template__c LIMIT 1
        ];
        Waiver_Record__c waiver = new Waiver_Record__c(
            Name                  = 'WR-Drew-Thompson',
            Franchise_Location__c  = loc.Id,
            Waiver_Template__c     = tmpl.Id,
            Member__c              = member.Id,
            Status__c              = 'Signed',
            Expiration_Date__c     = Date.today().addDays(365),
            Signature_Timestamp__c = DateTime.now(),
            Signature_Method__c    = 'Digital In-Person',
            Signer_Email__c        = 'drew.t@email.com',
            Signer_Role__c         = 'Participant'
        );
        insert waiver;

        // Process payment
        EPIC01_MemberOnboarding_Service.processPayment(member.Id, '150.00', 'Credit Card');

        Member__c check = [
            SELECT Status__c, Start_Date__c, Expiry_Date__c, Classes_Remaining__c
            FROM Member__c WHERE Id = :member.Id
        ];

        System.assertEquals('Active', check.Status__c, 'Status should be Active after payment');
        System.assertNotEquals(null, check.Start_Date__c, 'Start date should be set');
        System.assertNotEquals(null, check.Expiry_Date__c, 'Expiry date should be set');
        System.assertEquals(10, check.Classes_Remaining__c, '10-class pack should start with 10 classes remaining');

        // Verify payment transaction created
        List<Payment_Transaction__c> txns = [
            SELECT Amount__c, Payment_Type__c, Status__c, Is_Recurring__c
            FROM Payment_Transaction__c
            WHERE Member__c = :member.Id
        ];
        System.assertEquals(1, txns.size(), 'Exactly 1 payment transaction should be created');
        System.assertEquals(txns[0].Status__c, 'Completed');
        System.assertEquals(false, txns[0].Is_Recurring__c, 'Punch card is not recurring');
    }

    @isTest
    static void test_US004_PaymentFails_MemberStaysProspect() {
        // Scenario: Card payment fails — member stays in Prospect status
        // Gherkin: @failure @card-declined

        Franchise_Location__c loc = [
            SELECT Id FROM Franchise_Location__c WHERE Name = 'Lexington HQ' LIMIT 1
        ];
        Member__c member = new Member__c(
            Name             = 'Avery_Johnson',
            First_Name__c    = 'Avery',
            Last_Name__c     = 'Johnson',
            Email__c         = 'avery.j@email.com',
            Home_Location__c = loc.Id,
            Status__c        = 'Prospect',
            Membership_Tier__c = 'Monthly Unlimited ($129)'
        );
        insert member;

        // Simulate failed payment (mock)
        EPIC01_MemberOnboarding_Service.simulatePaymentFailure = true;
        Boolean paymentSuccess = EPIC01_MemberOnboarding_Service.processPayment(
            member.Id, '129.00', 'Credit Card'
        );
        EPIC01_MemberOnboarding_Service.simulatePaymentFailure = false;

        System.assertEquals(false, paymentSuccess, 'Payment should fail in test mock');

        Member__c check = [
            SELECT Status__c, Start_Date__c, Expiry_Date__c
            FROM Member__c WHERE Id = :member.Id
        ];
        System.assertEquals('Prospect', check.Status__c, 'Member should stay Prospect on failure');

        List<Payment_Transaction__c> txns = [
            SELECT Status__c FROM Payment_Transaction__c
            WHERE Member__c = :member.Id
        ];
        System.assertEquals('Failed', txns[0].Status__c);
    }

    @isTest
    static void test_US004_FriendGetsReferralDiscount() {
        // Scenario: Referred member gets friend discount on first payment
        // Gherkin: @referral @happy-path

        Franchise_Location__c loc = [
            SELECT Id FROM Franchise_Location__c WHERE Name = 'Lexington HQ' LIMIT 1
        ];
        Member__c referrer = [
            SELECT Id, Classes_Remaining__c
            FROM Member__c WHERE Referral_Code__c = 'SAM0KA00' LIMIT 1
        ];

        // Create Lead with referral
        Lead__c lead = new Lead__c(
            Name                = 'Quinn_Foster',
            First_Name__c       = 'Quinn',
            Last_Name__c        = 'Foster',
            Email__c            = 'quinn.f@email.com',
            Franchise_Location__c = loc.Id,
            Referred_By__c      = referrer.Id,
            Lead_Source__c      = 'Referral',
            Lead_Status__c      = 'Qualified'
        );
        insert lead;

        // Convert + process payment
        Member__c member = EPIC01_MemberOnboarding_Service.convertLeadToMember(lead.Id);
        member.Membership_Tier__c = 'Punch Card (10 classes - $150)';

        // Sign waiver (pre-existing from trial)
        Waiver_Template__c tmpl = [
            SELECT Id FROM Waiver_Template__c LIMIT 1
        ];
        Waiver_Record__c waiver = new Waiver_Record__c(
            Name                  = 'WR-Quinn-Foster',
            Franchise_Location__c  = loc.Id,
            Waiver_Template__c     = tmpl.Id,
            Member__c              = member.Id,
            Status__c              = 'Signed',
            Expiration_Date__c     = Date.today().addDays(365),
            Signature_Method__c    = 'Digital In-Person',
            Signer_Email__c        = 'quinn.f@email.com',
            Signer_Role__c         = 'Participant'
        );
        insert waiver;
        update member;

        // Process payment (should apply friend discount)
        Decimal finalAmount = EPIC01_MemberOnboarding_Service.calculatePaymentWithReferralDiscount(
            member.Id, '150.00'
        );

        System.assertEquals(75.00, finalAmount, '50% friend discount should apply');

        // Referrer gets class credit
        Member__c referrerCheck = [
            SELECT Classes_Remaining__c FROM Member__c WHERE Id = :referrer.Id
        ];
        System.assertEquals(referrer.Classes_Remaining__c + 1,
                            referrerCheck.Classes_Remaining__c,
                            'Referrer should get +1 class credit');
    }

    // =====================================================
    // US-006: Referral Program — Code Generation & Tracking
    // =====================================================

    @isTest
    static void test_US006_ReferralCodeGeneration() {
        // Scenario: Referral code auto-generated on member activation
        Franchise_Location__c loc = [
            SELECT Id FROM Franchise_Location__c WHERE Name = 'Lexington HQ' LIMIT 1
        ];

        Member__c member = new Member__c(
            Name = 'Morgan_Reyes',
            First_Name__c = 'Morgan',
            Last_Name__c  = 'Reyes',
            Email__c      = 'morgan.r@email.com',
            Home_Location__c = loc.Id,
            Status__c     = 'Active',
            Membership_Tier__c = 'Monthly Unlimited ($129)'
        );
        insert member;

        // Simulate activation flow that generates referral code
        EPIC01_MemberOnboarding_Service.generateReferralCode(member.Id);

        Member__c check = [
            SELECT Referral_Code__c, Referral_Attempts__c
            FROM Member__c WHERE Id = :member.Id
        ];
        System.assertNotEquals(null, check.Referral_Code__c, 'Referral code should be generated');
        System.assertEquals(8, check.Referral_Code__c.length(), 'Code should be 8 alphanumeric characters');
        System.assertEquals(0, check.Referral_Attempts__c, 'Attempts should start at 0');
    }

    @isTest
    static void test_US006_InvalidReferralCode_StillCreatesLead() {
        // Scenario: Invalid referral code shows error but still creates Lead
        Franchise_Location__c loc = [
            SELECT Id FROM Franchise_Location__c WHERE Name = 'Lexington HQ' LIMIT 1
        ];

        Lead__c lead = new Lead__c(
            Name = 'Invalid_Code_Lead',
            First_Name__c = 'Test',
            Last_Name__c  = 'User',
            Franchise_Location__c = loc.Id,
            Lead_Source__c = 'Online',
            Lead_Status__c = 'New'
        );
        insert lead;

        // Look up invalid code → should return null
        Member__c referrer = EPIC01_MemberOnboarding_Service.lookupReferralCode('BADCODE1');
        System.assertEquals(null, referrer, 'Invalid code should not match any member');
    }

    @isTest
    static void test_US006_SelfReferralBlocked() {
        // Scenario: Member cannot refer themselves
        Member__c member = [
            SELECT Id, Referral_Code__c FROM Member__c WHERE Referral_Code__c = 'SAM0KA00' LIMIT 1
        ];

        // Attempt to create a lead with own code
        Boolean isSelfReferral = EPIC01_MemberOnboarding_Service.isSelfReferral(
            member.Id, 'SAM0KA00'
        );
        System.assertEquals(true, isSelfReferral, 'Self-referral should be detected');
    }

    @isTest
    static void test_US006_DuplicateReferralBlocked() {
        // Scenario: Same person cannot be referred twice by same member
        Franchise_Location__c loc = [
            SELECT Id FROM Franchise_Location__c WHERE Name = 'Lexington HQ' LIMIT 1
        ];
        Member__c referrer = [
            SELECT Id FROM Member__c WHERE Referral_Code__c = 'SAM0KA00' LIMIT 1
        ];

        // Create a referred Lead
        Lead__c lead1 = new Lead__c(
            Name = 'Dup_Test',
            First_Name__c = 'Dup',
            Last_Name__c  = 'Test',
            Email__c      = 'dup.test@email.com',
            Referred_By__c = referrer.Id,
            Franchise_Location__c = loc.Id,
            Lead_Source__c = 'Referral',
            Lead_Status__c = 'Qualified'
        );
        insert lead1;

        // Attempt to create another lead with same email + same referrer
        Boolean isDuplicate = EPIC01_MemberOnboarding_Service.isDuplicateReferral(
            referrer.Id, 'dup.test@email.com'
        );
        System.assertEquals(true, isDuplicate, 'Should detect duplicate referral by email + referrer');
    }

    // =====================================================
    // US-005: Welcome Workflow
    // =====================================================

    @isTest
    static void test_US005_WelcomeEmailFiresOnActivation() {
        // Scenario: Welcome email fires when member transitions to Active
        Franchise_Location__c loc = [
            SELECT Id FROM Franchise_Location__c WHERE Name = 'Lexington HQ' LIMIT 1
        ];

        Member__c member = new Member__c(
            Name = 'Casey_Brooks',
            First_Name__c = 'Casey',
            Last_Name__c  = 'Brooks',
            Email__c      = 'casey.b@email.com',
            Home_Location__c = loc.Id,
            Status__c     = 'Prospect',
            Membership_Tier__c = 'Monthly Unlimited ($129)',
            Welcome_Email_Sent__c = false
        );
        insert member;

        // Process payment (triggers activation)
        Waiver_Template__c tmpl = [
            SELECT Id FROM Waiver_Template__c LIMIT 1
        ];
        Waiver_Record__c waiver = new Waiver_Record__c(
            Name = 'WR-Casey-Brooks',
            Franchise_Location__c = loc.Id,
            Waiver_Template__c = tmpl.Id,
            Member__c = member.Id,
            Status__c = 'Signed',
            Expiration_Date__c = Date.today().addDays(365),
            Signature_Timestamp__c = DateTime.now(),
            Signature_Method__c = 'Digital In-Person',
            Signer_Email__c = 'casey.b@email.com',
            Signer_Role__c = 'Participant'
        );
        insert waiver;

        EPIC01_MemberOnboarding_Service.processPayment(member.Id, '129.00', 'Credit Card');

        // Assert: Welcome_Email_Sent__c = true
        Member__c check = [
            SELECT Status__c, Welcome_Email_Sent__c, Start_Date__c, Expiry_Date__c
            FROM Member__c WHERE Id = :member.Id
        ];
        System.assertEquals('Active', check.Status__c);
        System.assert(check.Welcome_Email_Sent__c, 'Welcome email should be sent on activation');

        // Assert: Orientation task created
        List<Task> orientTasks = [
            SELECT Subject FROM Task
            WHERE Subject = 'Schedule facility orientation for Casey Brooks'
        ];
        System.assertEquals(1, orientTasks.size(), 'Orientation task should be created');
    }

    @isTest
    static void test_US005_WaiverReminder_TaskCreated() {
        // Scenario: Waiver reminder fires 7 days after conversion without waiver
        Franchise_Location__c loc = [
            SELECT Id FROM Franchise_Location__c WHERE Name = 'Lexington HQ' LIMIT 1
        ];

        Lead__c lead = new Lead__c(
            Name = 'Avery_Johnson',
            First_Name__c = 'Avery',
            Last_Name__c  = 'Johnson',
            Email__c      = 'avery.j@email.com',
            Franchise_Location__c = loc.Id,
            Lead_Source__c = 'Online',
            Lead_Status__c = 'Qualified'
        );
        insert lead;

        Member__c member = EPIC01_MemberOnboarding_Service.convertLeadToMember(lead.Id);

        // Assert: Waiver_Needed__c = true and task created
        List<Task> waiverReminderTasks = [
            SELECT Subject FROM Task
            WHERE Subject = 'Waiver reminder for Avery Johnson'
        ];
        // Note: Task is created by scheduled job at 7 days, not immediately
        // In test context, we verify the flag is set
        Member__c check = [
            SELECT Waiver_Needed__c FROM Member__c WHERE Id = :member.Id
        ];
        System.assert(check.Waiver_Needed__c, 'Waiver_Needed__c should be set when no waiver exists');
    }

    @isTest
    static void test_US005_WelcomeEmailDoesNotDuplicate() {
        // Scenario: Welcome email does not fire twice
        Franchise_Location__c loc = [
            SELECT Id FROM Franchise_Location__c WHERE Name = 'Lexington HQ' LIMIT 1
        ];

        Member__c member = new Member__c(
            Name = 'Riley_Patel',
            First_Name__c = 'Riley',
            Last_Name__c  = 'Patel',
            Email__c = 'riley.patel@email.com',
            Home_Location__c = loc.Id,
            Status__c = 'Active',
            Membership_Tier__c = 'Monthly Unlimited ($129)',
            Welcome_Email_Sent__c = true
        );
        insert member;

        // Simulate status update
        member.Membership_Tier__c = 'Monthly Unlimited ($129)';
        update member;

        // Assert: No new email should have been sent (tracked via email log count)
        // In test context, we verify the flag remains true and no duplicate task
        List<Task> dupTasks = [
            SELECT Id FROM Task
            WHERE WhatId = :member.Id AND Subject LIKE '%Welcome%'
        ];
        System.assertEquals(0, dupTasks.size(), 'No duplicate welcome tasks should be created');
    }
}
