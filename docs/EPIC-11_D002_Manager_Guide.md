# EPIC-11 / US-D002 — Manager Guide (Operations + Reporting)

Issue: #38. Kanban: `t_f19ed172`.

**Status:** Draft
**Last verified:** 2026-10-08 against `main` `23d6c67`
**Checked from:** source in `force-app` (not an org click-through)
**Still open:** screenshots of the report builder; scheduled-report clicks in `my-gym`; no revenue-by-tier report, expiring-membership report, or trainer-assignment screen

This is the canonical copy. The issue names `CRM-Documentation/EPIC-11_D002_Manager_Guide.md`. Sync that vault from this file when the vault is available.

Day-to-day lead, tier, and payment steps are US-D001. Changing tier values, users, and sharing is US-D004.

## Open reports and the dashboard

**Verified from source. Needs an org click-through** for the exact Lightning clicks.

1. Open the **Boxing Gym CRM** app.
2. Open the **Reports** tab. The folder is **Boxing Gym Management Reports** (API name `Boxing_Gym_Management`), shared to all internal users.
3. Open the **Dashboards** tab. The dashboard title is **Boxing Gym Management Dashboard**. Its running-user setting is `LoggedInUser`, so each viewer sees rows their own sharing allows. The permission set grants View All on these objects, so an assigned user sees every row.

The dashboard has five parts:

| Header on the dashboard | Report | Chart |
|---|---|---|
| Active Members by Location | Active Members by Location | Bar, count by Home Location |
| Total Active Members | Active Members by Location | Metric, row count |
| Class Attendance | Class Attendance | Stacked column by Program Type and booking Status |
| Staff Utilization | Staff Utilization (file name `Staff_Utilisation`) | Grouped column, sum of Max Capacity, by Assigned Trainer and Franchise Location |
| Upcoming Sessions and Capacity | Upcoming Sessions and Capacity | Table: session name, start time, booking name, booking status, member |

## What each report filters

**Verified from source.**

### Active Members by Location

- Report type: Members
- Filter: Status equals **Active**
- Grouped by Home Location
- Column: member name
- Scope: organization
- The date filter is on Date of Birth with a custom interval and no start or end in the file. **Needs an org click-through** to see whether that hides rows.

### Class Attendance

- Report type: Scheduled Sessions with Bookings
- Filter: Session Status equals **Completed**
- Rows grouped by Program Type
- Columns grouped by booking Status
- Columns: session name, booking name
- Scope: organization

### Upcoming Sessions and Capacity

- Report type: Scheduled Sessions with Bookings
- Filters: Start Time greater than or equal to today, and Session Status equals **Scheduled**
- Grouped by Franchise Location, then Program Type, then Max Capacity
- Columns: session name, start time, booking name, booking status, member
- Scope: **user** (My records), unlike the other three reports. A manager who does not own the session can see an empty report here even when the dashboard table looks different. **Needs an org click-through.**

### Staff Utilization

- Report type: Scheduled Sessions
- Filter: Session Status not equal to **Cancelled**
- Grouped by Assigned Trainer, then Franchise Location
- Columns: session name, and the sum of Max Capacity
- Scope: organization
- The sum is class capacity, not hours worked and not heads counted.

## Operations the issue asks for

| Asked for | Draft result |
|---|---|
| View and manage member records | **Verified from source.** Members tab in Boxing Gym CRM. Record actions that exist are in US-D001. |
| View class schedules and attendance | **Verified from source.** Use the two session reports above. No separate schedule editor. |
| Manage trainer assignments | **Not built** as a screen. `Scheduled_Session__c.Assigned_Trainer__c` is the field the Staff Utilization report groups by. Edit it on the session record. |
| View and manage membership tiers | **Verified from source** as a restricted picklist on the member. Staff pick a tier with **Select Membership Tier**. Changing the price list is a source change. See US-D004. There is no tier report. |
| Track expiring memberships | **Not built.** `Expiry_Date__c` is on the member. No report filters on it. |
| Revenue by tier | **Not built.** Payment Transaction exists. No revenue report is in the folder. |
| Membership growth, retention | **Not built.** The dashboard metric is a count of Active members, not growth or retention. |

## Create, schedule, and export a report

**Needs an org click-through.** This repo ships the four reports above. It does not ship a report subscription, an export file, or a custom report type beyond Scheduled Sessions with Bookings.

Salesforce's report run page can usually save a clone, export, and subscribe. Confirm those buttons in `my-gym` before writing the click path. Do not describe a gym KPI builder that is not in source.

Filters that already matter:

- Active Members by Location keeps Status = Active. Drop that filter to see Prospects.
- Class Attendance keeps Session Status = Completed. Scheduled classes will not appear.
- Upcoming Sessions keeps Start Time ≥ today and Session Status = Scheduled.
- Staff Utilization drops Cancelled sessions and sums Max Capacity.

## How to verify this draft

1. Reports tab → folder **Boxing Gym Management Reports** shows the four report names above.
2. Dashboards tab → **Boxing Gym Management Dashboard** shows the five headers above.
3. Upcoming Sessions and Capacity is the one report with scope **user**.
4. Leave revenue, retention, expiry, and scheduled email on the **Still open** list until a report for them exists.
