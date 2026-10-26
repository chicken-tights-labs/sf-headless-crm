# EPIC-03 / US-T001 — Trainer View Schedule

Issue: #46. Kanban: `t-ad823027db53`.

## What exists

| Concern      | Implementation                                                                                          |
| ------------ | ------------------------------------------------------------------------------------------------------- |
| Staff UI     | Boxing Gym CRM **Home** card **My schedule**, and nav tab **My Schedule** → LWC `epic03TrainerSchedule` |
| Why LWC      | Logged-in trainer filter + booked count are not a standard list view                                    |
| Data         | `EPIC03_TrainerSchedule_Controller.getMyWeekSessions`                                                   |
| Filter       | `Assigned_Trainer__c = running user`, `Start_Time__c = THIS_WEEK`, `Session_Status__c != Cancelled`     |
| Columns      | Class (link), start time, location, booked count, capacity                                              |
| Booked count | Non-cancelled `Booking__c` rows for each session                                                        |
| Capacity     | `Max_Capacity__c`                                                                                       |

## How to use

1. Open the **Boxing Gym CRM** app (App Launcher — not the default Salesforce app).
2. On **Home**, see **My schedule** for classes assigned to you this week — or open the **My Schedule** tab.
3. Click a class name to open the Scheduled Session (Attendees / check-in).

Home is assigned by `Boxing_Gym_CRM` CustomApplication overrides (`standard-home` → `Gym_Manager_Home`), not by a FlexiPageAssignment / Setup activation checkbox. If Home looks wrong after a scratch recreate, redeploy the app metadata (#84).

## Docs

- Update `docs/EPIC-11_D001_End_User_Manual.md` in the same PR.
- Obsidian vault path named in the issue: sync from this file when the vault is available.
