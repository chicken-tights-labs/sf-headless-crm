# EPIC-03 / US-T010 — Trainer Substitute Class

Issue: #55. Kanban: `t-8c5ef4c94d20`.

## What exists

| Concern               | Implementation                                                                                 |
| --------------------- | ---------------------------------------------------------------------------------------------- |
| Staff UI              | **Substitute** on the Scheduled Session highlights panel. Flow `EPIC03_Substitute_Class`       |
| Why Flow              | The button and the result screen are a screen flow the trainer can read in Setup               |
| Why Apex              | `EPIC03_SubstituteTrainer_Action` saves the substitute. A failed email does not undo that save |
| Field                 | `Scheduled_Session__c.Substitute_Trainer__c` (User lookup)                                     |
| Unchanged             | `Assigned_Trainer__c`, start time, and session status                                          |
| Notice                | Email to the assigned trainer, subject `Substitute covering your class`                        |
| Where to open a class | **Scheduled Session → This Week's Classes**. My schedule stays assigned-only                   |

## How to use

1. Open **Boxing Gym CRM**.
2. Open **Scheduled Session → This Week's Classes** and open a class assigned to someone else.
3. Click **Substitute**.
4. You are the Substitute Trainer. The assigned trainer is emailed and still owns the class.

A class that is cancelled, completed, already yours, or already covered by someone else is refused. The class time does not change.

## Docs

- Update `docs/EPIC-11_D001_End_User_Manual.md` in the same PR.
- Obsidian vault path named in the issue: sync from this file when the vault is available.
