# EPIC-11 / US-D003 — Franchise Owner Guide (Dashboards + Royalties)

Issue: #39. Kanban: `t_2d4f52f9`.

**Status:** Draft
**Last verified:** 2026-10-08 against `main` `23d6c67`
**Checked from:** source in `force-app` (not an org click-through)
**Still open:** no franchise-owner dashboard, no royalty calculation, no royalty payment tracking, no screenshots

This is the canonical copy. The issue names `CRM-Documentation/EPIC-11_D003_Franchise_Owner_Guide.md`. Sync that vault from this file when the vault is available.

Gym-wide member and class charts are the **Boxing Gym Management Dashboard** in US-D002. They are not a franchise-owner dashboard. There is no location comparison, date-range filter, or royalty chart in source.

## Dashboards

**Not built** for a franchise owner.

| Asked for | What exists |
|---|---|
| Franchise owner dashboard | No dashboard by that name. The only dashboard is **Boxing Gym Management Dashboard** (US-D002). |
| KPIs: membership count, revenue, attendance, retention | That dashboard shows an Active member count, class attendance, staff capacity, and upcoming sessions. It has no revenue and no retention. |
| Filter by date range and location | Not on a franchise dashboard. Upcoming Sessions is filtered to start time ≥ today. Active Members is grouped by Home Location, not filtered by a date range. |
| Compare performance across periods | No comparison report. |

## Royalty records

**Verified from source** as data entry. **Not built** as a calculation or a payment schedule.

Royalty Reports are not on the Boxing Gym CRM app bar. Open them from the App Launcher → **Royalty Reports**. The permission set can create, edit, and delete them.

Create a row with **New**. Nothing fills the amounts for you. `Royalty_Amount_Due__c` is currency, not a formula. Gross revenue times rate is not calculated.

| Field | Required in source | Notes |
|---|---|---|
| Royalty Report Name | Yes | Text name. |
| Franchise Location | No | Lookup. |
| Reporting Month | No | Date. |
| Gross Revenue | No | Currency. Type it. |
| Royalty Rate % | No | Percent on this report. Separate from Franchise Owner → Royalty Rate %. Neither one drives the other. |
| Royalty Amount Due | No | Currency. Type it. |
| Report Status | No | Draft, Calculated, Sent, Paid, or Disputed. A leftover value labeled `Status__c` is also in the picklist. Do not select it. Status is a label only. Setting Paid does not record a payment. |
| Notes | No | Text area. |

There is no royalty schedule, no invoice, and no payment object linked to this report.

Franchise Owner has its own **Royalty Rate %** (whole-number percent) plus agreement start and end dates. Those fields do not generate a Royalty Report. Creating an owner is in US-D004.

## How to verify this draft

1. App Launcher → Royalty Reports → New shows the fields above, with Amount Due empty until someone types it.
2. Dashboards tab does not show a franchise-owner or royalty dashboard.
3. Leave this guide Draft until a calculation and a dashboard exist. Do not invent the math.
