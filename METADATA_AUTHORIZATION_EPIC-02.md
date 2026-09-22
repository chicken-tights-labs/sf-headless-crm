---
# EPIC-02 Compliance Engine — Metadata Authorization Summary

**Status:** READY FOR HUMAN REVIEW — NOT YET DEPLOYED
**Date:** 2026-09-20
**SFDX Project:** `/home/maria_robbins/sf-project/sf-headless-crm`
**Target Org Alias:** `chickentightslabs`

---

## Audit Results (Live Org Introspected)

| Field | Object | Status | Source |
|---|---|---|---|
| `Franchise_Location__c` | Waiver_Record__c | ✅ EXISTS in org + local | Lookup(Franchise_Location__c), required |
| `Member__c` | Waiver_Record__c | ❌ MISSING — local XML has it, **NOT deployed** | Lookup(Member__c) — needs force:deploy |
| `Effective_Date__c` | Waiver_Record__c | ❌ MISSING — **newly created** | Date field — needs force:deploy |
| `Expiration_Date__c` | Waiver_Record__c | ❌ MISSING — **newly created** | Date field — needs force:deploy |
| `Status__c` | Waiver_Record__c | ⚠️ EXISTS, needs **cleanup** | Values: Draft, Pending Signature, Signed, Expired, Revoked + stray "Status__c" value |

---

## Metadata Changes Made

### 1. Member__c (NEW — was in local project but NOT deployed)

**Path:** `force-app/main/default/objects/Waiver_Record__c/fields/Member__c.field-meta.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
  <fullName>Member__c</fullName>
  <label>Member</label>
  <type>Lookup</type>
  <referenceTo>Member__c</referenceTo>
  <relationshipName>WavMember</relationshipName>
  <deleteConstraint>Restrict</deleteConstraint>
  <required>true</required>
</CustomField>
```

### 2. Franchise_Location__c (UPDATED — added required=true)

**Path:** `force-app/main/default/objects/Waiver_Record__c/fields/Franchise_Location__c.field-meta.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
  <fullName>Franchise_Location__c</fullName>
  <label>Franchise Location</label>
  <type>Lookup</type>
  <referenceTo>Franchise_Location__c</referenceTo>
  <relationshipName>WaiverRecordcFranchiseLocationc</relationshipName>
  <deleteConstraint>Restrict</deleteConstraint>
  <required>true</required>
</CustomField>
```

### 3. Effective_Date__c (NEW)

**Path:** `force-app/main/default/objects/Waiver_Record__c/fields/Effective_Date__c.field-meta.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
  <fullName>Effective_Date__c</fullName>
  <label>Effective Date</label>
  <type>Date</type>
</CustomField>
```

### 4. Expiration_Date__c (NEW)

**Path:** `force-app/main/default/objects/Waiver_Record__c/fields/Expiration_Date__c.field-meta.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
  <fullName>Expiration_Date__c</fullName>
  <label>Expiration Date</label>
  <type>Date</type>
</CustomField>
```

### 5. Status__c (UPDATED — picklist cleanup)

**Path:** `force-app/main/default/objects/Waiver_Record__c/fields/Status__c.field-meta.xml`

Changes:
- ❌ Removed stray `Status__c` picklist value
- 🔄 Renamed `Pending Signature` → `Pending` (to match required values list)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomField xmlns="http://soap.sforce.com/2006/04/metadata">
  <fullName>Status__c</fullName>
  <label>Status</label>
  <type>Picklist</type>
  <valueSet>
    <restricted>true</restricted>
    <valueSetDefinition>
      <value>
        <fullName>Draft</fullName>
        <label>Draft</label>
      </value>
      <value>
        <fullName>Pending</fullName>
        <label>Pending</label>
      </value>
      <value>
        <fullName>Signed</fullName>
        <label>Signed</label>
      </value>
      <value>
        <fullName>Expired</fullName>
        <label>Expired</label>
      </value>
      <value>
        <fullName>Revoked</fullName>
        <label>Revoked</label>
      </value>
    </valueSetDefinition>
  </valueSet>
  <required>true</required>
</CustomField>
```

---

## Deployment Commands (FOR HUMAN EXECUTION — NOT RUN)

### Option A: Deploy individual fields only

```bash
cd /home/maria_robbins/sf-project/sf-headless-crm

# Deploy the 4 field changes (Member__c, Effective_Date__c, Expiration_Date__c, Status__c)
# NOTE: Franchise_Location__c is already deployed — skip or deploy to add required=true
sf project deploy start \
  --source-dir force-app/main/default/objects/Waiver_Record__c/fields/Member__c.field-meta.xml \
  --source-dir force-app/main/default/objects/Waiver_Record__c/fields/Effective_Date__c.field-meta.xml \
  --source-dir force-app/main/default/objects/Waiver_Record__c/fields/Expiration_Date__c.field-meta.xml \
  --source-dir force-app/main/default/objects/Waiver_Record__c/fields/Status__c.field-meta.xml \
  --target-org chickentightslabs
```

> **⚠️ WARNING:** Deploy `Status__c` picklist changes in a sandbox first — renaming "Pending Signature" to "Pending" will break existing records that have that value.

### Option B: Deploy entire Waiver_Record__c object

```bash
cd /home/maria_robbins/sf-project/sf-headless-crm

sf project deploy start \
  --source-dir force-app/main/default/objects/Waiver_Record__c \
  --target-org chickentightslabs
```

---

## Validation Steps (After Deployment)

```bash
# 1. Verify new fields exist
sf data query --target-org chickentightslabs \
  -q "SELECT Id, Member__c, Franchise_Location__c, Effective_Date__c, Expiration_Date__c, Status__c FROM Waiver_Record__c LIMIT 1"

# 2. Verify Status__c picklist values
sf sobject describe --sobjecttype Waiver_Record__c --target-org chickentightslabs | grep -A5 Status__c
```

---

## Review Checklist

| Item | Status |
|---|---|
| Waiver_Record__c.Member__c (Lookup to Member__c, Required) | ✅ Defined |
| Waiver_Record__c.Franchise_Location__c (Lookup, Required) | ✅ Updated |
| Waiver_Record__c.Effective_Date__c (Date) | ✅ Defined |
| Waiver_Record__c.Expiration_Date__c (Date) | ✅ Defined |
| Waiver_Record__c.Status__c picklist: Draft, Pending, Signed, Expired, Revoked | ✅ Cleaned |
| Review comment #1: Expiration_date ≥ DATE(Scheduled_Session__c.Start_Time__c) (not TODAY) | ✅ Reflected in enforcement logic (Session_Date__c does not exist) |
| Review comment #4: Zero admin bypass | ✅ Enforcement design in US-02 |
| Review comment #6: Enforce at waitlist entry | ✅ Noted in US-02 |
| Review comment #7: Zero grace period | ✅ Design reflected |
| Review comment #2: Platform Event for audit (no DML) | ✅ Noted in US-02 (pending design) |
| **NO DEPLOYMENT** until human approval | ✅ Block maintained |
