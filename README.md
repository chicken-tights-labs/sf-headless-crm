# Boxing Gym Franchise CRM — Salesforce DX Project

Headless Salesforce CRM for Title Boxing Club franchise management.

## Project Structure

```
sf-headless-practice/
├── force-app/main/default/
│   ├── objects/
│   │   ├── Franchise_Location__c/     ← Each gym location
│   │   ├── Franchise_Owner__c/        ← Legal entity owning locations
│   │   ├── Member__c/                 ← Gym members
│   │   ├── Lead__c/                   ← Prospects
│   │   ├── Scheduled_Session__c/      ← Classes offered
│   │   ├── Booking__c/                ← Member class reservations
│   │   ├── Payment_Transaction__c/    ← Financial records
│   │   ├── Royalty_Report__c/         ← Franchise fee calculations
│   │   ├── Product_Category__c/       ← Merchandise categories
│   │   ├── Inventory_Item__c/         ← Products sold at gyms
│   │   ├── Merchandise_Sale__c/       ← Sale transaction header
│   │   ├── Sale_Line_Item__c/         ← Individual items in a sale
│   │   ├── Default_Class_Template__c/ ← Mandatory class templates
│   │   ├── Waiver_Template__c/        ← Legal waiver templates
│   │   └── Waiver_Record__c/          ← Individual signed waivers
│   └── classes/                       ← (Future Apex classes)
└── sfdx-project.json
```

## Object Inventory (15 Custom Objects + 23 Record Types + 31 Validation Rules + 24 Page Layouts)

| Object | Purpose | Record Types |
|--------|---------|--------------|
| Franchise_Location__c | Each gym location with address, hours, status | Corporate_Owned, Franchise_Owned |
| Franchise_Owner__c | Legal entity owning one or more gyms | Individual_Owner, Corporate_Entity |
| Member__c | Gym members with tiers, status, payment methods | Prospect, Active_Member, Former_Member |
| Lead__c | Prospects not yet converted to members | Walk_In, Online_Form, Referral |
| Scheduled_Session__c | Class schedules with capacity, trainers | Default_Template, Custom_Session |
| Booking__c | Member reservations for sessions | PreRegistration, DropIn |
| Payment_Transaction__c | All financial transactions | Membership_Payment, Merchandise_Sale, Fine_or_Adjustment |
| Royalty_Report__c | Monthly franchise fee calculations | Monthly_Report, Quarterly_Adjustment |
| Product_Category__c | Merchandise categories (apparel, equipment) | Standard_Stock, Promotional_Item |
| Inventory_Item__c | Stocked products with SKU, pricing, stock levels | — |
| Merchandise_Sale__c | Transaction headers for product sales | — |
| Sale_Line_Item__c | Individual items within a sale | — |
| Default_Class_Template__c | Mandatory class templates per franchise rules | — |
| Waiver_Template__c | Legal waiver templates (adult, minor, visitor) | — |
| Waiver_Record__c | Individual signed waivers with status tracking | Primary_Waiver, Guardian_Consent |

## Key Business Rules

1. **Franchise isolation**: All objects share Franchise_Location__c for data segregation
2. **Waiver requirement**: Cannot book classes without signed waiver (validation rule)
3. **Age-based waivers**: Auto-select adult/minor template based on DOB
4. **License optimization**: Trainers use thin-client app (no SF licenses)
5. **Royalty calculation**: Gross revenue × franchise rate = amount due

## Metadata Files Summary

- **231** total XML metadata files
- **16** Custom Object definitions
- **136** Custom Fields
- **23** Record Types
- **31** Validation Rules
- **24** Page Layouts

## Key Business Rules

1. **Franchise isolation**: All objects share Franchise_Location__c for data segregation
2. **Waiver requirement**: Cannot book classes without signed waiver
3. **Age-based waivers**: Auto-select adult/minor template based on DOB
4. **License optimization**: Trainers use thin-client app (no SF licenses)
5. **Royalty calculation**: Gross revenue × franchise rate = amount due

## CI/CD Pipeline (GitHub Actions)

- **main branch**: PR validation against scratch org
- **qa branch**: Auto-deployment to QA scratch org
- **prod branch**: Protected release branch with 2 approvals required

## Deployment Commands

```bash
# Create scratch org
sf org create scratch -f config/project-scratch-def.json -a my-gym -d 7

# Deploy metadata
sf project deploy start --target-org my-gym

# Push source (faster, for dev only)
sf project deploy start --source-dir force-app --target-org my-gym

# Run tests
sf apex run test --target-org my-gym --testlevel RunLocalTests
```

## Related Notes
- [[Salesforce Headless Orchestration Setup]]
- [[HAL 9000 - Persona Specification]]
## Learning the toolchain

New to Cursor + Hermes + GitHub + Salesforce DX? Start with the visual, hands-on pack:

