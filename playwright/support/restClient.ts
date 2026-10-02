/**
 * Minimal Salesforce REST client shared by seed-data setup and specs that need
 * to verify what a UI action actually persisted (rather than scraping Lightning's
 * detail-layout DOM field-by-field, which breaks on every page-layout tweak).
 */
import type { SalesforceSession } from './salesforceSession';

const API_VERSION = 'v58.0';

export async function sfRequest(
  session: SalesforceSession,
  method: 'GET' | 'POST' | 'PATCH',
  path: string,
  body?: unknown
): Promise<any> {
  const res = await fetch(`${session.instanceUrl}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${session.accessToken}`,
      'Content-Type': 'application/json',
    },
    body: body ? JSON.stringify(body) : undefined,
  });

  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Salesforce REST call failed (${method} ${path}): ${res.status} ${text}`);
  }
  if (res.status === 204) return null;
  return res.json();
}

export async function sfQueryOne<T = any>(
  session: SalesforceSession,
  soql: string
): Promise<T | null> {
  const result = await sfRequest(session, 'GET', `/services/data/${API_VERSION}/query?q=${encodeURIComponent(soql)}`);
  return result.totalSize > 0 ? (result.records[0] as T) : null;
}

export async function sfCreate(
  session: SalesforceSession,
  sobject: string,
  fields: Record<string, unknown>
): Promise<string> {
  const created = await sfRequest(session, 'POST', `/services/data/${API_VERSION}/sobjects/${sobject}`, fields);
  return created.id as string;
}

export async function sfGetRecord<T = any>(
  session: SalesforceSession,
  sobject: string,
  id: string,
  fields: string[]
): Promise<T> {
  return sfRequest(session, 'GET', `/services/data/${API_VERSION}/sobjects/${sobject}/${id}?fields=${fields.join(',')}`);
}
