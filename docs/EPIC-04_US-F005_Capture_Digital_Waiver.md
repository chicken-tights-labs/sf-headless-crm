# EPIC-04 / US-F005 — Capture Digital Waiver

Issue: #59. Kanban: `t-5d0a078d19f4`.

## What exists

| Concern        | Implementation                                                                                       |
| -------------- | ---------------------------------------------------------------------------------------------------- |
| Staff UI       | Quick action **Capture Waiver** on `Member__c` and `Lead__c` → LWC `epic04CaptureDigitalWaiver`      |
| Why LWC        | Screen Flow cannot capture a drawn signature; the pad is a canvas in LWC                             |
| Create engine  | `EPIC04_WaiverCapture_Controller.captureWaiver` inserts `Waiver_Record__c` with `Status__c = Signed` |
| Signature file | PNG stored as `ContentVersion` linked to the waiver                                                  |
| Member update  | Sets `Waiver_Needed__c = false` and `Waiver_Signed__c` to the new waiver                             |
| Placement      | Highlights panel on `Member_Record_Page` and `Lead_Record_Page`                                      |
| Tests          | `EPIC04_WaiverCapture_Test`; Jest for the LWC save guard                                             |

## Flow of the button

1. Open a Member or Lead that has a Franchise Location.
2. Click **Capture Waiver**.
3. Confirm signer name/email, role, and waiver template (Adult template preferred).
4. Visitor signs on the pad.
5. **Save signed waiver** creates a Signed record (`Signature_Method__c = Digital In-Person`, expiry today + 365 days).

Enforcement stays in EPIC-01 (booking trigger / payment gate / check-in). This story is capture only.

## Docs

- Update `docs/EPIC-11_D001_End_User_Manual.md` in the same PR.
- Obsidian vault path named in the issue: sync from this file when the vault is available.
