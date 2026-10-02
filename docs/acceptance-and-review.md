# Acceptance & Review Workflow

This is the bar every story in `sf-headless-crm` is held to, from first Gherkin line to merged PR. It applies to every EPIC (Trainer Ops, POS, Documentation, and anything added later). If a story doesn't move through these steps, it isn't done, regardless of what the code looks like.

Owners: Quinn (QA) writes acceptance criteria and UAT scripts, runs the Playwright suite, and verifies fixes. Nina (Solution Architect) co-writes acceptance criteria and owns the data model. Frank (Salesforce Developer) implements against approved AC. Ada (DevOps) owns the CI/CD pipeline that enforces gate 2. The board user is the only person who can approve AC, sign off UAT, and merge to `main`.

---

## 1. Definition of done

A user story is **done** when, in order:

1. Its acceptance criteria exist in Gherkin, in the repo, under `docs/`, and were approved by the board user *before* any code for that story was written (§2, §4 gate 1).
2. Frank's implementation satisfies every scenario in that Gherkin spec — nothing more, nothing less. A criterion with no matching behavior, or behavior with no matching criterion, is not done.
3. The PR carries automated checks that are all green: ESLint, Jest (`sfdx-lwc-jest`), Apex tests, a metadata validation deploy, and the relevant Playwright spec (§4 gate 2).
4. A UAT script for the story has been posted on the story's task, the board user has walked it in the Salesforce UI, and every acceptance criterion on the response card is checked "pass" (§4 gate 3).
5. The board user has merged the PR into the protected `main`, the CD deploy succeeded, and the post-deploy regression run is clean (§4 gate 4).
6. If the story fixed a prior defect or regression, a permanent automated test (Jest, Apex, or Playwright) now covers it, so it cannot silently reappear.

A story that passes gates 1–3 but is waiting on the board user to merge is `in_review`, not `done`. A story is never marked `done` on the strength of automated checks alone — gate 3 is manual and gate 3 is the one that matters most.

---

## 2. Acceptance criteria format

Use the Gherkin format already in `docs/` (see `docs/2026-09-26 Gherkin - Lead Registration & Conversion.md` for the canonical example). Do not invent a second format. One Markdown file per feature area, one `### Scenario:` heading per scenario, one fenced ` ```gherkin ` block per heading.

```markdown
## Feature: <Feature name>
**Epic:** EPIC-NN | **Tasks:** t_xxxxxxxx (US-Xnnn)

### Scenario: <short scenario name>
\`\`\`gherkin
Feature: <Feature name>
  As a <role>
  I want to <capability>
  So that <business value>

  Background:
    Given <shared precondition 1>
    And <shared precondition 2>

  Scenario: <happy path name>
    When <user action>
    And <user action>
    Then a new <Object>__c record is created in Salesforce with:
      | Field       | Value       |
      | Field_A__c  | <value>     |
      | Field_B__c  | <value>     |
    And the system displays "<exact UI message>"

  Scenario: <negative/edge case name>
    Given <precondition that breaks the happy path>
    When <user action>
    Then the system prevents <action>
    And the system displays "<exact UI message>"
    And <nothing changes — state the unchanged state explicitly>
\`\`\`
```

Rules that keep criteria testable, matching the QA lenses this project already uses:

- **One criterion, one observable outcome.** Each `Then`/`And` line asserts exactly one thing a human or a script can check — a record field, an exact UI string, a list membership, a record count. Never `Then it works correctly`.
- **Exact values, not categories.** Field values in tables are literal strings or explicit placeholders like `<today>`, `<Lead__c.Id>`, `<stripe-charge-id>` — resolved against named seed data, never "a member" or "some lead."
- **Multi-step system outcomes are numbered.** When one user action causes several records to change (e.g., lead conversion creating a Member, updating the Lead, creating an Order and a Payment), use `Then the system does the following in order:` followed by a numbered list, each with its own field table. This is how the existing lead-conversion spec documents atomicity.
- **Negative paths are scenarios, not footnotes.** Every feature file includes at least one scenario for a validation failure, a permission boundary, a declined/failed external call, or a zero-result state, with its own `Then` assertions for what did *not* happen.
- **Field names are verified against the metadata**, i.e. `force-app/main/default/objects/<Object>__c/fields/`, before being written into the spec — not guessed from the user story text.
- **Tag the bottom of the file** with `#gherkin #EPIC-NN #US-Xnnn ...` and list the Kanban task IDs, exactly as the existing files do, so specs stay discoverable.

This Gherkin file *is* the acceptance criteria. It is reviewed and approved in gate 1 before Frank starts. It is also the source the Playwright spec and the UAT script are both written from — the three should never diverge in wording.

---

## 3. UAT script template

The UAT script is for the board user, who did not build the feature and has 10–15 minutes. Every script follows this shape, one script per story, posted as a comment/attachment on the story's task when gate 2 is green.

