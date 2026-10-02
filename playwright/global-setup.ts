/**
 * Playwright global setup — runs once before the suite.
 *
 * 1. Pulls an access token + instance URL out of the Salesforce CLI's already
 *    authenticated session (see support/salesforceSession.ts) — no password,
 *    no security token, anywhere.
 * 2. Trades that access token for a logged-in browser session via Salesforce's
 *    frontdoor servlet, and saves it as Playwright storage state so every test
 *    starts already logged in.
 * 3. Seeds the deterministic test data the specs depend on.
 */
import { chromium } from '@playwright/test';
import { resolveSalesforceSession } from './support/salesforceSession';
import { ensureLeadRegistrationSeedData } from './support/seedData';
import { STORAGE_STATE_PATH, writeStoredSession } from './support/sessionStore';

export default async function globalSetup(): Promise<void> {
  const session = resolveSalesforceSession();

  const seeded = await ensureLeadRegistrationSeedData(session);

  const browser = await chromium.launch();
  try {
    const context = await browser.newContext();
    const page = await context.newPage();

    // Frontdoor session login: exchanges the CLI's OAuth access token for a
    // logged-in Lightning session cookie, with no login form involved.
    await page.goto(`${session.instanceUrl}/secur/frontdoor.jsp?sid=${session.accessToken}`);
    await page.waitForURL(/\/lightning\//, { timeout: 30000 });

    await context.storageState({ path: STORAGE_STATE_PATH });
  } finally {
    await browser.close();
  }

  writeStoredSession({
    instanceUrl: session.instanceUrl,
    franchiseOwnerId: seeded.franchiseOwnerId,
    franchiseLocationId: seeded.franchiseLocationId,
  });
}
