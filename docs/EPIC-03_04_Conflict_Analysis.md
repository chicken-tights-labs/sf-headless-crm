# EPIC Conflict & Dependency Analysis — sf-headless-crm

> **Date:** 2026-10-09
> **Branch:** `feat/EPIC11-USD004-system-admin-guide` (draft guides checked out)
> **Status:** ✅ C1, C3, C4 resolved. US-F001 already implemented in origin/main. Ready for US-F002 issue + branch.
> **Decisions:** C1 ✅ (US-F002 owns conversion), C3 ✅ (US-F001 owns lead creation), C4 ✅ (US-F004 is UI layer over EPIC-01 payment)

---

## 🔴 Conflicts (High Risk — Decide Before Implementing)

| #      | Conflict                                        | Stories Involved                                                             | Risk                                                                                                                                                                                                                                               | Recommendation                                                                                                                                                                                                                                                                                                                                                          |
| ------ | ----------------------------------------------- | ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **C1** | **Lead → Member conversion owned by two EPICs** | US-T008 (Trainer Create Member) ↔ US-F002 (Convert Lead to Member)           | `EPIC01_LeadConversion_Action.cls` + `EPIC01_Convert_Lead_To_Member.flow` already exist in main (EPIC-01 US-002, PR #30). Both stories map to the same conversion logic.                                                                           | **✅ RESOLVED 2026-10-09.** **Single owner: US-F002.** US-F002 reuses `EPIC01_LeadConversion_Action` (the `@InvocableMethod` flow action). US-T008 (Trainer Create Member) calls the **same** action — no new conversion path. The trainer app invokes `EPIC01_LeadConversion_Action.convert(leadId)` via the same flow or a direct Apex REST endpoint. No duplication. |
| **C2** | **Waiver enforcement logic duplicated**         | US-T006 (Trainer Waiver Block) ↔ EPIC-01 US-007 (Booking Waiver Enforcement) | `EPIC01_BookingWaiverGuard.trigger` (runs on `before insert, after insert` of `Booking__c`) already blocks bookings without a valid waiver. If US-T006 adds a separate trainer-side waiver check, you get two enforcement points that can diverge. | US-T006 should **reference** the existing trigger logic, not re-implement. The trigger is the single enforcement point.                                                                                                                                                                                                                                                 |
|        | **C3**                                          | **Lead creation owned by two EPICs**                                         | US-T008 (Trainer Create Member) ↔ US-F001 (Register Walk-In Lead)                                                                                                                                                                                  | `EPIC04_LeadRegistration_Controller.cls` (with `createLead()`) already creates walk-in leads — verified in origin/main. US-T008 "Trainer Create Member" may also need lead creation (trainer registers a walk-in who becomes a member on the spot).                                                                                                                     | **✅ RESOLVED 2026-10-09.** **US-F001 owns lead creation.** US-T008 (Trainer Create Member) calls the **same** `EPIC04_LeadRegistration_Controller.createLead()` method. The trainer app registers a walk-in by calling the shared controller, then optionally invokes `EPIC01_LeadConversion_Action` to convert immediately. One lead creation entry point — the LWC form is front-desk POS; the controller is the API for trainers.                                                                         |
|        | **C4**                                          | **Payment processing overlap**                                               | US-F004 (Process Payment) ↔ EPIC-01 US-004 (Payment Processing)                                                                                                                                                                                    | `EPIC01_ProcessPayment_Action.cls` (`@InvocableMethod` label "Process Membership Payment") and `EPIC01_Process_Membership_Payment.flow` already exist in main (EPIC-01 US-004, PR #44). `EPIC01_MemberOnboarding_Service.processPayment()` handles dates, status, Payment_Transaction__c, referral rewards, receipts, welcome email.                                    | **✅ RESOLVED 2026-10-09.** **EPIC-01 US-004 owns payment logic.** US-F004 is a **UI layer only** — a POS-specific screen Flow or LWC that calls `EPIC01_ProcessPayment_Action.pay()` (the same invocable method the EPIC-01 flow uses). It does NOT build a second payment engine. US-F004 may add a "Renew" quick action on Member__c that wires a new Flow to the existing `@InvocableMethod`, but the underlying Apex service (`EPIC01_MemberOnboarding_Service.processPayment`) is shared and unchanged. |
|        | **C5**                                          | **Member object fields — who owns schema?**                                  | US-T007 (Trainer View Profile) ↔ US-F003 (Renew Membership) ↔ US-D004 (Admin Guide)                                                                                                                                                                | Trainer profile viewing may need fields that POS renewal also touches (tier, dates, status). If both stories add fields independently, you get merge conflicts in `Member__c.object-meta.xml`.                                                                                                                                                                          | **Schema changes go through one PR per EPIC.** EPIC-03 adds trainer-facing fields, EPIC-04 adds POS-facing fields. Coordinate field names upfront.                                                                                                                                                                                                                                                                                                                                                            |

---

## 🟡 Dependencies (Medium Risk — Sequencing Matters)

| #       | Dependency                                                                                                                                         | Blocks           | Type                      | Status                                           |
| ------- | -------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------- | ------------------------- | ------------------------------------------------ |
| **D1**  | `Convert_Lead_To_Member` flow must exist before US-T008 can call it                                                                                | US-T008          | Hard (upstream)           | ✅ Flow exists in `force-app`                    |
| **D2**  | `BookingWaiverGuard.trigger` must exist before US-T006 can reference it                                                                            | US-T006          | Hard (upstream)           | ✅ Trigger exists                                |
| **D3**  | `EPIC01_ProcessPayment_Action.cls` must exist before US-F004 can call it                                                                           | US-F004          | Hard (upstream)           | ✅ Action exists                                 |
| **D4**  | `EPIC04_LeadRegistration_Controller.cls` must exist before US-T008 can extend it                                                                   | US-T008          | Hard (upstream)           | ✅ Controller exists                             |
| **D5**  | Trainer app needs a "New Lead" form (from EPIC-01 US-001 walk-in scenario) before US-T002 (QR Check-In) and US-T003 (Phone Check-In) can be tested | US-T002, US-T003 | Medium (test data)        | ✅ Controller exists; form UI not built          |
| **D6**  | `Scheduled_Session__c` must have sessions before US-T001 (View Schedule) and US-T004 (View Attendees) can be tested                                | US-T001, US-T004 | Medium (test data)        | ✅ Object exists; no seed data yet               |
| **D7**  | `Member__c.Medical_Notes__c` must be visible to trainer profiles before US-T009 (View Medical Notes) can be verified                               | US-T009          | Hard (security)           | ✅ Field exists; permset assignment needed       |
| **D8**  | `Waiver_Record__c` must have records before US-T006 (Waiver Block) can be tested                                                                   | US-T006          | Medium (test data)        | ✅ Object exists; no seed data yet               |
| **D9**  | `Inventory_Item__c` and `Product_Category__c` must have data before US-F006 (Merchandise Sale) can be tested                                       | US-F006          | Medium (test data)        | ✅ Objects exist; no seed data yet               |
| **D10** | `Merchandise_Sale__c` and `Sale_Line_Item__c` must exist before US-F008 (Refund/Return) can process returns                                        | US-F008          | Hard (upstream)           | ✅ Objects exist                                 |
| **D11** | `Royalty_Report__c` must have data before US-D003 (Franchise Owner Guide) can document royalty dashboards                                          | US-D003          | Medium (doc verification) | ✅ Object exists; no data yet                    |
| **D12** | `BookingWaiverGuard.trigger` must be deployed to the org before US-T006 can be verified with a live org check                                      | US-T006          | Hard (deploy)             | ✅ Trigger in `force-app`; deploy status unknown |

---

## 🟢 Cross-EPIC Shared Components (Must Be Coordinated)

| Component                 | EPIC-03 (Trainer)                       | EPIC-04 (POS)                 | EPIC-11 (Docs)              | Coordination Needed                                                              |
| ------------------------- | --------------------------------------- | ----------------------------- | --------------------------- | -------------------------------------------------------------------------------- |
| `Member__c` fields        | Views: profile, medical notes, schedule | Edits: tier, payment, renewal | Documents: all fields       | One schema change per EPIC; no simultaneous edits to `Member__c.object-meta.xml` |
| `Lead__c` fields          | Views: lead details                     | Creates: walk-in leads        | Documents: lead capture     | US-F001 owns creation; US-T008 reads                                             |
| `Waiver_Record__c`        | Blocks check-in if no waiver            | Captures digital waiver       | Documents: waiver flow      | EPIC-01 owns enforcement; EPIC-04 owns capture UI                                |
| `Scheduled_Session__c`    | Views: schedule, attendees              | Edits: create sessions        | Documents: scheduling       | EPIC-03 reads; EPIC-04 creates                                                   |
| `Booking__c`              | Views: attendee list                    | Creates: bookings             | Documents: booking flow     | EPIC-01 owns waiver guard; EPIC-04 owns creation                                 |
| `Payment_Transaction__c`  | —                                       | Creates: payment records      | Documents: payment flow     | EPIC-01 US-004 owns; EPIC-04 US-F004 calls                                       |
| Trainer app offline-first | US-T001–T010 all need offline sync      | —                             | Documents: offline behavior | EPIC-03 architecture decision needed before any story is built                   |

---

## 📋 Recommended Sequencing

| Phase  | Stories                                                                  | Rationale                                                                              |
| ------ | ------------------------------------------------------------------------ | -------------------------------------------------------------------------------------- |
| **1**  | US-F001 (Register Walk-In Lead)                                          | Already has `EPIC04_LeadRegistration_Controller.cls` — smallest increment, unblocks C3 |
| **2**  | US-F002 (Convert Lead to Member)                                         | Owns the conversion flow; unblocks C1 and D1                                           |
| **3**  | US-F003 (Renew Membership)                                               | Builds on conversion; adds POS renewal path                                            |
| **4**  | US-F004 (Process Payment)                                                | Calls existing `EPIC01_ProcessPayment_Action.cls`; unblocks C4                         |
| **5**  | US-F005 (Capture Digital Waiver)                                         | Adds waiver capture UI; complements EPIC-01 waiver enforcement                         |
| **6**  | US-F006 (Merchandise Sale)                                               | Uses `Inventory_Item__c` + `Sale_Line_Item__c`                                         |
| **7**  | US-F007 (Apply Discount with Approval)                                   | Depends on merchandise sale flow                                                       |
| **8**  | US-F008 (Refund/Return)                                                  | Depends on merchandise sale + payment                                                  |
| **9**  | US-T001–T005 (Trainer basics: schedule, check-in, attendees, attended)   | Can start once lead/member flow is stable                                              |
| **10** | US-T006 (Trainer Waiver Block)                                           | Depends on D2 (trigger exists) and D8 (test data)                                      |
| **11** | US-T007–T010 (Trainer profile, create member, medical notes, substitute) | US-T008 depends on C1 resolution                                                       |

---

## ⚡ Top 3 Decisions Needed Before Coding

1. **C1 ✅ RESOLVED (2026-10-09):** Who owns Lead → Member conversion? Decided: US-F002 owns it; US-F002 reuses `EPIC01_LeadConversion_Action` (already in main from PR #30). US-T008 calls the same action — do not build a second conversion path.
2. **C3 ✅ RESOLVED (2026-10-09):** Who owns walk-in lead creation? Decided: US-F001 owns it; `EPIC04_LeadRegistration_Controller.createLead()` already exists in main. US-T008 calls the same controller method.
3. **C4 ✅ RESOLVED (2026-10-09):** Is US-F004 a new payment engine or a UI layer? Decided: UI layer only — US-F004 calls `EPIC01_ProcessPayment_Action.pay()` (already in main from PR #44). No new payment engine.

---

> **Source:** `~/Documents/Obsidian Vault/Requirements/EPIC-03_04_11 Groupings.md`
> **Kanban board:** `salesforce-headless-dev`
> **GitHub repo:** `chicken-tights-labs/sf-headless-crm`
