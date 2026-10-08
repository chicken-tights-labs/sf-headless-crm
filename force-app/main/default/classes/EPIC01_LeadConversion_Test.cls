/**
 * EPIC01-US-002: Lead Conversion — maps to the Gherkin scenarios in issue #20.
 * (Waiver transfer scenarios are also covered in EPIC01_MemberOnboarding_Test.)
 */
@isTest
private class EPIC01_LeadConversion_Test {

    @testSetup
    static void setupData() {
        Franchise_Owner__c owner = new Franchise_Owner__c(
            Name = 'Test Owner', Contact_First_Name__c = 'Jane', Contact_Last_Name__c = 'Smith',
            Legal_Name__c = 'Test Owner Legal', Email__c = 'owner@test.com'
        );
        insert owner;
        insert new List<Franchise_Location__c>{
            new Franchise_Location__c(Name = 'Lexington HQ', Status__c = 'Active', Franchise_Owner__c = owner.Id),
            new Franchise_Location__c(Name = 'Winston-Salem Annex', Status__c = 'Active', Franchise_Owner__c = owner.Id)
        };
        insert new Member__c(
            Name = 'Sam_Okafor', First_Name__c = 'Sam', Last_Name__c = 'Okafor',
            Email__c = 'sam.okafor@email.com', Phone__c = '336-555-0100',
            Home_Location__c = [SELECT Id FROM Franchise_Location__c WHERE Name = 'Lexington HQ'].Id,
            Status__c = 'Active', Referral_Code__c = 'SAM0KA00'
        );
    }

    private static Id loc(String name) {
        return [SELECT Id FROM Franchise_Location__c WHERE Name = :name].Id;
    }

    private static Lead__c makeLead(String first, String last, String email, String status, String locName) {
        Lead__c l = new Lead__c(
            Name = first + '_' + last, First_Name__c = first, Last_Name__c = last,
            Email__c = email, Phone__c = '336-555-0199', Lead_Status__c = status,
            Lead_Source__c = 'Web Form', Program_Interest__c = 'Fencing',
            Franchise_Location__c = loc(locName)
        );
        insert l;
        return l;
    }

    private static String convertError(Id leadId) {
        try {
            EPIC01_MemberOnboarding_Service.convertLeadToMember(leadId);
            return null;
        } catch (EPIC01_MemberOnboarding_Service.ConversionException e) {
            return e.getMessage();
        }
    }

    @isTest
    static void qualifiedLeadConvertsWithAllFields() {
        Lead__c lead = makeLead('Maya', 'Rodriguez', 'maya.r@email.com', 'Qualified', 'Winston-Salem Annex');

        Test.startTest();
        Member__c m = EPIC01_MemberOnboarding_Service.convertLeadToMember(lead.Id);
        Test.stopTest();

        Member__c saved = [
            SELECT First_Name__c, Last_Name__c, Email__c, Phone__c, Home_Location__r.Name, Status__c,
                   Membership_Tier__c, Original_Lead__c, Program_Interest__c, Lead_Source__c
            FROM Member__c WHERE Id = :m.Id
        ];
        System.assertEquals('Maya', saved.First_Name__c);
        System.assertEquals('maya.r@email.com', saved.Email__c);
        System.assertEquals('336-555-0199', saved.Phone__c);
        System.assertEquals('Winston-Salem Annex', saved.Home_Location__r.Name);
        System.assertEquals('Prospect', saved.Status__c);
        System.assertEquals(null, saved.Membership_Tier__c);
        System.assertEquals(lead.Id, saved.Original_Lead__c);
        System.assertEquals('Fencing', saved.Program_Interest__c);
        System.assertEquals('Web Form', saved.Lead_Source__c);

        Lead__c l = [SELECT Lead_Status__c, Converted_Member__c FROM Lead__c WHERE Id = :lead.Id];
        System.assertEquals('Converted', l.Lead_Status__c);
        System.assertEquals(m.Id, l.Converted_Member__c);

        System.assertEquals(1, [SELECT COUNT() FROM Task
            WHERE WhatId = :m.Id AND Subject = 'Schedule first class for Maya Rodriguez']);
    }

