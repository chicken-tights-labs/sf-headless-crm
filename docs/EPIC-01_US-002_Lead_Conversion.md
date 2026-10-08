# EPIC-01 / US-002 — Lead Conversion (implementation notes)

Issue: #20. Gherkin lives in the issue body. The Obsidian copy is not reachable from the dev machine, so sync it from this file.

## What exists

| Concern | Implementation |
|---|---|
| Conversion logic | `EPIC01_MemberOnboarding_Service.convertLeadToMember` (extended): guards, field copy (incl. `Lead_Source__c`, `Program_Interest__c`, `Original_Lead__c`), waiver transfer, tasks, referrer email |
| Guards / messages | Member already linked, already Converted, Unqualified ("disqualified"), no location. Exact Gherkin messages, thrown as `ConversionException` |
| Buttons | Quick actions `Lead__c.Convert_to_Member` and `Member__c.Unconvert` run screen flows `EPIC01_Convert_Lead_To_Member` / `EPIC01_Unconvert_Member` through invocable wrappers `EPIC01_LeadConversion_Action` / `EPIC01_MemberUnconvert_Action` |
| Audit trail | Task "Schedule first class for <name>" on the new Member; waiver task now "Member needs to sign waiver before payment" |
| Referral notification | Plain-text email to the referring member: "Your referral <name> has joined NBS Gym!" (send failures are caught so a conversion is never rolled back) |
| Unconvert | `unconvertMember`: Prospect members only; clears `Converted_Member__c`, restores lead to Qualified, detaches transferred waivers, deletes Member |
| Schema | `Member__c.Program_Interest__c` (new picklist); `Member__c.Lead_Source__c` gained In Person, Web Form, Facebook Ad so lead sources copy across |
| Tests | `EPIC01_LeadConversion_Test`; `EPIC01_MemberOnboarding_Test` updated for the new waiver task subject |

## Deviations from the Gherkin / follow-ups

- "Disqualified" in the Gherkin is the existing `Unqualified` picklist value.
- The Gherkin says the button should be disabled. Quick actions cannot be disabled by state without a Lightning record page using Dynamic Actions, and there is no `Lead__c` page/layout in source. The button shows the guard message when clicked. Manual step: add the two quick actions to the Lead and Member page layouts / record pages.
- Referral email is inline plain text, not a Lightning email template.
- Unconvert refuses non-Prospect members (deleting an active paying member is not a reversal) and requires delete permission on `Member__c`.
- Waiver task subject changed to the Gherkin wording; any report or list view filtering on the old subject needs updating.
