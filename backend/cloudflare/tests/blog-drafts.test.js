import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import test from 'node:test';
import worker from '../src/index.js';

const adminSecret = 'test-admin-secret-with-more-than-32-bytes';
const topics = {
  schemaVersion: 1,
  tracks: [
    { id: 'electrician', name: '전기기사', subjects: ['전력공학', '전기기기', '회로이론'], theoryFiles: { hidden: 'PRIVATE_THEORY_SOURCE' } },
    { id: 'industrial_safety', name: '산업안전기사', subjects: ['안전관리론', '인간공학', '건설안전'] },
  ],
};

function adminToken() {
  const now = Math.floor(Date.now() / 1000);
  const payload = Buffer.from(JSON.stringify({
    email: 'operator@example.com', role: 'admin', iat: now, exp: now + 3600,
  })).toString('base64url');
  const signature = createHmac('sha256', adminSecret).update(payload).digest('base64url');
  return `${payload}.${signature}`;
}

function createDb() {
  const rows = new Map();
  const bySlot = new Map();
  return {
    rows,
    prepare(sql) {
      let values = [];
      return {
        bind(...args) { values = args; return this; },
        async run() {
          if (sql.includes('INSERT OR IGNORE INTO blog_drafts')) {
            const [id, day, slot, trackId, certificate, subject, token, createdAt, updatedAt] = values;
            const key = `${day}:${slot}`;
            if (bySlot.has(key)) return { meta: { changes: 0 } };
            const row = {
              id, slot_date: day, slot, track_id: trackId, certificate, subject, status: 'generating',
              generation_token: token, created_at: createdAt, updated_at: updatedAt,
              title: null, excerpt: null, body_markdown: null, editorial_notes: null,
              last_error: null,
            };
            rows.set(id, row);
            bySlot.set(key, id);
            return { meta: { changes: 1 } };
          }
          if (sql.includes('SET generation_token = ?')) {
            const [token, updatedAt, day, slot, cutoff] = values;
            const id = bySlot.get(`${day}:${slot}`);
            const row = rows.get(id);
            if (!row || row.status !== 'generating' || row.updated_at > cutoff) return { meta: { changes: 0 } };
            row.generation_token = token;
            row.updated_at = updatedAt;
            return { meta: { changes: 1 } };
          }
          if (sql.includes('SET status = ?') && sql.includes('editorial_notes = ?')) {
            const [status, title, excerpt, body, notes, updatedAt, id, token] = values;
            const row = rows.get(id);
            if (!row || row.status !== 'generating' || row.generation_token !== token) return { meta: { changes: 0 } };
            Object.assign(row, {
              status, title, excerpt, body_markdown: body, editorial_notes: notes,
              updated_at: updatedAt, last_error: null,
            });
            return { meta: { changes: 1 } };
          }
          if (sql.includes('SET status = ?') && sql.includes("WHERE id = ? AND status = 'review'")) {
            const [status, title, excerpt, body, updatedAt, id, priorStatus] = values;
            const row = rows.get(id);
            if (!row || row.status !== 'review') return { meta: { changes: 0 } };
            Object.assign(row, { status, title, excerpt, body_markdown: body, updated_at: updatedAt });
            return { meta: { changes: 1 } };
          }
          if (sql.includes('SET status = ?') && sql.includes('last_error = ?')) {
            const [status, error, updatedAt, id, token] = values;
            const row = rows.get(id);
            if (!row || row.status !== 'generating' || row.generation_token !== token) return { meta: { changes: 0 } };
            Object.assign(row, { status, last_error: error, updated_at: updatedAt });
            return { meta: { changes: 1 } };
          }
          throw new Error(`Unexpected D1 run SQL: ${sql}`);
        },
        async all() {
          if (!sql.includes('FROM blog_drafts')) throw new Error(`Unexpected D1 all SQL: ${sql}`);
          const selected = [...rows.values()]
            .filter((row) => !sql.includes('WHERE status = ?') || row.status === values[0])
            .sort((a, b) => b.created_at.localeCompare(a.created_at))
            .slice(0, values[sql.includes('WHERE status = ?') ? 1 : 0] || 50)
            .map((row) => ({
              id: row.id,
              slot_date: row.slot_date,
              slot: row.slot,
              track_id: row.track_id,
              certificate: row.certificate,
              subject: row.subject,
              status: row.status,
              title: row.title,
              excerpt: row.excerpt,
              bodyMarkdown: row.body_markdown,
              editorialNotes: row.editorial_notes,
              lastError: row.last_error,
              createdAt: row.created_at,
              updatedAt: row.updated_at,
            }));
          return { results: selected };
        },
        async first() {
          if (!sql.includes('FROM blog_drafts')) throw new Error(`Unexpected D1 first SQL: ${sql}`);
          if (sql.includes('slot_date = ? AND slot = ?')) return rows.get(bySlot.get(`${values[0]}:${values[1]}`)) || null;
          if (sql.includes('WHERE id = ?')) return rows.get(values[0]) || null;
          throw new Error(`Unexpected D1 first SQL: ${sql}`);
        },
      };
    },
  };
}

