# SF Headless CRM — Environment Facts

> Facts about the VM and Salesforce orgs. Cursor cannot see these — Hermes maintains this file. Update when things change.

## Services

| Resource | Value |
|---|---|
| Scratch org alias | `my-gym` |
| Scratch org expiration | ~Sept 30, 2026 |
| Dev org alias | `dev-org` |
| Partner Dev Org alias | `partner-dev` |
| VM scratch org path | `/home/maria_robbins/sf-project/sf-headless-crm` |

## Deploy & Verify Commands

```bash
# After PR merges to main:
cd /home/maria_robbins/sf-project/sf-headless-crm
git pull origin main

# Deploy to scratch org (for verification):
sf project deploy start --source-dir force-app --target-org my-gym

# Or deploy to dev org:
sf project deploy start --source-dir force-app --target-org dev-org

# Post-deploy sanity check:
sf data query --target-org my-gym -q "SELECT COUNT() FROM Waiver_Record__c" --json

# Run a specific Apex test class:
sf apex run test --target-org my-gym -n EPIC01_MemberOnboarding_Test

# Run tests via CI dry-run (no org auth required for metadata validation):
sf project deploy start --source-dir force-app --target-org my-gym --dry-run --test-level RunRelevantTests
```

## Known Gotchas

- **Connected App creation blocked in DevHub org**: "You can't create a connected app. To enable connected app creation, contact Salesforce Customer Support." Workaround: create via UI on laptop browser (login.salesforce.com) instead of programmatic deployment.
- **Scratch org auth is VM-only**: OTP URLs are network-bound to the VM. Cannot authenticate scratch org from laptop directly.
- **RunRelevantTests vs RunLocalTests**: Use RunRelevantTests to avoid flaky pre-existing tests (e.g., DataManager_QuotaTest).
- **Newer Salesforce UI uses "External Client App" naming** with per-flow checkboxes instead of traditional OAuth config certificate upload.