```markdown
# UAT Script — US-Xnnn: <Story name>

**Story:** US-Xnnn (t_xxxxxxxx) | **Epic:** EPIC-NN | **Gherkin:** docs/<spec file>.md
**Org / Starting URL:** <full Lightning URL, e.g.
  https://chickentightslabs.lightning.force.com/lightning/o/Lead__c/list?filterName=Recent>
**Seed data used (already loaded in the Dev Org, do not create your own):**
| Record | Key fields |
|---|---|
| Lead__c "Maria Testwalker" | Lead_Status__c = Walk-In, Franchise_Location__c = <Location Name> |
| Member__c "Diego Sampleton" | Status__c = Active |

## Steps

1. Open <exact starting URL> and log in if prompted.
2. Click <exact tab / button / link label>.
3. In the <exact field label> field, enter `<exact value>`.
4. Click <exact button label>.
5. ...continue, one numbered step per click or entry, no "navigate as needed."

## Expected results (one row per acceptance criterion)

| # | Acceptance criterion (from Gherkin) | What you should see | Pass / Fail |
|---|---|---|---|
| AC1 | New Lead__c created with Status__c = Walk-In | A record named "Maria Testwalker" appears in the list with Status = Walk-In | ☐ |
| AC2 | System displays success message | Toast reads exactly "Lead registered successfully" | ☐ |
| AC3 | Lead appears in "Recent Walk-Ins" list | "Maria Testwalker" is visible in that list view without further filtering | ☐ |

## If something doesn't match

Note which AC # failed, what you saw instead, and stop — do not try to work around it. Attach a screenshot if you can. Quinn will route it back to Frank with this script attached.
```

Rules for writing one:

- **Exact starting URL**, not "go to the Leads tab." Use the full Lightning URL (object list, record page, or app page) the board user should paste in. If the feature isn't yet placed on a Lightning page in the org, say so in the script rather than guessing.
- **Named, seeded records only.** Every record the reviewer is told to open was created by Quinn ahead of time with a fake, obviously-test name (e.g. "Maria Testwalker") — never "pick any lead."
- **One row per acceptance criterion**, in the same order as the Gherkin scenario, so the AC-to-checkbox mapping is 1:1 and a partial pass is unambiguous.
- **Numbered steps, one action per step**, phrased as literal clicks/typing, not "configure the form."
- **10–15 minutes**, one story. If a story needs more than ~20 steps, that's a signal the story is too large, not a reason to compress the script.

### Worked example — US-F001, Register Walk-In Lead

This story is already built (`force-app/main/default/lwc/epic04LeadRegistrationForm`, `EPIC04_LeadRegistration_Controller.cls`) against the scenario in `docs/2026-09-26 Gherkin - Lead Registration & Conversion.md`. A UAT script for it looks like:

> **Caveat this example demonstrates:** no FlexiPage in `force-app` currently places `epic04LeadRegistrationForm` on a Lightning page, so there is no deployed URL yet where the board user drives the actual custom form. The script below uses the standard Lead__c "New" record form as a stand-in reachable today — it exercises the same field-level acceptance criteria, but it is not the custom UI the story describes. Whoever writes the real script for this story should either confirm the component's page placement first or state this gap explicitly, per the "say so rather than guessing" rule above.

```markdown
# UAT Script — US-F001: Register Walk-In Lead

**Story:** US-F001 (t_b9d75b17) | **Epic:** EPIC-04
**Gherkin:** docs/2026-09-26 Gherkin - Lead Registration & Conversion.md
**Org / Starting URL:**
  https://chickentightslabs.lightning.force.com/lightning/o/Lead__c/list?filterName=Recent
**Seed data used (do not create your own):**
| Record | Key fields |
|---|---|
| Franchise_Location__c "Chicken Tights — Test Gym" | used as the walk-in's location |

## Steps

1. Open the starting URL above and log in if prompted.
2. On the Lead__c list view, click "New".
3. In "First Name", enter `John`.
4. In "Last Name", enter `Smith`.
5. In "Phone", enter `555-123-4567`.
6. In "Email", enter `john@example.com`.
7. In "Franchise Location", select "Chicken Tights — Test Gym".
8. In "Lead Status", select "Walk-In".
9. In "Lead Source", select "In Person".
10. Click "Save" (or "Register Walk-In", per the deployed form).

## Expected results

| # | Acceptance criterion | What you should see | Pass / Fail |
|---|---|---|---|
| AC1 | New Lead__c created with the entered fields | A record named "John Smith" exists with Phone = 555-123-4567, Email = john@example.com | ☐ |
| AC2 | Lead_Status__c = Walk-In, Lead_Source__c = In Person | Both fields show those exact values on the record detail page | ☐ |
| AC3 | System confirms success | A success toast/message is shown after save | ☐ |
| AC4 | Lead appears in the recent list | "John Smith" is visible in the Lead__c list view used in step 1 without extra filtering | ☐ |
```

