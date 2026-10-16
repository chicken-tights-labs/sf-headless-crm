# EPIC-04 / US-F003 — Renew Membership

Issue: #57. Kanban: `t-7c48be427486`.

## What exists

| Concern                  | Implementation                                                                                                                         |
| ------------------------ | -------------------------------------------------------------------------------------------------------------------------------------- |
| Staff UI                 | Quick action **Renew Membership** → screen flow `EPIC04_Renew_Membership`                                                              |
| Engine                   | `EPIC04_RenewMembership_Action` → `EPIC01_MemberOnboarding_Service.renewMembership`                                                    |
| Why not `processPayment` | First payment resets `Start_Date__c`, sends welcome email, and can award referral. Renewal must not                                    |
| Dates                    | Extends `Expiry_Date__c` from the later of today and the current expiry (tier length: 30 / 365 / 180). Does not change `Start_Date__c` |
| Payment                  | Creates `Payment_Transaction__c` (simulated processor). Receipt email only                                                             |
| Waiver                   | Requires a **Signed** waiver with `Signature_Timestamp__c` on/after today. Capture via US-F005 first                                   |
| Field name               | Gherkin `Membership_Expiry_Date__c` → actual field `Member__c.Expiry_Date__c`                                                          |
| Eligibility              | Status **Active**. Non–Drop-In tiers must have expiry today or earlier                                                                 |
| Placement                | Member record highlights panel; Process Membership Payment **Already Active** screen points here                                       |

## Flow of the button

1. Confirm tier (optional change saves on Member).
2. Collect amount and payment method.
3. Apex renews: waiver check → extend expiry → payment txn → receipt.

## Docs

- Update `docs/EPIC-11_D001_End_User_Manual.md` in the same PR.
- Obsidian vault path named in the issue: sync from this file when the vault is available.
