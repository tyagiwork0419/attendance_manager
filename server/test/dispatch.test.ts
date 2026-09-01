import { describe, expect, it, vi } from 'vitest';
import { dispatch, type DispatchServices } from '../src/dispatch.js';
import { sha256Hex, signSessionToken } from '../src/crypto.js';
import type { SheetsClient } from '../src/google/sheets.js';
import type { DriveClient } from '../src/google/drive.js';
import type { CalendarClient } from '../src/google/calendar.js';

const SECRET = 'test-secret';

const USERS = [
  ['name', 'password', 'role'],
  ['八木', '111111', 'admin'],
  ['大滝', '222222', ''],
];

const DEVICE_HEADER = ['token_hash', 'user', 'label', 'created', 'last_used', 'revoked'];

function makeUsersClient(deviceRows: string[][] = [DEVICE_HEADER]): SheetsClient {
  return {
    getValues: vi.fn(async (range: string) => {
      if (range === 'devices') return deviceRows;
      if (range.startsWith('settings')) return [];
      return USERS;
    }),
    batchUpdateValues: vi.fn(async () => {}),
    appendValues: vi.fn(async () => {}),
    ensureSheetWithHeader: vi.fn(async () => {}),
    listSheetNames: vi.fn(async () => []),
    ensureSheetCopiedFrom: vi.fn(async () => {}),
  };
}

function makeServices(overrides: Partial<DispatchServices> = {}): DispatchServices {
  const drive: DriveClient = {
    findFileInFolder: vi.fn(async () => 'year-id'),
    listFileNamesInFolder: vi.fn(async () => []),
    copyFile: vi.fn(async () => 'year-id'),
  };
  const calendar: CalendarClient = { listEvents: vi.fn(async () => []) };

  return {
    usersClient: makeUsersClient(),
    drive,
    calendar,
    sheetsFactory: vi.fn(() => makeUsersClient()),
    sessionSecret: SECRET,
    ...overrides,
  };
}

describe('dispatch: malformed requests', () => {
  it('returns empty_request for an empty body', async () => {
    const result = await dispatch('', makeServices());
    expect(result).toEqual({ ok: false, error: 'リクエストが空です', code: 'empty_request' });
  });

  it('returns empty_request for unparsable JSON', async () => {
    const result = await dispatch('not json', makeServices());
    expect(result).toEqual({ ok: false, error: 'リクエストが空です', code: 'empty_request' });
  });

  it('returns no_action when action is missing', async () => {
    const result = await dispatch(JSON.stringify({}), makeServices());
    expect(result).toEqual({
      ok: false,
      error: 'action が指定されていません',
      code: 'no_action',
    });
  });

  it('returns unknown_action for an unrecognized action', async () => {
    const result = await dispatch(JSON.stringify({ action: 'doSomethingElse' }), makeServices());
    expect(result).toEqual({
      ok: false,
      error: '不明な action です: doSomethingElse',
      code: 'unknown_action',
    });
  });
});

describe('dispatch: public actions (no device token needed)', () => {
  it('getUsers returns names only', async () => {
    const result = await dispatch(JSON.stringify({ action: 'getUsers' }), makeServices());
    expect(result).toEqual({ ok: true, result: ['八木', '大滝'] });
  });

  it('login issues a valid session token', async () => {
    const services = makeServices();
    const result = await dispatch(
      JSON.stringify({ action: 'login', name: '八木', password: '111111' }),
      services
    );
    expect(result.ok).toBe(true);
  });

  it('registerDevice works without any prior device token', async () => {
    const services = makeServices();
    const result = await dispatch(
      JSON.stringify({
        action: 'registerDevice',
        name: '大滝',
        password: '222222',
        label: '',
        shared: false,
      }),
      services
    );
    expect(result.ok).toBe(true);
  });
});

describe('dispatch: device actions require a registered device token', () => {
  it('rejects with device_unauthorized when no/invalid deviceToken is given', async () => {
    const result = await dispatch(
      JSON.stringify({ action: 'getSettings', deviceToken: 'not-registered' }),
      makeServices()
    );
    expect(result).toEqual({
      ok: false,
      error: 'この端末は登録されていません',
      code: 'device_unauthorized',
    });
  });

  it('succeeds with a valid deviceToken', async () => {
    const token = 'valid-token';
    const services = makeServices({
      usersClient: makeUsersClient([
        DEVICE_HEADER,
        [sha256Hex(token), '八木', '', '', '', 'FALSE'],
      ]),
    });

    const result = await dispatch(
      JSON.stringify({ action: 'getSettings', deviceToken: token }),
      services
    );
    expect(result.ok).toBe(true);
  });

  it('rejects a revoked device', async () => {
    const token = 'revoked-token';
    const services = makeServices({
      usersClient: makeUsersClient([
        DEVICE_HEADER,
        [sha256Hex(token), '八木', '', '', '', 'TRUE'],
      ]),
    });
    const result = await dispatch(
      JSON.stringify({ action: 'getSettings', deviceToken: token }),
      services
    );
    expect(result).toEqual({
      ok: false,
      error: 'この端末は登録されていません',
      code: 'device_unauthorized',
    });
  });
});

