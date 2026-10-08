/**
 * US-F001 — Register a walk-in visitor as a lead
 *
 * Maps to: docs/2026-09-26 Gherkin - Lead Registration & Conversion.md
 *          Scenario: "Successful walk-in lead registration"
 *
 * ── Gaps this spec documents rather than hides ──────────────────────────────
 *
 * 1. NO FLEXIPAGE PLACEMENT. No FlexiPage in force-app places the custom
 *    `epic04LeadRegistrationForm` LWC on a Lightning page yet, so there is no
 *    deployed URL where this spec can drive the custom component. This spec
 *    therefore drives the standard Lead__c "New" record form, which exercises
 *    the same field-level acceptance criteria (AC1/AC2/AC4). AC3's exact
 *    success-toast wording is specific to the undeployed custom UI and is
 *    asserted generically here.
 *
 * 2. NO LEAD__C PAGE LAYOUT IN force-app. There is no `layouts/Lead__c-*.layout`
 *    in the repo, so the org falls back to the SYSTEM DEFAULT layout. Verified
 *    against scratch org `my-gym` (2026-10-08), that default renders only:
 *      Lead Name, Owner, First Name, Location, Last Name, Lead Status
 *    Consequently **Phone__c, Email__c and Lead_Source__c are not on the form
 *    and cannot be filled through the UI.** Their ACs are therefore NOT
 *    asserted here — asserting a value this spec itself wrote via the REST API
 *    would be circular and would prove nothing. When a Lead__c layout (or the
 *    custom LWC form) ships with those fields, extend this spec to fill and
 *    assert them.
 *
 * 3. THE LOCATION LOOKUP IS "RECENTLY USED"-ONLY. Clicking the Location lookup
 *    without typing lists recently-used records and the seeded location appears
 *    there directly. TYPING a search term instead opens an "Advanced Search"
 *    dialog that returns "No results" for this scratch org. So the spec clicks
 *    the lookup and selects from the initial list — do not "improve" this by
 *    typing, it breaks the test.
 *
 * ── Authentication ──────────────────────────────────────────────────────────
 * Frontdoor session from ../global-setup.ts. No password or security token.
 * Field-value assertions are made via the REST API against the record the UI
 * actually created, not by scraping the detail-layout DOM.
 */
import { test, expect, type Page, type Locator } from '@playwright/test';
import { gotoObjectHome, waitForUrl } from '../support/lightning';
import { resolveSalesforceSession } from '../support/salesforceSession';
import { sfDelete, sfGetRecord } from '../support/restClient';
import { QA_FRANCHISE_LOCATION_NAME } from '../support/seedData';

interface LeadFields {
  First_Name__c: string;
  Last_Name__c: string;
  Lead_Status__c: string;
  Franchise_Location__c: string;
}

/**
 * Matches a Lightning record-detail URL and captures the record Id.
 *
 * The Lightning router omits the object API name when the Id alone resolves it,
 * so both of these are real:
 *   /lightning/r/Lead__c/a05RL00000amcLwYAI/view
 *   /lightning/r/a05RL00000amcLwYAI/view          <-- what the org actually emits
 */
const RECORD_VIEW_URL = /\/lightning\/r\/(?:Lead__c\/)?([a-zA-Z0-9]{15,18})\/view/;

/**
 * Select a value from a Lightning combobox.
 *
 * LEX wraps comboboxes in shadow DOM and puts a literal "*" in the accessible
 * name of required fields, so `getByLabel(name, { exact: true })` does not
 * match. A non-exact `getByLabel` matches both the visual label and the
 * combobox element, hence `.first()`.
 */
async function selectComboboxValue(page: Page, dialog: Locator, label: string, optionName: string) {
  await dialog.getByLabel(label).first().click();
  await page.getByRole('option', { name: optionName, exact: true }).first().click();
}

/** Poll for a lookup option whose text contains `text`, then click it. */
async function selectLookupOption(page: Page, lookup: Locator, text: string) {
  await lookup.click();
  const option = page.getByRole('option', { name: new RegExp(escapeRegExp(text)) }).first();
  await expect(option).toBeVisible({ timeout: 15000 });
  await option.click();
}

