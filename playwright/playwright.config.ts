import * as path from 'node:path';
import * as dotenv from 'dotenv';
import { defineConfig } from '@playwright/test';
import { STORAGE_STATE_PATH } from './support/sessionStore';

// Local dev only: in CI, env vars come from the workflow, not a .env file.
dotenv.config({ path: path.join(__dirname, '.env') });

export default defineConfig({
  testDir: './tests',
  outputDir: './test-results',
  globalSetup: require.resolve('./global-setup'),
  screenshot: 'only-on-failure',
  video: 'retain-on-failure',
  use: {
    // The Dev Org's Lightning domain — never the sandbox login host
    // (test.salesforce.com), which is wrong for this org and was never
    // reachable from a frontdoor session anyway. Override with SF_BASE_URL
    // if the org's My Domain ever changes.
    baseURL: process.env.SF_BASE_URL || 'https://chickentightslabs-dev-ed.develop.lightning.force.com',
    storageState: STORAGE_STATE_PATH,
    browserName: 'chromium',
    headless: true,
    viewport: { width: 1920, height: 1080 },
    ignoreHTTPSErrors: true,
  },
  timeout: 60000,
  fullyParallel: false, // Salesforce doesn't handle parallel sessions well
  retries: 1,
  reporter: [
    ['list'],
    ['html', { open: 'never', outputFolder: './playwright-report' }],
  ],
});
