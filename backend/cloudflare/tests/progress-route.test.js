import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import test from 'node:test';
import worker from '../src/index.js';

const signingKey = 'progress-route-test-signing-key-at-least-32-bytes';

function tokenFor(userId) {
  const now = Math.floor(Date.now() / 1000);
  const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
  const payload = Buffer.from(JSON.stringify({ sub: userId, iat: now, exp: now + 60, jti: `test-${userId}` })).toString('base64url');
  const input = `${header}.${payload}`;
  return `${input}.${createHmac('sha256', signingKey).update(input).digest('base64url')}`;
}

function makeEnvironment() {
  const rows = new Map();
  const database = {
    prepare(sql) {
      let values = [];
      const statement = {
        bind(...args) { values = args; return statement; },
        async first() {
          assert.match(sql, /SELECT snapshot, updated_at FROM user_progress/);
          return rows.get(values[0]) ?? null;
        },
        async run() {
          const [userId, snapshot, updatedAt, expectedUpdatedAt] = values;
          const current = rows.get(userId);
          if ((current?.updated_at ?? 0) !== expectedUpdatedAt) return { meta: { changes: 0 } };
          rows.set(userId, { snapshot, updated_at: updatedAt });
          return { meta: { changes: 1 } };
        },
      };
      return statement;
    },
  };
  const state = { enabled: true, message: '', updatedAt: new Date().toISOString(), revision: 0 };
  return {
    rows,
    env: {
      DB: database,
      JWT_SIGNING_KEY: signingKey,
      SESSIONS: { get: async () => null },
      SERVICE_CONTROL: {
        idFromName: () => 'gisaclub-global',
        get: () => ({ fetch: async () => Response.json(state) }),
      },
    },
  };
}

async function call(env, userId, method, body) {
  return worker.fetch(new Request('https://api.example.test/v1/progress', {
    method,
    headers: {
      Authorization: `Bearer ${tokenFor(userId)}`,
      ...(body === undefined ? {} : { 'Content-Type': 'application/json' }),
    },
    ...(body === undefined ? {} : { body }),
  }), env, {});
}

test('authenticated progress route keeps A and B rows isolated', async () => {
  const { env, rows } = makeEnvironment();
  const bodyA = JSON.stringify({ items: { a_q: { wrong: 1, updatedAt: 10 } } });
  const bodyB = JSON.stringify({ items: { b_q: { correct: 1, updatedAt: 20 } } });

  assert.equal((await call(env, 'account-a', 'POST', bodyA)).status, 200);
  assert.equal((await call(env, 'account-b', 'POST', bodyB)).status, 200);
  const a = await (await call(env, 'account-a', 'GET')).json();
  const b = await (await call(env, 'account-b', 'GET')).json();

  assert.deepEqual(Object.keys(a.snapshot.items), ['a_q']);
  assert.deepEqual(Object.keys(b.snapshot.items), ['b_q']);
  assert.deepEqual([...rows.keys()].sort(), ['account-a', 'account-b']);
});

test('progress route rejects an oversized body before JSON parsing or D1 access', async () => {
  const { env, rows } = makeEnvironment();
  const oversized = ' '.repeat(5 * 1024 * 1024 + 1);
  const response = await call(env, 'account-a', 'POST', oversized);

  assert.equal(response.status, 413);
  assert.equal((await response.json()).error, 'progress_too_large');
  assert.equal(rows.size, 0);
});

test('progress route also enforces the limit while streaming a body without Content-Length', async () => {
  const { env, rows } = makeEnvironment();
  const stream = new ReadableStream({
    start(controller) {
      controller.enqueue(new TextEncoder().encode(' '.repeat(5 * 1024 * 1024 + 1)));
      controller.close();
    },
  });
  const request = new Request('https://api.example.test/v1/progress', {
    method: 'POST',
    headers: { Authorization: `Bearer ${tokenFor('account-a')}`, 'Content-Type': 'application/json' },
    body: stream,
    duplex: 'half',
  });

  assert.equal(request.headers.has('Content-Length'), false);
  const response = await worker.fetch(request, env, {});
  assert.equal(response.status, 413);
  assert.equal(rows.size, 0);
});

test('progress route accepts a valid request at the exact 5 MiB limit', async () => {
  const { env, rows } = makeEnvironment();
  const body = ' '.repeat(5 * 1024 * 1024 - 2) + '{}';
  assert.equal(new TextEncoder().encode(body).byteLength, 5 * 1024 * 1024);

  const response = await call(env, 'account-a', 'POST', body);
  assert.equal(response.status, 200);
  assert.equal(rows.size, 1);
});
