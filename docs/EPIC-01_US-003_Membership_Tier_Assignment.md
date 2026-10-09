# EPIC-01 / US-003 — Membership Tier Assignment + Waiver Gate (implementation notes)

Issue: #21. Kanban: `t-6eeade238f60`. Gherkin lives in the issue body. The Obsidian copy is not reachable from the dev machine, so sync it from this file.

## What exists

| Concern | Implementation |
|---|---|
| Payment gate | `EPIC01_MemberOnboarding_Service.attemptProceedToPayment` / `waiverStatusByMember` (shared with US-007 booking) |
| Messages | Missing / pending / expired-with-date / revoked. Success copy for the UI is `MSG_WAIVER_VALID` |
| Staff UI | Quick action `Member__c.Select_Membership_Tier` runs screen flow `EPIC01_Select_Membership_Tier` through invocable `EPIC01_PaymentGate_Action` |
| Tier save | Flow updates `Membership_Tier__c` only. `Start_Date__c` / `Expiry_Date__c` stay null until US-004 payment |
| Waiver signed | Record-triggered Flow `EPIC01_Waiver_Confirmed_Notify`: Prospect + valid Signed waiver → Task + email `MSG_WAIVER_CONFIRMED` |
| Trial-class skip | US-002 already transfers a signed Lead waiver onto the Member. The gate then opens immediately; the notify Flow also fires on that transfer |
| Tests | `EPIC01_PaymentGate_Test`; existing `test_US003_*` in `EPIC01_MemberOnboarding_Test` |

Why Apex for the gate (not a Validation Rule): a VR cannot query related `Waiver_Record__c` rows. The same Apex is the booking rule (US-007). Why Flow for the UI: staff already use Convert/Unconvert as record quick actions.

## Deviations from the Gherkin / follow-ups

- Live `Membership_Tier__c` values are kept: Drop-In ($20/class), Punch Card (10 classes - $150), Monthly Unlimited ($129), Annual Prepaid ($99/mo). Not the Gherkin Drop-in $25 / 4-pack / 8-pack / Unlimited Monthly $150 / Student-Military set.
- Dates live on `Start_Date__c` / `Expiry_Date__c`, not `Membership_Start_Date__c` / `Membership_Expiry_Date__c`.
- There is no Lightning "Proceed to Payment" button that enables in place. The Select Membership Tier flow shows the gate result; payment is a separate US-004 quick action.
- Dummy picklist value whose API name was `Membership_Tier__c` is deactivated.
- Success message is "Your waiver is valid. You can proceed to payment." rather than the trial-specific "Your waiver from your trial class is valid…" (same gate either way).
- Confirmation notification is Task + plain-text email, not a Lightning email template.
