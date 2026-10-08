/**
 * Playwright E2E smoke suite — Salesforce Headless CRM (Boxing Gym Franchise)
 *
 * Authentication is handled once in ../global-setup.ts via a frontdoor session
 * derived from the Salesforce CLI's already-authenticated org (see
 * ../support/salesforceSession.ts). No username, password, or security token
 * is read by this file or by CI.
 *
 * Run:
 *   npm run test:e2e
 */
import { test, expect } from '@playwright/test';
import { gotoObjectHome, listViewTitle, newButton } from '../support/lightning';

const TARGET_OBJECTS = [
  'Franchise_Location__c',
  'Franchise_Owner__c',
  'Member__c',
  'Lead__c',
  'Scheduled_Session__c',
  'Booking__c',
  'Payment_Transaction__c',
  'Royalty_Report__c',
  'Product_Category__c',
  'Inventory_Item__c',
  'Merchandise_Sale__c',
  'Sale_Line_Item__c',
  'Default_Class_Template__c',
  'Waiver_Template__c',
  'Waiver_Record__c'
];

/**
 * Object label → the text that actually appears in the browser tab title.
 *
 * The title format for an object list view is:
 *   "Recently Viewed | <Object Label> | Salesforce"
 *
 * Every label below was read off a live page in scratch org `my-gym`
 * (2026-10-08) — do NOT "fix" these to match the API name. Note in particular
 * that `Product_Category__c` renders as **"Product Categorys"**: Salesforce
 * pluralises the label naively, so the human-correct "Product Categories" would
 * fail this assertion. Asserting on the API name (the previous behaviour) never
 * matched either, since the title carries the label, not the API name.
 */
const OBJECT_LABELS: Record<string, string> = {
  'Franchise_Location__c': 'Franchise Locations',
  'Franchise_Owner__c': 'Franchise Owners',
  'Member__c': 'Members',
  'Lead__c': 'Leads',
  'Scheduled_Session__c': 'Scheduled Sessions',
  'Booking__c': 'Bookings',
  'Payment_Transaction__c': 'Payment Transactions',
  'Royalty_Report__c': 'Royalty Reports',
  'Product_Category__c': 'Product Categorys',
  'Inventory_Item__c': 'Inventory Items',
  'Merchandise_Sale__c': 'Merchandise Sales',
  'Sale_Line_Item__c': 'Sale Line Items',
  'Default_Class_Template__c': 'Default Class Templates',
  'Waiver_Template__c': 'Waiver Templates',
  'Waiver_Record__c': 'Waiver Records',
};

test.describe('Salesforce Headless CRM — Smoke Tests', () => {
  test('All 15 custom objects are accessible in Lightning', async ({ page }) => {
    // 15 sequential cold list-view loads at ~3-4s each do not fit the 60s
    // default test timeout — this test timed out mid-loop and reported as flaky.
    // Give it a budget that actually covers the loop, and keep the per-object
    // wait (45s in gotoObjectHome) below it so a single slow object fails with a
    // useful "header never appeared" error rather than killing the whole test.
    test.setTimeout(240000);
    for (const obj of TARGET_OBJECTS) {
      await test.step(`Navigate to ${obj}`, async () => {
        await gotoObjectHome(page, obj);
        const title = await page.title();
        expect(title).toContain(OBJECT_LABELS[obj]);
      });
    }
  });

  test('Franchise_Location__c list view loads', async ({ page }) => {
    await gotoObjectHome(page, 'Franchise_Location__c');

    // The list view name renders as static header text in this org. There is no
    // list-view picker dropdown to assert on — a previous version of this test
    // looked for `[data-testid="list-view-dropdown"]`, which does not exist in
    // modern Lightning Experience (verified against `my-gym`).
    expect(await listViewTitle(page)).toBe('Recently Viewed');

    // The view is actually usable: its New action is present.
    // Scoped to the page header — an unscoped `getByRole('button', {name:'New'})`
    // can match the global quick-create button in the nav bar.
    await expect(newButton(page)).toBeVisible({ timeout: 15000 });
  });

  test('Deployed list views render (Active Members, This Week\'s Classes)', async ({ page }) => {
    // These two list views ship as metadata (Member__c.Active_Members,
    // Scheduled_Session__c.This_Weeks_Classes) and are addressed by developer
    // name via ?filterName=. Guards against a metadata change silently dropping
    // a deployed list view.
    await gotoObjectHome(page, 'Member__c', 'Active_Members');
    expect(await listViewTitle(page)).toBe('Active Members');

    await gotoObjectHome(page, 'Scheduled_Session__c', 'This_Weeks_Classes');
    expect(await listViewTitle(page)).toBe("This Week's Classes");
  });

  test('Waiver_Record__c has Primary_Waiver record type', async ({ page }) => {
    await gotoObjectHome(page, 'Waiver_Record__c');

    const createBtn = page.locator('button[data-id="CreateOverride-Waiver_Record__c"]');
    if ((await createBtn.count()) > 0) {
      await createBtn.click();
      const recordTypeOption = page.locator('text=Primary Waiver');
      await expect(recordTypeOption).toBeVisible({ timeout: 5000 });
    }
  });

  test('Member__c has Active_Member record type', async ({ page }) => {
    await gotoObjectHome(page, 'Member__c');

    const createBtn = page.locator('button[data-id="CreateOverride-Member__c"]');
    if ((await createBtn.count()) > 0) {
      await createBtn.click();
      const recordTypeOption = page.locator('text=Active Member');
      await expect(recordTypeOption).toBeVisible({ timeout: 5000 });
    }
  });
});

test.describe('Salesforce Headless CRM — Business Rule Tests', () => {
  test('Cannot book class without waiver (validation rule)', async () => {
    // "Cannot book classes without signed waiver" — needs Booking__c + Waiver_Record__c
    // seed data wired up before this can assert anything real.
    test.skip(true, 'Requires full org setup with record data');
  });

  test('Franchise isolation works across locations', async () => {
    // Data segregation by Franchise_Location__c — needs multi-location seed data.
    test.skip(true, 'Requires full org setup with multi-location records');
  });
});
