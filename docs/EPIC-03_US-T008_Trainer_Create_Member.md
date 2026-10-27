# EPIC-03 / US-T008 — Trainer Create Member

Issue: #53. Kanban: `t-a63d5906d6ac`.

## What exists

| Concern   | Implementation                                                                                                     |
| --------- | ------------------------------------------------------------------------------------------------------------------ |
| Staff UI  | Boxing Gym CRM **Home** card **New Member** (`epic03TrainerNewMember`), under **My schedule**                      |
| Why LWC   | The walk-in method is AuraEnabled, so a Flow cannot call it. The screen only forwards to the methods that exist.   |
| Create    | `EPIC04_LeadRegistration_Controller.createLead` (Walk-In, In Person)                                               |
| Convert   | `EPIC01_LeadConversion_Action.convertForScreen`, which only calls `convert()`                                      |
| Pay       | Optional. **Take payment** embeds flow `EPIC01_Process_Membership_Payment` (US-F004). Skipping it leaves Prospect. |
| Placement | `Gym_Manager_Home` right column. Not on the My Schedule tab.                                                       |

## How to use

1. Open **Boxing Gym CRM** → **Home**.
2. Under **My schedule**, enter the visitor and click **New Member**.
3. The member is **Prospect**. Click **Take payment** only if they are paying now. That is the same payment flow as **Process Membership Payment**.
4. Click **Done** to clear the card without paying. Open the member link to confirm status.

A missing signed waiver blocks payment inside the existing flow and leaves the member Prospect. There is no second lead, convert, or payment path.

If the lead saves and conversion fails, the card keeps that lead Id, links to the lead, and **Try convert again** calls `convertForScreen` only. **Done** is what starts another walk-in.

## Docs

- Update `docs/EPIC-11_D001_End_User_Manual.md` in the same PR.
- Obsidian vault path named in the issue: sync from this file when the vault is available.
