# EPIC-11 / US-D006 — Troubleshooting + FAQ

Issue: #42. Kanban: `t_d0ee0511`.

**Status:** Draft
**Last verified:** 2026-10-08 against `main` `23d6c67`
**Checked from:** source in `force-app` and the EPIC-01 notes (not an org click-through)
**Still open:** org click-through of each symptom; merge-duplicates, bulk update, export clicks, and "set up a new trainer" have no product feature yet

This is the canonical copy. The issue names `CRM-Documentation/EPIC-11_D006_Troubleshooting_FAQ.md`. Sync that vault from this file when the vault is available.

Feature steps live in US-D001 through US-D005. This page is the symptom list. Search by the quoted message or the heading.

## Troubleshooting

### Login and passwords

**Needs an org click-through** for a normal user reset. The path is in US-D004: Setup → Users → the user → **Reset Password**.

Scratch-org OTP links are tied to the VM network. From a laptop, generate a password instead: `sf org generate password --target-org my-gym`. See `docs/environment.md`.

A user who can log in and still cannot see custom fields is not a password problem. Assign **Boxing Gym CRM Access**. Deployed fields stay invisible, including for System Administrator, until that set is assigned.

### Data does not appear

| Symptom | Cause | What to do |
|---|---|---|
| Custom fields are blank on a record you know has values | Field-level security. The permission set is missing on this user, or the field was deployed without a field permission. | Assign **Boxing Gym CRM Access**. If the field is new, add it to that permission set in source and redeploy. US-D004. |
| A report is empty and the object is not | Report filters. Active Members keeps Status = Active. Class Attendance keeps Session Status = Completed. Upcoming Sessions keeps start time ≥ today, Session Status = Scheduled, and scope **user**. | US-D002. Widen the filter or own the session. |
| Sharing hides a row | Unlikely for a user with the permission set. That set has View All and Modify All, and org-wide default is Public Read/Write (Sale Line Item is controlled by its parent). | If the set is not assigned, Salesforce sharing applies and this project defines no sharing rules. |

### Payment did not complete

**Verified from source.**

| Symptom | Cause | What to do |
|---|---|---|
| Screen **Cannot Take Payment**, `Select a membership tier first` | No tier saved | Run **Select Membership Tier**, then pay. |
| Screen **Waiver Required** or a waiver sentence (`Please sign your waiver first`, pending, revoked, expired) | No valid Signed waiver | Create a Waiver Record with Status Signed and a future expiration, then retry. |
| Screen **Payment Failed**, `Payment failed. A retry task was created.` | Simulated card decline | Member stays Prospect. Task `Retry payment for {name}`. Cash does not decline. There is no Stripe dashboard to check. |
| Member is Active but no receipt | Email blank, or send failed | Receipt sends only when Email is set. The send is caught and does not roll back the payment. |
| Amount was not halved for a referral | The payment screen does not apply the 50% calculator | Type the discounted amount. `calculatePaymentWithReferralDiscount` is not called by the screen. |

### Waiver problems

| Symptom | Cause | What to do |
|---|---|---|
| Booking error `Cannot book class — member does not have a valid signed waiver` | No Signed, unexpired waiver. A Draft waiver counts as missing. | Add a Signed waiver with a future Expiration Date. |
| `member's waiver has expired` / `pending signature` / `has been revoked` | The member's waiver status | New Signed waiver, or finish the pending one. A newer Pending waiver does not block someone who still has a different valid Signed waiver. |
| `Membership not active — please complete payment` | Booking insert and the member is not Active | Take payment first. |
| No signature pad | Digital capture is not built | Staff type a Waiver Record. US-D001. |

### Reports

**Verified from source** for filters. **Needs an org click-through** if the report folder is missing after a partial deploy. Folder name: **Boxing Gym Management Reports**. Dashboard: **Boxing Gym Management Dashboard**. Empty-report causes are in the table under Data does not appear.

### API errors

**Verified from source** for `POST /services/apexrest/leadcapture`. Full table in US-D005.

| Status | Message | What to do |
|---|---|---|
| 400 | `First Name is required` / `Last Name is required` / email or phone message | Fix that field. |
| 400 | `A valid franchise location is required` | Send an existing location Id, or the name of an **Active** location. |
| 400 | `Invalid request body` | Send JSON, not form data. |
| 409 | `Lead already exists — redirecting to update flow` | Use `leadId` from the body. There is no update call. |
| Auth error before a JSON body | Class access or token | Grant `EPIC01_LeadCapture_Rest`. The CRM permission set does not include it. |

Other POS paths are not deployed. A 404 on those URLs is expected.

## FAQ

### How do I reset a member's membership?

**Not built** as a reset button. **Unconvert** deletes a Prospect member and restores the lead. It refuses anyone who is not Prospect (`Only Prospect members can be unconverted`) and refuses non-admins (`Only a System Administrator can unconvert a Member`). An Active member stays Active. Changing Status, dates, or Classes Remaining by hand is a data edit, not a supported reset.

### How do I merge duplicate member records?

**Not built.** There is no merge tool. A second lead with the same email is blocked (`Lead already exists — redirecting to update flow`, or the duplicate-email trigger). Members are not matched the same way.

### How do I export data?

**Needs an org click-through.** No gym export action is in source. Salesforce report export from **Boxing Gym Management Reports** is the closest built-in path. Confirm the Export button on a report run in `my-gym`.

### How do I bulk update records?

**Not built** as a screen. This project does not ship a bulk-update flow. Data Loader or a spreadsheet load is a Salesforce admin tool, outside these guides. Booking inserts still require an Active member and a valid waiver, one row at a time in the trigger.

### How do I set up a new trainer?

**Not built.** There is no Trainer user, profile, or app. A person who needs the CRM gets a Salesforce user plus **Boxing Gym CRM Access** (US-D004). That set is full CRM access, not a trainer-only set. Class ownership for the Staff Utilization report is the **Assigned Trainer** field on Scheduled Session.

### How do I change membership tiers?

Before payment: open the Member → **Select Membership Tier** → pick one of the four values. Dates stay empty until **Process Membership Payment**.

The four values and their prices are fixed strings in source. Renaming them in Setup breaks payment. See US-D004.

After the member is Active, there is no change-tier action.

### Why did the referrer get two emails?

**Verified from source.** Conversion emails the referrer (`Your referral {name} has joined Boxing Fitness Gym!`). Becoming Active can send that news again on the welcome path. Both match their own stories. US-D001 and the welcome note in `docs/EPIC-01_US-005_Welcome_Workflow.md`.

### Why is Classes Remaining 0 on a drop-in?

**Verified from source.** The field default is 0. Drop-in payment does not clear it. 0 means "not a punch card," not "the card is empty."

## How to verify this draft

1. Each row above quotes a message or a field that exists in source, or it says **Not built**.
2. Click the payment and booking cases in `my-gym` before moving any row from Draft to verified-in-org.
3. Leave merge, bulk update, and new-trainer as **Not built** until a feature exists.
