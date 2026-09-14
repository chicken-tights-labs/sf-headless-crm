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