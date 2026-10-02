# Gherkin Specs — Management App Surface (CHI-8)

## Feature: Curated navigation for the Boxing Gym CRM app

**Issue:** [CHI-8](/CHI/issues/CHI-8)

```gherkin
Feature: App navigation
  As a gym manager
  I want the app to show only the tabs I use day to day, in a sensible order
  So that I am not navigating a developer's object list

  Background:
    Given a gym manager is logged in and has opened the "Boxing Gym CRM" app

  Scenario: Tab bar shows the curated set in order
    Then the visible tabs, left to right, are:
      | Tab                |
      | Home                |
      | Member              |
      | Scheduled Session    |
      | Booking              |
      | Lead                 |
      | Franchise Location   |
      | Waiver Record        |
      | Payment Transaction  |
      | Reports              |
      | Dashboards           |
    And "Inventory Item", "Merchandise Sale", "Sale Line Item", "Product Category",
      "Royalty Report", "Franchise Owner", "Waiver Template", and "Default Class Template"
      are not shown as tabs in this app

  Scenario: Removed tabs are not deleted, just hidden from this app
    Given an object whose tab was removed from the app's navigation, e.g. "Royalty Report"
    When an admin opens the object manager or another app that still lists that tab
    Then the "Royalty Report" tab, object, and all of its records still exist and are unchanged
```

## Feature: Gym Manager home page

**Issue:** [CHI-8](/CHI/issues/CHI-8)

```gherkin
Feature: Home page
  As a gym manager
  I want useful information and quick guidance when I log in
  So that I know where to go without hunting through Setup or global search

  Background:
    Given a gym manager is logged into the "Boxing Gym CRM" app

  Scenario: Home tab shows the manager home page
    When the manager clicks the "Home" tab
    Then the "Gym Manager Home" page is displayed
    And it shows a welcome panel naming where to find active members by location
      and this week's classes
    And it shows recently viewed Members and Leads
    And it shows recently viewed Scheduled Sessions and Bookings

  Scenario: No recent records yet (empty state)
    Given the manager has not yet viewed any Member, Lead, Scheduled Session, or Booking records
    When the manager opens the Home page
    Then the recent-items panels render without error and show their standard
      Salesforce "no recent records" empty state
```

## Feature: Member record page

**Issue:** [CHI-8](/CHI/issues/CHI-8)

```gherkin
Feature: Member record page
  As a gym manager
  I want member fields grouped by purpose and the related activity visible
  So that I can read a member's standing at a glance

  Background:
    Given a gym manager has permission to view Member records
    And a Member record "Jane Doe" exists with Status__c = "Active"

  Scenario: Highlights panel shows key identity at a glance
    When the manager opens the "Jane Doe" Member record
    Then the highlights panel shows Name, Status, Membership Tier, Home Location,
      Expiry Date, and Phone

  Scenario: Details tab groups fields into sensible sections
    When the manager opens the "Details" tab on the Member record
    Then the fields are grouped into "Member Info", "Contact & Emergency",
      "Compliance & Medical", and "Engagement & Referral" sections
    And no section mixes unrelated fields (e.g. billing fields do not appear
      in "Contact & Emergency")

  Scenario: Related tab shows the member's activity
    When the manager opens the "Related" tab on the Member record
    Then the Bookings, Payment Transactions, and Waiver Records related lists
      for that member are visible

  Scenario: Field-level permission denies a field
    Given the manager's permission set does not grant read access to "Medical_Notes__c"
    When the manager opens the Member record's Details tab
    Then the "Compliance & Medical" section renders without that field
      and without an error
```

## Feature: Scheduled Session (class) record page

**Issue:** [CHI-8](/CHI/issues/CHI-8)

