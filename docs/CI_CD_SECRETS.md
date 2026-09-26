# CI/CD Secrets Setup — Dev Org

## Required GitHub Secret (just one)

Set in your GitHub repo → Settings → Secrets and variables → Actions:

| Secret Name | Value | How to Get |
|---|---|---|
| `SFDX_AUTH_URL` | The `force://` auth URL for the Dev Org | On the VM: `SF_TEMP_SHOW_SECRETS=true sf org display --target-org chickentightslabs --verbose` (the `sfdxAuthUrl` field) |

**Why one secret instead of three?** The VM already holds a working OAuth refresh token for the org (`force://...`). CI re-uses it via `sf org login sfdx-url`. No password in GitHub, no security-token reset, no Connected App needed. If the token ever expires or is revoked, regenerate it on the VM and update this one secret.

## How to Set It

```bash
# On the VM (auth URL never appears in chat or logs)
gh secret set SFDX_AUTH_URL < <(SF_TEMP_SHOW_SECRETS=true sf org display --target-org chickentightslabs --verbose --json | python3 -c "import sys,json; print(json.load(sys.stdin)['result']['sfdxAuthUrl'])")
```

## Workflow Overview

1. **`ci.yml`** — Runs on every PR: authenticates with `SFDX_AUTH_URL`, check-only validates metadata against the Dev Org, runs Apex tests (informational only while org coverage is 64% and `DataManager_QuotaTest` is flaky)
2. **`deploy.yml`** — Manual trigger (`workflow_dispatch`) after PR review sign-off: deploys to the Dev Org with `RunRelevantTests`, then a post-deploy SOQL sanity check

## What We Chose (and why) — Option C

- **CI auth:** single `SFDX_AUTH_URL` secret (OAuth refresh token) instead of username/password/token. Less secrets sprawl, no password rotation coupling, no security token reset needed.
- **Scratch org stage: removed for now.** Dev Hub isn't enabled in the Dev Org, and the JWT flow (connected app + cert) is a separate setup session. The scratch-org commands are preserved as comments in `ci.yml` for when that's ready.
- **Test level:** `RunRelevantTests` for deploys/validations (org has pre-existing 64% coverage + flaky `DataManager_QuotaTest`; full-suite runs trip on old noise, not new code).
- **Deploy trigger:** manual (`workflow_dispatch`) — deploys stay gated behind your PR review sign-off, consistent with the review-first workflow. Auto-deploy on merge can be enabled by uncommenting the `push:` trigger.

## Restoring the Scratch Org Stage (later)

1. Enable Dev Hub: Setup → Dev Hub (toggle, free, ~2 min)
2. Set up JWT auth for CI: create a Connected App + certificate, set `SF_JWT_KEY`/`SF_JWT_ISSUER`/`SF_JWT_SUBJECT` secrets
3. Uncomment the scratch-org block in `ci.yml`
4. Delete the `SFDX_AUTH_URL` secret if you want pure JWT auth

## Old Three-Secret Setup (superseded, kept for reference)

| Secret Name | Value |
|---|---|
| `SF_USERNAME` | Dev Org username |
| `SF_PASSWORD` | Dev Org password |
| `SF_SECURITY_TOKEN` | Security token (reset in Setup → My Personal Information → Reset My Security Token) |

The old `deploy.yml` used username/password auth via `sfdxgithub/salesforce-cli-action` (which doesn't exist — it was never a real GitHub Action) and pointed at `https://test.salesforce.com` (sandbox login URL; the Dev Org uses `login.salesforce.com`). Fixed in PR #2.
