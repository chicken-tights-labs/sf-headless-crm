# EPIC-11 / US-D001 — End User Manual (Trainers + Front Desk)

Issue: #37. Kanban: `t_9d84897e`.

**Status:** Draft
**Last verified:** 2026-10-27 against branch `feat/EPIC04-USF008-merchandise-refund`
**Checked from:** source in `force-app` (not an org click-through)
**Still open:** screenshots in `my-gym`

This is the canonical copy. The issue names `CRM-Documentation/EPIC-11_D001_End_User_Manual.md`. Sync that vault from this file when the vault is available.

Sections are marked **Verified from source**, **Not built**, or **Needs an org click-through**.

Admin setup (users, the permission set, locations, waiver templates, tier values) is US-D004.

## Where staff work

**Verified from source.** The Lightning app is **Boxing Gym CRM**. Front-desk steps below use that app. There is no trainer mobile app in source. Trainers will work in the Boxing Gym CRM app on a Salesforce Platform license ([licensing decision](licensing-and-architecture.md)).

## Trainer workflows

**Partially built.** My schedule (this week), class attendee roster, Mark Attended (with waiver block), phone check-in, QR check-in, trainer member profile (with permission-gated medical notes), New Member (walk-in to Prospect, optional payment), and class substitute are in the Boxing Gym CRM app.

### Trainer: view my schedule

**Verified from source.** Open the **Boxing Gym CRM** app from the App Launcher. On **Home**, the **My schedule** card lists classes assigned to the logged-in user for the current week. The **My Schedule** tab shows the same list (useful if Home is not the custom page). Home is wired in app metadata (`Gym_Manager_Home`), not via Setup Lightning Pages activation.

Each row shows session name (opens the Scheduled Session), start time, location, booked count (non-cancelled bookings), and capacity (`Max_Capacity__c`). Cancelled sessions and other trainers' classes do not appear. Sessions with no start time in this week do not appear.

### Trainer: view class attendees and mark attended

**Verified from source.** Open a **Scheduled Session** in Boxing Gym CRM. The **Attendees** tab (default) lists every booking for that session: member name, check-in status (`Checked in` / `Not checked in` / `No-Show` / `Cancelled`), waiver status, and booking status.

1. Open the row menu → **Mark Attended**.
2. On success: booking `Status__c = Completed` and `Checked_In_At__c` is set. There is no Attended picklist value.
3. Without a valid Signed waiver: blocked with `Cannot check in - member does not have a valid signed waiver`. Capture a waiver (US-F005), then retry. The booking insert trigger is not used at check-in.

### Trainer: check in by phone

**Verified from source.** On the same **Attendees** tab, enter a phone number and click **Find**. The search compares digits only (punctuation and a leading `+1` are ignored) to `Phone` on bookings for **this class**. It does not check anyone in.

1. One match: the member name appears with **Confirm check-in**.
2. Several bookings share that phone: click **Select** on one name, then **Confirm check-in**.
3. Confirm runs the same **Mark Attended** action, including the waiver block. A missing booking is not created.
4. No booking on this class for that phone: `No booking on this class matches that phone.`
5. Blank or not 10 digits: `Enter a 10-digit phone number.` Nothing is searched.

### Trainer: check in by QR code

**Verified from source.** On the same **Attendees** tab, type a check-in code or click **Check in**. A handheld scanner can type the code and press Enter. On the Salesforce mobile app, **Scan QR** uses the camera. A desktop browser has no camera button.

A scan looks up `Check-In Code` on bookings for **this class**. One match runs **Mark Attended**, including the waiver block. It does not create a booking. No match: `No booking on this class matches that code.`

The code is a random value on the member. It is not the phone number or email. **Replace check-in code** on the Member page overwrites it. The previous code stops working. The wallet pass and fob that show the code are #64, outside this repo.

### Trainer: substitute for a class

**Verified from source.** **Substitute** is on the Scheduled Session highlights panel in Boxing Gym CRM. Open the class from **Scheduled Session → This Week's Classes**. My schedule still lists only classes assigned to you. **Needs an org click-through** for screenshots.

1. Open a class whose Assigned Trainer is someone else, and whose status is Scheduled.
2. Click **Substitute**.

