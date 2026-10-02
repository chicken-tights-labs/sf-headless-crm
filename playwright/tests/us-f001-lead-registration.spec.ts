/**
 * US-F001 — Register a walk-in visitor as a lead
 *
 * Maps to: docs/2026-09-26 Gherkin - Lead Registration & Conversion.md
 *          Scenario: "Successful walk-in lead registration"
 *
 * Gap this spec documents rather than hides (see docs/acceptance-and-review.md
 * §3 worked example): no FlexiPage in force-app places the custom
 * `epic04LeadRegistrationForm` LWC on a Lightning page yet, so there is no
 * deployed URL where this spec can drive the actual custom component. Until
 * that placement lands, this spec drives the standard Lead__c "New" record
 * form instead — it exercises the same field-level acceptance criteria
 * (AC1/AC2/AC4) that the story promises, but AC3's exact success-toast
 * wording is specific to the undeployed custom UI and is asserted generically
 * here. When the FlexiPage placement ships, point this spec at the custom
 * component and tighten AC3 to the exact message.
 *
 * Authentication: frontdoor session from ../global-setup.ts. No password or
 * security token. Field-value assertions are made via the REST API against
 * the record the UI actually created, not by scraping the detail-layout DOM.
 */
import { test, expect } from '@playwright/test';
import { resolveSalesforceSession } from '../support/salesforceSession';
import { sfGetRecord } from '../support/restClient';
import { QA_FRANCHISE_LOCATION_NAME } from '../support/seedData';

interface LeadFields {
  First_Name__c: string;
  Last_Name__c: string;
  Phone__c: string;
  Email__c: string;
  Lead_Status__c: string;
  Lead_Source__c: string;
}

test.describe('US-F001 — Register Walk-In Lead', () => {
  test('Successful walk-in lead registration creates a Lead__c with the entered fields', async ({ page }) => {
    await page.goto('/lightning/o/Lead__c/list');
    await page.waitForSelector('.slds-page--container', { timeout: 15000 });

    await page.getByRole('button', { name: 'New', exact: true }).first().click();
    const dialog = page.getByRole('dialog');
    await expect(dialog).toBeVisible({ timeout: 10000 });

    await dialog.getByLabel('First Name', { exact: true }).fill('John');
    await dialog.getByLabel('Last Name', { exact: true }).fill('Smith');
    await dialog.getByLabel('Phone', { exact: true }).fill('555-123-4567');
    await dialog.getByLabel('Email', { exact: true }).fill('john@example.com');

    // Location is a required Lookup to the seeded Franchise_Location__c.
    const locationInput = dialog.getByLabel('Location', { exact: true });
    await locationInput.fill(QA_FRANCHISE_LOCATION_NAME);
    await page.getByRole('option', { name: new RegExp(QA_FRANCHISE_LOCATION_NAME.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')) }).first().click();

    await dialog.getByLabel('Lead Status', { exact: true }).click();
    await page.getByRole('option', { name: 'Walk-In', exact: true }).click();

    await dialog.getByLabel('Lead Source', { exact: true }).click();
    await page.getByRole('option', { name: 'In Person', exact: true }).click();

    await dialog.getByRole('button', { name: 'Save', exact: true }).click();

    // AC3: the system confirms success. Exact toast copy ("Lead registered
    // successfully") belongs to the undeployed custom component; here we only
    // assert that Salesforce's own save confirmation appeared.
    await expect(page.locator('.slds-notify_toast, .forceToastMessage')).toBeVisible({ timeout: 10000 });

    // Record creation redirects to the new Lead__c detail page.
    await page.waitForURL(/\/lightning\/r\/Lead__c\/[a-zA-Z0-9]+\/view/, { timeout: 15000 });
    const match = page.url().match(/\/lightning\/r\/Lead__c\/([a-zA-Z0-9]+)\/view/);
    expect(match).not.toBeNull();
    const leadId = match![1];

    const session = resolveSalesforceSession();
    const lead = await sfGetRecord<LeadFields>(session, 'Lead__c', leadId, [
      'First_Name__c',
      'Last_Name__c',
      'Phone__c',
      'Email__c',
      'Lead_Status__c',
      'Lead_Source__c',
    ]);

    // AC1: new Lead__c record created with the entered fields.
    expect(lead.First_Name__c).toBe('John');
    expect(lead.Last_Name__c).toBe('Smith');
    expect(lead.Phone__c).toBe('555-123-4567');
    expect(lead.Email__c).toBe('john@example.com');

    // AC2: Lead_Status__c = Walk-In, Lead_Source__c = In Person.
    expect(lead.Lead_Status__c).toBe('Walk-In');
    expect(lead.Lead_Source__c).toBe('In Person');

    // AC4: the lead appears in the Lead__c "Recent" list without extra filtering.
    // (No "Recent Walk-Ins" list view exists in metadata yet — see gap note above.)
    await page.goto('/lightning/o/Lead__c/list?filterName=Recent');
    await page.waitForSelector('.slds-page--container', { timeout: 15000 });
    await expect(page.getByRole('link', { name: 'John Smith' }).first()).toBeVisible({ timeout: 10000 });
  });
});
