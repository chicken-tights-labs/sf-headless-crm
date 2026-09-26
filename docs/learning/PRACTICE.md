# PRACTICE — Hands-on drills

Do these in order. Check boxes as you go. Commands are for **PowerShell** on your PC unless noted.

**Working directory:**

```powershell
cd C:\Users\maria\Documents\sf-headless-crm
```

---

## Drill 1 — Map the system (15 min)

Read: [00-overview.md](00-overview.md)

- [ ] I can name the five pieces: You, Cursor, Hermes, GitHub, Salesforce org  
- [ ] I know GitHub is the bridge between Cursor and Hermes  
- [ ] I ran `git log -1 --oneline` and wrote down the SHA: _______________  
- [ ] I ran `sf org list` and saw alias: _______________  

**Expected:** Org alias `chickentightslabs` Connected; a recent commit SHA.

---

## Drill 2 — Prove GitHub sync (15–20 min)

Read: [01-github-is-the-bridge.md](01-github-is-the-bridge.md)

```powershell
git status -sb
git fetch origin
git log -1 --oneline HEAD
git log -1 --oneline origin/main
```

- [ ] HEAD and `origin/main` show the **same** short SHA (or I pulled to fix it)  
- [ ] If behind, I ran `git pull --ff-only origin main` successfully  
- [ ] `Test-Path` for `EPIC01_MemberOnboarding_Service.cls` is `True`  
- [ ] I compared SHA with Hermes (same or I know who should pull/push)  

**Expected:** Same SHA on PC and (after Hermes pull/push) on VM; EPIC Apex file present.

---

## Drill 3 — Org aliases (15 min)

Read: [02-salesforce-orgs.md](02-salesforce-orgs.md)

```powershell
sf org list
sf org display --target-org chickentightslabs
```

- [ ] I understand DevHub / Dev org / scratch in one sentence each  
- [ ] I understand why `my-gym` can work on Hermes but fail on this PC  
- [ ] I wrote my org Id from `sf org display`: _______________  

**Optional stretch:** create a scratch org later using `config/project-scratch-def.json` (not required for this drill).

---

## Drill 4 — Dry-run deploy (20–30 min)

Read: [03-deploy-retrieve-loop.md](03-deploy-retrieve-loop.md)

**Only when you’re ready to talk to Salesforce:**

```powershell
git status -sb
sf project deploy start --target-org chickentightslabs --dry-run
```

- [ ] Working tree was clean (or I understood dirty files before deploying)  
- [ ] Dry-run finished; I noted Succeeded or listed failures  
- [ ] I did **not** need a real deploy to complete this drill  

**Expected:** You can explain one success or one failure message in plain English.

---

## Drill 5 — Simulate a handoff (20 min)

Read: [04-handoff-cursor-hermes.md](04-handoff-cursor-hermes.md)

Without needing Hermes online:

1. Open [README.md](../../README.md) EPIC-01 source map.  
2. Pick the first story marked Logic ⏳.  
3. Write a Cursor chat prompt you would paste after a pull (2–4 sentences).

- [ ] My prompt includes: pull confirmation, which US to do, and “no Skills yet”  
- [ ] I know who would run `sf project deploy` afterward (PC vs Hermes)  

**Example prompt shape:**

> Local repo matches origin/main at \<SHA\>. Implement US-002 lead conversion logic in `EPIC01_MemberOnboarding_Service.cls` using the existing test class as the contract. Do not create Skills or Automations. Show a short plan before editing.

---

## Drill 6 — Real deploy + test (optional, 30+ min)

Only after Drill 4 succeeds and you intend to change the org:

```powershell
sf project deploy start --target-org chickentightslabs
sf apex run test --target-org chickentightslabs -n EPIC01_MemberOnboarding_Test --result-format human --wait 10
```

- [ ] Deploy succeeded  
- [ ] I read the test summary (skeleton tests may fail until logic is implemented — that’s OK)  

---

## After the drills

You don’t need Skills yet. When the manual loop feels boring (in a good way), revisit Automations / `NEXT.md` with Hermes as your release mentor.

Return to [00-overview.md](00-overview.md) anytime.
