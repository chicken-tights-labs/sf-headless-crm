# EPIC-04 / US-F002 — Convert Lead to Member (POS)

Issue: #56. Kanban: `t-e865c6f6936b`.

## What exists

| Concern           | Implementation                                                                                                                          |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| Staff UI          | Quick action `Lead__c.Convert_to_Member` → screen flow `EPIC04_Convert_Lead_And_Pay`                                                    |
| Convert engine    | Reuses `EPIC01_LeadConversion_Action` → `EPIC01_MemberOnboarding_Service.convertLeadToMember` (Prospect member)                         |
| Pay / Active      | Subflow `EPIC01_Process_Membership_Payment` (US-F004): waiver gate, tier confirm, simulated payment → Active                            |
| Placement         | Lightning record page `Lead_Record_Page` with Convert to Member in the highlights panel; Boxing Gym CRM app View override for `Lead__c` |
| Convert-only flow | `EPIC01_Convert_Lead_To_Member` remains in source for the convert step alone; the POS button uses the compose flow                      |
| Tests             | `EPIC04_ConvertAndPay_Test` (Walk-In convert + cash pay → Active; no-waiver gate stays Prospect)                                        |

## Flow of the button

1. Convert the Lead (creates Prospect Member, copies signed lead waiver when present).
2. Intro screen: member is Prospect until payment succeeds.
3. Same payment screens as **Process Membership Payment** (tier → amount/method → Active).

Active comes from the payment engine, not a second converter. Do not create `Order__c` or `Payment__c`; the payment record is `Payment_Transaction__c`.

## Field note

Gherkin may say Lead `Status__c = Walk-In`. The field is `Lead_Status__c`. Value `Walk-In` is valid and converts.

## Docs

- Update `docs/EPIC-11_D001_End_User_Manual.md` in the same PR.
- Obsidian vault path named in the issue: sync from this file when the vault is available.
