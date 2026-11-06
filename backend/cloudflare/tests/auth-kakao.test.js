import assert from 'node:assert/strict';
import test from 'node:test';
import worker from '../src/index.js';
import { signInWithKakao } from '../src/auth.js';

const appId = '1625637';
const accessToken = 'test-kakao-access-token';
const signingKey = 'test-only-jwt-signing-key-with-at-least-32-bytes';

function enabledServiceControl() {
  const state = {
    enabled: true,
    message: '',
    updatedAt: '2026-10-28T00:00:00.000Z',
    revision: 0,
  };
  return {
    idFromName: () => 'gisaclub-global',
    get: () => ({ fetch: async () => Response.json(state) }),
  };
}

function makeEnv(overrides = {}) {
  const statements = [];
  const env = {
    KAKAO_APP_ID: appId,
    JWT_SIGNING_KEY: signingKey,
    SERVICE_CONTROL: enabledServiceControl(),
    DB: {
      prepare(sql) {
        return {
          bind(...values) {
            statements.push({ sql, values });
            return { run: async () => ({ success: true }) };
          },
        };
      },
    },
    ...overrides,
  };
  return { env, statements };
}

function jsonResponse(data, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

test('Kakao login route verifies provider token and issues a Gisaclub session', async (t) => {
  const originalFetch = globalThis.fetch;
  t.after(() => { globalThis.fetch = originalFetch; });
  const { env, statements } = makeEnv();
  const calls = [];
  const providerResponses = [
    { id: 123456789, app_id: Number(appId), expires_in: 3600 },
    {
      id: 123456789,
      kakao_account: {
        profile: {
          nickname: '학습자',
          profile_image_url: 'https://t1.kakaocdn.net/profile.png',
        },
      },
    },
  ];
  globalThis.fetch = async (url, options) => {
    calls.push({ url: String(url), authorization: options.headers.Authorization });
    return jsonResponse(providerResponses.shift());
  };

  const response = await worker.fetch(
    new Request('https://gisaclub-api.example.workers.dev/v1/auth/kakao', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ accessToken }),
    }),
    env,
    {},
  );
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(body.profile.id, 'kakao:123456789');
  assert.equal(body.profile.provider, 'kakao');
  assert.equal(body.profile.email, '');
  assert.equal(body.profile.name, '학습자');
  assert.equal(body.profile.photoUrl, 'https://t1.kakaocdn.net/profile.png');
  assert.equal(body.expiresIn, 7 * 24 * 60 * 60);
  assert.match(body.accessToken, /^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/);
  assert.deepEqual(calls.map((call) => call.url), [
    'https://kapi.kakao.com/v1/user/access_token_info',
    'https://kapi.kakao.com/v2/user/me',
  ]);
  assert.ok(calls.every((call) => call.authorization === `Bearer ${accessToken}`));
  assert.equal(statements.length, 1);
  assert.match(statements[0].sql, /INSERT INTO users \(id, email, created_at, last_seen_at\)/);
  assert.deepEqual(statements[0].values.slice(0, 1), ['kakao:123456789']);
});

test('Kakao login rejects tokens from a different Kakao app before profile lookup', async (t) => {
  const originalFetch = globalThis.fetch;
  t.after(() => { globalThis.fetch = originalFetch; });
  const { env, statements } = makeEnv();
  let calls = 0;
  globalThis.fetch = async () => {
    calls += 1;
    return jsonResponse({ id: 123456789, app_id: 7, expires_in: 3600 });
  };

  await assert.rejects(
    signInWithKakao(env, { accessToken }),
    (error) => error.status === 401 && error.code === 'bad_kakao_token',
  );
  assert.equal(calls, 1);
  assert.equal(statements.length, 0);
});

test('Kakao login rejects a profile whose member id differs from the token owner', async (t) => {
  const originalFetch = globalThis.fetch;
  t.after(() => { globalThis.fetch = originalFetch; });
  const { env, statements } = makeEnv();
  const responses = [
    { id: 123456789, app_id: Number(appId), expires_in: 3600 },
    { id: 987654321, kakao_account: { profile: { nickname: '다른 사용자' } } },
  ];
  globalThis.fetch = async () => jsonResponse(responses.shift());

  await assert.rejects(
    signInWithKakao(env, { accessToken }),
    (error) => error.status === 401 && error.code === 'bad_kakao_token',
  );
  assert.equal(statements.length, 0);
});

test('Kakao login rejects invalid access tokens without creating a user', async (t) => {
  const originalFetch = globalThis.fetch;
  t.after(() => { globalThis.fetch = originalFetch; });
  const { env, statements } = makeEnv();
  globalThis.fetch = async () => jsonResponse({ msg: 'invalid token' }, 401);

  await assert.rejects(
    signInWithKakao(env, { accessToken }),
    (error) => error.status === 401 && error.code === 'bad_kakao_token',
  );
  assert.equal(statements.length, 0);
});

test('Kakao login fails closed when the app id is missing', async (t) => {
  const originalFetch = globalThis.fetch;
  t.after(() => { globalThis.fetch = originalFetch; });
  const { env, statements } = makeEnv({ KAKAO_APP_ID: '' });
  let called = false;
  globalThis.fetch = async () => { called = true; throw new Error('unexpected'); };

  await assert.rejects(
    signInWithKakao(env, { accessToken }),
    (error) => error.status === 503 && error.code === 'auth_not_configured',
  );
  assert.equal(called, false);
  assert.equal(statements.length, 0);
});
