/**
 * Resolves a usable Salesforce session (access token + instance URL) from the
 * Salesforce CLI's already-authenticated org — never from a username/password.
 *
 * - Locally, the board user runs `sf org login web --alias partner-dev --set-default`
 *   once in Cursor; this just reads that session back out.
 * - In CI, the workflow runs `sf org login sfdx-url -f auth.txt -a ci-org -s` using the
 *   `SFDX_AUTH_URL` secret, then sets SF_TARGET_ORG=ci-org before `npm run test:e2e`.
 *
 * Either way, no Salesforce password or security token ever reaches this suite.
 */
import { execFileSync } from 'node:child_process';

export interface SalesforceSession {
  accessToken: string;
  instanceUrl: string;
  username: string;
}

export function resolveSalesforceSession(): SalesforceSession {
  const targetOrg = process.env.SF_TARGET_ORG;
  const args = ['org', 'display', '--json'];
  if (targetOrg) {
    args.push('--target-org', targetOrg);
  }

  let raw: string;
  try {
    raw = execFileSync('sf', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
  } catch (err) {
    throw new Error(
      `Could not resolve a Salesforce session via the "sf" CLI (${targetOrg ?? 'default org'}). ` +
        `Locally: run "sf org login web --alias partner-dev --set-default" first. ` +
        `In CI: authenticate with SFDX_AUTH_URL and set SF_TARGET_ORG before running tests.\n${
          (err as Error).message
        }`
    );
  }

  const parsed = JSON.parse(raw);
  const result = parsed?.result;
  if (parsed.status !== 0 || !result?.accessToken || !result?.instanceUrl) {
    throw new Error(
      `"sf org display" did not return an access token for ${targetOrg ?? 'the default org'}. ` +
        'Is the org authenticated and not expired?'
    );
  }

  return {
    accessToken: result.accessToken as string,
    instanceUrl: result.instanceUrl as string,
    username: result.username as string,
  };
}