You are stored in **Substitute Trainer**. Assigned Trainer does not change. Start time does not change. The assigned trainer gets an email, subject `Substitute covering your class`, saying you are covering the class and they remain the assigned trainer. A missing email or a mail failure still saves the substitute. The screen says which of those happened.

These clicks do not change the class:

| Message                                              | What happened                             |
| ---------------------------------------------------- | ----------------------------------------- |
| You are already the assigned trainer for this class. | You cannot substitute for your own class. |
| You are already the substitute for this class.       | You are already covering it.              |
| This class already has a substitute.                 | Someone else is already the substitute.   |
| Cancelled classes cannot be covered.                 | Status is Cancelled.                      |
| Completed classes cannot be covered.                 | Status is Completed.                      |

### Trainer: create a member from a walk-in

**Verified from source.** The **New Member** card is on Boxing Gym CRM **Home**, under **My schedule**. It is not on the My Schedule tab. **Needs an org click-through** for screenshots.

1. Enter **First Name**, **Last Name**, **Phone**, and **Email**.
2. Pick the gym from **Franchise Location**. The list is the same active-location list as Walk-In Lead Registration.
3. Click **New Member**.

The card calls the existing walk-in action (`EPIC04_LeadRegistration_Controller.createLead`), then the existing convert action (`EPIC01_LeadConversion_Action`). The lead is Walk-In / In Person, and the member is **Prospect**. No payment record is created. The card says the member stays Prospect until payment succeeds, and links to the member.

4. Click **Take payment** only if they are paying now. That opens the existing **Process Membership Payment** flow (`EPIC01_Process_Membership_Payment`). Active still comes from that flow. A missing signed waiver blocks payment and leaves the member Prospect. Click **Done** to register someone else without paying.

If the name or gym is missing, the card does not call Apex. If the lead saves and conversion fails, the form closes. The card shows the conversion message plus `The walk-in lead was saved. Open the lead and use Convert to Member.`, and an **Open lead** link. **Try convert again** calls convert for that same lead. **Done** clears the card so the next **New Member** starts a new walk-in.

| Asked for                 | What exists                                                                                                                                                                                                                       |
| ------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| View my class schedule    | **Verified from source.** **My schedule** on Home and the **My Schedule** tab list this week's classes assigned to you (US-T001).                                                                                                 |
| Check in by QR code       | **Verified from source.** On the session **Attendees** tab, a typed or scanned code matches this class. One match calls Mark Attended (US-T002). **Replace check-in code** on the Member page overwrites the code.                |
| Check in by phone lookup  | **Verified from source.** On the session **Attendees** tab, **Find** matches a 10-digit phone to this class's bookings. **Confirm check-in** calls Mark Attended (US-T003). A member who is not booked is not added.              |
| Mark attendance           | **Verified from source.** Row action **Mark Attended** on the Attendees tab (US-T005 / US-T006).                                                                                                                                  |
| View class attendee lists | **Verified from source.** On a Scheduled Session, the **Attendees** tab lists bookings with member name, check-in status, and waiver status (US-T004).                                                                            |
| Open a member profile     | **Verified from source.** From a session **Attendees** list, click the member name. The Member page shows a read-only **Trainer profile** card (name, tier, status, expiry). There is no separate trainer app.                    |
| View medical notes        | **Verified from source.** On **Trainer profile**, medical notes appear only with `Boxing_Gym_Trainer_Medical_Notes` (read-only). Shared `Boxing_Gym_CRM_Access` does not grant the field. Members update notes in the member app. |
| Substitute a class        | **Verified from source.** On a Scheduled Session you are not assigned to, **Substitute** sets Substitute Trainer to you and emails the assigned trainer (US-T010). Assigned Trainer and the class time stay the same.             |
| Create a member record    | **Verified from source.** **New Member** on Home creates a walk-in lead and converts it to a Prospect (US-T008). **Take payment** opens Process Membership Payment. Skipping payment leaves the member Prospect.                  |

## Front desk: register a walk-in lead

**Verified from source.** The card **Walk-In Lead Registration** is on the **Home** tab of the Boxing Gym CRM app (page **Gym Manager Home**), in the Members & Leads column. Desktop only; the app's home page override is set for large screens. **Needs an org click-through** for screenshots.

