# CI Validation Gotchas (read before trusting a green or red PR)

Lessons from real PR failures. Add to this file whenever CI surprises us.

## 1. "Tests: 0 passing, 0 failing" means the tests did NOT run

The `validate-salesforce` job does one dry-run deploy with `--test-level RunRelevantTests`. Salesforce runs Apex tests only **after** the metadata deploy stage succeeds. If any component fails to deploy, the log still ends with:

```
Test Results Summary
Passing: 0
Failing: 0
Total: 0
Dry-run complete.
```

That is a failure to reach the tests, not a clean test run. Always read the **Component Failures** table above it first. Example: PR #30 (US-002) failed on 4 metadata errors, so `EPIC01_LeadConversion_Test` and `EPIC01_MemberOnboarding_Test` never executed. After fixing the metadata, a second CI run can still reveal Apex test failures that were hidden the first time. Budget for at least two CI rounds on any PR that adds Apex and metadata together.

## 1b. All tests can pass and the dry-run still fails on coverage

`RunRelevantTests` enforces **75% coverage per selected Apex class**. With 28/28 passing, PR #30's second CI run still failed with `EPIC01_MemberUnconvert_Action - Test coverage of selected Apex Class is 73.333%, at least 75% test coverage is required`. The uncovered lines were the `catch` branch (the failure path). The "Failing: 0" count and the `Running Tests` summary hide this: look for the coverage warning above `Dry-run complete`. Every new Apex class needs tests for both the success path and the error/catch path, including invocable wrappers.

## 2. Hand-written metadata cannot be validated locally without an org

Flows, quick actions and similar XML are easy to get subtly wrong. The project's `sourceApiVersion` is **58.0**, and the deploy rejects properties from newer versions.

Known issues we have hit:

| Symptom | Cause | Fix |
|---|---|---|
| `Property 'versionString' not valid in version 58.0` | `<versionString>` inside a Flow `actionCalls` element | Remove it |
| QuickAction `Required fields are missing: [Component]` (type Flow) | Seen alongside the flow errors above; may be a knock-on of the flow failing, not confirmed | Re-check after the flows deploy; if it persists, fix the QuickAction XML shape |

Before pushing Flow, QuickAction, validation-rule or layout XML, run a check-only deploy of just those files against a confirmed org (see `docs/environment.md`), for example:

```bash
sf project deploy start --dry-run --source-dir force-app/main/default/flows --target-org <confirmed alias>
```

Note: the CI org is the same org as the locally authenticated Dev Hub login (`chickentightslabs`), which is not a scratch org. A `--dry-run` does not change metadata, but confirm the target before running it.

## 3. Things in this repo that make Apex tests fail

When a test fails after metadata deploys, check these first:

- **Restricted picklists.** `Lead_Source__c`, `Lead_Status__c`, `Program_Interest__c`, `Member__c.Lead_Source__c` etc. are restricted. Inserting a value that is not in the picklist fails the whole test. When Lead data is copied to Member, the Member picklist must contain every Lead value (this bit US-002).
- **Required fields.** `Lead__c.Name`, `Lead__c.First_Name__c`, `Lead__c.Franchise_Location__c`, `Lead__c.Lead_Status__c`, `Member__c.Name`, and `Waiver_Record__c.Status__c` are required. Franchise Location needs a Franchise Owner first.
- **Duplicate email trigger** (`EPIC01_LeadDuplicateGuard`). Two `Lead__c` rows with the same email (case-insensitive) in one test fail. Use unique emails per lead in a test method. Data created in `@testSetup` counts.
- **Phone validation rule** (`Valid_Phone_Format`). `Lead__c.Phone__c` must be 10 digits after stripping `-`, spaces, parentheses, dots and a leading `+1`. Test data like `555-1234` fails.
- **Automation side effects.** Inserting a Signed `Waiver_Record__c` linked to a Lead flips that Lead to `Trial Completed` (flow `EPIC01_Waiver_Marks_Lead_Trial_Completed`). Setting `Referral_Code_Entered__c` on a new Lead runs the referral flow and may overwrite `Notes__c` / `Lead_Source__c`.
- **Magic strings.** Tests and service code compare literal strings (tier names, task subjects, error messages). Changing one without the other breaks tests. Example: the waiver task subject changed to "Member needs to sign waiver before payment" and two existing tests had to change. Search for the string across `force-app` and `playwright` before renaming.
- **Restrict-on-delete lookups.** `Lead__c.Converted_Member__c` and `Waiver_Record__c.Member__c` block deleting a Member until cleared. Tests that delete Members must clear these first.
- **Email.** `Messaging.sendEmail` can fail where deliverability is off. Service code catches this; tests should only assert `Limits.getEmailInvocations()`.
- **No `isDeletable` shortcuts.** Unconvert checks `Member__c` delete permission; tests run as an admin so this passes, but a non-admin run will not.

## 4. Other checks in the same PR run

- `lint-and-unit-test` (ESLint + Jest) runs first and gates the org job. LWC changes must pass both.
- The same `validate-salesforce` job then runs the Playwright suite against the dev org, which is shared. Parallel PRs can collide on test records.
- `validate-and-test` is only a shim that reports the required check name. If it is red, open the two jobs it depends on; the shim shows no detail.
- `RunRelevantTests` only runs tests that cover the deployed components. A test class that does not reference changed code may not run, so a "pass" does not prove untouched areas still work. The post-merge deploy also uses `RunRelevantTests`.

## 5. Checklist before asking for review

1. Read the **Component Failures** section of the log before the test summary.
2. Confirm the test summary total is greater than 0 and covers the new test classes.
3. Confirm Playwright ran.
4. After merge: deploy workflow green, then the manual sanity check from `docs/WORKFLOW.md` section 7.
