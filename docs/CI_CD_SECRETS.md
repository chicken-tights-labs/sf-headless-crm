# CI/CD Secrets Setup — Salesforce Partner Dev Org

## Required GitHub Secrets

Set these in your GitHub repo → Settings → Secrets and variables → Actions:

| Secret Name | Value | How to Get |
|---|---|---|
| `SF_USERNAME` | Your Partner Dev Org username | From the org signup email |
| `SF_PASSWORD` | Your org password | Set during org creation or reset in Setup → Users |
| `SF_SECURITY_TOKEN` | Security token for API access | Reset in Setup → My Personal Information → Reset My Security Token (emailed after reset) |
| `SF_JWT_KEY` | Private key for JWT flow (optional) | Create a Connected App in Setup → App Manager |
| `SF_JWT_ISSUER` | Connected App consumer key (optional) | From the Connected App |
| `SF_JWT_SUBJECT` | Username for JWT flow (optional) | Your Partner Dev username |
| `SF_DEFAULT_USERNAME` | Alias for default org | Just set to `partner-dev` |

## How to Set Secrets

```bash
gh secret set SF_USERNAME --body "your_username@example.com"
gh secret set SF_PASSWORD --body "your_password"
gh secret set SF_SECURITY_TOKEN --body "your_security_token"
```

## Workflow Overview

1. **`ci.yml`** — Runs on every PR: validates metadata, runs Apex tests, creates a scratch org for full integration tests
2. **`deploy.yml`** — Runs on push to `main`: deploys all metadata to the Partner Dev Org and runs Apex tests with coverage

## Important Notes

- The devHub scratch org approach requires a Dev Hub-enabled org. If your Partner Dev Org doesn't have Dev Hub, the CI workflow will skip scratch org creation and only do check-only deploy validation.
- The `deploy.yml` workflow uses username/password auth which is simpler but less secure. For production, consider switching to JWT bearer flow.
