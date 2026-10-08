/**
 * EPIC01-US-001: Lead Capture — maps 1:1 to the Gherkin scenarios in issue #19.
 */
@isTest
private class EPIC01_LeadCapture_Test {

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

    private static EPIC01_LeadCapture_Service.Request baseRequest() {
        EPIC01_LeadCapture_Service.Request r = new EPIC01_LeadCapture_Service.Request();
        r.firstName = 'Maya';
        r.lastName = 'Rodriguez';
        r.email = 'maya.rodriguez@email.com';
        r.phone = '336-555-0199';
        r.programInterest = 'Boxing';
        r.franchiseLocationName = 'Lexington HQ';
        return r;
    }

    @isTest
    static void webFormCreatesLead() {
        EPIC01_LeadCapture_Service.Response res = EPIC01_LeadCapture_Service.capture(baseRequest());
        System.assertEquals(true, res.success, res.message);
        Lead__c l = [SELECT First_Name__c, Last_Name__c, Email__c, Phone__c, Lead_Source__c,
                            Program_Interest__c, Lead_Status__c, Franchise_Location__r.Name
                     FROM Lead__c WHERE Id = :res.leadId];
        System.assertEquals('Maya', l.First_Name__c);
        System.assertEquals('Rodriguez', l.Last_Name__c);
        System.assertEquals('maya.rodriguez@email.com', l.Email__c);
        System.assertEquals('336-555-0199', l.Phone__c);
        System.assertEquals('Web Form', l.Lead_Source__c);
        System.assertEquals('Boxing', l.Program_Interest__c);
        System.assertEquals('Lexington HQ', l.Franchise_Location__r.Name);
        System.assertEquals('New', l.Lead_Status__c);
    }

    @isTest
    static void walkInWithoutEmailCreatesLead() {
        EPIC01_LeadCapture_Service.Request r = baseRequest();
        r.firstName = 'Jordan'; r.lastName = 'Smith'; r.phone = '336-555-0177';
        r.email = ''; r.leadSource = 'Walk-in'; r.programInterest = 'Fencing';
        EPIC01_LeadCapture_Service.Response res = EPIC01_LeadCapture_Service.capture(r);
        System.assertEquals(true, res.success, res.message);
        Lead__c l = [SELECT Phone__c, Email__c, Lead_Source__c FROM Lead__c WHERE Id = :res.leadId];
        System.assertEquals('336-555-0177', l.Phone__c);
        System.assertEquals(null, l.Email__c);
        System.assertEquals('Walk-in', l.Lead_Source__c);
    }

    @isTest
    static void trialWaiverMarksLeadTrialCompleted() {
        Franchise_Location__c loc = [SELECT Id FROM Franchise_Location__c WHERE Name = 'Lexington HQ'];
        Waiver_Template__c tmpl = new Waiver_Template__c(
            Name = 'General Liability Waiver - Fencing & Boxing', Template_Type__c = 'Adult',
            Content_Version_Id__c = '068000000000001', Effective_Date__c = Date.today()
        );
        insert tmpl;

        EPIC01_LeadCapture_Service.Request r = baseRequest();
        r.firstName = 'Avery'; r.lastName = 'Johnson'; r.email = 'avery.j@email.com';
        r.phone = '336-555-0166'; r.leadSource = 'Walk-in';
        EPIC01_LeadCapture_Service.Response res = EPIC01_LeadCapture_Service.capture(r);
        System.assertEquals(true, res.success, res.message);

        insert new Waiver_Record__c(
            Name = 'WR-Avery-Johnson', Franchise_Location__c = loc.Id, Lead__c = res.leadId,
            Waiver_Template__c = tmpl.Id, Status__c = 'Signed',
            Expiration_Date__c = Date.today().addDays(180), Signature_Timestamp__c = DateTime.now(),
            Signature_Method__c = 'Digital In-Person', Signer_Email__c = 'avery.j@email.com',
            Signer_Role__c = 'Participant'
        );

        System.assertEquals('Trial Completed',
            [SELECT Lead_Status__c FROM Lead__c WHERE Id = :res.leadId].Lead_Status__c);
    }

    @isTest
    static void facebookLeadAdStoresCampaignMetadata() {
        EPIC01_LeadCapture_Service.Request r = baseRequest();
        r.firstName = 'Marcus'; r.lastName = 'Williams'; r.email = 'marcus.w@email.com';
        r.phone = '336-555-0155'; r.leadSource = 'Facebook Ad';
        r.campaignMetadata = '{"ad_id":"123","form_id":"456"}';
        EPIC01_LeadCapture_Service.Response res = EPIC01_LeadCapture_Service.capture(r);
        System.assertEquals(true, res.success, res.message);
        Lead__c l = [SELECT Lead_Source__c, Campaign_Metadata__c FROM Lead__c WHERE Id = :res.leadId];
        System.assertEquals('Facebook Ad', l.Lead_Source__c);
        System.assertEquals('{"ad_id":"123","form_id":"456"}', l.Campaign_Metadata__c);
    }