**[docs/learning/00-overview.md](docs/learning/00-overview.md)** → then [PRACTICE.md](docs/learning/PRACTICE.md)

No Skills or Automations required — docs and drills only.

---

## Review Workflow

All changes go through PRs. Human sign-off is documented as a PR comment before merge (solo-account setup — GitHub blocks self-approval). Deploys to the Dev Org are manual-trigger, post sign-off.

---

## 🎯 EPIC-01: Member Onboarding — Source Map

This project implements EPIC-01. The requirements docs live in the Obsidian vault at `~/Documents/Obsidian Vault/CRM-Documentation/`. Use this table to jump between docs and source.

| User Story | Key Source Files | Tests | Status |
|---|---|---|---|
| **US-001: Lead Capture** | `objects/Lead__c/fields/` (Phone__c, Lead_Source__c already exist; Program_Interest__c, Referred_By__c newly added) | — | Schema ✅ |
| **US-002: Lead Conversion** | `objects/Lead__c/fields/Converted_Member__c.field-meta.xml` (exists), `objects/Member__c/fields/Original_Lead__c.field-meta.xml` (new), `classes/EPIC01_MemberOnboarding_Service.cls` | `classes/EPIC01_MemberOnboarding_Test.cls` | Logic ⏳ |
| **US-003: Tier + Waiver Gate** | `objects/Waiver_Record__c/fields/Expiration_Date__c.field-meta.xml` (from GitHub), `objects/Member__c/fields/Waiver_Needed__c.field-meta.xml` (new) | `classes/EPIC01_MemberOnboarding_Test.cls` | Gate ⏳ |
| **US-004: Payment** | `objects/Payment_Transaction__c/fields/Is_Recurring__c.field-meta.xml` (new), `objects/Member__c/fields` (Start_Date__c, Expiry_Date__c already exist) | `classes/EPIC01_MemberOnboarding_Test.cls` | Logic ⏳ |
| **US-005: Welcome Workflow** | `objects/Member__c/fields/Welcome_Email_Sent__c.field-meta.xml` (new) | `classes/EPIC01_MemberOnboarding_Test.cls` | Logic ⏳ |
| **US-006: Referral Program** | `objects/Referral_Reward__c/` (new object + 9 fields), `objects/Member__c/fields/Referral_Code__c.field-meta.xml` (new) | `classes/EPIC01_MemberOnboarding_Test.cls` | Logic ⏳ |

### ⚠️ Schema Status: Existing vs. New

| Field | Object | Status | Notes |
|---|---|---|---|
| `Phone__c` | Lead__c | ✅ Already exists | Source + GitHub |
| `Lead_Source__c` | Lead__c | ✅ Already exists | Values: Walk-in, Online, Referral, Social Media, Community Event |
| `Program_Interest__c` | Lead__c | 🆕 Newly added | Values: Boxing, Fencing, MMA, Multi, Not Sure |
| `Referred_By__c` | Lead__c | 🆕 Newly added | Lookup to Member |
| `Converted_Member__c` | Lead__c | ✅ Already exists | |
| `Original_Lead__c` | Member__c | 🆕 Newly added | Lookup to Lead |
| `Start_Date__c` | Member__c | ✅ Already exists | Use instead of Membership_Start_Date__c |
| `Expiry_Date__c` | Member__c | ✅ Already exists | Use instead of Membership_Expiry_Date__c |
| `Membership_Tier__c` | Member__c | ✅ Already exists | Values: Monthly Unlimited $129, Annual Prepaid $99/mo, Drop-In $20/class, Punch Card 10 classes $150 |
| `Member__c` | Waiver_Record__c | ✅ Already exists | EPIC-02 gap already resolved in source |
| `Lead__c` | Waiver_Record__c | ✅ Already exists | For trial class waivers |
| `Expiration_Date__c` | Waiver_Record__c | ✅ Already exists | From GitHub commit 625faa0 (EPIC-02) |
| `Effective_Date__c` | Waiver_Record__c | ✅ Already exists | From GitHub commit 625faa0 (EPIC-02) |
| `Is_Recurring__c` | Payment_Transaction__c | 🆕 Newly added | |
| `Referral_Code__c` | Member__c | 🆕 Newly added | Unique, externalId |
| `Classes_Remaining__c` | Member__c | 🆕 Newly added | |
| `Referral_Reward__c` | (new object) | 🆕 Newly added | 9 fields |

### 🛠️ Next Steps for Development

1. Deploy new schema + Apex classes to scratch org: `sf project deploy start --target-org my-gym`
2. Implement `EPIC01_MemberOnboarding_Service.cls` method bodies (skeleton is ready)
3. Run the test class: `sf apex run test --target-org my-gym -n EPIC01_MemberOnboarding_Test`
4. Note: Tier values in CRM-Documentation Gherkin scenarios differ from source — see table above
