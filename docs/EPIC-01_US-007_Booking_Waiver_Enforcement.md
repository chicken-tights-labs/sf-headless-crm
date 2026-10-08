# EPIC-01 / US-007 — Booking Waiver Enforcement (implementation notes)

Issue: #28. Gherkin lives in the issue body. The Obsidian copy is not reachable from the dev machine, so sync it from this file.

## What exists

| Concern | Implementation |
|---|---|
| Enforcement point | `EPIC01_BookingWaiverGuard` (before insert on `Booking__c`) calls `EPIC01_BookingWaiver_Handler`. A trigger is used (not a validation rule) because it must query `Waiver_Record__c`, and it must hold for UI, API, data loader and flows alike |
| Shared rule | `EPIC01_MemberOnboarding_Service.waiverStatusByMember(Set<Id>)` is the one definition of "valid waiver" (bulk-safe). `attemptProceedToPayment` (US-003 payment gate) was refactored to use it, with unchanged messages and results |
| Rule | **Any** Signed, non-expired `Waiver_Record__c` makes the member valid. If none is valid, the member is blocked and the message reflects their most recent waiver (Pending, Revoked, Expired, Draft) or "none" |
| Messages | Exact Gherkin text for missing / expired / pending / revoked. A Draft waiver is reported as "does not have a valid signed waiver" |
| Tests | `EPIC01_BookingWaiver_Test` (6 Gherkin scenarios + draft + bulk + shared-rule check) |
| Test data | `EPIC01_TestDataFactory` — use `createMemberWithWaiver(...)` for any test that inserts a `Booking__c` |

## Test waivers (how to avoid being blocked)

There is intentionally **no bypass** of the rule. Test bookings need a real valid waiver:

- **Apex:** `EPIC01_TestDataFactory.createMemberWithWaiver('First', 'Last', locationId, templateId)`.
- **Manual / UAT:** create a clearly fake Member (e.g. "Maria Testwalker") with a `Waiver_Record__c` linked through `Member__c`, `Status__c = Signed`, and a future `Expiration_Date__c`.
- **Playwright:** no spec creates bookings today (`salesforce-smoke.spec.ts` only lists objects). When one does, add a seed helper in `playwright/support/seedData.ts` that creates a Member and a Signed waiver first.

## Notes / decisions

- Decision (board user): any valid waiver is good. A member with a valid waiver and a newer Pending one (e.g. mid-renewal) can still book and pay. This also applies to the US-003 payment gate because both use `waiverStatusByMember`.
- Only inserts are guarded (per the issue). Updating an existing booking, or inserting a Cancelled booking, still requires a valid waiver on insert.
- The payment gate messages still differ from the US-003 Gherkin; that wording is handled in #21.
