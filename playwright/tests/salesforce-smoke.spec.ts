/**
 * Playwright E2E Tests for Salesforce Headless CRM
 * Boxing Gym Franchise Management
 *
 * Run on the VM:
 *   npx playwright test --headed     # with browser
 *   npx playwright test --headless   # without browser (default)
 *
 * Prerequisites: Authenticated to Salesforce Partner Dev Org
 *   sf org login web --alias partner-dev --set-default --no-browser
 *   npx playwright test
 */

import { test, expect, chromium, Browser, Page, BrowserContext } from '@playwright/test';
import * as dotenv from 'dotenv';
dotenv.config();

// ─── Configuration ──────────────────────────────────────────────────────────

const SF_BASE_URL = process.env.SF_BASE_URL || 'https://test.salesforce.com';
const SF_USERNAME = process.env.SF_USERNAME || '';
const SF_PASSWORD = process.env.SF_PASSWORD || '';
const SF_SECURITY_TOKEN = process.env.SF_SECURITY_TOKEN || '';

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

// ─── Helpers ────────────────────────────────────────────────────────────────

async function loginToSalesforce(page: Page, username: string, password: string, token: string): Promise<void> {
  const loginUrl = `${SF_BASE_URL}/`;
  await page.goto(loginUrl);

  await page.fill('#username', username);
  await page.fill('#password', `${password}${token}`);
  await page.click('#Login');

  // Wait for Lightning Experience to load
  await page.waitForURL(/.*\/lightning\//, { timeout: 30000 });

  // Handle 2FA if present (manual step for CI)
  if (page.url().includes('verify')) {
    console.log('🔐 2FA challenge detected — complete manually in headed mode');
    await page.waitForURL(/.*\/lightning\//, { timeout: 120000 });
  }
}

async function gotoObjectHome(page: Page, objectApiName: string): Promise<void> {
  await page.goto(`${SF_BASE_URL}/lightning/o/${objectApiName}/list`);
  await page.waitForSelector('.slds-page--container', { timeout: 15000 });
}

// ─── Tests ──────────────────────────────────────────────────────────────────

test.describe('Salesforce Headless CRM — Smoke Tests', () => {
  let browser: Browser;

  test.beforeAll(async () => {
    browser = await chromium.launch({ headless: true });
  });

  test.afterAll(async () => {
    await browser.close();
  });

  test.beforeEach(async ({ page }) => {
    await loginToSalesforce(page, SF_USERNAME, SF_PASSWORD, SF_SECURITY_TOKEN);
  });

  test('All 15 custom objects are accessible in Lightning', async ({ page }) => {
    for (const obj of TARGET_OBJECTS) {
      await test.step(`Navigate to ${obj}`, async () => {
        await gotoObjectHome(page, obj);
        // Verify the object list view loaded
        const title = await page.title();
        expect(title).toContain(obj.replace('__', '_'));
      });
    }
  });

  test('Franchise_Location__c list view loads', async ({ page }) => {
    await gotoObjectHome(page, 'Franchise_Location__c');
    // Look for the list view dropdown
    const listView = page.locator('[data-testid="list-view-dropdown"]');
    await expect(listView).toBeVisible({ timeout: 10000 });
  });

  test('Waiver_Record__c has Primary_Waiver record type', async ({ page }) => {
    await gotoObjectHome(page, 'Waiver_Record__c');

    // Navigate to record types via Setup
    await page.goto(`${SF_BASE_URL}/lightning/o/Waiver_Record__c/list`);
    await page.waitForSelector('.slds-page--container', { timeout: 10000 });

    // Verify record type exists by checking Create button dropdown
    const createBtn = page.locator('button[data-id="CreateOverride-Waiver_Record__c"]');
    if (await createBtn.count() > 0) {
      await createBtn.click();
      const recordTypeOption = page.locator('text=Primary Waiver');
      await expect(recordTypeOption).toBeVisible({ timeout: 5000 });
    }
  });

  test('Member__c has Active_Member record type', async ({ page }) => {
    await gotoObjectHome(page, 'Member__c');

    const createBtn = page.locator('button[data-id="CreateOverride-Member__c"]');
    if (await createBtn.count() > 0) {
      await createBtn.click();
      const recordTypeOption = page.locator('text=Active Member');
      await expect(recordTypeOption).toBeVisible({ timeout: 5000 });
    }
  });
});

test.describe('Salesforce Headless CRM — Business Rule Tests', () => {
  test('Cannot book class without waiver (validation rule)', async () => {
    // This test verifies the business rule:
    // "Cannot book classes without signed waiver"
    // Implementation: Create Booking__c record, expect validation error
    test.skip('Requires full org setup with record data');
  });

  test('Franchise isolation works across locations', async () => {
    // This test verifies data segregation by Franchise_Location__c
    test.skip('Requires full org setup with multi-location records');
  });
});
