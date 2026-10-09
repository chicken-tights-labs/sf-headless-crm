# EPIC-11 / US-D001 — End User Manual (Trainers + Front Desk)

Issue: #37. Kanban: `t_9d84897e`.

**Status:** Draft
**Last verified:** 2026-10-08 against `main` `23d6c67`
**Checked from:** source in `force-app` (not an org click-through)
**Still open:** screenshots in `my-gym`; trainer check-in, attendance, substitutes, merchandise, discounts, refunds, and renewals are not built; the walk-in form and Convert to Member are not placed on a page in source

This is the canonical copy. The issue names `CRM-Documentation/EPIC-11_D001_End_User_Manual.md`. Sync that vault from this file when the vault is available.

Sections are marked **Verified from source**, **Not built**, or **Needs an org click-through**.

Admin setup (users, the permission set, locations, waiver templates, tier values) is US-D004.

## Where staff work

**Verified from source.** The Lightning app is **Boxing Gym CRM**. Front-desk steps below use that app. There is no trainer mobile app in source. Architecture notes say trainers are meant to use a thin client without a Salesforce license. That client is not in this repo, so none of the trainer steps can be written yet.

## Trainer workflows

**Not built**, except where a Salesforce report already shows the same data to someone who can log into the CRM.

| Asked for | What exists |
|---|---|
| View my class schedule | No trainer schedule screen. The report **Upcoming Sessions and Capacity** lists sessions from today forward. See US-D002. |
| Check in by QR code | No QR check-in. |
| Check in by phone lookup | No phone-lookup check-in. |
| Mark attendance | No attendance action. `Booking__c.Status__c` exists as data. |
| View class attendee lists | No trainer attendee screen. **Class Attendance** and **Upcoming Sessions and Capacity** include booking rows. See US-D002. |
| Open a member profile | A CRM user can open a Member record. There is no trainer profile or trainer app. |
| View medical notes | `Member__c.Medical_Notes__c` (Medical Notes) is a text area. The permission set does not hide it from other CRM fields. No separate medical-notes permission exists. |
| Substitute a class | No substitute-class action. |
| Create a member record | Staff create a member by converting a lead (below). There is no trainer "create member" screen. |

## Front desk: register a walk-in lead

**Verified from source, with a placement gap.** Component `epic04LeadRegistrationForm` shows a card titled **Walk-In Lead Registration**. It is allowed on an app page, record page, or home page. No page in source places it. **Needs an org click-through** to see whether the org has it on a screen that source does not.

When the card is on screen:

1. Enter **First Name**, **Last Name**, **Phone**, **Email**, and **Franchise Location**.
2. Franchise Location is a plain text box. Type the location record Id, not the gym name.
3. Click **Register Walk-In**.

Success text: `Lead registered successfully! Lead ID: ` plus the new Id. The form then clears First Name, Last Name, Phone, and Email.

The saved lead uses Lead Status **Walk-In** and Lead Source **In Person**. Phone must be a 10-digit number or the org validation rule rejects it. A duplicate email is rejected. The controller does not set program interest or a referral code.

Creating the lead any other way (including the API in US-D005) with `Referral_Code_Entered__c` set runs **EPIC01 Lead Referral Attribution** before save. A matching member code sets Referred By and Lead Source Referral. An unknown code still saves the lead and writes `Referral code not found — continuing without attribution` on Notes.

## Front desk: convert a lead to a member

**Verified from source, with a placement gap.** Quick action **Convert to Member** on Lead runs the screen flow **EPIC01 Convert Lead To Member**. Source has no Lead record page, so the button may be missing until it is added to the Lead page. **Needs an org click-through.**

1. Open the Lead.
2. Run **Convert to Member**.
3. Success screen **Lead Converted** shows the conversion message. The new Member is Status Prospect. A signed lead waiver is copied onto the Member. A task **Schedule first class for {name}** is created. If there is no signed waiver, the task subject is **Member needs to sign waiver before payment**.
4. The referring member, when there is one, gets a plain-text email: `Your referral {name} has joined Boxing Fitness Gym!`

These messages mean the convert did not happen:

| Message | What to do |
|---|---|
| Member already exists for this lead — view existing Member record | Open the linked Member. |
| Lead already converted to Member — view linked Member record | Open the linked Member. |
| Cannot convert disqualified lead — change status to Qualified first | The status value in the org is **Unqualified**. Set Lead Status to Qualified, then convert again. |
| Cannot convert: Lead has no Franchise Location assigned | Set Franchise Location on the lead, then convert again. |

**Unconvert** is on the Member record page. It runs only for a System Administrator, and only while the Member is still Prospect. It restores the lead to Qualified, detaches transferred waivers, and deletes the Member. Other statuses show **Only Prospect members can be unconverted**.

## Front desk: select a tier