function createEnv({ provider, db = createDb() } = {}) {
  const requests = [];
  return {
    db,
    requests,
    env: {
      BLOG_DRAFTS_ENABLED: 'true',
      DB: db,
      CONTENT: { get: async (key) => key === 'catalog/tracks.json' ? { json: async () => topics } : null },
      SERVICE_CONTROL: {
        idFromName: () => 'gisaclub-global',
        get: () => ({ fetch: async () => Response.json({ enabled: true, message: '', updatedAt: new Date().toISOString(), revision: 0 }) }),
      },
      AI_ENDPOINT: 'https://ai.example.test/chat/completions',
      CEREBRAS_API_KEY: 'test-provider-key',
      AI_MODEL: 'test-model',
      ADMIN_TOKEN_SECRET: adminSecret,
      fetch: async (url, init) => {
        const body = JSON.parse(init.body);
        requests.push(body);
        return provider ? provider(body) : Response.json({ choices: [{ message: { content: JSON.stringify(draftPayload()) } }] });
      },
    },
  };
}

function draftPayload(title = '전력공학 개념 정리') {
  return {
    title,
    excerpt: '전력공학의 기본 개념을 예시와 함께 복습하는 초안입니다.',
    bodyMarkdown: '## 핵심 개념\n\n전력계통에서 전압과 전류의 관계를 이해하는 것이 출발점입니다. 전력은 단순한 숫자가 아니라 공급원, 선로, 부하가 서로 영향을 주는 과정을 설명하는 기준입니다.\n\n## 직접 만든 예시\n\n부하가 변하면 전압 강하와 손실이 달라지는 상황을 가정해 흐름을 정리합니다. 먼저 어느 구간의 값이 바뀌었는지 확인하고, 그 변화가 다음 구간에 미치는 영향을 차례로 살펴봅니다.\n\n## 복습 순서\n\n1. 정의를 읽습니다.\n2. 단위를 확인합니다.\n3. 예시를 다시 계산합니다.',
    editorialNotes: '공식과 최신 출제 기준을 사람이 확인한 뒤 게시하세요.',
  };
}

function scheduledEvent(iso = '2026-10-27T23:00:00.000Z') {
  return { cron: '0 23 * * *', scheduledTime: Date.parse(iso) };
}

function runScheduler(event, env, ctx) {
  assert.equal(typeof worker.scheduled, 'function', 'Worker exposes the scheduled draft generator');
  return worker.scheduled(event, env, ctx);
}

test('daily scheduler writes at most three distinct private drafts and duplicate invocations do not duplicate provider calls', async () => {
  const { env, db, requests } = createEnv();
  const ctx = { waitUntil(promise) { this.pending = promise; } };

  await Promise.all([
    runScheduler(scheduledEvent(), env, ctx),
    runScheduler(scheduledEvent(), env, ctx),
  ]);

  assert.equal(db.rows.size, 3);
  assert.equal(requests.length, 3);
  assert.equal(new Set([...db.rows.values()].map((row) => row.subject)).size, 3);
  assert.ok([...db.rows.values()].every((row) => row.slot_date === '2026-10-28' && row.status === 'review'));
  assert.ok(requests.every((body) => !JSON.stringify(body).includes('PRIVATE_THEORY_SOURCE')));
});