1. Open **Boxing Gym CRM**, then **Home**.
2. Enter **First Name**, **Last Name**, **Phone**, and **Email**.
3. Pick the gym from **Franchise Location**. The list shows active locations by name.
4. Click **Register Walk-In**.

Success text: `Lead registered successfully! Lead ID: ` plus the new Id. The form then clears First Name, Last Name, Phone, and Email. Franchise Location stays selected for the next walk-in.

If the list is empty, the card says `No active gym locations found. Ask an admin to add one.` A location must have Status **Active** to appear (US-D004). If the list fails to load, the card says `Could not load gym locations. Refresh the page and try again.`

The saved lead uses Lead Status **Walk-In** and Lead Source **In Person**. Phone must be a 10-digit number or the org validation rule rejects it. A duplicate email is rejected. The controller does not set program interest or a referral code.

Creating the lead any other way (including the API in US-D005) with `Referral_Code_Entered__c` set runs **EPIC01 Lead Referral Attribution** before save. A matching member code sets Referred By and Lead Source Referral. An unknown code still saves the lead and writes `Referral code not found — continuing without attribution` on Notes.

## Front desk: convert a lead to a member (and take first payment)

**Verified from source.** Quick action **Convert to Member** on Lead runs **EPIC04 Convert Lead And Pay**. The Lead record page (**Lead Record Page**) is in source and is the Boxing Gym CRM View override for Lead, with the button in the highlights panel. **Needs an org click-through** for screenshots.

1. Open the Lead (Leads tab or from a recent walk-in).
2. Click **Convert to Member**.
3. Conversion runs first (same engine as EPIC-01 US-002). Screen **Lead Converted — Continue to Payment** shows the conversion message. The new Member is Status **Prospect**. A signed lead waiver is copied onto the Member. A task **Schedule first class for {name}** is created. If there is no signed waiver, the task subject is **Member needs to sign waiver before payment**. The referring member, when there is one, gets: `Your referral {name} has joined Boxing Fitness Gym!`
4. Finish that screen. The flow continues into the same payment screens as **Process Membership Payment** (waiver gate, confirm tier, collect payment). Active comes from a successful payment, not from conversion alone.
5. If the waiver gate blocks payment, the Member stays Prospect. Fix the waiver, then use **Process Membership Payment** on the Member (or convert again only if conversion had failed).

These messages mean the convert step did not happen (payment never starts):

| Message                                                             | What to do                                                                                        |
| ------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| Member already exists for this lead — view existing Member record   | Open the linked Member. Use **Process Membership Payment** if they still need first payment.      |
| Lead already converted to Member — view linked Member record        | Open the linked Member.                                                                           |
| Cannot convert disqualified lead — change status to Qualified first | The status value in the org is **Unqualified**. Set Lead Status to Qualified, then convert again. |
| Cannot convert: Lead has no Franchise Location assigned             | Set Franchise Location on the lead, then convert again.                                           |

Walk-In leads convert. The field is **Lead Status** (`Lead_Status__c`), not `Status__c`.

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

| Message                                                                          | Meaning                                         |
| -------------------------------------------------------------------------------- | ----------------------------------------------- |
| Please sign your waiver first                                                    | No waiver on the member.                        |
| Your waiver is pending signature. Please complete it before continuing.          | Latest relevant waiver is Pending.              |
| Waiver has been revoked                                                          | Latest relevant waiver is Revoked.              |
| Your waiver has expired on {date}. Please re-sign your waiver before continuing. | Last signed waiver is past its expiration date. |
| Your waiver is valid. You can proceed to payment.                                | Gate is open.                                   |

A trial waiver that was signed on the lead and copied at conversion counts. Any Signed, unexpired waiver is enough, even if a newer waiver is still Pending.

## Front desk: capture a digital waiver

**Verified from source.** On a Member or Lead record, **Capture Waiver** opens the signature pad (`epic04CaptureDigitalWaiver`).

1. Open the Member or Lead (Franchise Location must be set).
2. Click **Capture Waiver**.
3. Confirm signer name, email, role, and waiver template (Adult template is preferred when present).
4. Ask the visitor to sign on the pad.
5. Click **Save signed waiver**.

What it writes:

