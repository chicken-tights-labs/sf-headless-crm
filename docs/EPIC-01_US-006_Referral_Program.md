# EPIC-01 / US-006 — Referral Program (GitHub #24)

## What it does

| Gherkin scenario | Implementation |
|---|---|
| Code generated when a member becomes Active | `EPIC01_MemberActivation` trigger → `handleActivation` → `EPIC01_Referral_Handler.generateCodes`. 8 characters: 3 initials (padded with `X`) + 5 random. Never overwrites an existing code. Bulk-safe, uniqueness checked per round. |
| Valid code on a lead | `EPIC01_Lead_Referral_Attribution` flow sets `Referred_By__c`; `EPIC01_LeadReferral` (after insert) adds 1 to the referrer's `Referral_Attempts__c` and creates a `Referral_Reward__c` in **Code Used**. |
| Invalid code | Lead still saved; `Notes__c` = "Referral code not found — continuing without attribution" (US-001 wording reconciled). No attempt counted. |
| Self-referral | Lead email equals the referrer's email → insert blocked: "You cannot refer yourself". |
| Referred person is already a member | Referral not applied (`Referred_By__c` cleared), lead's `Converted_Member__c` points at the existing member, note "Already a member — referral not applied". |
| Lifecycle | Code Used → (lead converted) Member Created → (first payment) Payment Completed → Reward Claimed. Un-converting a Prospect returns the record to Code Used. |
| Deactivated referrer | Referrer status Cancelled / Lapsed / Suspended: attribution stays, reward record becomes **Cancelled**, no credit given. |

## Bug fixes found on the way

- **Double award removed.** `processPayment` and `calculatePaymentWithReferralDiscount` both paid the referrer. The discount method is now pricing only; `awardReward` is also idempotent per referred member.
- **Code generator was not random.** The old code took the first 5 hex characters of a hex-encoded timestamp, which are the same for every member (`31373`). Same initials meant the same code. Replaced by `Crypto.getRandomInteger`.

## Deviations / decisions to confirm

- Picklist has no "Inactive" status; I treated **Cancelled, Lapsed, Suspended** as "deactivated" (constant `INELIGIBLE_REFERRER_STATUSES`). Say if Suspended should still earn.
- Reward amounts are unchanged from the old code: +1 class, plus +$10 account credit for the Monthly Unlimited and Annual Prepaid tiers. Those tier names will change with #21 (tier decision).
- Portal "Refer a Friend" page is out of scope.
- Friend discount (50%) is still only calculated, not applied by the payment screen (belongs to #22).
- The existing-member check matches on email across all members, not only members referred by this referrer.

## Tests

`EPIC01_Referral_Test` (11 tests): activation code once/kept, bulk uniqueness, valid code (attempt + reward), invalid code, self-referral, existing member, full lifecycle with a single award, account-credit referrer, deactivated referrer, discount does not award, un-convert reverts. Run in scratch org `us-test`: 71/71 across the related classes.