test('daily scheduler skips generation while the global service is disabled', async () => {
  const { env, db, requests } = createEnv();
  env.SERVICE_CONTROL.get = () => ({
    fetch: async () => Response.json({
      enabled: false,
      message: '점검 중',
      updatedAt: '2026-10-28T00:00:00.000Z',
      revision: 1,
    }),
  });

  await runScheduler(scheduledEvent(), env, {});

  assert.equal(db.rows.size, 0);
  assert.equal(requests.length, 0);
});

test('daily scheduler fails closed when the global service state is unavailable', async () => {
  const { env, db, requests } = createEnv();
  env.SERVICE_CONTROL.get = () => ({
    fetch: async () => { throw new Error('service control unavailable'); },
  });

  await runScheduler(scheduledEvent(), env, {});

  assert.equal(db.rows.size, 0);
  assert.equal(requests.length, 0);
});

test('daily scheduler does not call the model if service is disabled while loading the catalog', async () => {
  const { env, db, requests } = createEnv();
  let enabled = true;
  env.SERVICE_CONTROL.get = () => ({
    fetch: async () => Response.json({
      enabled,
      message: enabled ? '' : '점검 중',
      updatedAt: '2026-10-28T00:00:00.000Z',
      revision: enabled ? 0 : 1,
    }),
  });
  const getContent = env.CONTENT.get;
  env.CONTENT.get = async (key) => {
    const result = await getContent(key);
    if (key === 'catalog/tracks.json') enabled = false;
    return result;
  };

  await runScheduler(scheduledEvent(), env, {});

  assert.equal(db.rows.size, 0);
  assert.equal(requests.length, 0);
});

test('daily scheduler discards model output if service is disabled during generation', async () => {
  let enabled = true;
  const provider = async () => {
    enabled = false;
    return Response.json({ choices: [{ message: { content: JSON.stringify(draftPayload()) } }] });
  };
  const { env, db } = createEnv({ provider });
  env.SERVICE_CONTROL.get = () => ({
    fetch: async () => Response.json({
      enabled,
      message: enabled ? '' : '점검 중',
      updatedAt: '2026-10-28T00:00:00.000Z',
      revision: enabled ? 0 : 1,
    }),
  });

  await runScheduler(scheduledEvent(), env, {});

  assert.ok([...db.rows.values()].every((row) => row.status !== 'review' && row.title === null));
});

test('daily prompts contain the selected certificate and subject but no question bank or theory source', async () => {
  const { env, requests } = createEnv();
  await runScheduler(scheduledEvent(), env, {});

  assert.equal(requests.length, 3);
  for (const body of requests) {
    const prompt = body.messages.map((message) => message.content).join('\n');
    assert.match(prompt, /전기기사|산업안전기사/);
    assert.match(prompt, /전력공학|전기기기|회로이론|안전관리론|인간공학|건설안전/);
    assert.doesNotMatch(prompt, /PRIVATE_THEORY_SOURCE|정답은 4번|해설은 이 문장/);
  }
});

test('provider failure is kept as a private failed draft and reported to the scheduler', async () => {
  const { env, db } = createEnv({ provider: async () => new Response('unavailable', { status: 503 }) });

  await assert.rejects(runScheduler(scheduledEvent(), env, {}), { code: 'draft_generation_failed' });
  assert.equal(db.rows.size, 3);
  assert.ok([...db.rows.values()].every((row) => row.status === 'failed' && row.title === null));
});

test('malformed model output is stored only as failed and cannot be approved', async () => {
  const provider = async () => Response.json({ choices: [{ message: { content: '{"title":"잘못된 결과"}' } }] });
  const { env, db } = createEnv({ provider });

  await assert.rejects(runScheduler(scheduledEvent(), env, {}), { code: 'draft_generation_failed' });
  assert.ok([...db.rows.values()].every((row) => row.status === 'failed' && row.title === null && row.last_error === 'invalid_ai_output'));
});

