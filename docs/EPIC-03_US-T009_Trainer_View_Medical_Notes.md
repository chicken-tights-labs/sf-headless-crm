# EPIC-03 / US-T009 — Trainer View Medical Notes

Issue: #54. Kanban: `t-653dd84c1ebf`.

## What shipped

- Shared permission set `Boxing_Gym_CRM_Access` no longer grants `Member__c.Medical_Notes__c`.
- New permission set `Boxing_Gym_Trainer_Medical_Notes` grants **read-only** FLS on that field.
- Trainers who need notes get both sets. Front desk and managers get only the shared set.

## Edit path (decision)

This story does **not** add a Salesforce edit path for medical notes.

| Who                  | Where they see/edit notes                                                |
| -------------------- | ------------------------------------------------------------------------ |
| Trainer              | Salesforce: read-only via `Boxing_Gym_Trainer_Medical_Notes`             |
| Front desk / manager | Salesforce: no access                                                    |
| Member / guardian    | Member-facing app (outside this repo) — enter and update their own notes |
| System work          | Not via CRM staff permsets; no CRM edit FLS is granted                   |

## How to verify

1. Deploy: `sf project deploy start --source-dir force-app --target-org <alias> --test-level RunRelevantTests --wait 30`
2. User with only `Boxing_Gym_CRM_Access`: open a Member — Medical Notes is not visible.
3. Same user after assigning `Boxing_Gym_Trainer_Medical_Notes`: Medical Notes is visible and not editable.
