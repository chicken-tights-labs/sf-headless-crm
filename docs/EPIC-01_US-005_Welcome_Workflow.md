# EPIC-01 / US-005 — Welcome Workflow (implementation notes)

Issue: #23. Gherkin lives in the issue body. The Obsidian copy is not reachable from the dev machine, so sync it from this file.

## What exists

| Concern | Implementation |
|---|---|
| Trigger | `EPIC01_MemberActivation` (after update on `Member__c`): when `Status__c` changes to Active (from anything else) it calls `EPIC01_MemberOnboarding_Service.handleActivation`. Not fired on inserts or unrelated updates |
| Welcome email | `sendWelcomeEmails(Set<Id>)` (bulk-safe, one `sendEmail` call). Subject "Welcome to Boxing Fitness Gym, <first>!"; body has tier name, schedule line, location name and phone, guardian section, referral thank-you |
| Idempotence | Only members with `Welcome_Email_Sent__c = false` are processed; the flag is set after a successful send. No duplicate email or task |
| Orientation task | "Schedule facility orientation for <name>", due today + 7 |
| Failure path | Blank or invalid address, or a send error: task "Welcome email failed for <name> — verify email address", flag stays false |
| Minor / guardian | Section "Parent/Guardian Information" when `Guardian_Name__c` is set or `Date_of_Birth__c` is under 18; greeting uses the guardian name when present |
| Referral | Welcome email includes "Thanks to <referrer> for the referral!" and the referrer gets "Your referral <name> has joined Boxing Fitness Gym!" |
| Waiver reminder | `EPIC01_WaiverReminder_Job` (Schedulable) runs `runWaiverReminderJob`: members with `Waiver_Needed__c`, created 7+ days ago, with no valid waiver, get task "Waiver reminder for <name>" and email "Friendly reminder: Your Boxing Fitness Gym waiver is still pending". One task per member (daily reruns skip them) |
| Tests | `EPIC01_Welcome_Test` |

## Register the reminder job (one time per org)

```apex
System.schedule('EPIC01 Waiver Reminder', '0 0 8 * * ?', new EPIC01_WaiverReminder_Job());
```

## Deviations / follow-ups

- **Front desk coordinator:** tasks are not assigned to a specific user or queue (no such user/queue exists in source). They default to the running user. Tell us who the coordinator is and we assign tasks (a queue is the cleanest option).
- **Email bounce:** the Gherkin uses `Email__c = "invalid-email"`, which the Email field type rejects at insert (and `Email__c` is required on `Member__c`). The code still handles blank/invalid format and synchronous send failures; the test simulates a send failure through a test hook. Asynchronous bounces after delivery are not detectable in Apex without Email Bounce Management; not built.
- **Address:** `Franchise_Location__c` has no `Address__c` field, so the email shows the location name and phone only.
- **Email format:** inline plain text, not a Lightning email template (same as US-002).
- **Referrer notification:** US-002 already emails the referrer when the lead converts; US-005 also emails on activation. Both match their own Gherkin, so the referrer may get two messages. Revisit if that is too noisy.
- **SMS** (Twilio) is out of scope.
