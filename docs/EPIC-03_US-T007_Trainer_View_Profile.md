# EPIC-03 / US-T007 — Trainer View Profile

Issue: #52. Kanban: `t-b82e748f2466`.

## What shipped

- Read-only LWC `epic03MemberProfile` on the Member record page (Boxing Gym CRM).
- Apex `EPIC03_MemberProfile_Controller.getProfile` returns name, membership tier, status, and expiry date.
- Medical notes appear only when the running user can read `Member__c.Medical_Notes__c` (US-T009: `Boxing_Gym_Trainer_Medical_Notes`). No second medical-notes permission.
- Attendee roster member names link to the Member record so trainers can open the profile from check-in.

## Out of scope

- Editing the member
- Editing medical notes

## How to verify

1. Deploy with `RunRelevantTests`.
2. From a Scheduled Session **Attendees** tab, click a member name → Member record shows **Trainer profile**.
3. User with only `Boxing_Gym_CRM_Access`: profile shows name / tier / status / expiry; no medical notes section.
4. Same user plus `Boxing_Gym_Trainer_Medical_Notes`: medical notes section appears read-only.
