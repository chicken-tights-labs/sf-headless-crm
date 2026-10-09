# SF Headless CRM — Shared Workflow

> **Single source of truth.** Both Hermes and Cursor read this file. No more `.cursorrules`-only rules that one agent can't see.
>
> This is the **Salesforce-adapted** version of the CEO Dashboard workflow pattern. Every Chicken Tights Labs repo follows the same **governance skeleton** — only deploy procedures and CI checks change per tech stack.

## 1. Roles

| Role | Who | Responsibility |
|---|---|---|
| **Issue Creator** | Hermes (via auto-ticket-creator) or Cursor | Converts EPIC stories → GitHub issue + kanban card |
| **Implementer** | Cursor (Agent mode) | All `@platform:cursor` stories |
| **Hermes Worker** | Hermes | Non-`@platform:cursor` stories (auto-spawned) |
| **Reviewer** | Maria (manual) or Cursor | PR review — `needs-review` label gates merge |
| **Merger** | Maria; Hermes for its own non-`@platform:cursor` PRs | Merges PR to `main` once CI is green |
| **Deployer** | Hermes (post-merge) | `git pull` + `sf project deploy start` to scratch org / dev org |

## 2. State Machine

| Kanban Card Status | GitHub Issue State | GitHub PR State | Who moves it |
|---|---|---|---|
| `ready` | open | — | Issue creator |
| `review` | open | OPEN | Implementer (on PR open) |
| `done` | closed | MERGED | **Merger** merges PR, then **Deployer** deploys to org |

**Rules:**
- A card and its issue stay **open** until the PR is merged.
- The GitHub issue **auto-closes** on PR merge (via `Closes #N`). The kanban card does **not** move to `done` until the org is deployed and verified.
- **Never** close a GitHub issue or move a card to `done` based on VM-only state (code deployed to scratch org but not merged to `main`).
- Hermes kanban `done` = PR merged **AND** `sf project deploy start` succeeded **AND** post-deploy sanity check passed.
- `needs-review` label is set only when a PR is waiting on a human. Never set it on a story with no branch.

## 3. Hard Rules for Hermes

1. **No direct pushes to `main`.** Always use a feature branch (`feat/EPICxx-USxx-short-name`) and create a PR.
2. **Do not implement stories assigned to `@platform:cursor`.** These are Cursor's terminal lane — they wait for manual pickup in Cursor IDE.
3. **Do not close an issue or mark a card `done` before the PR merges AND the org is deployed.**
4. **After merge:** `git pull origin main` → `sf project deploy start` → verify with post-deploy sanity check.
5. **Naming:** Branch `feat/EPICxx-USxx-short-name`, PR body includes `Closes #<issue>`, set kanban card `branch_name` to match.
6. **Each story gets its own kanban ID.** Do not reuse EPIC umbrella cards for child stories.
7. **New kanban tasks default to:** status `ready`, assignee `@platform:cursor`.
8. **Docs-as-code:** If the running org and docs disagree, update the doc in the same PR. Never let them drift.

## 4. Templates

- **Issue template:** `.github/ISSUE_TEMPLATE/story.md` — filled in by issue creator
- **PR template:** `.github/pull_request_template.md` — filled in by implementer

Both templates enforce the fields listed in section 5 below.

## 5. Required Fields per Artifact

### GitHub Issue (story)
- **Story**: What story does this implement?
- **Acceptance Criteria**: Gherkin scenarios
- **Out of Scope**: What's explicitly excluded
- **How to Verify**: Manual or automated check
- **Docs to Update**: Which Obsidian doc or `CRM-Documentation/` doc
- **Open Questions**: Anything blocking implementation

### Pull Request
- **Closes #N**: Issue reference
- **Kanban ID**: e.g., `t_sf_07`
- **What Changed**: Summary of changes
- **How it was Verified**: Test results, deploy dry-run, manual checks
- **Docs Updated**: Links to doc changes

## 6. VM Environment & Deployment

See [`docs/environment.md`](./environment.md) for:
- Scratch org alias and credentials
- Dev org SFDX auth URL
- Deploy and verify commands
- Known gotchas

## 7. Deploy Procedure (Post-Merge)

After PR merges to `main`:
1. `cd /home/maria_robbins/sf-project/sf-headless-crm`
2. `git pull origin main`
3. Deploy **with the test gate**:
   ```bash
   sf project deploy start --source-dir force-app --target-org my-gym \
     --test-level RunRelevantTests --wait 30
   ```
   Use `RunRelevantTests`, **not** `RunLocalTests` — the org has pre-existing
   flaky/unrelated test classes (e.g. `DataManager_QuotaTest`) that depend on
   org-specific Documents and would fail a full-suite deploy on noise.
   This matches `.github/workflows/ci.yml` and `.github/workflows/deploy.yml`.
