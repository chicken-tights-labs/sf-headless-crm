# EPIC-03 / US-T006 — Trainer Waiver Block

Issue: #51. Kanban: `t-22dfab73e137`.
Ships inside the Mark Attended action from US-T005 (#50).

## What exists

| Concern                 | Implementation                                                                           |
| ----------------------- | ---------------------------------------------------------------------------------------- |
| Guard                   | `markAttended` calls `EPIC01_MemberOnboarding_Service.waiverStatusByMember`              |
| Block message           | `Cannot check in - member does not have a valid signed waiver` when status is not Signed |
| Not the booking trigger | `EPIC01_BookingWaiverGuard` runs on Booking insert only; check-in does not call it       |
| Capture path            | Front desk uses **Capture Waiver** (US-F005) to fix a missing waiver                     |

## Docs

- Update `docs/EPIC-11_D001_End_User_Manual.md` in the same PR.
