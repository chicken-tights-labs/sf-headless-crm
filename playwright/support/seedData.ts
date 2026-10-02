/**
 * Deterministic, reproducible test data for the E2E suite.
 *
 * Every record here is created (idempotently — query first, insert only if missing)
 * under an obviously-fake name so a reviewer always sees the same starting state,
 * and so nobody mistakes it for a real franchise or customer record.
 */
import type { SalesforceSession } from './salesforceSession';
import { sfCreate, sfQueryOne } from './restClient';

export const QA_FRANCHISE_OWNER_NAME = 'Chicken Tights QA Owner (E2E)';
export const QA_FRANCHISE_LOCATION_NAME = 'Chicken Tights — QA Gym (E2E)';

interface SeededRecords {
  franchiseOwnerId: string;
  franchiseLocationId: string;
}

async function findOrCreate(
  session: SalesforceSession,
  sobject: string,
  whereClause: string,
  createFields: Record<string, unknown>
): Promise<string> {
  const existing = await sfQueryOne<{ Id: string }>(session, `SELECT Id FROM ${sobject} WHERE ${whereClause} LIMIT 1`);
  if (existing) return existing.Id;
  return sfCreate(session, sobject, createFields);
}

/**
 * Ensures the QA Franchise Owner + Franchise Location used by the Lead
 * Registration spec exist, and returns their ids.
 */
export async function ensureLeadRegistrationSeedData(session: SalesforceSession): Promise<SeededRecords> {
  const franchiseOwnerId = await findOrCreate(
    session,
    'Franchise_Owner__c',
    `Name = '${QA_FRANCHISE_OWNER_NAME}'`,
    {
      Name: QA_FRANCHISE_OWNER_NAME,
      Contact_First_Name__c: 'Quinn',
      Contact_Last_Name__c: 'QA',
      Legal_Name__c: `${QA_FRANCHISE_OWNER_NAME} Legal`,
      Email__c: 'qa-owner-e2e@chickentightslabs.invalid',
    }
  );

  const franchiseLocationId = await findOrCreate(
    session,
    'Franchise_Location__c',
    `Name = '${QA_FRANCHISE_LOCATION_NAME}'`,
    {
      Name: QA_FRANCHISE_LOCATION_NAME,
      Status__c: 'Active',
      Franchise_Owner__c: franchiseOwnerId,
    }
  );

  return { franchiseOwnerId, franchiseLocationId };
}
