# Journey Maps — Salesforce Headless CRM (NBS Gym)

## Legend
- 🟢 **Object** = Salesforce custom object (from `sf-project` schema)
- 🟤 **Task** = Kanban user story ID on `salesforce-headless-dev` board
- 🟡 **Step** = Touchpoint in the persona's journey
- 🔵 **Output** = What the system delivers to the user

---

## JOURNEY 1: Walk-In Lead → Active Member

### Persona: Prospective Customer (Walk-In or Web)

| Phase | Touchpoint | Object | Task ID | System Output |
|-------|------------|--------|---------|---------------|
| **Awareness** | Sees gym signage / social post | 📄 Lead__c | t_b9d75b17 | Lead captured in CRM |
| **Capture** | Front desk scans QR or fills web form | 📄 Lead__c | t_b9d75b17 | Lead record created |
| **Trial** | Books & attends free class | 📄 Booking__c, 📄 Waiver_Record__c | t_6b7f8d51 | Booking linked + waiver signed |
| **Evaluation** | Trainer notes interest / questions | 📄 Member__c (pending) | t_4f0ffc9f | Trainer records notes |
| **Conversion** | Staff converts lead → member, collects deposit | 📄 Lead__c → Member__c | t_c3f762c7 | Member created, Lead status = Converted |
| **Payment** | Member pays dues via POS terminal | 📄 Order__c, 📄 Payment__c | t_676a32c0 | Payment captured |
| **Activation** | Waiver transferred, membership start date set | 📄 Waiver_Record__c, 📄 Membership__c | t_94d7d834 | Active member status set |
| **Ongoing** | Member books recurring classes | 📄 Booking__c | t_c21aec23 | Calendar populated |

### Key Integrations
- POS system pushes payment data to `Payment__c` (US-F004)
- E-signature tool writes to `Waiver_Record__c` (US-F005)
- Member Portal reads from `Membership__c` + `Booking__c`

---

## JOURNEY 2: Trainer — Daily Operations

### Persona: Gym Trainer (Boxing / Fencing Coach)

| Phase | Touchpoint | Object | Task ID | System Output |
|-------|------------|--------|---------|---------------|
| **Login** | Opens tablet app at gym start | 📄 User__c (role = Trainer) | t_716de98a | Dashboard loads today’s classes |
| **Schedule** | Views assigned classes | 📄 Scheduled_Session__c | t_716de98a | List of upcoming sessions |
| **Check-In** | Scans member QR or enters phone number | 📄 Check_In__c | t_78422857, t_9837744a | Attendance logged |
| **Attendee Review** | Taps session to see roster | 📄 Check_In__c | t_c21aec23 | List of checked-in members |
| **Attendance** | Marks participants present | 📄 Check_In__c | t_45806d09 | Real-time attendance update |
| **New Member** | Adds walk-in to session | 📄 Member__c | t_5f743612 | New member record created |
| **Medical Alert** | Flags injury concern | 📄 Medical_Note__c | t_4f0ffc9f | Medical alert shown on profile |
| **Profile** | Reviews member payment status | 📄 Member__c, 📄 Payment__c | t_17178f4d | Payment history visible |
| **Substitute** | Can't make class → marks substitute | 📄 Scheduled_Session__c | t_e5ecb0fe | Substitute assigned, notif sent |
| **Waiver** | System blocks session entry | 📄 Waiver_Record__c | t_a79785a7 | Red flag on member card |

### Key Integrations
- Member Portal feeds upcoming bookings to trainer app
- Health records (Medical_Note__c) are read-only for trainers
- Offline-first design (no internet = cached last 7 days)

---

## JOURNEY 3: Management / Front-Desk Staff

### Persona: Gym Manager / Owner / Front Desk

| Phase | Touchpoint | Object | Task ID | System Output |
|-------|------------|--------|---------|---------------|
| **Login** | Accesses dashboard via web portal | 📄 User__c (role = Staff) | t_f19ed172 | Role-based dashboard loads |
| **Member Lookup** | Searches member by name/phone | 📄 Member__c | t_4f0ffc9f | Member card with full history |
| **New Member Creation** | Manually enters offline sign-up | 📄 Member__c | t_5f743612, t_c3f762c7 | Record created + welcome flow triggered |
| **Membership Renewal** | Processes annual renewal | 📄 Membership__c | t_94d2d834 | New expiration date set |
| **Payment Processing** | Handles cash/check/card payments | 📄 Payment__c | t_676a32c0, t_2292b443 | Receipt printed |
| **Discount Approval** | Reviews/approves 50%+ discount requests | 📄 Discount_Request__c | t_2292b443 | Approval logged |
| **Refund / Return** | Processes membership cancellation | 📄 Refund__c | t_e22d7ba3 | Refund record + audit trail |
| **Merch Sales** | Ring up merchandise sales | 📄 Merch_Item__c, 📄 Sale__c | t_cc2cae33 | Inventory decremented, payment captured |
| **Reporting** | Runs occupancy/revenue reports | 📄 All objects (roll-up summaries) | t_7b14be8b | Dashboard widgets populated |
| **Compliance Check** | Reviews expiring waivers | 📄 Waiver_Record__c | t_e22d7ba3 | Compliance status alert |

### Key Integrations
- POS system (Shopify/Stripe) syncs to `Order__c` and `Payment__c`
- External accounting software pulls `Order__c` data nightly
- Manager Portal shows compliance alerts (EPIC-02 waiver expiry engine)

---

## Cross-Referenced Objects (from sf-project schema)

| Object Name | Purpose | Linked From |
|-------------|---------|-------------|
| Lead__c | Prospective customers | EPIC-03 US-T001, US-T002 |
| Member__c | Paid/active customers | EPIC-04 US-F002, US-F008 |
| Booking__c | Class reservations | Journeys 1, 2 |
| Scheduled_Session__c | Class schedule | Journey 2 |
| Check_In__c | Attendance tracking | Journey 2 |
| Waiver_Record__c | Legal compliance docs | Journeys 1, 3 |
| Membership__c | Subscription details | Journeys 1, 3 |
| Payment__c | Transaction log | EPIC-04 US-F004 |
| Order__c | POS sales record | EPIC-04 US-F004, US-F006 |
| Discount_Request__c | Manager approval workflow | EPIC-04 US-F007 |
| Refund__c | Cancellation / return log | EPIC-04 US-F008 |
| Medical_Note__c | Health records | Journey 2 |
| Merch_Item__c | Retail inventory | EPIC-04 US-F006 |
| Sale__c | Merchandise transactions | EPIC-04 US-F006 |
| User__c | Staff identity (roles) | All journeys |

## Gaps Identified
1. **Lead Source Tracking**: Not represented in current US stories → future epic?
2. **Loyalty Points / Referrals**: Partially covered (US-F007 discount) but no dedicated referral engine
3. **Email/SMS Notifications**: No explicit notification object — assumed external tool via API

Tags: #journey-mapping #salesforce-crm #nbs-gym #user-stories