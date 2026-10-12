# Story Order: EPIC-03, EPIC-04, EPIC-11

**Last updated:** 2026-10-12
**Supersedes:** the sequencing, C2, and trainer-app offline sections of [`EPIC-03_04_Conflict_Analysis.md`](./EPIC-03_04_Conflict_Analysis.md)

This is the order the open stories are expected to merge. Each story's GitHub issue has a dependency comment with the details. If this file and an issue comment disagree, the newer one wins, and this file gets updated in the same PR.

## Lanes

- Every story below is `platform:cursor`. Hermes does not implement them. Hermes deploys and runs the sanity check after each PR merges (WORKFLOW.md section 7).
- #64 (member QR wallet pass and fob) is `platform:app`. It belongs to the non-Salesforce app. Neither Cursor nor Hermes builds it in this repo.
- One story, one branch, one PR. Wave 1 PRs do not depend on each other and can merge in any order.

## Wave 1: start in parallel

| Issue | Story | Depends on |
|---|---|---|
| #65 | US-F001 Place walk-in lead form for front desk | None |
| #59 | US-F005 Capture digital waiver | None |
| #58 | US-F004 First payment screen (calls `EPIC01_ProcessPayment_Action`) | None |
| #60 | US-F006 Merchandise sale | None |
| #46 | US-T001 Trainer schedule | None |
| #49 | US-T004 Attendee list (becomes the class check-in screen) | None |
| #54 | US-T009 Medical-notes permission (trainers only) | None |
| #40 | US-D004 System admin guide | None |

## Wave 2

| Issue | Story | Depends on |
|---|---|---|
| #56 | US-F002 Convert and pay | #58, #65 |
| #57 | US-F003 Renew membership (new signed waiver required) | #58, #59 |
| #61 | US-F007 Merchandise discount: promo codes and manager PIN | #60 |
| #52 | US-T007 Member profile | #54 |
| #50 + #51 | US-T005 Mark Attended with US-T006 waiver block, as one action | #49, #59 |

## Wave 3

| Issue | Story | Depends on |
|---|---|---|
| #48 | US-T003 Phone check-in | #50 + #51 |
| #47 | US-T002 QR check-in (Salesforce side: code field and scan) | #50 + #51 |
| #64 | Member QR wallet pass and fob (`platform:app`) | Code field from #47 |
| #53 | US-T008 Trainer new member | #65, #56, #58 |
| #55 | US-T010 Substitute trainer | #46 |
| #62 | US-F008 Merchandise refund | #60 |

## Docs

- #37 End user manual: stays open, updated in the same PR as each screen.
- #38 Manager guide and #39 Franchise owner guide: describe what exists now. Trainer and royalty sections wait for those features.
- #41 API docs: after #58, #57, #60, #61, and #62.
- #42 Troubleshooting and FAQ: last.

## Decisions that change how stories are built

- **No separate trainer app in this repo.** Trainer stories are screens in the Boxing Gym CRM app. No offline architecture decision is needed before they start.
- **One check-in screen.** The #49 attendee list is the class check-in screen. #50, #48, and #47 add to it.
- **One attendance write.** Check-in sets `Booking__c.Checked_In_At__c` and `Status__c = Completed`. There is no Attended value.
- **The check-in waiver block calls `waiverStatusByMember`.** `EPIC01_BookingWaiverGuard` runs when a booking is created, not at check-in. Booking stays guarded by the trigger.
- **A QR scan records class attendance,** not gym entry. Scanners: camera in the Salesforce mobile app, or a handheld scanner typing into the screen. Salesforce stores a random check-in code per member; #64 delivers it.
- **Medical notes:** trainers only in Salesforce. Members and guardians see their own notes in the member app.
- **Discounts and refunds are merchandise only.** Promo codes live in a new `Promo_Code__c` object, managed by users with a new manager permission set. A manager PIN covers one-off discounts.
- **Renewal** extends `Expiry_Date__c` from the later of today and the current expiry. It needs a new signed waiver. It does not call `processPayment`, resend the welcome email, or award the referral again.
- **Substitute** uses a new trainer lookup on `Scheduled_Session__c`. `Assigned_Trainer__c` stays the original trainer.
- **Do not create** `Order__c`, `Payment__c`, `Refund__c`, `Discount_Request__c`, `Check_In__c`, or `Medical_Note__c` from older docs. Use `Payment_Transaction__c`, `Merchandise_Sale__c`, `Sale_Line_Item__c`, `Booking__c`, and `Member__c.Medical_Notes__c`.

## Shared files

`Boxing_Gym_CRM_Access.permissionset-meta.xml` is touched by #54, #61, #47, and #55. `Member__c` gets a new field from #47. Rebase on `main` before opening each PR.

## Open questions

| Issue | Question |
|---|---|
| #54 | Who enters or updates medical notes, if front desk and managers cannot see them? |
| #61 | Where is a manager's PIN stored, and who sets it? Does 10% or less skip the PIN? Do promo codes expire or have usage limits? |
| #57 | How do we tell that a waiver belongs to this renewal? |
| #47, #64 | How is a lost code replaced so the old one stops working? |
| #64 | Which repo and team build the wallet pass and fob? |
| #65 | Gym Manager Home or a separate front desk page? Default the location to the staff member's gym? |
