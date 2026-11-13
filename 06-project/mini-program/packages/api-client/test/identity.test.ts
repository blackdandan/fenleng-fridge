import test from 'node:test';
import assert from 'node:assert/strict';
import { MiniIdentity, miniIdentityError } from '../src/identity.ts';
import type { IdentityDriver } from '../src/identity.ts';

const config = {enabled: true, baseUrl: 'https://platform.example.test', clientId: 'fenleng-fridge-miniapp'};
function fixture() {
  const storage = new Map<string, string>();
  let logins = 0;
  const requests: unknown[] = [];
  let resolveCode!: (value: {code: string}) => void;
  const code = new Promise<{code: string}>(resolve => {resolveCode = resolve;});
  const driver: IdentityDriver = {
    getStorageSync: key => storage.get(key),
    setStorageSync: (key, value) => {storage.set(key, value);},
    removeStorageSync: key => {storage.delete(key);},
    login: () => {logins++; return code;},
    request: input => {
      requests.push(input.data);
      assert.equal(input.url, 'https://platform.example.test/api/platform/v1/auth/wechat/login');
      input.success({statusCode: 200, data: {accessToken: 'platform-access', refreshToken: 'platform-refresh'}});
    },
  };
  return {driver, storage, requests, resolveCode, logins: () => logins};
}

test('disabled configuration cannot create a platform session', () => {
  assert.throws(() => new MiniIdentity({...config, enabled: false}, fixture().driver), /loginNotConfigured/);
});

test('initial anonymous restore does not invoke wx.login or a network call', async () => {
  const f = fixture(); const identity = new MiniIdentity(config, f.driver);
  await identity.start();
  assert.equal(f.logins(), 0); assert.equal(f.requests.length, 0);
  assert.equal(identity.session.snapshot().status, 'anonymous');
  await identity.close();
});

test('duplicate taps obtain one code and persist only platform tokens across page close', async () => {
  const f = fixture(); const identity = new MiniIdentity(config, f.driver);
  await identity.start();
  const first = identity.login(), second = identity.login();
  assert.equal(f.logins(), 1);
  f.resolveCode({code: 'temporary-wechat-code'});
  await Promise.all([first, second]);
  assert.equal(f.requests.length, 1);
  assert.deepEqual(f.requests[0], {applicationCode: 'fenleng-fridge', clientId: config.clientId, code: 'temporary-wechat-code'});
  assert.equal(identity.session.snapshot().status, 'authenticated');
  assert.deepEqual([...f.storage.values()].sort(), ['platform-access', 'platform-refresh']);
  await identity.close();
  assert.equal(f.storage.size, 2);
});

test('late native code after leaving the page does not exchange or persist tokens', async () => {
  const f = fixture(); const identity = new MiniIdentity(config, f.driver);
  await identity.start();
  const operation = identity.login();
  await identity.close();
  f.resolveCode({code: 'late-code'});
  await assert.rejects(operation, /loginCancelled/);
  assert.equal(f.requests.length, 0); assert.equal(f.storage.size, 0);
});

test('login waits for initial restore, even when its caller did not await start', async () => {
  const f = fixture(); const identity = new MiniIdentity(config, f.driver);
  const starting = identity.start();
  const login = identity.login();
  f.resolveCode({code: 'fresh-code'});
  await Promise.all([starting, login]);
  assert.equal(f.logins(), 1);
  assert.equal(identity.session.snapshot().status, 'authenticated');
  await identity.close();
});

test('logout during native login prevents a late code from signing back in', async () => {
  const f = fixture(); const identity = new MiniIdentity(config, f.driver);
  await identity.start();
  const login = identity.login();
  await identity.logout();
  f.resolveCode({code: 'late-code'});
  await assert.rejects(login, /loginCancelled/);
  assert.equal(f.requests.length, 0);
  assert.equal(f.storage.size, 0);
  assert.equal(identity.session.snapshot().status, 'anonymous');
  await identity.close();
});

test('failed code exchange retries using a fresh native code', async () => {
  const f = fixture(); let calls = 0;
  f.driver.login = async () => ({code: `code-${++calls}`});
  const seen: unknown[] = [];
  f.driver.request = input => {
    seen.push(input.data);
    if (seen.length === 1) input.fail({errMsg: 'request:fail offline'});
    else input.success({statusCode: 200, data: {accessToken: 'access', refreshToken: 'refresh'}});
  };
  const identity = new MiniIdentity(config, f.driver);
  await identity.start();
  await assert.rejects(identity.login());
  assert.equal(f.storage.size, 0);
  await identity.login();
  assert.equal(calls, 2);
  assert.deepEqual(seen.map(value => (value as {code: string}).code), ['code-1', 'code-2']);
  assert.equal(identity.session.snapshot().status, 'authenticated');
  await identity.close();
});

test('native and SDK failures expose translated keys instead of raw messages', () => {
  assert.equal(miniIdentityError({errMsg: 'login:fail timeout'}), 'loginTimeout');
  assert.equal(miniIdentityError({errMsg: 'login:fail cancel'}), 'loginCancelled');
  assert.equal(miniIdentityError({code: 'SESSION_CHANGED'}), 'loginCancelled');
  assert.equal(miniIdentityError(new Error('private transport details')), 'loginFailed');
});

test('reopening restores persisted tokens and logout clears them without another wx.login', async () => {
  const f = fixture(); const routes: string[] = [];
  f.driver.request = input => {
    const route = input.url.split('/auth/')[1]; routes.push(route);
    if (route === 'logout') {
      input.success({statusCode: 204, data: null}); return;
    }
    assert.ok(route === 'wechat/login' || route === 'refresh');
    input.success({statusCode: 200, data: {accessToken: `access-${route}`, refreshToken: `refresh-${route}`}});
  };
  const first = new MiniIdentity(config, f.driver);
  await first.start();
  const login = first.login(); f.resolveCode({code: 'first-code'}); await login;
  await first.close();
  const reopened = new MiniIdentity(config, f.driver);
  await reopened.start();
  assert.equal(reopened.session.snapshot().status, 'authenticated');
  assert.equal(f.logins(), 1);
  await reopened.logout();
  assert.deepEqual(routes, ['wechat/login', 'refresh', 'logout']);
  assert.equal(f.storage.size, 0);
  await reopened.close();
});