---

## 4. The four gates — and which ones block a merge

| # | Gate | What happens | Who acts | Blocks merge? |
|---|---|---|---|---|
| 1 | **AC approved before code** | Quinn + Nina write the Gherkin spec for every story in a phase; one approval card covers the whole phase, not one per story. Frank does not start a story until its phase's card is accepted. | Board user approves; Quinn/Nina author | **Yes, indirectly** — a PR implementing an unapproved story should not exist. No PR, no merge. |
| 2 | **Automated PR checks** | ESLint, Jest (`sfdx-lwc-jest`), Apex tests, a metadata validation (check-only) deploy, and Playwright all run on the PR. Red means Frank fixes it before anyone reviews by hand. | Ada wires the CI steps; Frank keeps them green; Quinn owns what Playwright asserts | **Yes, directly** — these are (or become, as Ada completes CI wiring) required status checks on `main`. A PR cannot merge while any is red. |
| 3 | **Manual UAT in the Salesforce UI** | Quinn deploys the branch to the Dev Org, seeds named data, posts the UAT script on the story's task. The board user walks it by hand and answers a card with one checkbox per acceptance criterion. | Board user executes; Quinn prepares and verifies | **Yes — this is the gate that matters most.** The board user does not merge a story whose UAT card has an unchecked or failing criterion. It isn't a GitHub-enforced check; it's enforced by the fact that only the board user can perform gate 4, and they don't perform it until gate 3 passes. |
| 4 | **Merge and deploy** | The board user merges the PR into protected `main`. CD (`deploy.yml`) deploys to the Dev Org with `RunRelevantTests`. Quinn runs the regression suite and reports pass/fail. | Board user merges; CD deploys; Quinn verifies | **This gate *is* the merge** — nothing blocks it further once reached, but it does not start until 1–3 are satisfied. |

Unambiguous summary: **gate 2 blocks the merge button through CI-required status checks; gate 3 blocks it through the board user's judgment and sign-off, which is the harder and more important gate; gates 1 and 4 are the bookends — nothing starts before 1, nothing finishes before 4.** Automated E2E (Playwright) in gate 2 exists so gate 3 is spent judging whether the app is *good*, not rediscovering that it's broken.

**Current implementation status** (so this document doesn't overclaim): gate 2's CI today (`.github/workflows/ci.yml`) runs a metadata validation dry-run deploy with `RunRelevantTests`, which covers Apex. ESLint and Jest are enforced locally via `husky`/`lint-staged` pre-commit hooks but are not yet separate required PR checks, and Playwright is not yet wired into CI at all (package not installed, no `test:e2e` script, no CI step, and the smoke spec's login strategy won't survive headless 2FA). Closing that gap is tracked as separate work between Quinn (spec correctness, frontdoor-session login) and Ada (CI step, secrets, required-check wiring) — until it lands, treat "automated checks" in gate 2 as ESLint/Jest (local) + Apex + metadata validate (CI), with Playwright run and reported manually by Quinn.

---

## 5. What happens on a UAT failure

1. The board user marks the failing criterion (or criteria) on the UAT response card — "fail", with a note on what they saw instead of what was expected.
2. Quinn reproduces the failure, confirms the exact failing step and the expected-vs-actual behavior, and redacts any sensitive detail from the evidence.
3. Quinn attaches the failing acceptance criterion, the reproduction steps, and the evidence to the story, and routes the story back to **[Frank](/CHI/agents/frank)**. The story moves out of `in_review` — it is not `done` and the PR does not merge.
4. Frank fixes the defect against the same, unchanged acceptance criterion (a UAT failure is evidence the AC wasn't met, not grounds to change the AC — if the AC itself turns out to be wrong or ambiguous, that goes to Nina instead, per §1).
5. Once Frank's fix is in and gate 2 is green again, Quinn re-verifies the failing criterion specifically, then re-runs or re-posts the UAT script (full or delta, Quinn's judgment) for a fresh board-user pass.
6. The criterion that failed gets a permanent regression test (Jest, Apex, or Playwright, whichever seam it belongs to) so the same break can't resurface silently.

---

## Reading this with a story in hand

Given any user story under `docs/` (e.g. `docs/2026-09-26 Gherkin - Lead Registration & Conversion.md`), a reader should be able to:

1. Pull the `### Scenario:` blocks for that story — those *are* its acceptance criteria.
2. Fill in the UAT template in §3 with that story's starting URL, named seed records, and one expected-result row per `Then`/`And` line in the scenario.
3. Check this story's status against §4 — has its phase been approved (gate 1)? Is its PR green (gate 2)? Has the board user walked the UAT script (gate 3)? Has it merged and deployed clean (gate 4)?

If any of those three steps requires guessing, the spec or the script is incomplete — fix it before calling the story ready for review.
