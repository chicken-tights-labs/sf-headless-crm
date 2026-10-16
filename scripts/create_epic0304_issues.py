#!/usr/bin/env python3
"""Create GitHub issues for EPIC-03 (Trainer) and EPIC-04 (POS) stories.

Each issue body follows the .github/ISSUE_TEMPLATE/story.md format.
Issues are created on chicken-tights-labs/sf-headless-crm.
"""
import subprocess
import textwrap

REPO = "chicken-tights-labs/sf-headless-crm"

STORIES = [
    # === EPIC-03: Trainer Operations ===
    {
        "title": "US-T001: Trainer View Schedule",
        "story": "As a trainer, I want to view my upcoming class schedule in the trainer app, so that I know which sessions I am assigned to teach.",
        "gherkin": """```gherkin
@EPIC-03 @US-T001
Feature: Trainer View Schedule
  As a trainer
  I want to see my upcoming class schedule
  So that I can prepare for my teaching sessions

  @cursor
  Scenario: Trainer views upcoming week of classes
    Given a trainer is logged into the trainer app
    And the trainer has classes assigned this week
    When the trainer opens the app
    Then the trainer sees their schedule for the current week
    And each class shows: session name, time, location, booked count, and capacity
```""",
        "out_of_scope": "- Creating or editing sessions (EPIC-04 owns session creation)\n- Booking classes (separate trainer stories)\n- Managing other trainers schedules\n- Calendar sync to external calendars",
        "docs": "- `CRM-Documentation/EPIC-03_US-T001_Trainer_View_Schedule.md`\n- `docs/EPIC-11_D001_End_User_Manual.md` (trainer workflow section)",
        "epic": "EPIC-03",
    },
    {
        "title": "US-T002: Trainer QR Check-In",
        "story": "As a trainer, I want to scan a member's QR code to check them into a session, so that attendance is recorded quickly without manual lookup.",
        "gherkin": """```gherkin
@EPIC-03 @US-T002
Feature: Trainer QR Check-In
  As a trainer
  I want to scan a QR code to check in a member
  So that attendance is recorded without manual lookup

  @cursor
  Scenario: Member scans QR code to check into class
    Given a trainer is on the check-in screen for a session
    And the session has an active booking list
    When a member scans their QR code
    Then the member is marked as attended
    And the attendance timestamp is recorded
```""",
        "out_of_scope": "- Phone lookup check-in (US-T003)\n- Manual attendance marking (US-T005)\n- Waiver block enforcement (US-T006)",
        "docs": "- `CRM-Documentation/EPIC-03_US-T002_Trainer_QR_CheckIn.md`\n- `docs/EPIC-11_D001_End_User_Manual.md`",
        "epic": "EPIC-03",
    },
    {
        "title": "US-T003: Trainer Phone Check-In",
        "story": "As a trainer, I want to check in a member by phone number lookup, so that members who forgot their QR code can still attend.",
        "gherkin": """```gherkin
@EPIC-03 @US-T003
Feature: Trainer Phone Check-In
  As a trainer
  I want to check in a member by searching their phone number
  So that members without QR codes can still attend

  @cursor
  Scenario: Trainer searches member by phone and checks them in
    Given a trainer has selected a session
    When the trainer enters a member phone number
    Then the system finds the member
    And the trainer can confirm attendance
```""",
        "out_of_scope": "- QR check-in (US-T002)\n- Creating new leads from walk-in members (US-T008)",
        "docs": "- `CRM-Documentation/EPIC-03_US-T003_Trainer_Phone_CheckIn.md`\n- `docs/EPIC-11_D001_End_User_Manual.md`",
        "epic": "EPIC-03",
    },
    {
        "title": "US-T004: Trainer View Attendees",
        "story": "As a trainer, I want to see the list of attendees for my class, so that I know who is expected and can verify attendance.",
        "gherkin": """```gherkin
@EPIC-03 @US-T004
Feature: Trainer View Attendees
  As a trainer
  I want to see who is signed up for my class
  So that I can verify attendance and spot missing members

  @cursor
  Scenario: Trainer views attendee list for todays class
    Given a trainer is viewing a session
    When the trainer opens the Attendees tab
    Then the trainer sees all members who booked that session
    And each attendee shows name, check-in status, and waiver status
```""",
        "out_of_scope": "- Editing bookings\n- Checking in attendees (US-T005)",
        "docs": "- `CRM-Documentation/EPIC-03_US-T004_Trainer_View_Attendees.md`",
        "epic": "EPIC-03",
    },
    {
        "title": "US-T005: Trainer Mark Attended",
        "story": "As a trainer, I want to mark a member as attended after they check in, so that attendance records are complete for reporting.",
        "gherkin": """```gherkin
@EPIC-03 @US-T005
Feature: Trainer Mark Attended
  As a trainer
  I want to mark a member as attended
  So that attendance is recorded for reporting and billing

  @cursor
  Scenario: Trainer marks member as attended
    Given a trainer has a list of attendees for a session
    When the trainer selects a member
    And clicks "Mark Attended"
    Then the Booking__c record is updated with attended status
    And the attendance timestamp is saved
```""",
        "out_of_scope": "- Booking creation (front desk owns this)\n- Waiver enforcement (US-T006)",
        "docs": "- `CRM-Documentation/EPIC-03_US-T005_Trainer_Mark_Attended.md`",
        "epic": "EPIC-03",
    },
    {
        "title": "US-T006: Trainer Waiver Block",
        "story": "As a trainer, I want the system to block class attendance for members without a valid waiver, so that liability compliance is enforced at check-in.",
        "gherkin": """```gherkin
@EPIC-03 @US-T006
Feature: Trainer Waiver Block
  As a trainer
  I want check-in blocked for members without a valid waiver
  So that we maintain liability compliance

  @cursor
  Scenario: Member without waiver is blocked from check-in
    Given a member attempts to check in
    And the member has no signed waiver
    When the trainer attempts to mark them as attended
    Then the system blocks the check-in
    And displays: "Cannot check in - member does not have a valid signed waiver"
```""",
        "out_of_scope": "- Re-implementing waiver validation (reference EPIC01_BookingWaiverGuard.trigger only)\n- Creating digital waivers (US-F005 owns capture)",
        "docs": "- `CRM-Documentation/EPIC-03_US-T006_Trainer_Waiver_Block.md`",
        "epic": "EPIC-03",
    },
    {
        "title": "US-T007: Trainer View Profile",
        "story": "As a trainer, I want to view a member's profile including membership status and medical notes, so that I can provide safe, informed coaching.",
        "gherkin": """```gherkin
@EPIC-03 @US-T007
Feature: Trainer View Profile
  As a trainer
  I want to view a member's profile
  So that I can see their membership status and medical notes for safe coaching

  @cursor
  Scenario: Trainer views member profile
    Given a trainer selects a member
    When the trainer opens the member profile
    Then the trainer sees: name, membership tier, status, expiry date
    And medical notes (read-only, permission-gated)
```""",
        "out_of_scope": "- Editing member profiles (admin function)\n- Medical notes editing (member data entry only)",
        "docs": "- `CRM-Documentation/EPIC-03_US-T007_Trainer_View_Profile.md`",
        "epic": "EPIC-03",
    },
    {
        "title": "US-T008: Trainer Create Member",
        "story": "As a trainer, I want to create a new member record from a walk-in visitor, so that the visitor's information is captured in the CRM immediately.",
        "gherkin": """```gherkin
@EPIC-03 @US-T008
Feature: Trainer Create Member
  As a trainer
  I want to create a member from a walk-in visitor
  So that their information is captured in the CRM

  @cursor
  Scenario: Trainer registers walk-in and converts to member
    Given a trainer encounters a walk-in visitor
    When the trainer selects "New Member"
    And enters their details
    And optionally processes payment
    Then a Lead__c is created via EPIC04_LeadRegistration_Controller.createLead()
    And if payment is processed, the lead is converted via EPIC01_LeadConversion_Action
```""",
        "out_of_scope": "- Building a second lead creation path (calls EPIC04_LeadRegistration_Controller)\n- Building a second conversion path (calls EPIC01_LeadConversion_Action)",
        "docs": "- `CRM-Documentation/EPIC-03_US-T008_Trainer_Create_Member.md`",
        "epic": "EPIC-03",
    },
    {
        "title": "US-T009: Trainer View Medical Notes",
        "story": "As a trainer, I want to view medical notes for a member with appropriate permissions, so that I can ensure training safety for members with health concerns.",
        "gherkin": """```gherkin
@EPIC-03 @US-T009
Feature: Trainer View Medical Notes
  As a trainer with medical notes permission
  I want to view a member's medical notes
  So that I can ensure training safety

  @cursor
  Scenario: Trainer with permission views medical notes
    Given a trainer has the "View Medical Notes" permission
    When the trainer views a member profile
    Then the trainer sees medical notes from Member__c.Medical_Notes__c
    And notes are read-only
```""",
        "out_of_scope": "- Medical notes editing\n- Trainers without medical notes permission seeing the field",
        "docs": "- `CRM-Documentation/EPIC-03_US-T009_Trainer_View_Medical_Notes.md`",
        "epic": "EPIC-03",
    },
    {
        "title": "US-T010: Trainer Substitute Class",
        "story": "As a trainer, I want to mark myself as a substitute for another trainer's class, so that coverage gaps are filled.",
        "gherkin": """```gherkin
@EPIC-03 @US-T010
Feature: Trainer Substitute Class
  As a trainer
  I want to substitute for another trainer's class
  So that class coverage is not lost

  @cursor
  Scenario: Trainer signs up as substitute
    Given a trainer views a session they are not assigned to
    When the trainer clicks "Substitute"
    Then the trainer is associated as the substitute for that session
    And the original trainer is notified
```""",
        "out_of_scope": "- Rescheduling sessions\n- Managing substitute pay rates",
        "docs": "- `CRM-Documentation/EPIC-03_US-T010_Trainer_Substitute_Class.md`",
        "epic": "EPIC-03",
    },
    # === EPIC-04: Point of Sale (POS) System ===
    {
        "title": "US-F002: Convert Lead to Member",
        "story": "As a front desk staff member, I want to convert a walk-in lead into a member with membership tier assignment and payment, so that the prospect becomes a paying member in one workflow.",
        "gherkin": """```gherkin
@EPIC-04 @US-F002
Feature: Convert Lead to Member (POS)
  As a front desk staff member
  I want to convert a lead to a member
  So that the prospect becomes a paying member

  @cursor
  Scenario: Front desk converts walk-in lead to member and processes payment
    Given a Lead__c exists with Status__c = "Walk-In"
    And the lead has completed a facility tour
    When the front desk clicks "Convert to Member"
    And selects membership tier "Monthly Unlimited ($129)"
    And processes payment via cash
    Then the lead is converted to a Member__c
    And Membership_Tier__c is set
    And a Payment_Transaction__c is created
    And the Member Status__c = "Active"
```""",
        "out_of_scope": "- Building a new conversion engine (reuses EPIC01_LeadConversion_Action)\n- Building a new payment engine (reuses EPIC01_ProcessPayment_Action)\n- Membership tier selection UI (EPIC-01 US-003 flow is the owner)",
        "docs": "- `CRM-Documentation/EPIC-04_US-F002_Convert_Lead_To_Member.md`\n- `docs/EPIC-11_D001_End_User_Manual.md`",
        "epic": "EPIC-04",
    },
    {
        "title": "US-F003: Renew Membership",
        "story": "As a front desk staff member, I want to renew a member's membership when their subscription expires, so that membership continuity is maintained without service interruption.",
        "gherkin": """```gherkin
@EPIC-04 @US-F003
Feature: Renew Membership
  As a front desk staff member
  I want to renew an expiring membership
  So that the member can continue without interruption

  @cursor
  Scenario: Front desk renews expired membership
    Given a Member__c with Status__c = "Active"
    And Membership_Expiry_Date__c is today or past
    When the front desk clicks "Renew Membership"
    And processes payment
    Then the member's dates are extended
    And a new Payment_Transaction__c is created
```""",
        "out_of_scope": "- Building a new payment path (calls EPIC01_ProcessPayment_Action)\n- Prorated billing calculations",
        "docs": "- `CRM-Documentation/EPIC-04_US-F003_Renew_Membership.md`\n- `docs/EPIC-11_D001_End_User_Manual.md`",
        "epic": "EPIC-04",
    },
    {
        "title": "US-F004: Process Payment",
        "story": "As a front desk staff member, I want to process a membership payment from the POS interface, so that payments are collected efficiently during member onboarding or renewal.",
        "gherkin": """```gherkin
@EPIC-04 @US-F004
Feature: Process Payment (POS UI Layer)
  As a front desk staff member
  I want to process a payment from the POS screen
  So that I can complete membership onboarding or renewal

  @cursor
  Scenario: Front desk processes membership payment via POS screen
    Given a Member__c with Status__c = "Prospect" or "Active"
    And a Membership_Tier__c is selected
    And a valid signed Waiver_Record__c exists
    When the front desk enters amount and payment method
    And clicks "Process Payment"
    Then EPIC01_ProcessPayment_Action.pay() is called
    And a Payment_Transaction__c is created
    And the member status updates correctly
```""",
        "out_of_scope": "- Building a new payment engine (calls EPIC01_ProcessPayment_Action only - UI layer, not engine)\n- Payment gateway integration (simulated processor is the source of truth)",
        "docs": "- `CRM-Documentation/EPIC-04_US-F004_Process_Payment.md`\n- `docs/EPIC-11_D001_End_User_Manual.md`",
        "epic": "EPIC-04",
    },
    {
        "title": "US-F005: Capture Digital Waiver",
        "story": "As a front desk staff member, I want to capture a member's digital signature on a waiver, so that liability coverage is recorded automatically.",
        "gherkin": """```gherkin
@EPIC-04 @US-F005
Feature: Capture Digital Waiver
  As a front desk staff member
  I want to capture a digital waiver signature
  So that liability coverage is recorded

  @cursor
  Scenario: Front desk captures waiver for new member
    Given a Member__c or Lead__c record
    When the front desk selects "Capture Waiver"
    And the visitor signs digitally
    Then a Waiver_Record__c is created with Status__c = "Signed"
    And the member's waiver status is updated
```""",
        "out_of_scope": "- Building waiver enforcement logic (EPIC-01 US-007 trigger is the enforcement point)\n- Creating new Waiver_Record__c object (exists in source)",
        "docs": "- `CRM-Documentation/EPIC-04_US-F005_Capture_Digital_Waiver.md`",
        "epic": "EPIC-04",
    },
    {
        "title": "US-F006: Process Merchandise Sale",
        "story": "As a front desk staff member, I want to sell merchandise (boxing gear, apparel) through the POS system, so that retail revenue is tracked alongside memberships.",
        "gherkin": """```gherkin
@EPIC-04 @US-F006
Feature: Process Merchandise Sale
  As a front desk staff member
  I want to sell merchandise items
  So that retail revenue is tracked

  @cursor
  Scenario: Front desk sells merchandise to a member
    Given Inventory_Item__c records exist with stock
    When the front desk adds items to the cart
    And processes payment
    Then a Merchandise_Sale__c record is created
    And Sale_Line_Item__c records are created for each item
    And Inventory_Item__c stock is decremented
```""",
        "out_of_scope": "- Selling membership plans (covered by US-F004)\n- Inventory management (admin function)",
        "docs": "- `CRM-Documentation/EPIC-04_US-F006_Process_Merchandise_Sale.md`",
        "epic": "EPIC-04",
    },
    {
        "title": "US-F007: Apply Discount with Approval",
        "story": "As a front desk staff member, I want to apply a discount above 10% only with manager approval, so that revenue protection rules are enforced.",
        "gherkin": """```gherkin
@EPIC-04 @US-F007
Feature: Apply Discount with Approval
  As a front desk staff member
  I want to apply a discount requiring manager approval
  So that unauthorized discounts are prevented

  @cursor
  Scenario: Staff applies discount with manager PIN
    Given a front desk staff without manager role
    When the staff clicks "Apply Discount"
    And enters manager PIN
    Then the discount is applied to the sale
```""",
        "out_of_scope": "- Discounts under 10% (no approval needed in future)\n- Manager role management (admin function)",
        "docs": "- `CRM-Documentation/EPIC-04_US-F007_Apply_Discount.md`",
        "epic": "EPIC-04",
    },
    {
        "title": "US-F008: Process Refund / Return",
        "story": "As a front desk staff member, I want to process refunds for merchandise returns or overpaid memberships, so that customer service issues are resolved efficiently.",
        "gherkin": """```gherkin
@EPIC-04 @US-F008
Feature: Process Refund / Return
  As a front desk staff member
  I want to issue a refund
  So that customers get money back for returns or overpayments

  @cursor
  Scenario: Front desk processes a merchandise return refund
    Given a completed Merchandise_Sale__c record
    When the front desk clicks "Refund"
    And enters the reason
    Then a Payment_Transaction__c is created with Payment_Type__c = "Refund"
    And the Merchandise_Sale__c status is updated to "Refunded"
```""",
        "out_of_scope": "- Partial refunds (full refund only in this iteration)\n- Automated refund processing (manual approval required)",
        "docs": "- `CRM-Documentation/EPIC-04_US-F008_Process_Refund_Return.md`",
        "epic": "EPIC-04",
    },
]


def create_issue(s):
    body = f"""## Story

{s["story"]}

## Gherkin Acceptance Criteria

{s["gherkin"]}

## Out of Scope

{s["out_of_scope"]}

## How to Verify

1. Deploy to scratch org `my-gym`: `sf project deploy start --source-dir force-app --target-org my-gym --test-level RunRelevantTests --wait 30`
2. Run relevant Apex tests
3. Manual verification in the UI

## Docs to Update

{s["docs"]}

## Open Questions

-

---

**Epic:** {s["epic"]}
**Labels:** `platform:cursor`
"""
    result = subprocess.run(
        ["gh", "issue", "create", "--repo", REPO, "--title", s["title"], "--body", body],
        capture_output=True, text=True
    )
    if result.returncode == 0:
        print(f"OK  {s['title']}")
        print(f"    {result.stdout.strip()}")
    else:
        print(f"FAIL {s['title']}")
        print(f"    {result.stderr.strip()}")


if __name__ == "__main__":
    for s in STORIES:
        create_issue(s)