4. **Verify the deploy** (do not eyeball the success table — assert the fields):
   ```bash
   sf project deploy report --target-org my-gym --use-most-recent --json > /tmp/dr.json
   ```
   Then check:

   | Field | Expected |
   |---|---|
   | `status` | `Succeeded` |
   | `numberComponentsDeployed` == `numberComponentsTotal` | e.g. 203 / 203 |
   | `numberComponentErrors` | `0` |
   | `numberTestsCompleted` | **> 0 when components actually changed** — see note below |

   > **Reading `numberTestsCompleted` correctly:** `RunRelevantTests` runs the tests
   > for the components *being deployed*. If nothing changed, nothing is deployed and
   > **0 tests run — that is correct, not a failure.** Verified on `my-gym`: a full
   > 203/203 re-deploy reported `numberTestsCompleted: 0` because every component came
   > back `"changed": false`; deploying one changed Apex class reported
   > `numberTestsCompleted: 1` (`EPIC04_LeadRegistration_Test`, PASSED).
   >
   > So the gate is: **`numberTestsCompleted > 0` whenever `numberComponentsDeployed > 0`
   > with real changes.** A `0` on a no-op re-deploy is expected. A `0` on a deploy that
   > *did* change Apex is the red flag — it means your test gate silently did nothing.

   > **Gotcha:** `sf project deploy report` **requires `--use-most-recent` or
   > `--job-id`**. Verified on CLI 2.150.6: omitting it **hard-errors with exit
   > code 2** —
   > `Exactly one of the following must be provided: --job-id, --use-most-recent`.
   > (Older/other builds reportedly returned an all-`None` payload that reads like
   > "no data" instead. Either way: if you see no deploy fields, suspect the missing
   > flag before you suspect the deploy.)
5. Post-deploy sanity check:
   ```bash
   sf data query --target-org my-gym -q "SELECT COUNT() FROM Waiver_Record__c" --json
   ```
6. Comment on the issue with handoff protocol (see section 8).

**Why this matters:** a bare `sf project deploy start` performs **no Apex tests**
(`numberTestsCompleted: 0`). Without the test level, "deployed successfully" means
*metadata landed*, not *behavior verified*. The test gate makes `done` mean verified.

## 8. Handoff Protocol

When Hermes finishes or fixes work, add a comment on the GitHub issue covering:
1. **What it did** — summary of changes
2. **VM state** — scratch org / dev org health
3. **main state** — PR merged or not
4. **Cards moved** — kanban IDs and their new status
5. **Unsure about** — anything needing human judgment

## 9. Guardrails

- **Branch protection on `main`** (GitHub repo settings): require a PR before merging with **0 required approvals**, required status check (**`validate-and-test`**), linear history (squash or rebase merges), no force pushes, no deletions, `enforce_admins` on.
- **Required status checks ARE enforced.** A red `validate-and-test` blocks the merge button. This is the only automated gate.
- **Never `gh pr merge --admin`** for a routine merge. With approvals at 0, there is nothing to bypass. Reserve `--admin` for a true service outage, with a retro issue afterward.
- **Why 0 approvals**: `chicken-tights-labs` is a single GitHub User account and the sole collaborator.
- **Merge split**: Hermes may merge its own non-`@platform:cursor` PRs once CI is green. Maria merges `@platform:cursor` PRs and anything changing branch protection, CI, or this policy.

## 10. Principles (Restored from .cursorrules)

- **Docs-as-code**: CRM-Documentation lives in `~/Documents/Obsidian Vault/CRM-Documentation/` — updated alongside features, not after.
- **GitHub `main` is the only finished copy**: Code deployed to a scratch org but not merged is not "done."
- **Terminal lane**: Tasks assigned to `@platform:cursor` are Cursor's terminal lane — Hermes will NOT auto-spawn workers for them.

## 11. Documentation Drafts (EPIC-11)

EPIC-11 user guides stay **Draft** until the org is finished. A first pass is a **source-verified draft**, not a finished manual.

**Canonical file is the repo file.** Obsidian `CRM-Documentation/` is a copy, synced from the repo when that vault is available. Do not let the two copies evolve separately.

### Story → File Map

| Story | Issue | Canonical file |
|---|---|---|
| US-D001 End user manual | #37 | `docs/EPIC-11_D001_End_User_Manual.md` |
| US-D002 Manager guide | #38 | `docs/EPIC-11_D002_Manager_Guide.md` |
| US-D003 Franchise owner guide | #39 | `docs/EPIC-11_D003_Franchise_Owner_Guide.md` |
| US-D004 System admin guide | #40 | `docs/EPIC-11_D004_System_Admin_Guide.md` |
| US-D005 API docs | #41 | `docs/EPIC-11_D005_API_Documentation.md` |
| US-D006 Troubleshooting + FAQ | #42 | `docs/EPIC-11_D006_Troubleshooting_FAQ.md` |

These issues are `@platform:cursor`. Do not implement them. Maria is drafting US-D004 on `feat/EPIC11-USD004-system-admin-guide`. Do not open a competing guide.

### Rules

1. **Every guide starts with:** `Status: Draft`. `Last verified:` date and the `main` SHA the facts were checked against. `Checked from:` source in `force-app`, or a named org. `Still open:` the short list that is not true yet.
2. **Mark each section** as verified from source, not built, or needs an org click-through. Write only what is in `force-app` or what you confirmed in the org. A "not built" note is the right content for the rest. Do not describe screens that do not exist.
3. **A draft PR says `Relates to #N`.** Do not use `Closes #N`. Leave the GitHub issue open and do not move the kanban card to done. Close the issue only when its own How to Verify is true, including a live org check and screenshots where the issue requires them.
4. **When your PR changes behavior a guide describes,** update that guide in the same PR if the file already exists. Set `Last verified` to the new `main` SHA. Diff only since the previous `Last verified` SHA, and edit the sections that diff touches. If the file does not exist yet, write "docs not drafted yet" under Docs Updated and leave the Cursor story open.
5. **Update map:** permission set, profiles, sharing, users → US-D004. Staff quick actions and record pages → US-D001. Reports or the management dashboard → US-D002. Royalty or franchise dashboards → US-D003. REST or auth → US-D005. A real failure you had to diagnose → US-D006.

## 12. Where This Doc Lives

- Repo path: `docs/WORKFLOW.md` on `main`
- `.cursorrules` points here (3-line pointer)
- Hermes skill `sf-headless-crm-workflow` enforces it