    @isTest
    static void validReferralCodeAttributesMember() {
        EPIC01_LeadCapture_Service.Request r = baseRequest();
        r.referralCode = 'SAM0KA00';
        EPIC01_LeadCapture_Service.Response res = EPIC01_LeadCapture_Service.capture(r);
        System.assertEquals(true, res.success, res.message);
        Lead__c l = [SELECT Referred_By__r.Name, Lead_Source__c FROM Lead__c WHERE Id = :res.leadId];
        System.assertEquals('Sam_Okafor', l.Referred_By__r.Name);
        System.assertEquals('Referral', l.Lead_Source__c);
    }

    @isTest
    static void invalidReferralCodeStillCreatesLeadWithWarning() {
        EPIC01_LeadCapture_Service.Request r = baseRequest();
        r.referralCode = 'BADCODE1';
        EPIC01_LeadCapture_Service.Response res = EPIC01_LeadCapture_Service.capture(r);
        System.assertEquals(true, res.success, res.message);
        Lead__c l = [SELECT Referred_By__c, Lead_Source__c, Notes__c FROM Lead__c WHERE Id = :res.leadId];
        System.assertEquals(null, l.Referred_By__c);
        System.assertEquals('Web Form', l.Lead_Source__c);
        System.assertEquals('Invalid referral code — continuing without attribution', l.Notes__c);
    }

    @isTest
    static void duplicateEmailIsPrevented() {
        EPIC01_LeadCapture_Service.Request r = baseRequest();
        r.email = 'alex.r@email.com';
        System.assertEquals(true, EPIC01_LeadCapture_Service.capture(r).success);

        r.firstName = 'Alex'; r.lastName = 'Rivera';
        EPIC01_LeadCapture_Service.Response second = EPIC01_LeadCapture_Service.capture(r);
        System.assertEquals(false, second.success);
        System.assertEquals(true, second.duplicate);
        System.assertEquals('Lead already exists — redirecting to update flow', second.message);
        System.assertEquals(1, [SELECT COUNT() FROM Lead__c WHERE Email__c = 'alex.r@email.com']);
    }

    @isTest
    static void duplicateEmailBlockedOnDirectInsert() {
        Id locId = [SELECT Id FROM Franchise_Location__c WHERE Name = 'Lexington HQ'].Id;
        insert new Lead__c(Name = 'A B', First_Name__c = 'A', Last_Name__c = 'B',
            Email__c = 'dup@email.com', Lead_Status__c = 'New', Franchise_Location__c = locId);
        try {
            insert new Lead__c(Name = 'C D', First_Name__c = 'C', Last_Name__c = 'D',
                Email__c = 'DUP@email.com', Lead_Status__c = 'New', Franchise_Location__c = locId);
            System.assert(false, 'Expected duplicate to be blocked');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Lead already exists'), e.getMessage());
        }
    }

    @isTest
    static void invalidEmailRejected() {
        EPIC01_LeadCapture_Service.Request r = baseRequest();
        r.email = 'not-an-email';
        EPIC01_LeadCapture_Service.Response res = EPIC01_LeadCapture_Service.capture(r);
        System.assertEquals(false, res.success);
        System.assert(res.errors.contains('Please enter a valid email address'));
    }

    @isTest
    static void invalidPhoneRejected() {
        EPIC01_LeadCapture_Service.Request r = baseRequest();
        r.phone = 'abc-def-ghij';
        EPIC01_LeadCapture_Service.Response res = EPIC01_LeadCapture_Service.capture(r);
        System.assertEquals(false, res.success);
        System.assert(res.errors.contains('Please enter a valid 10-digit phone number'));
    }

    @isTest
    static void phoneValidationRuleBlocksBadPhoneOnDirectInsert() {
        Id locId = [SELECT Id FROM Franchise_Location__c WHERE Name = 'Lexington HQ'].Id;
        try {
            insert new Lead__c(Name = 'P Q', First_Name__c = 'P', Last_Name__c = 'Q',
                Phone__c = '12345', Lead_Status__c = 'New', Franchise_Location__c = locId);
            System.assert(false, 'Expected validation rule to fire');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('valid 10-digit phone number'), e.getMessage());
        }
    }

    @isTest
    static void missingFirstNameRejected() {
        EPIC01_LeadCapture_Service.Request r = baseRequest();
        r.firstName = '';
        EPIC01_LeadCapture_Service.Response res = EPIC01_LeadCapture_Service.capture(r);
        System.assertEquals(false, res.success);
        System.assert(res.errors.contains('First Name is required'));
        System.assertEquals(0, [SELECT COUNT() FROM Lead__c]);
    }

    @isTest
    static void restEndpointCreatesLeadAndReportsErrors() {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/leadcapture';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(baseRequest()));
        RestContext.request = req;
        RestContext.response = new RestResponse();
        EPIC01_LeadCapture_Rest.doPost();
        System.assertEquals(201, RestContext.response.statusCode);

        // same payload again -> 409 duplicate
        RestContext.response = new RestResponse();
        EPIC01_LeadCapture_Rest.doPost();
        System.assertEquals(409, RestContext.response.statusCode);

        // malformed body -> 400
        req.requestBody = Blob.valueOf('not json');
        RestContext.response = new RestResponse();
        EPIC01_LeadCapture_Rest.doPost();
        System.assertEquals(400, RestContext.response.statusCode);
    }
}