    @isTest
    static void referredLeadCarriesReferrerAndTriggersNotification() {
        Member__c sam = [SELECT Id FROM Member__c WHERE Referral_Code__c = 'SAM0KA00'];
        Lead__c lead = makeLead('Jordan', 'Smith', 'jordan.s@email.com', 'Qualified', 'Lexington HQ');
        lead.Referred_By__c = sam.Id;
        update lead;

        Test.startTest();
        Member__c m = EPIC01_MemberOnboarding_Service.convertLeadToMember(lead.Id);
        Integer emails = Limits.getEmailInvocations();
        Test.stopTest();

        System.assertEquals(sam.Id, [SELECT Referred_By__c FROM Member__c WHERE Id = :m.Id].Referred_By__c);
        System.assertEquals(1, emails, 'Referrer should be emailed');
    }

    @isTest
    static void alreadyConvertedLeadIsRejected() {
        Lead__c lead = makeLead('Alex', 'Rivera', 'alex.r@email.com', 'Converted', 'Lexington HQ');
        System.assertEquals('Lead already converted to Member — view linked Member record', convertError(lead.Id));
    }

    @isTest
    static void disqualifiedLeadIsRejected() {
        Lead__c lead = makeLead('Taylor', 'Kim', 'taylor.k@email.com', 'Unqualified', 'Lexington HQ');
        System.assertEquals('Cannot convert disqualified lead — change status to Qualified first', convertError(lead.Id));
    }

    @isTest
    static void leadWithExistingMemberIsRejected() {
        Member__c sam = [SELECT Id FROM Member__c WHERE Referral_Code__c = 'SAM0KA00'];
        Lead__c lead = makeLead('Sam', 'Lee', 'sam.lee@email.com', 'Converted', 'Lexington HQ');
        lead.Converted_Member__c = sam.Id;
        update lead;
        System.assertEquals('Member already exists for this lead — view existing Member record', convertError(lead.Id));
    }

    @isTest
    static void noWaiverCreatesGatedTaskAndFlag() {
        Lead__c lead = makeLead('Jordan', 'Lane', 'jordan.l@email.com', 'Qualified', 'Lexington HQ');
        Member__c m = EPIC01_MemberOnboarding_Service.convertLeadToMember(lead.Id);
        System.assertEquals(true, [SELECT Waiver_Needed__c FROM Member__c WHERE Id = :m.Id].Waiver_Needed__c);
        System.assertEquals(1, [SELECT COUNT() FROM Task
            WHERE WhatId = :m.Id AND Subject = 'Member needs to sign waiver before payment']);
    }

    @isTest
    static void invocableReturnsGuardMessageInsteadOfThrowing() {
        Lead__c lead = makeLead('Alex', 'Rivera', 'alex.r@email.com', 'Converted', 'Lexington HQ');
        EPIC01_LeadConversion_Action.Request req = new EPIC01_LeadConversion_Action.Request();
        req.leadId = lead.Id;
        List<EPIC01_LeadConversion_Action.Result> res = EPIC01_LeadConversion_Action.convert(
            new List<EPIC01_LeadConversion_Action.Request>{ req });
        System.assertEquals(false, res[0].success);
        System.assertEquals('Lead already converted to Member — view linked Member record', res[0].message);
    }