- A `Waiver_Record__c` with Status **Signed**, Signature Method **Digital In-Person**, effective today, expiration in 365 days.
- A PNG signature file attached to that waiver.
- On a Member: `Waiver_Needed__c = false` and `Waiver_Signed__c` points at the new record.

Staff can still create a Waiver Record manually (App Launcher → **Waiver Records** → New) if needed.

When a Prospect gets a valid Signed waiver, **EPIC01 Waiver Confirmed Notify** creates a task and sends `Your waiver is confirmed! You can now proceed to payment.`

## Front desk: take a membership payment

**Verified from source.** On the Member record, **Process Membership Payment** runs **EPIC01 Process Membership Payment**. The processor is simulated. There is no Stripe charge.

1. Open the Member.
2. Click **Process Membership Payment**.
3. If the member is already **Active**, screen **Already Active** says no payment was taken and to use **Renew Membership** instead. Every other status continues.
4. If the waiver gate fails, **Cannot Take Payment** shows the waiver message. No payment record is created.
5. On **Confirm Membership Tier**, pick Drop-In, Punch Card, Monthly Unlimited, or Annual Prepaid. The member's saved tier is preselected. Choosing a different tier saves it on the Member before payment.
6. On **Collect Payment**, the screen shows the tier and the line `Processor is simulated (no Stripe). Only Credit Card and Debit Card can decline.`
7. **Amount** is prefilled from the chosen tier: Drop-In `20.00`, Monthly `129.00`, Punch Card `150.00`, Annual `1188.00` (99 × 12). Staff can change it.
8. **Payment Method**: **Credit Card**, **Debit Card**, **Cash (paid in person)**, **Check**, **ACH**, or **Gift Card**. The choice is stored as the transaction method. Cash is stored as Cash.
9. Finish.

Success screen **Payment Completed** includes `Payment completed` and `Member is now Active. A receipt was emailed when an address is on file.` A welcome email can also send. See US-D006 if the member has no email.

What payment writes:

| Tier                           | Dates and classes                                                                                                                   |
| ------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------- |
| Drop-In ($20/class)            | Status Active. Start and expiry stay empty. Classes Remaining stays 0.                                                              |
| Monthly Unlimited ($129)       | Start today, expiry in 30 days. A task **Process recurring payment for {name}** is due in 30 days. That task is not a subscription. |
| Annual Prepaid ($99/mo)        | Start today, expiry in 365 days.                                                                                                    |
| Punch Card (10 classes - $150) | Start today, expiry in 180 days. Classes Remaining becomes 10.                                                                      |

Card decline (Credit Card or Debit Card only): screen **Payment Failed**, message `Payment failed. A retry task was created.` The member stays Prospect. Task subject: `Retry payment for {name}`. If the tier was changed on step 5, the new tier stays saved.

The 50% referred-friend discount is a calculator in Apex (`calculatePaymentWithReferralDiscount`). The payment screen does not apply it. Staff who want that price type half the amount.

## Front desk: renew a membership

**Verified from source.** On an Active Member, **Renew Membership** runs **EPIC04 Renew Membership**. It does **not** call Process Membership Payment / `processPayment`.

1. Capture a new waiver today (**Capture Waiver**) if one was not already signed today.
2. Open the Member → **Renew Membership**.
3. Confirm the tier (optional change is saved on the Member).
4. Enter amount and payment method (same method list as first payment; processor is simulated).
5. Finish.

Rules:

- Member must be **Active**. Prospects use **Process Membership Payment**.
- Non–Drop-In tiers: `Expiry_Date__c` must be today or earlier (not due yet → blocked).
- Waiver: Signed with `Signature_Timestamp__c` on/after today. An older valid waiver is not enough for renewal.
- Expiry extends from the later of today and the current expiry (Monthly +30, Annual +365, Punch +180 and +10 classes). `Start_Date__c` is unchanged.
- Creates a Completed `Payment_Transaction__c`. Does not resend the welcome email or award the referral again. A receipt can still email.

## Front desk: book a class

**Verified from source.** Inserting a Booking fails unless the member is Active and has a valid signed waiver. Messages:

- `Membership not active — please complete payment`
- `Cannot book class — member does not have a valid signed waiver`
- `Cannot book class — member's waiver has expired`
- `Cannot book class — member's waiver is pending signature`
- `Cannot book class — member's waiver has been revoked`

