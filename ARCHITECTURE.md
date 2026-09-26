# NBS Gym CRM — Architecture Overview

## Three Environments, One Source of Truth

```
              ┌─────────────────────────────────────────────────┐
              │         LOCAL CURSOR (Maria's Laptop)           │
              │                                                   │
              │  ~/sf-project/sf-headless-crm/ (separate clone) │
              │  git clone from GitHub                          │
              │  • 15 custom objects (at ec763fe)                │
              │  • Salesforce auth: NOT available (VM-bound)     │
              │  • Can edit, commit, push                        │
              └──────┬──────────────────┬────────────────────────┘
                     │ git push         │ git pull
                     ▼                  ▲
              ┌────────────┴────────────┴────────────┐
              │              GitHub                   │
              │  github.com/chicken-tights-labs       │
              │         sf-headless-crm               │
              │  ✅ CURRENT: commit 0e6aa8b (EPIC-01) │
              └──────┬──────────────────┬────────────┘
                     ▲                  │
              git pull                 │ git pull
              origin/main              │ origin/main
                     │                  │
              ┌────────────┬────────────┴────────────┐
              │     HERMES VM (Google Cloud)          │
              │                                       │
              │  /home/maria_robbins/sf-project/      │
              │   sf-headless-crm/                   │
              │  • 26+ custom objects (15 from GitHub │
              │    + Referral_Reward__c from EPIC-01)  │
              │  • Apex classes (service + test)       │
              │  • Salesforce auth: ✅ configured     │
              │  • `sf` CLI + `sfdx` available         │
              │  • Scratch org alias: my-gym          │
              │  • GitHub: ✅ authenticated (gh CLI)   │
              └───────────────────────────────────────┘

              ┌─────────────────────────────────────┐
              │  SALESFORCE ORG (Dev Hub + my-gym)   │
              │  • Auth tokens: VM-only (~/.sfdx/)  │
              │  • OTP URLs: VM network-bound ✗      │
              └─────────────────────────────────────┘
```

## Key Rules

1. **GitHub is source of truth** — all changes flow through GitHub
2. **Hermes VM writes to the VM's clone** → must push to GitHub
3. **Local Cursor is a separate clone** → must pull from GitHub
4. **Salesforce auth is VM-only** — OTP URLs are network-bound to the VM IP.
   Use `sf org generate password --target-org my-gym` instead of OTP links.
5. **Cursor ↔ VM sync method: GitHub** (not direct file copy)

## EPIC-01 Delivery Status

| What | Location | Status |
|---|---|---|
| 10 new fields (Lead__c, Member__c, Payment_Transaction__c) | `force-app/main/default/objects/*/fields/` | ✅ Deployed on VM, pushed to GitHub |
| Referral_Reward__c object + 9 fields | `force-app/main/default/objects/Referral_Reward__c/` | ✅ Deployed on VM, pushed to GitHub |
| EPIC01_MemberOnboarding_Service.cls | `force-app/main/default/classes/` | ✅ Skeleton on VM, pushed to GitHub |
| EPIC01_MemberOnboarding_Test.cls | `force-app/main/default/classes/` | ✅ 13 tests on VM, pushed to GitHub |
| Expired/Effective dates on Waiver_Record__c | `force-app/main/default/objects/Waiver_Record__c/fields/` | ✅ Already existed in GitHub (625faa0) |
| Schema docs | `~/Documents/Obsidian Vault/CRM-Documentation/` | ✅ Updated (13 fields already existed, 10 deployed) |

## Next Steps for Local Cursor

1. **Pull the latest:** `git pull origin main`
2. **Deploy to scratch org:** `sf project deploy start --target-org my-gym`
3. **Implement service logic:** Fill in TODO stubs in `EPIC01_MemberOnboarding_Service.cls`
4. **Run tests:** `sf apex run test --target-org my-gym -n EPIC01_MemberOnboarding_Test`

> Note: Your Cursor workspace is at the old commit (ec763fe). After pulling, you'll have all 26+ objects, Apex classes, and the EPIC-01 schema. Salesforce auth is on the VM — you'll need to use the VM for `sf` CLI operations, or use password-based auth from a local `sf` install.
