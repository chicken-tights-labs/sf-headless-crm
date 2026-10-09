# EPIC-01 / US-004 — Payment Processing (implementation notes)

Issue: #22. Kanban: `t-fb4958ca7608`. Gherkin lives in the issue body. The Obsidian copy is not reachable from the dev machine, so sync it from this file.

## What exists

| Concern | Implementation |
|---|---|
| Take payment | `EPIC01_MemberOnboarding_Service.processPayment` (simulated processor; `simulatePaymentFailure` for card declines). Cash never declines. |
| Staff UI | Quick action `Member__c.Process_Membership_Payment` → screen flow `EPIC01_Process_Membership_Payment` → `EPIC01_ProcessPayment_Action` |
| Gate | Payment refuses without a selected tier and a valid signed waiver (US-003). No Payment_Transaction is created on a gate miss. |
| Dates / classes | Drop-In: Active, no dates, `Classes_Remaining__c` stays at the field default `0`. Punch Card: start today, expiry +180, `Classes_Remaining__c = 10`. Monthly: start today, expiry +30, `Is_Recurring__c`. Annual: start today, expiry +365. |
| Recurring stand-in | Task due in 30 days: `Process recurring payment for {First Last}` (not a Stripe subscription). |
| Receipt | Plain-text email with tier, amount, payment date, expiry. Welcome email still fires via US-005 activation. |
| Card decline | Failed txn, member stays Prospect, Task `Retry payment for {First Last}` |
| Booking | Active required (`Membership not active — please complete payment`). Punch-card bookings decrement `Classes_Remaining__c`. |
| Referral on pay | Already in US-006 (`awardReferralReward`) |
| Tests | `EPIC01_PaymentProcessing_Test`; booking cases in `EPIC01_BookingWaiver_Test`; existing `test_US004_*` |

Why Apex: one transaction across Member, Payment_Transaction, Tasks, referral, and email — not a single-object Flow formula.

## Deviations from the Gherkin / follow-ups

- Live tiers/prices kept (see US-003). Dates are `Start_Date__c` / `Expiry_Date__c`.
- Payment method is `Transaction_Method__c` (Credit Card / Cash). `Payment_Type__c` is the fee category (Monthly Fee, Punch Card Top-Up, …).
- No Stripe / Named Credential. Processor is simulated. Dummy `Payment_Type__c` / `Transaction_Method__c` picklist API-name values are deactivated.
- Annual prepaid default in the Flow is `$1188` (`$99 × 12`); staff can edit the amount.
- Recurring monthly is a follow-up Task, not a payment schedule object or Stripe subscription.
- Receipt and welcome are two emails on success (receipt is this story; welcome is US-005).