A punch-card booking decrements Classes Remaining. There is no front-desk booking wizard in source. Staff create a Booking record.

## Front desk: sell merchandise

**Verified from source.** **Sell Merchandise** is on Boxing Gym CRM **Home**, under Walk-In Lead Registration.

1. Choose the gym. The item list is active, in-stock inventory at that gym.
2. Find the member (at least two characters) and select them.
3. Choose an item and quantity, then **Add to cart**. Quantity cannot exceed stock. Adding the same item again increases the quantity.
4. Choose a payment method: Cash, Card, Account Credit, or Gift Card.
5. **Complete sale.**

What it writes:

- `Merchandise_Sale__c` with the member, gym, payment method, and total.
- One `Sale_Line_Item__c` per item. The price is `Unit_Price__c` at that moment.
- `Inventory_Item__c.Current_Stock__c` goes down by the quantity sold.
- `Payment_Transaction__c` with type Merchandise Purchase and status Completed. Card is stored as Credit Card. Cash, Gift Card, and Account Credit keep those names.

This screen does not call **Process Membership Payment**. A merchandise sale does not change membership dates, send the welcome email, or award a referral.

### Discount

**Verified from source.** On the same card, before payment:

- Leave discount and promo code blank to charge full price.
- **Discount %** of 1 to 10 needs no PIN. The sale records you as Discount Approved By, reason Staff discount.
- **Discount %** above 10 shows **Manager PIN**. A wrong or missing PIN refuses the sale and leaves stock unchanged. The message is `Manager approval required for this discount tier`. The approver stored is the manager whose PIN matched.
- **Promo code** uses a code a manager created. It can be any percent from 1 to 99 and does not ask for a PIN. A code that is inactive or past its expiration date is refused. A code is valid through the end of its expiration date. There is no usage limit.
- Enter a percent or a promo code, not both.
- Line items stay at shelf price. The sale total and the payment use the discounted amount.

Managers with **Boxing Gym Manager** see **Merchandise manager PIN** on Home and can replace their own 4 to 6 digit PIN. They create codes on the **Promo Code** tab. Front desk cannot read the stored PIN.

## Front desk: refund a merchandise sale

**Verified from source.** This is a full refund of one merchandise sale. It does not refund a membership.

1. Open **Merchandise Sales** from the App Launcher. That tab is not on the Boxing Gym CRM bar.
2. Open the sale. **Refund** is on the record.
3. Enter a reason. There is no manager PIN and no amount to type.
4. Finish.

What it writes:

- `Merchandise_Sale__c.Status__c` becomes Refunded. The reason is stored on Refund Reason.
- Sold quantity goes back onto `Inventory_Item__c.Current_Stock__c`.
- A new `Payment_Transaction__c` with type Refund and status Completed. The amount is the sale total (what the member paid, after any discount). Card is stored as Credit Card. The payment points at this sale.

The original Merchandise Purchase payment stays Completed. The member’s status and dates do not change. A sale that is already Refunded cannot be refunded again. A sale with no status yet can be refunded once.

## Front desk stories that are not built

**Not built.**

- Partial merchandise refunds, and any membership refund.

## How to verify this draft

1. In **Boxing Gym CRM**, open a Member and confirm **Capture Waiver**, **Select Membership Tier**, **Process Membership Payment**, **Renew Membership**, and **Unconvert** are on the record.
2. On a Lead, confirm **Capture Waiver** and **Convert to Member** are on the record.
3. Confirm **Walk-In Lead Registration** is on **Home** (Gym Manager Home).
4. Run **Capture Waiver**, sign the pad, and confirm a Signed Waiver Record appears.
5. Run the tier action with no Signed waiver and expect **Waiver Required**.
6. On **Home**, confirm **Sell Merchandise** is under Walk-In Lead Registration. A discount above 10% asks for a manager PIN. Open a Merchandise Sale from the App Launcher and confirm **Refund** asks for a reason. QR check-in is on the session Attendees tab.
7. On **Home**, under **My schedule**, confirm **New Member**. Creating a member without **Take payment** leaves Status **Prospect**.
8. On a Scheduled Session you are not assigned to, click **Substitute**. Assigned Trainer stays the same and Substitute Trainer is you.
