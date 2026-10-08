/**
 * EPIC01-US-001: Lead Capture service.
 *
 * Single entry point used by the REST endpoint (web form, trainer app,
 * Facebook Lead Ad webhook). Performs the checks the Gherkin requires
 * (required fields, email/phone format, duplicate email) and inserts a
 * Lead__c. Referral attribution is resolved declaratively by the
 * EPIC01_Lead_Referral_Attribution flow from Referral_Code_Entered__c.
 */
public with sharing class EPIC01_LeadCapture_Service {

    public static final String MSG_FIRST_NAME_REQUIRED = 'First Name is required';
    public static final String MSG_LAST_NAME_REQUIRED  = 'Last Name is required';
    public static final String MSG_INVALID_EMAIL       = 'Please enter a valid email address';
    public static final String MSG_INVALID_PHONE       = 'Please enter a valid 10-digit phone number';
    public static final String MSG_LOCATION_REQUIRED   = 'A valid franchise location is required';
    public static final String MSG_DUPLICATE           = 'Lead already exists — redirecting to update flow';

    private static final Pattern EMAIL_PATTERN = Pattern.compile('^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$');

    public class Request {
        public String firstName;
        public String lastName;
        public String email;
        public String phone;
        public String leadSource;        // Web Form | Walk-in | Facebook Ad (defaults to Web Form)
        public String programInterest;
        public String referralCode;
        public String franchiseLocationId;
        public String franchiseLocationName;
        public String campaignMetadata;  // raw webhook payload (Facebook Lead Ad)
    }

    public class Response {
        public Boolean success;
        public Id leadId;
        public String message;
        public Boolean duplicate = false;
        public List<String> errors = new List<String>();
    }

    public static Response capture(Request req) {
        Response res = new Response();
        res.errors = validate(req);
        if (!res.errors.isEmpty()) {
            res.success = false;
            res.message = String.join(res.errors, '; ');
            return res;
        }

        if (String.isNotBlank(req.email)) {
            List<Lead__c> existing = [
                SELECT Id FROM Lead__c WHERE Email__c = :req.email.trim() LIMIT 1
            ];
            if (!existing.isEmpty()) {
                res.success   = false;
                res.duplicate = true;
                res.leadId    = existing[0].Id;
                res.message   = MSG_DUPLICATE;
                return res;
            }
        }

        Id locationId = resolveLocation(req);
        if (locationId == null) {
            res.success = false;
            res.errors.add(MSG_LOCATION_REQUIRED);
            res.message = MSG_LOCATION_REQUIRED;
            return res;
        }

        String source = String.isBlank(req.leadSource) ? 'Web Form' : req.leadSource;
        Lead__c lead = new Lead__c(
            First_Name__c         = req.firstName.trim(),
            Last_Name__c          = req.lastName.trim(),
            Email__c              = String.isBlank(req.email) ? null : req.email.trim(),
            Phone__c              = String.isBlank(req.phone) ? null : req.phone.trim(),
            Lead_Source__c        = source,
            Lead_Status__c        = 'New',
            Program_Interest__c   = String.isBlank(req.programInterest) ? null : req.programInterest,
            Franchise_Location__c = locationId,
            Referral_Code_Entered__c = String.isBlank(req.referralCode) ? null : req.referralCode.trim(),
            Campaign_Metadata__c  = req.campaignMetadata,
            Name                  = req.firstName.trim() + ' ' + req.lastName.trim()
        );
        try {
            insert lead;
        } catch (DmlException e) {
            res.success = false;
            res.duplicate = e.getMessage().contains(MSG_DUPLICATE);
            res.message = res.duplicate ? MSG_DUPLICATE : e.getDmlMessage(0);
            res.errors.add(res.message);
            return res;
        }
        res.success = true;
        res.leadId  = lead.Id;
        res.message = 'Lead created';
        return res;
    }

    public static List<String> validate(Request req) {
        List<String> errors = new List<String>();
        if (req == null || String.isBlank(req.firstName)) {
            errors.add(MSG_FIRST_NAME_REQUIRED);
        }
        if (req == null || String.isBlank(req.lastName)) {
            errors.add(MSG_LAST_NAME_REQUIRED);
        }
        if (req != null && String.isNotBlank(req.email)
            && !EMAIL_PATTERN.matcher(req.email.trim()).matches()) {
            errors.add(MSG_INVALID_EMAIL);
        }
        if (req != null && String.isNotBlank(req.phone) && !isValidPhone(req.phone)) {
            errors.add(MSG_INVALID_PHONE);
        }
        return errors;
    }

    public static Boolean isValidPhone(String phone) {
        String digits = phone.replaceAll('[\\s\\-\\(\\)\\.]', '');
        if (digits.startsWith('+1')) {
            digits = digits.substring(2);
        }
        return digits.length() == 10 && digits.isNumeric();
    }

    private static Id resolveLocation(Request req) {
        if (String.isNotBlank(req.franchiseLocationId)) {
            List<Franchise_Location__c> byId = [
                SELECT Id FROM Franchise_Location__c WHERE Id = :req.franchiseLocationId LIMIT 1
            ];
            return byId.isEmpty() ? null : byId[0].Id;
        }
        if (String.isNotBlank(req.franchiseLocationName)) {
            List<Franchise_Location__c> byName = [
                SELECT Id FROM Franchise_Location__c
                WHERE Name = :req.franchiseLocationName AND Status__c = 'Active' LIMIT 1
            ];
            return byName.isEmpty() ? null : byName[0].Id;
        }
        return null;
    }
}
