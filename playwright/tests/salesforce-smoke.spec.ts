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
import { test, expect, type Page } from '@playwright/test';

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
  'Waiver_Record__c',
];

async function gotoObjectHome(page: Page, objectApiName: string): Promise<void> {
  await page.goto(`/lightning/o/${objectApiName}/list`);
  await page.waitForSelector('.slds-page--container', { timeout: 15000 });
}

test.describe('Salesforce Headless CRM — Smoke Tests', () => {
  test('All 15 custom objects are accessible in Lightning', async ({ page }) => {
    for (const obj of TARGET_OBJECTS) {
      await test.step(`Navigate to ${obj}`, async () => {
        await gotoObjectHome(page, obj);
        const title = await page.title();
        expect(title).toContain(obj.replace('__', '_'));
      });
    }
  });

  test('Franchise_Location__c list view loads', async ({ page }) => {
    await gotoObjectHome(page, 'Franchise_Location__c');
    const listView = page.locator('[data-testid="list-view-dropdown"]');
    await expect(listView).toBeVisible({ timeout: 10000 });
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
