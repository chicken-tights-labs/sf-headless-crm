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
  // --verbose + SF_TEMP_SHOW_SECRETS are both required, or recent `sf` CLI
  // versions redact accessToken/sfdxAuthUrl from the JSON output (see
  // docs/CI_CD_SECRETS.md), and the redacted placeholder fails auth with
  // INVALID_AUTH_HEADER instead of a helpful "no token" error.
  const args = ['org', 'display', '--json', '--verbose'];
  if (targetOrg) {
    args.push('--target-org', targetOrg);
  }

  let raw: string;
  try {
    raw = execFileSync('sf', args, {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
      env: { ...process.env, SF_TEMP_SHOW_SECRETS: 'true' },
    });
  } catch (err) {
    throw new Error(
      `Could not resolve a Salesforce session via the "sf" CLI (${targetOrg ?? 'default org'}). ` +
        `Locally: run "sf org login web --alias partner-dev --set-default" first. ` +
        `In CI: authenticate with SFDX_AUTH_URL and set SF_TARGET_ORG before running tests.\n${
          (err as Error).message
        }`
    );
  }

  // The `sf` CLI writes ANSI colour codes when it thinks it is talking to a TTY,
  // and inside Playwright workers it does. Those escapes are interleaved BETWEEN
  // JSON tokens (e.g. "\u001b[97m{\u001b[39m\n  \u001b[94m\"status\"..."), so the
  // output is not valid JSON and a bare JSON.parse throws "Expected property name
  // or '}' in JSON at position 1". Strip the escapes first, then the CLI's
  // non-JSON chatter ("›   Warning: @salesforce/cli update available..."), then
  // slice from the first '{'.
  const stripped = raw.replace(/\u001b\[[0-9;]*m/g, '');
  const jsonStart = stripped.indexOf('{');
  if (jsonStart === -1) {
    throw new Error(
      `"sf org display" produced no JSON output for ${targetOrg ?? 'the default org'}. Raw output:\n${stripped}`
    );
  }
  const parsed = JSON.parse(stripped.slice(jsonStart));
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
