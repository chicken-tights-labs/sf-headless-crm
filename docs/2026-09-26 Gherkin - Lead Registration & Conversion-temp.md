# Gherkin Specs — Lead → Member Journey (EPIC-04: POS System)

## Feature: Walk-In Lead Registration & Conversion
**Epic:** EPIC-04 | **Tasks:** t_b9d75b17 (US-F001), t_c3f762c7 (US-F002), t_676a32c0 (US-F004)

### Scenario: Register a walk-in visitor as a lead
```gherkin
Feature: Lead Capture
  As a front-desk staff member
    10|  I want to register a walk-in visitor as a lead in the CRM
  So that they appear in the sales pipeline and can be converted later

  Background:
    Given a front-desk staff user is logged into the POS system
    And the POS system is connected to Salesforce via API
    And the "Lead" object exists in the Salesforce org

  Scenario: Successful walk-in lead registration
    When the staff enters "John Smith" as the visitor name
    20|    And selects visit reason "Tour Request"
    And enters phone number "555-123-4567"
    And enters email "john@example.com"
    And clicks "Register Walk-In"
    Then a new Lead__c record is created in Salesforce with:
      | Field         | Value             |
      | First_Name__c | John              |
      | Last_Name__c  | Smith             |
      | Phone__c      | 555-123-4567      |
      | Email__c      | john@example.com  |
    30|      | Status__c     | Walk-In           |
      | Source__c     | In Person         |
    And the system displays "Lead registered successfully"
    And the lead appears in the "Recent Walk-Ins" list
```

### Scenario: Convert lead to member with initial payment
```gherkin
Feature: Lead-to-Member Conversion
  As a front-desk staff member
    40|  I want to convert a walk-in lead into an active member with payment
  So that the CRM reflects their membership status and payment history

  Background:
    Given an existing Lead__c record with Status__c = "Walk-In"
    And the lead has completed a facility tour and agreed to join
    And the POS system has a connected payment processor (Stripe)

  Scenario: Convert lead to member and process first payment
    When the staff selects the lead from the recent walk-ins list
    50|    And clicks "Convert to Member"
    And selects membership tier "Monthly Adult ($120)"
    And selects payment method "Card"
    And enters card details
    And clicks "Process Payment"
    Then the system does the following in order:
      1. Creates a new Member__c record with:
        | Field                  | Value                  |
        | First_Name__c          | John                   |
        | Last_Name__c           | Smith                  |
    60|        | Phone__c               | 555-123-4567           |
        | Email__c               | john@example.com       |
        | Membership_Start_Date__c | <today>             |
        | Membership_Expiration__c | <today + 30 days>   |
        | Status__c              | Active                 |
        | Source_Lead__c         | <Lead__c.Id>           |
      2. Updates the Lead__c record with:
        | Field     | Value       |
        | Status__c | Converted   |
      3. Creates an Order__c record with:
    70|        | Field            | Value                  |
        | Member__c        | <Member__c.Id>         |
        | Amount__c        | 120.00                 |
        | Status__c        | Paid                   |
        | Payment_Method__c| Card                   |
      4. Creates a Payment__c record with:
        | Field              | Value              |
        | Member__c          | <Member__c.Id>     |
        | Order__c           | <Order__c.Id>      |
        | Amount__c          | 120.00            |
    80|        | Payment_Method__c  | Card              |
        | External_Id__c     | <stripe-charge-id>|
        | Status__c          | Completed         |
    And the system prints a membership card with the member's name and barcode
    And the system displays "Member created! Payment confirmed."
    And the lead is removed from the "Recent Walk-Ins" list

  Scenario: Conversion fails because payment is declined
    When the staff selects the lead from the recent walk-ins list
    And clicks "Convert to Member"
    90|    And enters card details
    And submits payment
    But the payment processor returns a "declined" response
    Then the system does NOT create a Member__c record
    And the system does NOT update the Lead__c Status__c
    And the system displays "Payment failed — lead remains unconverted"
    And the system logs the failed payment attempt in the audit trail

  Scenario: Staff attempts to convert a lead with missing required fields
    Given a Lead__c record with Email__c = null
   100|    When the staff attempts to convert the lead to a member
    Then the system prevents the conversion
    And the system displays "Lead must have an email address to convert"
    And the lead remains unchanged
```

### Scenario: Apply discount with manager approval
```gherkin
Feature: Discount Approval Workflow
  As a front-desk staff member
   110|  I want to apply a discount to a membership payment with manager approval
  So that revenue protection rules are enforced

  Background:
    Given the lead-to-member conversion form is open
    And the staff member does not have the "Manager" role
    And a membership tier "Annual ($1,200)" is selected

  Scenario: Discount applied with manager approval via PIN
    When the staff clicks "Apply Discount"
   120|    And selects discount type "10% off first month"
    And enters manager PIN "1234"
    And clicks "Approve"
    Then the system applies the discount to the Order__c
    And the Order__c record includes:
      | Field              | Value        |
      | Applied_Discount__c | 10%         |
      | Discount_Reason__c  | Manager Approval |
      | Manager_Approver__c | <Manager User>   |
    And the final Amount__c on Order__c is reduced to $1,080.00
   130|    And the system logs the discount event with timestamp

  Scenario: Discount rejected — no manager PIN
    When the staff clicks "Apply Discount"
    And selects discount type "50% off annual"
    But the staff does not enter a valid manager PIN
    Then the system prevents the discount
    And the system displays "Manager approval required for this discount tier"
    And no discount is applied to the original amount
```
   140|
## Field References
All object schemas verified against:
- `/home/maria_robbins/sf-project/sf-headless-crm/force-app/main/default/objects/`
- Existing user stories: t_b9d75b17 (US-F001), t_c3f762c7 (US-F002), t_676a32c0 (US-F004), t_2292b443 (US-F007)

Tags: #gherkin #EPIC-04 #US-F001 #US-F002 #US-F004 #US-F007 #salesforce-crm