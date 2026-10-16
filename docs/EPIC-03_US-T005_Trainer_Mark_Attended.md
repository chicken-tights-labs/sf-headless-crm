# EPIC-03 / US-T005 — Trainer Mark Attended

Issue: #50. Kanban: `t-512b8e7ed64e`.
Ships with US-T006 (#51) as one attendance action.

## What exists

| Concern           | Implementation                                                                                        |
| ----------------- | ----------------------------------------------------------------------------------------------------- |
| UI                | Row action **Mark Attended** on `epic03SessionAttendees` (Scheduled Session **Attendees** tab)        |
| Write             | `EPIC03_SessionAttendees_Controller.markAttended` sets `Checked_In_At__c` and `Status__c = Completed` |
| No Attended value | Booking status picklist has Confirmed / Completed / No-Show / Cancelled only                          |
| Shared method     | US-T002 / US-T003 will call the same Apex; they do not write the booking themselves                   |
| Waiver            | Guarded by US-T006 inside the same method                                                             |

## Docs

- Update `docs/EPIC-11_D001_End_User_Manual.md` in the same PR.