**Verified from source.** On the Member record, **Select Membership Tier** runs **EPIC01 Select Membership Tier**.

1. Open the Member.
2. Click **Select Membership Tier**.
3. If the waiver gate fails, the screen **Waiver Required** shows the message and does not save a tier. Fix the waiver, then run the action again.
4. If the gate passes, choose a tier and finish. The screen says choosing a tier does not start the membership or set dates.

Tiers on the screen:

- Drop-In ($20/class)
- Punch Card (10 classes - $150)
- Monthly Unlimited ($129)
- Annual Prepaid ($99/mo)

Success screen **Ready for Payment**: `Tier saved: {tier}. Dates are still empty until payment.`

Waiver messages from the gate:

| Message | Meaning |
|---|---|
| Please sign your waiver first | No waiver on the member. |
| Your waiver is pending signature. Please complete it before continuing. | Latest relevant waiver is Pending. |
| Waiver has been revoked | Latest relevant waiver is Revoked. |
| Your waiver has expired on {date}. Please re-sign your waiver before continuing. | Last signed waiver is past its expiration date. |
| Your waiver is valid. You can proceed to payment. | Gate is open. |

A trial waiver that was signed on the lead and copied at conversion counts. Any Signed, unexpired waiver is enough, even if a newer waiver is still Pending.

To record a waiver: App Launcher → **Waiver Records** → New. Required links are a Waiver Template, the Member (or the Lead, before conversion), Status **Signed**, and an expiration date in the future. There is no signature-pad or digital-capture screen.

When a Prospect gets a valid Signed waiver, **EPIC01 Waiver Confirmed Notify** creates a task and sends `Your waiver is confirmed! You can now proceed to payment.`

## Front desk: take a membership payment

**Verified from source.** On the Member record, **Process Membership Payment** runs **EPIC01 Process Membership Payment**. The processor is simulated. There is no Stripe charge.

1. Open the Member. A tier must already be saved.
2. Click **Process Membership Payment**.
3. If the gate fails, **Cannot Take Payment** shows the waiver or tier message. No payment record is created.
4. On **Collect Payment**, the screen shows the tier and the line `Processor is simulated (no Stripe). Cash never declines.`
5. **Amount** is prefilled: Drop-In `20.00`, Monthly `129.00`, Punch Card `150.00`, Annual `1188.00` (99 × 12). Staff can change it.
6. **Payment Method**: **Credit Card** or **Cash (paid in person)**. Cash is stored as Cash.
7. Finish.

Success screen **Payment Completed** includes `Payment completed` and `Member is now Active. A receipt was emailed when an address is on file.` A welcome email can also send. See US-D006 if the member has no email.

What payment writes:

| Tier | Dates and classes |
|---|---|
| Drop-In ($20/class) | Status Active. Start and expiry stay empty. Classes Remaining stays 0. |
| Monthly Unlimited ($129) | Start today, expiry in 30 days. A task **Process recurring payment for {name}** is due in 30 days. That task is not a subscription. |
| Annual Prepaid ($99/mo) | Start today, expiry in 365 days. |
| Punch Card (10 classes - $150) | Start today, expiry in 180 days. Classes Remaining becomes 10. |

Card decline: screen **Payment Failed**, message `Payment failed. A retry task was created.` The member stays Prospect. Task subject: `Retry payment for {name}`.

The 50% referred-friend discount is a calculator in Apex (`calculatePaymentWithReferralDiscount`). The payment screen does not apply it. Staff who want that price type half the amount.

## Front desk: book a class

**Verified from source.** Inserting a Booking fails unless the member is Active and has a valid signed waiver. Messages:

- `Membership not active — please complete payment`
- `Cannot book class — member does not have a valid signed waiver`
- `Cannot book class — member's waiver has expired`
- `Cannot book class — member's waiver is pending signature`
- `Cannot book class — member's waiver has been revoked`

A punch-card booking decrements Classes Remaining. There is no front-desk booking wizard in source. Staff create a Booking record.

## Front desk stories that are not built

**Not built.**

- Renew a membership. Paying again is the same **Process Membership Payment** action. There is no renewal screen.
- Capture a digital waiver. Waiver Records are data entry.
- Sell merchandise. Merchandise Sale and Sale Line Item exist as objects. There is no sale screen.
- Apply a discount with manager approval. No approval process.
- Refund or return. No refund action.

## How to verify this draft

1. In **Boxing Gym CRM**, open a Member and confirm **Select Membership Tier**, **Process Membership Payment**, and **Unconvert** are on the record.
2. Confirm whether **Convert to Member** is visible on a Lead. Source does not place it.
3. Confirm whether **Walk-In Lead Registration** is on any page. Source does not place it.
4. Run the tier action with no Signed waiver and expect **Waiver Required**.
5. Do not expect QR check-in, merchandise, or refunds. Those sections stay **Not built** until the feature exists.
