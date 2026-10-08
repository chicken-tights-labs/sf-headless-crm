/**
 * Shared Lightning Experience navigation helpers.
 *
 * Why this file exists (read before "simplifying" it back to waitForSelector):
 *
 * Lightning Experience is a client-side single-page app. When you navigate from
 * one list view to another, the PREVIOUS page's `.slds-page-header` stays in the
 * DOM carrying the `slds-hide` class while the next one hydrates. A plain
 * `page.waitForSelector('.slds-page-header')` therefore resolves immediately
 * against that stale, hidden element and the subsequent assertion fails (or the
 * test hangs) even though the page is fine.
 *
 * Observed on scratch org `my-gym`: a cold list-view load takes ~3-4s to hydrate,
 * and `.slds-page-header` was present-but-hidden for several seconds after
 * `page.goto()` resolved.
 *
 * The fix is to wait for a VISIBLE header (Playwright's `:visible` pseudo-class
 * excludes zero-size / display:none / slds-hide elements), which is immune to the
 * stale-element race. `expect(locator).toBeVisible()` from `@playwright/test`
 * auto-retries and is the preferred primitive inside specs.
 */
import { expect, type Page } from '@playwright/test';

/** A list-view / object-home page is ready when a visible page header exists. */
export const VISIBLE_PAGE_HEADER = '.slds-page-header:visible';

/**
 * Navigate to an object's list view and wait until it has actually rendered.
 *
 * @param objectApiName e.g. 'Franchise_Location__c'
 * @param filterName    optional list-view developer name, e.g. 'Active_Members'
 *                      (appended as `?filterName=` to select a specific view)
 */
export async function gotoObjectHome(
  page: Page,
  objectApiName: string,
  filterName?: string
): Promise<void> {
  const suffix = filterName ? `?filterName=${filterName}` : '';
  await page.goto(`/lightning/o/${objectApiName}/list${suffix}`);
  // Auto-retrying: skips the stale hidden header left by the previous route.
  await expect(page.locator(VISIBLE_PAGE_HEADER).first()).toBeVisible({ timeout: 45000 });
}

/**
 * The rendered list-view title, e.g. "Recently Viewed", "Active Members",
 * "This Week's Classes".
 *
 * The `.slds-page-header__title` element contains BOTH the object name and the
 * view name stacked on separate lines ("Franchise Locations\nRecently Viewed"),
 * so this returns the LAST non-empty line — the list-view name — not the whole
 * blob. (Asserting on the raw innerText compares "Franchise Locations |
 * Recently Viewed" against "Recently Viewed" and fails.)
 */
export async function listViewTitle(page: Page): Promise<string> {
  const raw = await page.locator('.slds-page-header__title:visible').first().innerText();
  const lines = raw
    .split('\n')
    .map((l) => l.trim())
    .filter(Boolean);
  return lines[lines.length - 1] ?? '';
}

/** The "New" action button in the visible page header (scoped to avoid the global quick-create button). */
export function newButton(page: Page) {
  return page.locator(VISIBLE_PAGE_HEADER).getByRole('button', { name: 'New', exact: true }).first();
}

/**
 * Wait until `page.url()` matches `pattern`.
 *
 * Prefer this over `page.waitForURL` for Lightning route changes. Lightning
 * navigates client-side, and both `waitForURL` (any waitUntil) and an in-page
 * `page.waitForFunction(() => location.href...)` were observed to time out on
 * scratch org `my-gym` even though the URL had already changed. Polling
 * `page.url()` from the driver side is immune to those navigation-event and
 * execution-context issues.
 */
export async function waitForUrl(page: Page, pattern: RegExp, timeoutMs = 20000): Promise<void> {
  const deadline = Date.now() + timeoutMs;
  let last = page.url();
  while (Date.now() < deadline) {
    last = page.url();
    if (pattern.test(last)) return;
    await page.waitForTimeout(250);
  }
  throw new Error(`Timed out after ${timeoutMs}ms waiting for URL matching ${pattern}. Current URL: ${last}`);
}