test('a stale generation claim can be reclaimed and its older response is fenced out', async () => {
  let resolveOldOutput;
  let notifyStarted;
  let callCount = 0;
  const oldOutput = new Promise((resolve) => { resolveOldOutput = resolve; });
  const started = new Promise((resolve) => { notifyStarted = resolve; });
  const provider = async () => {
    callCount += 1;
    if (callCount <= 3) {
      if (callCount === 3) notifyStarted();
      const draft = await oldOutput;
      return Response.json({ choices: [{ message: { content: JSON.stringify(draft) } }] });
    }
    return Response.json({ choices: [{ message: { content: JSON.stringify(draftPayload('새로 점유한 작업 초안')) } }] });
  };
  const { env, db } = createEnv({ provider });
  const originalNow = Date.now;
  const initialNow = originalNow();
  const firstRun = runScheduler(scheduledEvent(), env, {});

  try {
    await started;
    Date.now = () => initialNow + 16 * 60 * 1000;
    await runScheduler(scheduledEvent(), env, {});
  } finally {
    Date.now = originalNow;
  }

  resolveOldOutput(draftPayload('오래된 초안 응답 내용'));
  await firstRun;
  assert.equal(callCount, 6);
  assert.ok([...db.rows.values()].every((row) => row.status === 'review' && row.title === '새로 점유한 작업 초안'));
});

test('admin draft list requires admin auth and never returns provider claim tokens', async () => {
  const { env } = createEnv();
  await runScheduler(scheduledEvent(), env, {});

  const denied = await worker.fetch(new Request('https://api.example.test/v1/admin/blog-drafts'), env, {});
  assert.equal(denied.status, 403);
  const response = await worker.fetch(new Request('https://api.example.test/v1/admin/blog-drafts', {
    headers: { Authorization: `Bearer ${adminToken()}` },
  }), env, {});
  const payload = await response.json();
  assert.equal(response.status, 200);
  assert.equal(payload.items.length, 3);
  assert.ok(payload.items.every((item) => !('generation_token' in item)));
});

test('admin may approve or reject a draft but invalid decisions and public access are refused', async () => {
  const { env, db } = createEnv();
  await runScheduler(scheduledEvent(), env, {});
  const id = [...db.rows.values()][0].id;
  const headers = { Authorization: `Bearer ${adminToken()}`, 'Content-Type': 'application/json' };

  const publicResponse = await worker.fetch(new Request('https://api.example.test/v1/blog-drafts', { headers }), env, {});
  assert.equal(publicResponse.status, 401);
  const invalid = await worker.fetch(new Request(`https://api.example.test/v1/admin/blog-drafts/${id}/review`, {
    method: 'POST', headers, body: JSON.stringify({ decision: 'publish' }),
  }), env, {});
  assert.equal(invalid.status, 400);
  const approved = await worker.fetch(new Request(`https://api.example.test/v1/admin/blog-drafts/${id}/review`, {
    method: 'POST', headers, body: JSON.stringify({ decision: 'approve' }),
  }), env, {});
  assert.equal(approved.status, 200);
  assert.equal((await approved.json()).item.status, 'approved');
  assert.equal([...db.rows.values()].find((row) => row.id === id).status, 'approved');
});

test('admin review rejects out-of-range text and leaves the draft pending', async () => {
  const { env, db } = createEnv();
  await runScheduler(scheduledEvent(), env, {});
  const row = [...db.rows.values()][0];
  const headers = { Authorization: `Bearer ${adminToken()}`, 'Content-Type': 'application/json' };

  const shortTitle = await worker.fetch(new Request(`https://api.example.test/v1/admin/blog-drafts/${row.id}/review`, {
    method: 'POST', headers, body: JSON.stringify({ decision: 'approve', title: '짧음' }),
  }), env, {});
  assert.equal(shortTitle.status, 400);
  assert.equal(row.status, 'review');

  const longBody = await worker.fetch(new Request(`https://api.example.test/v1/admin/blog-drafts/${row.id}/review`, {
    method: 'POST', headers, body: JSON.stringify({ decision: 'approve', bodyMarkdown: 'x'.repeat(8_001) }),
  }), env, {});
  assert.equal(longBody.status, 400);
  assert.equal(row.status, 'review');
});
