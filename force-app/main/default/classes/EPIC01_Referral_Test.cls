@isTest
private class EPIC01_Referral_Test {

    private static Franchise_Location__c loc;
    private static Waiver_Template__c tmpl;
    private static Member__c referrer;

    private static void setup() {
        loc = EPIC01_TestDataFactory.createLocation('Referral HQ');
        tmpl = EPIC01_TestDataFactory.createWaiverTemplate();
        referrer = EPIC01_TestDataFactory.createMember('Sam', 'Okafor', loc.Id);
        referrer.Referral_Code__c = 'SAMAB234';
        referrer.Referral_Attempts__c = 0;
        referrer.Membership_Tier__c = 'Punch Card (10 classes - $150)';
        referrer.Classes_Remaining__c = 3;
        update referrer;
    }

    private static Lead__c newLead(String first, String email, String code) {
        return new Lead__c(
            Name = first + '_Lead', First_Name__c = first, Last_Name__c = 'Lead',
            Email__c = email, Franchise_Location__c = loc.Id,
            Lead_Source__c = 'Web Form', Lead_Status__c = 'Qualified',
            Referral_Code_Entered__c = code
        );
    }

    private static Member__c reload(Id id) {
        return [SELECT Referral_Code__c, Referral_Attempts__c, Classes_Remaining__c, Account_Credit__c, Status__c
                FROM Member__c WHERE Id = :id];
    }

    private static Boolean pay(Id memberId, String amount) {
        EPIC01_TestDataFactory.createValidWaiver(memberId, loc.Id, tmpl.Id);
        return EPIC01_MemberOnboarding_Service.processPayment(memberId, amount, 'Credit Card');
    }

    @isTest
    static void activationGeneratesCodeOnceAndKeepsItAfterwards() {
        setup();
        Member__c m = EPIC01_TestDataFactory.createMember('Morgan', 'Reyes', loc.Id);
        m.Status__c = 'Prospect';
        update m;
        System.assertEquals(null, reload(m.Id).Referral_Code__c);

        m.Status__c = 'Active';
        update m;
        Member__c a = reload(m.Id);
        System.assertNotEquals(null, a.Referral_Code__c);
        System.assertEquals(8, a.Referral_Code__c.length());
        System.assert(a.Referral_Code__c.startsWith('MRX'), 'two initials padded to three characters');
        System.assertEquals(0, a.Referral_Attempts__c);

        m.Status__c = 'Suspended';
        update m;
        m.Status__c = 'Active';
        update m;
        System.assertEquals(a.Referral_Code__c, reload(m.Id).Referral_Code__c, 'code must not change on re-activation');
    }

    @isTest
    static void bulkCodeGenerationProducesUniqueCodes() {
        setup();
        List<Member__c> ms = new List<Member__c>();
        for (Integer i = 0; i < 25; i++) {
            ms.add(new Member__c(
                Name = 'Bulk_' + i, First_Name__c = 'Bo', Last_Name__c = 'Lk',
                Email__c = 'bulk' + i + '@email.com', Home_Location__c = loc.Id, Status__c = 'Prospect'
            ));
        }
        insert ms;
        for (Member__c m : ms) { m.Status__c = 'Active'; }
        update ms;
        Set<String> codes = new Set<String>();
        for (Member__c m : [SELECT Referral_Code__c FROM Member__c WHERE Id IN :ms]) {
            System.assertNotEquals(null, m.Referral_Code__c);
            codes.add(m.Referral_Code__c);
        }
        System.assertEquals(25, codes.size(), 'every generated code is unique');
    }

    @isTest
    static void validCodeAttributesLeadCountsAttemptAndOpensReward() {
        setup();
        Lead__c l = newLead('Quinn', 'quinn@email.com', 'SAMAB234');
        insert l;

        Lead__c saved = [SELECT Referred_By__c, Lead_Source__c FROM Lead__c WHERE Id = :l.Id];
        System.assertEquals(referrer.Id, saved.Referred_By__c);
        System.assertEquals('Referral', saved.Lead_Source__c);
        System.assertEquals(1, reload(referrer.Id).Referral_Attempts__c);

        Referral_Reward__c r = [SELECT Status__c, Referring_Member__c, Date_Attributed__c
                                FROM Referral_Reward__c WHERE Referred_Lead__c = :l.Id];
        System.assertEquals('Code Used', r.Status__c);
        System.assertEquals(referrer.Id, r.Referring_Member__c);
        System.assertNotEquals(null, r.Date_Attributed__c);
    }

    @isTest
    static void invalidCodeContinuesWithoutAttributionOrAttempt() {
        setup();
        Lead__c l = newLead('Pat', 'pat@email.com', 'NOPE1234');
        insert l;
        Lead__c saved = [SELECT Referred_By__c, Notes__c FROM Lead__c WHERE Id = :l.Id];
        System.assertEquals(null, saved.Referred_By__c);
        System.assertEquals(EPIC01_Referral_Handler.MSG_NOT_FOUND, saved.Notes__c);
        System.assertEquals(0, reload(referrer.Id).Referral_Attempts__c);
        System.assertEquals(0, [SELECT COUNT() FROM Referral_Reward__c]);
    }

    @isTest
    static void selfReferralIsBlocked() {
        setup();
        Lead__c l = newLead('Sam', referrer.Email__c, 'SAMAB234');
        Database.SaveResult res = Database.insert(l, false);
        System.assertEquals(false, res.isSuccess());
        System.assertEquals(EPIC01_Referral_Handler.MSG_SELF, res.getErrors()[0].getMessage());
        System.assertEquals(0, reload(referrer.Id).Referral_Attempts__c);
    }