```gherkin
Feature: Scheduled Session record page
  As a gym manager
  I want class fields grouped by purpose and the roster visible
  So that I can confirm a class is staffed and see who is booked

  Background:
    Given a gym manager has permission to view Scheduled Session records
    And a Scheduled Session "Tuesday 6pm Boxing" exists

  Scenario: Highlights panel shows key class info at a glance
    When the manager opens the "Tuesday 6pm Boxing" session
    Then the highlights panel shows Name, Program Type, Location, Start Time,
      and Session Status

  Scenario: Details tab groups fields into sensible sections
    When the manager opens the "Details" tab on the session record
    Then the fields are grouped into "Class Info" (program, location, trainer,
      status) and "Timing & Capacity" (start/end time, max capacity, template) sections

  Scenario: Related tab shows the roster
    When the manager opens the "Related" tab on the session record
    Then the Bookings related list for that session is visible
```

## Feature: Active Members list view

**Issue:** [CHI-8](/CHI/issues/CHI-8)

```gherkin
Feature: Active Members list view
  As a gym manager
  I want to see active members and filter to one location
  So that I can answer "who is active at location X" without Setup or global search

  Background:
    Given a gym manager is on the Member tab
    And Member records exist with Status__c = "Active" at multiple Home_Location__c values
    And Member records exist with Status__c = "Lapsed" or "Cancelled"

  Scenario: Active Members list view shows only active members
    When the manager selects the "Active Members" list view
    Then only Members with Status__c = "Active" are shown
    And the columns include Name, Status, Home Location, Membership Tier,
      Expiry Date, and Phone

  Scenario: Filter the list view to one location
    When the manager filters the "Home Location" column to a single Franchise Location
    Then only active members whose Home_Location__c matches that location are shown
    And the manager did not need to open Setup or use global search to do this

  Scenario: No active members at a location (empty state)
    Given a Franchise Location has no Members with Status__c = "Active"
    When the manager filters "Active Members" to that location
    Then the list view shows the standard "no records to display" empty state

  Scenario: Permission-denied state
    Given a user's permission set does not grant read access to the Member object
    When that user opens the Member tab
    Then Salesforce shows the standard insufficient-access page
    And no Member data is shown
```

## Feature: This Week's Classes list view

**Issue:** [CHI-8](/CHI/issues/CHI-8)

```gherkin
Feature: This Week's Classes list view
  As a gym manager
  I want to see this week's scheduled classes with trainer and capacity
  So that I can confirm coverage without Setup or global search

  Background:
    Given a gym manager is on the Scheduled Session tab
    And Scheduled Session records exist with Start_Time__c values this week and
      other weeks
    And some sessions this week have Session_Status__c = "Cancelled"

  Scenario: This Week's Classes list view shows only this week's active sessions
    When the manager selects the "This Week's Classes" list view
    Then only sessions with Start_Time__c in the current week and
      Session_Status__c not equal to "Cancelled" are shown
    And the columns include Name, Location, Program Type, Assigned Trainer,
      Start Time, End Time, Max Capacity, and Session Status

  Scenario: No classes scheduled this week (empty state)
    Given no Scheduled Session records have a Start_Time__c in the current week
    When the manager selects "This Week's Classes"
    Then the list view shows the standard "no records to display" empty state
```

## Out of scope / follow-up

- **Staff roster list view and a Staff record page are not included.** CHI-8 is
  explicitly blocked on the `Staff__c` vs `User` decision (gap analysis). Once
  that decision lands, add a Staff tab to the app navigation (between Member
  and Scheduled Session) and a roster list view grouped by role and home
  location, and repoint `Scheduled_Session__c.Assigned_Trainer__c` accordingly.
- **Custom Report/Dashboard metadata is not included.** The "Reports" and
  "Dashboards" standard tabs are added to navigation so a manager has an entry
  point, but authoring specific report types/reports/dashboards as source
  metadata is separate follow-up work.
- Booking__c, Lead__c, Franchise_Location__c, Waiver_Record__c, and
  Payment_Transaction__c keep their stock (auto-generated) record pages for
  now; only Member__c and Scheduled_Session__c record pages were explicitly
  in scope for this issue.
