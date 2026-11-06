import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import test from 'node:test';
import worker from '../src/index.js';
import { getQuestionImage, getStudyFile } from '../src/content.js';

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

function base64url(value) {
  return Buffer.from(value).toString('base64url');
}

function sessionToken() {
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const payload = base64url(JSON.stringify({
    sub: 'security-test-user',
    iat: now,
    exp: now + 60,
    jti: 'security-test-session',
  }));
  const signingInput = `${header}.${payload}`;
  const signature = createHmac('sha256', signingKey).update(signingInput).digest('base64url');
  return `${signingInput}.${signature}`;
}

function envWith(overrides = {}) {
  return {
    JWT_SIGNING_KEY: signingKey,
    SESSIONS: { get: async () => null },
    SERVICE_CONTROL: enabledServiceControl(),
    ...overrides,
  };
}

test('every study, grading, entitlement, billing, AI and progress endpoint requires a session', async () => {
  const paths = [
    ['/v1/tracks', 'GET'],
    ['/v1/auth/logout', 'POST'],
    ['/v1/tracks/electrician/exams', 'GET'],
    ['/v1/exams/electrician/2016_1/paper', 'GET'],
    ['/v1/study/track/electrician/study_plan.json', 'GET'],
    ['/v1/study/theory/electrician/01.md', 'GET'],
    ['/v1/study/common/common/basics_dict.json', 'GET'],
    ['/v1/study/qnet/qnet/qnet_schedule.json', 'GET'],
    ['/v1/question-images/electrician/2016_1_001.png', 'GET'],
    ['/v1/exams/electrician/2016_1/questions', 'GET'],
    ['/v1/questions/electrician_2016_1_001', 'GET'],
    ['/v1/quiz/grade', 'POST'],
    ['/v1/entitlement', 'GET'],
    ['/v1/ai/chat', 'POST'],
    ['/v1/billing/verify', 'POST'],
    ['/v1/progress', 'GET'],
    ['/v1/progress', 'POST'],
  ];

  for (const [path, method] of paths) {
    const response = await worker.fetch(
      new Request(`https://gisaclub-api.example.workers.dev${path}`, { method }),
      envWith(),
      {},
    );
    assert.equal(response.status, 401, `${method} ${path} must reject unauthenticated access`);
  }
});

test('study-file allowlists reject unapproved paths before reading R2', async () => {
  let reads = 0;
  const env = { CONTENT: { get: async () => { reads++; return null; } } };
  await assert.rejects(getStudyFile(env, 'track', 'electrician', 'answers_private.json'), {
    code: 'not_found',
  });
  await assert.rejects(getStudyFile(env, 'theory', 'electrician', '../secrets.md'), {
    code: 'not_found',
  });
  assert.equal(reads, 0, 'rejected names must not reach the content bucket');
});

test('authenticated question images are never stored by HTTP caches', async () => {
  let requestedKey = '';
  const env = envWith({
    CONTENT: {
      get: async (key) => {
        requestedKey = key;
        return { body: new Response('image').body, httpMetadata: { contentType: 'image/png' } };
      },
    },
  });
  const response = await worker.fetch(
    new Request('https://gisaclub-api.example.workers.dev/v1/question-images/electrician/images/2016_1_001.png', {
      headers: { Authorization: `Bearer ${sessionToken()}` },
    }),
    env,
    {},
  );

  assert.equal(response.status, 200);
  assert.equal(requestedKey, 'images/electrician/2016_1_001.png');
  assert.equal(response.headers.get('Cache-Control'), 'no-store');
  assert.equal(response.headers.get('Content-Type'), 'image/png');
});
