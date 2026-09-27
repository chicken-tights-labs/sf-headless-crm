# EPIC Groupings — Salesforce Headless CRM

## EPIC-03: Trainer Operations
**Kanban ID:** `t_epic_03` | **Status:** todo
**Scope:** All trainer-facing workflows for the gym's mobile check-in app.

### User Stories (10)
| ID | User Story | Kanban Task ID |
|---|---|---|
| US-T001 | Trainer View Schedule | t_716de98a |
| US-T002 | Trainer QR Check-In | t_78422857 |
| US-T003 | Trainer Phone Check-In | t_9837744a |
| US-T004 | Trainer View Attendees | t_c21aec23 |
| US-T005 | Trainer Mark Attended | t_45806d09 |
| US-T006 | Trainer Waiver Block | t_a79785a7 |
| US-T007 | Trainer View Profile | t_17178f4d |
| US-T008 | Trainer Create Member | t_5f743612 |
| US-T009 | Trainer View Medical Notes | t_4f0ffc9f |
| US-T010 | Trainer Substitute Class | t_e5ecb0fe |

---

## EPIC-04: Point of Sale (POS) System
**Kanban ID:** `t_epic_04` | **Status:** todo
**Scope:** Front-desk POS — lead registration through payment/refunds.

### User Stories (8)
| ID | User Story | Kanban Task ID |
|---|---|---|
| US-F001 | Register Walk-In Lead | t_b9d75b17 |
| US-F002 | Convert Lead to Member | t_c3f762c7 |
| US-F003 | Renew Membership | t_94d7d834 |
| US-F004 | Process Payment | t_676a32c0 |
| US-F005 | Capture Digital Waiver | t_6b7f8d51 |
| US-F006 | Process Merchandise Sale | t_cc2cae33 |
| US-F007 | Apply Discount with Approval | t_2292b443 |
| US-F008 | Process Refund / Return | t_e22d7ba3 |

---

## EPIC-11: System Documentation & User Guides
**Kanban ID:** `t_b1948b81` | **Status:** ready
**Scope:** All documentation deliverables (must be written alongside features, not after).

### User Stories (6)
| ID | User Story | Kanban Task ID |
|---|---|---|
| US-D001 | End User Manual (Trainers + Front Desk) | t_9d84897e |
| US-D002 | Manager Guide (Operations + Reporting) | t_f19ed172 |
| US-D003 | Franchise Owner Guide (Dashboards + Royalties) | t_2d4f52f9 |
| US-D004 | System Admin Guide (Users + Permissions) | t_7b14be8b |
| US-D005 | API Documentation (POS Integration) | t_24523042 |
| US-D006 | Troubleshooting + FAQ | t_d0ee0511 |

---

## Existing EPICs (already documented elsewhere)
- **EPIC-01:** Member Onboarding — 6 user stories (US-001 through US-006), Obsidian docs at `CRM-Documentation/EPIC-01_*.md`
- **EPIC-02:** Member Compliance & Liability Engine — 1 user story (Gherkin), Obsidian at `docs/requirements/EPIC-02_Compliance_Engine.md`

## Next EPICs to Define
Based on the architecture review, candidates for future EPICS:
- **EPIC-05:** Gym Flows (welcome email, waiver reminders, membership expiry) — Phase 2
- **EPIC-06:** API Integration Layer (JWT bearer + server-side bridge) — Phase 3
- **EPIC-07:** Next.js Member Portal (schedule → book → clock-in) — Phase 4

Tags: #salesforce-crm #epics #user-stories #nbs-gym