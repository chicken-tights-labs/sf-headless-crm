# EPIC-01 / US-001 — Lead Capture (implementation notes)

Issue: #19. Gherkin lives in the issue body. The Obsidian copy (`CRM-Documentation/EPIC-01_US-001_Lead_Capture.md`) is not reachable from this machine, so these notes are the in-repo record; sync the Obsidian doc from this file.

## What exists

| Concern | Implementation |
|---|---|
| Schema | `Lead__c`: `Phone__c`, `Lead_Source__c`, `Program_Interest__c`, `Referred_By__c` already existed (the issue lists them as PENDING, which was out of date). Added `Campaign_Metadata__c` (long text) and `Referral_Code_Entered__c`. Added picklist values: Lead Source `Web Form`, `Facebook Ad`; Lead Status `Trial Completed`. |
| Phone / email format | Validation rule `Valid_Phone_Format` (10 digits). Email format is enforced by the Email field type, plus the REST layer message. |
| Required fields | `First_Name__c` is a required field; REST layer returns "First Name is required". |
| Referral attribution | Flow `EPIC01_Lead_Referral_Attribution` (before-save, create): valid code sets `Referred_By__c` and source `Referral`; invalid code leaves it blank and writes the warning to `Notes__c`. |
| Duplicate email | Trigger `EPIC01_LeadDuplicateGuard` (all entry paths) and pre-check in `EPIC01_LeadCapture_Service` (returns 409 + "Lead already exists — redirecting to update flow"). |
| Walk-in trial waiver | Flow `EPIC01_Waiver_Marks_Lead_Trial_Completed`: Signed waiver linked to a Lead sets status `Trial Completed` (not if Converted). |
| Web form / trainer app / Facebook | `POST /services/apexrest/leadcapture` (`EPIC01_LeadCapture_Rest`). Facebook payload goes in `campaignMetadata`, `leadSource = "Facebook Ad"`. |
| Tests | `EPIC01_LeadCapture_Test` |

## Request body

```json
{
  "firstName": "Maya", "lastName": "Rodriguez",
  "email": "maya.rodriguez@email.com", "phone": "336-555-0199",
  "leadSource": "Web Form", "programInterest": "Boxing",
  "referralCode": "SAM0KA00",
  "franchiseLocationName": "Lexington HQ",
  "campaignMetadata": "{...raw webhook payload...}"
}
```

## Known gaps / decisions

- `Lead__c.Franchise_Location__c` is required, so every request (including Facebook) must send `franchiseLocationId` or `franchiseLocationName`. The webhook relay should map each ad form to a location.
- Duplicate detection is email only. Phone is not used (walk-ins often share or lack contact data); revisit if needed.
- Lead Source value is `Walk-in` (existing picklist value; restricted picklists match case-insensitively).
- Duplicate handling uses a trigger instead of a Duplicate Rule (custom-object matching rules are hard to deploy and test across scratch orgs).
- `EPIC04_LeadRegistration_Controller` / LWC were left unchanged (they still create `Walk-In` / `In Person` leads and benefit from the new validation and duplicate guard).
- Apex REST access: the permission set has no Apex class access entries; grant `EPIC01_LeadCapture_Rest` to the integration user's profile or permission set before go-live.
- Not built: the actual Facebook webhook relay, web form hosting, trainer app UI.
