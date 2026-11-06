import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import test from 'node:test';
import worker from '../src/index.js';
import { ServiceControl } from '../src/service-control.js';

const secret = 'test-admin-secret-with-more-than-32-bytes';

function appAdminToken() {
  const now = Math.floor(Date.now() / 1000);
  const payload = Buffer.from(JSON.stringify({
    email: 'operator@example.com', role: 'admin', iat: now, exp: now + 3600,
  })).toString('base64url');
  const signature = createHmac('sha256', secret).update(payload).digest('base64url');
  return `${payload}.${signature}`;
}

function validState(overrides = {}) {
  return {
    enabled: true,
    message: '',
    updatedAt: '2026-10-28T00:00:00.000Z',
    revision: 0,
    ...overrides,
  };
}

function controlNamespace(initialState = validState(), options = {}) {
  const requests = [];
  const id = { toString: () => 'gisaclub-global' };
  const stub = {
    async fetch(request, init = {}) {
      requests.push(request);
      if (options.fail) throw new Error('control unavailable');
      if (options.malformed) return Response.json({ enabled: 'yes' });
      if (options.onFetch) return options.onFetch(request, requests.length);
      const url = new URL(typeof request === 'string' ? request : request.url);
      const method = init.method || request.method || 'GET';
      if (url.pathname === '/state' && method === 'GET') return Response.json(initialState);
      if (url.pathname === '/state' && method === 'PUT') {
        const body = JSON.parse(init.body);
        initialState = validState({
          enabled: body.enabled,
          message: body.message,
          updatedAt: new Date().toISOString(),
          revision: initialState.revision + 1,
        });
        return Response.json(initialState);
      }
      return new Response('not found', { status: 404 });
    },
  };
  return {
    requests,
    namespace: { idFromName: (name) => { assert.equal(name, 'gisaclub-global'); return id; }, get: () => stub },
  };
}

function envWith(control, extra = {}) {
  return {
    SERVICE_CONTROL: control.namespace,
    ADMIN_TOKEN_SECRET: secret,
    SESSIONS: { get: async () => null },
    ...extra,
  };
}

test('Durable Object starts enabled and persists validated toggles with a new revision', async () => {
  const values = new Map();
  const control = new ServiceControl({ storage: {
    get: async (key) => values.get(key),
    put: async (key, value) => values.set(key, value),
  } });

  const initial = await (await control.fetch(new Request('https://do/state'))).json();
  assert.equal(initial.enabled, true);
  assert.equal(initial.message, '');
  assert.equal(initial.revision, 0);
  assert.ok(Number.isFinite(Date.parse(initial.updatedAt)));

  const changed = await (await control.fetch(new Request('https://do/state', {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ enabled: false, message: '점검 중' }),
  }))).json();
  assert.equal(changed.enabled, false);
  assert.equal(changed.message, '점검 중');
  assert.equal(changed.revision, 1);
  assert.equal((await (await control.fetch(new Request('https://do/state'))).json()).revision, 1);
});

async function call(path, { method = 'GET', token, body } = {}, env) {
  return worker.fetch(new Request(`https://gisaclub-api.example.workers.dev${path}`, {
    method,
    headers: {
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(body ? { 'Content-Type': 'application/json' } : {}),
    },
    ...(body ? { body: JSON.stringify(body) } : {}),
  }), env, {});
}

test('public status returns the validated singleton service state', async () => {
  const control = controlNamespace(validState({ enabled: false, message: '점검' }));
  const response = await call('/v1/app/service-status', {}, envWith(control));
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), validState({ enabled: false, message: '점검' }));
});

test('disabled mode blocks protected routes before session authentication', async () => {
  const control = controlNamespace(validState({ enabled: false, message: '점검 예정' }));
  for (const path of ['/v1/app/version', '/v1/tracks', '/v1/auth/google', '/v1/admin/users']) {
    const response = await call(path, {}, envWith(control));
    assert.equal(response.status, 503, `${path} should be blocked before auth`);
    assert.deepEqual(await response.json(), { error: 'service_disabled', message: '점검 예정' });
  }
});

test('unauthenticated callers cannot read or change admin service control', async () => {
  const control = controlNamespace();
  for (const [method, body] of [['GET', undefined], ['PUT', { enabled: false, message: '' }]]) {
    const response = await call('/v1/admin/service-control', { method, body }, envWith(control));
    assert.equal(response.status, 403);
  }
  assert.equal(control.requests.length, 0, 'authentication must happen before contacting the control object');
});

test('authenticated admins can turn service off and back on', async () => {
  const control = controlNamespace();
  const token = appAdminToken();
  const env = envWith(control);
  const off = await call('/v1/admin/service-control', {
    method: 'PUT', token, body: { enabled: false, message: '점검' },
  }, env);
  assert.equal(off.status, 200);
  assert.equal((await off.json()).enabled, false);
  const on = await call('/v1/admin/service-control', {
    method: 'PUT', token, body: { enabled: true, message: '' },
  }, env);
  assert.equal(on.status, 200);
  const state = await on.json();
  assert.equal(state.enabled, true);
  assert.equal(state.revision, 2);
});

test('health, public status, admin verification and admin control remain available while disabled', async () => {
  const control = controlNamespace(validState({ enabled: false, message: '점검' }));
  const env = envWith(control);
  const token = appAdminToken();

  assert.equal((await call('/v1/health', {}, env)).status, 200);
  const publicStatus = await call('/v1/app/service-status', {}, env);
  assert.equal(publicStatus.status, 200);
  assert.equal((await publicStatus.json()).enabled, false);
  const verified = await call('/v1/admin/verify', { token }, env);
  assert.equal(verified.status, 200);
  const adminStatus = await call('/v1/admin/service-control', { token }, env);
  assert.equal(adminStatus.status, 200);
  assert.equal((await adminStatus.json()).enabled, false);
});

test('control-store failure and malformed state fail closed for protected routes', async () => {
  for (const control of [controlNamespace(undefined, { fail: true }), controlNamespace(undefined, { malformed: true })]) {
    const response = await call('/v1/tracks', {}, envWith(control));
    assert.equal(response.status, 503);
    assert.equal((await response.json()).error, 'service_control_unavailable');
  }
});

test('response is rejected if service is disabled while a protected route is running', async () => {
  let count = 0;
  const control = controlNamespace(validState(), {
    onFetch: async (_request, requestCount) => {
      count = requestCount;
      return Response.json(validState({ enabled: requestCount < 2 }));
    },
  });
  const response = await call('/v1/app/version', {}, envWith(control, {
    SETTINGS: { get: async () => null },
  }));
  assert.equal(count, 2);
  assert.equal(response.status, 503);
});

test('preflight advertises PUT for the admin control endpoint', async () => {
  const control = controlNamespace();
  const response = await call('/v1/admin/service-control', { method: 'OPTIONS' }, envWith(control));
  assert.match(response.headers.get('Access-Control-Allow-Methods'), /PUT/);
});