    @isTest
    static void unconvertRestoresLeadAndDeletesMember() {
        Franchise_Location__c l = [SELECT Id FROM Franchise_Location__c WHERE Name = 'Lexington HQ'];
        Lead__c lead = makeLead('Maya', 'Unconvert', 'maya.u@email.com', 'Qualified', 'Lexington HQ');
        Waiver_Template__c tmpl = new Waiver_Template__c(
            Name = 'General Liability', Template_Type__c = 'Adult',
            Content_Version_Id__c = '068000000000001', Effective_Date__c = Date.today()
        );
        insert tmpl;
        insert new Waiver_Record__c(
            Name = 'WR-U', Franchise_Location__c = l.Id, Lead__c = lead.Id, Waiver_Template__c = tmpl.Id,
            Status__c = 'Signed', Expiration_Date__c = Date.today().addDays(90),
            Signature_Timestamp__c = DateTime.now(), Signature_Method__c = 'Digital In-Person',
            Signer_Email__c = 'maya.u@email.com', Signer_Role__c = 'Participant'
        );
        Member__c m = EPIC01_MemberOnboarding_Service.convertLeadToMember(lead.Id);

        EPIC01_MemberUnconvert_Action.Request req = new EPIC01_MemberUnconvert_Action.Request();
        req.memberId = m.Id;
        List<EPIC01_MemberUnconvert_Action.Result> res = EPIC01_MemberUnconvert_Action.unconvert(
            new List<EPIC01_MemberUnconvert_Action.Request>{ req });

        System.assertEquals(true, res[0].success, res[0].message);
        System.assertEquals(0, [SELECT COUNT() FROM Member__c WHERE Id = :m.Id]);
        Lead__c restored = [SELECT Lead_Status__c, Converted_Member__c FROM Lead__c WHERE Id = :lead.Id];
        System.assertEquals('Qualified', restored.Lead_Status__c);
        System.assertEquals(null, restored.Converted_Member__c);
        System.assertEquals(null, [SELECT Member__c FROM Waiver_Record__c WHERE Lead__c = :lead.Id].Member__c);
    }

    @isTest
    static void unconvertActionReturnsMessageInsteadOfThrowing() {
        Member__c sam = [SELECT Id FROM Member__c WHERE Referral_Code__c = 'SAM0KA00'];
        EPIC01_MemberUnconvert_Action.Request req = new EPIC01_MemberUnconvert_Action.Request();
        req.memberId = sam.Id;
        List<EPIC01_MemberUnconvert_Action.Result> res = EPIC01_MemberUnconvert_Action.unconvert(
            new List<EPIC01_MemberUnconvert_Action.Request>{ req });
        System.assertEquals(false, res[0].success);
        System.assert(res[0].message.contains('not created from a Lead'), res[0].message);
        System.assertEquals(1, [SELECT COUNT() FROM Member__c WHERE Id = :sam.Id], 'Member must not be deleted');
    }

    @isTest
    static void convertActionSucceedsAndReturnsMemberId() {
        Lead__c lead = makeLead('Pat', 'Ok', 'pat.ok@email.com', 'Qualified', 'Lexington HQ');
        EPIC01_LeadConversion_Action.Request req = new EPIC01_LeadConversion_Action.Request();
        req.leadId = lead.Id;
        List<EPIC01_LeadConversion_Action.Result> res = EPIC01_LeadConversion_Action.convert(
            new List<EPIC01_LeadConversion_Action.Request>{ req });
        System.assertEquals(true, res[0].success, res[0].message);
        System.assertNotEquals(null, res[0].memberId);
    }

    @isTest
    static void unconvertRefusesActiveMember() {
        Member__c sam = [SELECT Id, Original_Lead__c FROM Member__c WHERE Referral_Code__c = 'SAM0KA00'];
        Lead__c lead = makeLead('Orig', 'Lead', 'orig@email.com', 'Converted', 'Lexington HQ');
        sam.Original_Lead__c = lead.Id;
        update sam;
        try {
            EPIC01_MemberOnboarding_Service.unconvertMember(sam.Id);
            System.assert(false, 'Expected refusal');
        } catch (EPIC01_MemberOnboarding_Service.ConversionException e) {
            System.assertEquals('Only Prospect members can be unconverted', e.getMessage());
        }
    }

    @isTest
    static void unconvertRefusesMemberWithoutLead() {
        Member__c sam = [SELECT Id FROM Member__c WHERE Referral_Code__c = 'SAM0KA00'];
        try {
            EPIC01_MemberOnboarding_Service.unconvertMember(sam.Id);
            System.assert(false, 'Expected refusal');
        } catch (EPIC01_MemberOnboarding_Service.ConversionException e) {
            System.assert(e.getMessage().contains('not created from a Lead'));
        }
    }
}
