# Licensing and Architecture Decision

**Decided:** 2026-10-12 (Maria)
**Status:** Accepted, pending confirmation with the Salesforce account rep (see Open items)
**Affects:** EPIC-03 trainer stories, EPIC-06 API layer, EPIC-07 member portal, #64 QR credential

## Decision

1. **Staff work in Salesforce on internal licenses.** Trainers, front desk, and managers use the Boxing Gym CRM Lightning app. Trainers get Platform Starter. Front desk and managers get Platform Plus.
2. **Members use a separate thin-client app** (EPIC-07) that reads and writes Salesforce through a server-side bridge (EPIC-06). Members get no Salesforce license.
3. **Salesforce stays the system of record and the rule engine.** Waiver checks, payments, renewals, check-in, and medical-notes permissions live in Salesforce. The member app calls them; it does not re-implement them.
4. **An Experience Cloud member site is the fallback.** If Salesforce says the thin-client pattern needs a license per member anyway, only the member front end moves to an Experience site. Data and rules are already in Salesforce.

This replaces the earlier README rule "Trainers use thin-client app (no SF licenses)".

## Why

Members are the volume. The target is about 400 members per location who can access their accounts. At the last published Customer Community member price ($5/member/month), that is about $2,000 a month per location, against roughly $650 a month for one location's staff in the example below. A thin client removes the member line.

Staff cannot move to community licenses to save money. Experience Cloud licenses (Customer Community, Customer Community Plus, Partner Community) are for external users only. Salesforce requires internal licenses for employees, however they reach the data. Internal users can still log in to an Experience site with their Platform license.

## Licenses by role

| Role               | License            | Published price | Why                                                                     |
| ------------------ | ------------------ | --------------- | ----------------------------------------------------------------------- |
| Manager            | Platform Plus      | $100/user/month | Needs most custom objects, plus reports                                 |
| Front desk         | Platform Plus      | $100/user/month | Uses more than 10 custom objects                                        |
| Trainer            | Platform Starter   | $25/user/month  | Fewer than 10 custom objects; Salesforce mobile app for camera scanning |
| Member or guardian | None (thin client) | $0              | See fallback below                                                      |

Prices checked 2026-10-12, billed annually, before tax and optional Premier support (30% of license fees):

- Platform Starter and Plus: [Platform pricing](https://www.salesforce.com/platform/enterprise-app-development/pricing/)
- Customer Community Plus ($15/login, $35/member) and Partner Community ($20/login, $50/member): [Experience Cloud add-on pricing](https://www.salesforce.com/manufacturing/cloud/experience-cloud/)
- Customer Community ($2/login, $5/member): [2023 price list](https://wp.salesforce.com/en-us/wp-content/uploads/sites/4/2023/06/Service-SelfService-PricingList.pdf). Salesforce no longer publishes this price. Get a quote.

**10-custom-object limit.** Platform Starter and all community licenses allow each user 10 custom objects ([license limits](https://help.salesforce.com/s/articleView?id=users_license_types_communities_lightning_platform_details.htm&language=en_US&type=5)). This org has 16 custom objects, and promo codes (#61) will add one. Keep trainer permissions under 10 objects, or trainers need Platform Plus.

**No Sales Cloud licenses needed.** `Lead__c` and `Member__c` are custom objects, not the standard Lead and Contact.

### Example, one location (assumed staff counts)

| Line                                         | Monthly  |
| -------------------------------------------- | -------- |
| 2 managers × $100                            | $200     |
| 3 front desk × $100                          | $300     |
| 6 trainers × $25                             | $150     |
| **Staff total**                              | **$650** |
| Fallback only: 400 members × $5 (2023 price) | $2,000   |

## What the member app must own

Without an Experience site, Salesforce sharing no longer separates members from each other. The integration user can see every record.

- **Member login.** The app handles sign-up, login, and password reset, then maps each person to their `Member__c` record by a stored ID.
- **Authorization on every request.** A member sees only their own records. A guardian sees only their child's. Medical notes follow #54 (the member, their guardian, and trainers only).
- **Credentials stay on the server.** EPIC-06 uses the OAuth JWT bearer flow from the server, never from the phone or browser. Use an API-only integration user.
- **API limits.** The org has a daily API call cap shared by everything. Cache the class schedule, read a member's data once per session, and batch writes.
- **QR credential (#64).** The wallet pass and fob live in this app. Salesforce stores the check-in code (#47).

## Open items

| Item                                                                                                                  | Who                                    |
| --------------------------------------------------------------------------------------------------------------------- | -------------------------------------- |
| Confirm in writing that members using our own app, through one integration user, do not each need a community license | Maria, with the Salesforce account rep |
| Current Customer Community member and login prices, for the fallback                                                  | Maria, quote                           |
| Whether franchisee-owned locations' staff qualify for Partner Community                                               | Maria, with the account rep            |
| Whether trainers who are contractors count as internal users                                                          | Maria, with the account rep            |
| Number of locations, staff per location, and how often members log in                                                 | Maria                                  |
| How many free API-only Salesforce Integration user licenses the contract includes                                     | Maria, contract                        |