    @isTest
    static void existingMemberEmailDropsReferralAndLinksMember() {
        setup();
        Member__c existing = EPIC01_TestDataFactory.createMember('Dana', 'Existing', loc.Id);
        Lead__c l = newLead('Dana', existing.Email__c, 'SAMAB234');
        insert l;
        Lead__c saved = [SELECT Referred_By__c, Converted_Member__c, Notes__c FROM Lead__c WHERE Id = :l.Id];
        System.assertEquals(null, saved.Referred_By__c);
        System.assertEquals(existing.Id, saved.Converted_Member__c);
        System.assert(saved.Notes__c.contains(EPIC01_Referral_Handler.MSG_ALREADY_MEMBER));
        System.assertEquals(0, reload(referrer.Id).Referral_Attempts__c);
        System.assertEquals(0, [SELECT COUNT() FROM Referral_Reward__c]);
    }

    @isTest
    static void fullLifecycleRewardsReferrerExactlyOnce() {
        setup();
        Lead__c l = newLead('Quinn', 'quinn@email.com', 'SAMAB234');
        insert l;

        Member__c member = EPIC01_MemberOnboarding_Service.convertLeadToMember(l.Id);
        Referral_Reward__c r = [SELECT Status__c, Referred_Member__c FROM Referral_Reward__c WHERE Referred_Lead__c = :l.Id];
        System.assertEquals('Member Created', r.Status__c);
        System.assertEquals(member.Id, r.Referred_Member__c);

        update new Member__c(Id = member.Id, Membership_Tier__c = 'Punch Card (10 classes - $150)');
        System.assertEquals(true, pay(member.Id, '75.00'));

        r = [SELECT Status__c, Reward_Type__c, Date_Claimed__c FROM Referral_Reward__c WHERE Referred_Lead__c = :l.Id];
        System.assertEquals('Reward Claimed', r.Status__c);
        System.assertEquals('Class Credit', r.Reward_Type__c);
        System.assertNotEquals(null, r.Date_Claimed__c);
        System.assertEquals(4, reload(referrer.Id).Classes_Remaining__c);

        // Retried / repeated award must not pay twice
        EPIC01_MemberOnboarding_Service.awardReferralReward(referrer.Id, member.Id);
        System.assertEquals(4, reload(referrer.Id).Classes_Remaining__c);
        System.assertEquals(1, [SELECT COUNT() FROM Referral_Reward__c]);
        // The new member is activated, so they get their own code
        System.assertNotEquals(null, reload(member.Id).Referral_Code__c);
    }

    @isTest
    static void unlimitedReferrerGetsAccountCredit() {
        setup();
        referrer.Membership_Tier__c = 'Monthly Unlimited ($129)';
        update referrer;
        Lead__c l = newLead('Quinn', 'quinn@email.com', 'SAMAB234');
        insert l;
        Member__c member = EPIC01_MemberOnboarding_Service.convertLeadToMember(l.Id);
        update new Member__c(Id = member.Id, Membership_Tier__c = 'Punch Card (10 classes - $150)');
        pay(member.Id, '75.00');
        Member__c r = reload(referrer.Id);
        System.assertEquals(10, r.Account_Credit__c);
        System.assertEquals(4, r.Classes_Remaining__c);
        System.assertEquals('Account Credit', [SELECT Reward_Type__c FROM Referral_Reward__c].Reward_Type__c);
    }

    @isTest
    static void deactivatedReferrerKeepsAttributionButEarnsNoReward() {
        setup();
        Lead__c l = newLead('Quinn', 'quinn@email.com', 'SAMAB234');
        insert l;
        Member__c member = EPIC01_MemberOnboarding_Service.convertLeadToMember(l.Id);

        referrer.Status__c = 'Cancelled';
        update referrer;

        update new Member__c(Id = member.Id, Membership_Tier__c = 'Punch Card (10 classes - $150)');
        pay(member.Id, '75.00');

        System.assertEquals('Cancelled', [SELECT Status__c FROM Referral_Reward__c].Status__c);
        System.assertEquals(3, reload(referrer.Id).Classes_Remaining__c, 'no reward for a cancelled referrer');
        System.assertEquals(referrer.Id, [SELECT Referred_By__c FROM Member__c WHERE Id = :member.Id].Referred_By__c);
    }

    @isTest
    static void discountCalculationDoesNotAwardReward() {
        setup();
        Lead__c l = newLead('Quinn', 'quinn@email.com', 'SAMAB234');
        insert l;
        Member__c member = EPIC01_MemberOnboarding_Service.convertLeadToMember(l.Id);
        Decimal amount = EPIC01_MemberOnboarding_Service.calculatePaymentWithReferralDiscount(member.Id, '150.00');
        System.assertEquals(75.00, amount);
        System.assertEquals(3, reload(referrer.Id).Classes_Remaining__c);
        System.assertEquals('Member Created', [SELECT Status__c FROM Referral_Reward__c].Status__c);
    }

    @isTest
    static void unconvertReturnsRewardToCodeUsed() {
        setup();
        Lead__c l = newLead('Quinn', 'quinn@email.com', 'SAMAB234');
        insert l;
        Member__c member = EPIC01_MemberOnboarding_Service.convertLeadToMember(l.Id);
        EPIC01_MemberOnboarding_Service.unconvertMember(member.Id);
        Referral_Reward__c r = [SELECT Status__c, Referred_Member__c FROM Referral_Reward__c WHERE Referred_Lead__c = :l.Id];
        System.assertEquals('Code Used', r.Status__c);
        System.assertEquals(null, r.Referred_Member__c);
    }
}
