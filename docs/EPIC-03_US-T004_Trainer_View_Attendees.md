# EPIC-03 / US-T004 — Trainer View Attendees

Issue: #49. Kanban: `t-ab762acbff85`.

## What exists

| Concern         | Implementation                                                                                               |
| --------------- | ------------------------------------------------------------------------------------------------------------ |
| Staff UI        | **Attendees** tab on `Scheduled_Session_Record_Page` → LWC `epic03SessionAttendees`                          |
| Why LWC         | Need Booking rows plus `waiverStatusByMember` in one roster; later check-in actions land on this same screen |
| Data            | `EPIC03_SessionAttendees_Controller.getAttendees` reads `Booking__c` for the session                         |
| Columns         | Member name, check-in status, waiver status, booking status                                                  |
| Check-in status | From `Checked_In_At__c` + `Status__c` (Confirmed / Completed / No-Show / Cancelled). No Attended value       |
| Waiver status   | `EPIC01_MemberOnboarding_Service.waiverStatusByMember`                                                       |
| Check-in        | Row action **Mark Attended** (US-T005 / US-T006) sets Completed + timestamp after waiver gate                |

## How to use

1. Open Boxing Gym CRM → a Scheduled Session.
2. Open the **Attendees** tab (default).
3. See everyone booked for that session.

## Docs

- Update `docs/EPIC-11_D001_End_User_Manual.md` in the same PR.
- Obsidian vault path named in the issue: sync from this file when the vault is available.
