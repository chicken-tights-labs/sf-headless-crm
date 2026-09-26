import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  outputDir: './test-results',
  screenshot: 'only-on-failure',
  video: 'retain-on-failure',
  use: {
    baseURL: process.env.SF_BASE_URL || 'https://test.salesforce.com',
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
    ['html', { open: 'never' }],
  ],
});