function escapeRegExp(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

test.describe('US-F001 — Register Walk-In Lead', () => {
  test('Successful walk-in lead registration creates a Lead__c with the entered fields', async ({ page }) => {
    await gotoObjectHome(page, 'Lead__c');

    // Scope to the page header — an unscoped role=button "New" can match the
    // global quick-create button in the nav bar.
    await page
      .locator('.slds-page-header:visible')
      .getByRole('button', { name: 'New', exact: true })
      .first()
      .click();

    const dialog = page.getByRole('dialog').first();
    await expect(dialog).toBeVisible({ timeout: 15000 });

    // Lead Name is a REQUIRED text field on Lead__c (not an autonumber), and it
    // is the one the org flags as missing if left blank ("We hit a snag. Review
    // the following fields: Lead Name"). Fill it before saving.
    await dialog.locator('input[name="Name"]').fill('John Smith');

    // Name-based locators: the accessible names of required fields carry a
    // leading "*" (e.g. "*First Name"), so label matching is unreliable here.
    await dialog.locator('input[name="First_Name__c"]').fill('John');
    await dialog.locator('input[name="Last_Name__c"]').fill('Smith');

    // Location: required lookup. Select from the recently-used list — do NOT
    // type (typing routes to Advanced Search, which finds nothing here).
    const locationLookup = dialog.getByLabel('Location').first();
    await selectLookupOption(page, locationLookup, QA_FRANCHISE_LOCATION_NAME);

    await selectComboboxValue(page, dialog, 'Lead Status', 'Walk-In');

    await dialog.getByRole('button', { name: 'Save', exact: true }).click();

    // AC3: the system confirms success. Exact toast copy ("Lead registered
    // successfully") belongs to the undeployed custom component; here we only
    // assert that Salesforce's own save confirmation appeared.
    await expect(page.locator('.slds-notify_toast, .forceToastMessage')).toBeVisible({ timeout: 15000 });

    // Record creation redirects to the new Lead__c detail page. Two gotchas,
    // both verified against scratch org my-gym (2026-10-08):
    //   1. Lightning routes client-side; page.waitForURL and an in-page
    //      location.href poll both time out even after the URL has changed, so
    //      poll page.url() from the driver side instead (see waitForUrl).
    //   2. The Lightning router OMITS the object segment once the ID alone
    //      resolves it. The real post-save URL is
    //        /lightning/r/a05RL00000amcLwYAI/view
    //      NOT /lightning/r/Lead__c/<id>/view. The pattern below accepts both.
    await waitForUrl(page, RECORD_VIEW_URL, 30000);
    const match = page.url().match(RECORD_VIEW_URL);
    expect(match).not.toBeNull();
    const leadId = match![1];

    const session = resolveSalesforceSession();
    const lead = await sfGetRecord<LeadFields>(session, 'Lead__c', leadId, [
      'First_Name__c',
      'Last_Name__c',
      'Lead_Status__c',
      'Franchise_Location__c',
    ]);

    // AC1: new Lead__c record created with the entered fields.
    expect(lead.First_Name__c).toBe('John');
    expect(lead.Last_Name__c).toBe('Smith');

    // AC2: Lead_Status__c = Walk-In, and the required Location was persisted.
    expect(lead.Lead_Status__c).toBe('Walk-In');
    expect(lead.Franchise_Location__c).toBeTruthy();

    // AC4: the lead appears in the Lead__c "Recent" list without extra filtering.
    // (No "Recent Walk-Ins" list view exists in metadata yet — see gap note above.)
    await gotoObjectHome(page, 'Lead__c', 'Recent');
    await expect(page.getByRole('link', { name: 'John Smith' }).first()).toBeVisible({ timeout: 15000 });

    // Cleanup: delete the lead so the test is idempotent and doesn't leave
    // records in the org. Uses the REST API (not the UI) for reliability.
    await sfDelete(session, 'Lead__c', leadId);
  });
});
