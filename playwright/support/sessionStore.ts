import * as fs from 'node:fs';
import * as path from 'node:path';

export const AUTH_DIR = path.join(__dirname, '..', '.auth');
export const STORAGE_STATE_PATH = path.join(AUTH_DIR, 'storageState.json');
const SESSION_PATH = path.join(AUTH_DIR, 'session.json');

export interface StoredSession {
  instanceUrl: string;
  franchiseOwnerId: string;
  franchiseLocationId: string;
}

export function writeStoredSession(session: StoredSession): void {
  fs.mkdirSync(AUTH_DIR, { recursive: true });
  fs.writeFileSync(SESSION_PATH, JSON.stringify(session, null, 2));
}

export function readStoredSession(): StoredSession {
  if (!fs.existsSync(SESSION_PATH)) {
    throw new Error(
      `No Playwright global-setup session found at ${SESSION_PATH}. ` +
        'Run tests via "npm run test:e2e" so global-setup.ts runs first.'
    );
  }
  return JSON.parse(fs.readFileSync(SESSION_PATH, 'utf8')) as StoredSession;
}