describe('dispatch: personal actions require own-device or a matching session', () => {
  const token = 'personal-token';

  function servicesWithDevice(owner: string) {
    return makeServices({
      usersClient: makeUsersClient([
        DEVICE_HEADER,
        [sha256Hex(token), owner, '', '', '', 'FALSE'],
      ]),
    });
  }

  it('allows opening your own name from your own personal device without a session token', async () => {
    const services = servicesWithDevice('八木');
    const result = await dispatch(
      JSON.stringify({
        action: 'selectByName',
        deviceToken: token,
        parameters: { fileName: '2026年', sheetName: '8月', name: '八木' },
      }),
      services
    );
    expect(result.ok).toBe(true);
  });

  it('rejects opening someone else\'s name from a personal device with no session', async () => {
    const services = servicesWithDevice('八木');
    const result = await dispatch(
      JSON.stringify({
        action: 'selectByName',
        deviceToken: token,
        parameters: { fileName: '2026年', sheetName: '8月', name: '大滝' },
      }),
      services
    );
    expect(result).toEqual({ ok: false, error: '本人確認が必要です', code: 'unauthorized' });
  });

  it('rejects a shared device (empty owner) with no session', async () => {
    const services = servicesWithDevice('');
    const result = await dispatch(
      JSON.stringify({
        action: 'selectByName',
        deviceToken: token,
        parameters: { fileName: '2026年', sheetName: '8月', name: '八木' },
      }),
      services
    );
    expect(result).toEqual({ ok: false, error: '本人確認が必要です', code: 'unauthorized' });
  });

  it('allows a shared device with a session token matching the target name', async () => {
    const services = servicesWithDevice('');
    const session = signSessionToken({ name: '八木', ttlSeconds: 3600 }, SECRET);
    const result = await dispatch(
      JSON.stringify({
        action: 'selectByName',
        deviceToken: token,
        token: session,
        parameters: { fileName: '2026年', sheetName: '8月', name: '八木' },
      }),
      services
    );
    expect(result.ok).toBe(true);
  });

  it('rejects a session token for a different name than the target', async () => {
    const services = servicesWithDevice('');
    const session = signSessionToken({ name: '大滝', ttlSeconds: 3600 }, SECRET);
    const result = await dispatch(
      JSON.stringify({
        action: 'selectByName',
        deviceToken: token,
        token: session,
        parameters: { fileName: '2026年', sheetName: '8月', name: '八木' },
      }),
      services
    );
    expect(result).toEqual({ ok: false, error: '本人確認が必要です', code: 'unauthorized' });
  });
});

describe('dispatch: account actions', () => {
  const token = 'account-token';

  function servicesWithDevice() {
    return makeServices({
      usersClient: makeUsersClient([
        DEVICE_HEADER,
        [sha256Hex(token), '八木', '', '', '', 'FALSE'],
      ]),
    });
  }

  it('changePassword still requires a registered device token', async () => {
    const result = await dispatch(
      JSON.stringify({
        action: 'changePassword',
        deviceToken: 'not-registered',
        name: '八木',
        currentPassword: '111111',
        newPassword: '222222',
      }),
      makeServices()
    );
    expect(result).toEqual({
      ok: false,
      error: 'この端末は登録されていません',
      code: 'device_unauthorized',
    });
  });

  it('routes updateSettings to the admin-gated handler', async () => {
    const services = servicesWithDevice();
    const result = await dispatch(
      JSON.stringify({
        action: 'updateSettings',
        deviceToken: token,
        name: '大滝', // not an admin
        password: '222222',
        settings: { standardWorkHoursPerDay: 7 },
      }),
      services
    );
    expect(result).toEqual({
      ok: false,
      error: '管理者のみ設定を変更できます',
      code: 'admin_required',
    });
  });
});

describe('dispatch: unexpected errors', () => {
  it('are caught and reported as internal_error without leaking details', async () => {
    const services = makeServices({
      usersClient: {
        ...makeUsersClient(),
        getValues: vi.fn(async () => {
          throw new Error('boom: something sensitive');
        }),
      },
    });

    const result = await dispatch(JSON.stringify({ action: 'getUsers' }), services);
    expect(result).toEqual({ ok: false, error: 'サーバー内部エラー', code: 'internal_error' });
  });
});
