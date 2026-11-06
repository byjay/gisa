import assert from 'node:assert/strict';
import test from 'node:test';
import { getProgress, mergeSnapshots, putProgress } from '../src/progress.js';

const stamp = '2026-10-28T00:00:00.000Z';

function session(id, minutes, updatedAt) {
  return { id, examId: '', date: stamp, minutes, updatedAt };
}

function quiz(id, correct, updatedAt) {
  return {
    id,
    title: '진도 테스트',
    total: 2,
    correct,
    date: stamp,
    updatedAt,
    subjectTotal: { 회로이론: 2 },
    subjectCorrect: { 회로이론: correct },
  };
}

function fakeDb(seed = {}) {
  const rows = new Map(Object.entries(seed));
  const queries = [];
  return {
    rows,
    queries,
    prepare(sql) {
      let values = [];
      const statement = {
        bind(...args) { values = args; return statement; },
        async first() {
          queries.push({ sql, values, op: 'first' });
          if (!sql.includes('SELECT snapshot, updated_at')) throw new Error(`unexpected query: ${sql}`);
          return rows.get(values[0]) || null;
        },
        async run() {
          queries.push({ sql, values, op: 'run' });
          const [userId, snapshot, updatedAt, expectedUpdatedAt] = values;
          const current = rows.get(userId);
          if ((current?.updated_at ?? 0) !== expectedUpdatedAt) {
            return { meta: { changes: 0 } };
          }
          rows.set(userId, { snapshot, updated_at: updatedAt });
          return { meta: { changes: 1 } };
        },
      };
      return statement;
    },
  };
}

test('progress rows are read only for the verified user id', async () => {
  const db = fakeDb({
    alice: { snapshot: JSON.stringify({ items: { q1: { wrong: 1 } } }), updated_at: 10 },
    bob: { snapshot: JSON.stringify({ items: { q2: { wrong: 2 } } }), updated_at: 20 },
  });

  const alice = await getProgress({ DB: db }, 'alice');
  const bob = await getProgress({ DB: db }, 'bob');
  assert.equal(alice.snapshot.items.q1.wrong, 1);
  assert.equal(alice.snapshot.items.q2, undefined);
  assert.equal(alice.snapshot.items.q1.updatedAt, 0);
  assert.equal(bob.snapshot.items.q2.wrong, 2);
  assert.equal(bob.snapshot.items.q1, undefined);
  assert.deepEqual(db.queries.map((q) => q.values[0]), ['alice', 'bob']);
});

test('deletion tombstones prevent stale device records from being resurrected', () => {
  const merged = mergeSnapshots(
    {
      sessions: [session('s1', 10, 100), session('s2', 20, 100)],
      deleted: { sessions: ['s1'] },
    },
    {
      sessions: [session('s1', 10, 100), session('s3', 30, 100)],
      deleted: { quizResults: ['q9'] },
    },
  );

  assert.deepEqual(merged.sessions.map((item) => item.id).sort(), ['s2', 's3']);
  assert.deepEqual(merged.deleted, {
    sessions: ['s1'], quizResults: ['q9'], registrations: {},
  });
});

test('newer mutable session and quiz records win by updatedAt', () => {
  const merged = mergeSnapshots(
    {
      sessions: [session('s1', 10, 100)],
      quizResults: [quiz('q1', 1, 200)],
    },
    {
      sessions: [session('s1', 20, 101)],
      quizResults: [quiz('q1', 2, 199)],
    },
  );

  assert.equal(merged.sessions[0].minutes, 20);
  assert.equal(merged.quizResults[0].correct, 1);
});

test('progress items drop question content and answer fields before storage', () => {
  const merged = mergeSnapshots({}, {
    items: {
      q1: {
        wrong: 1,
        updatedAt: 20,
        question: '시험 원문',
        answer: 4,
        explanation: '정답 해설',
      },
    },
  });

  assert.deepEqual(merged.items.q1, { wrong: 1, updatedAt: 20 });
});

test('safe study collections validate and strip content fields', () => {
  const merged = mergeSnapshots({}, {
    flashcards: [{
      id: 'card-q1', box: 2, seen: 4, known: 3,
      nextDue: stamp, updatedAt: 20,
      question: '문제 원문', answer: '정답', explanation: '해설',
    }],
    scores: [{
      id: '2026-10-29', scoreMilli: 70125, attempts: 40, updatedAt: 21,
      question: '문제 원문', memo: '개인 메모',
    }],
    slides: {
      seen_1: 3,
      seen_summary_2: 4,
      lastDay: 2,
      lastDayUpdatedAt: 22,
      level: 'fast',
      levelUpdatedAt: 23,
      question: '문제 원문',
      memo: '개인 메모',
    },
    registrations: [
      {
        id: '1234__2026_1__written', jmCd: '1234', catalogId: 'electrician',
        certName: '전기기사', roundLabel: '2026년 1회', phase: 'written',
        status: 'taken', scoredTotal: 100, scoredCorrect: 70,
        subjectFails: 0, scoredAt: stamp, updatedAt: 24,
        question: '문제 원문', answer: '정답',
      },
      {
        id: 'reg-planned', jmCd: '1234', catalogId: 'electrician',
        certName: '전기기사', roundLabel: '2026년 2회', phase: 'written',
        status: 'planned', scoredTotal: null, scoredCorrect: null,
        subjectFails: null, scoredAt: null, updatedAt: 25,
      },
    ],
  });

  assert.deepEqual(merged.flashcards, [{
    id: 'card-q1', box: 2, seen: 4, known: 3,
    nextDue: stamp, updatedAt: 20,
  }]);
  assert.deepEqual(merged.scores, [{
    id: '2026-10-29', scoreMilli: 70125, attempts: 40, updatedAt: 21,
  }]);
  assert.deepEqual(merged.slides, {
    seen_1: 3,
    seen_summary_2: 4,
    lastDay: 2,
    lastDayUpdatedAt: 22,
    level: 'fast',
    levelUpdatedAt: 23,
  });
  assert.deepEqual(merged.registrations, [{
    id: '1234__2026_1__written', jmCd: '1234', catalogId: 'electrician',
    certName: '전기기사', roundLabel: '2026년 1회', phase: 'written',
    status: 'taken', scoredTotal: 100, scoredCorrect: 70,
    subjectFails: 0, scoredAt: stamp, updatedAt: 24,
  }, {
    id: 'reg-planned', jmCd: '1234', catalogId: 'electrician',
    certName: '전기기사', roundLabel: '2026년 2회', phase: 'written',
    status: 'planned', updatedAt: 25,
  }]);
  assert.equal(JSON.stringify(merged).includes('문제 원문'), false);
  assert.equal(JSON.stringify(merged).includes('개인 메모'), false);
});

test('safe study collections reject invalid counters, scores, levels, and result ratios', () => {
  assert.throws(() => mergeSnapshots({}, {
    flashcards: [{ id: 'card-q1', box: 6, seen: 1, known: 1, updatedAt: 1 }],
  }), (error) => error.code === 'bad_progress');
  assert.throws(() => mergeSnapshots({}, {
    flashcards: [{ id: 'card-q1', box: 1, seen: 1, known: 2, updatedAt: 1 }],
  }), (error) => error.code === 'bad_progress');
  assert.throws(() => mergeSnapshots({}, {
    scores: [{ id: '2026-10-29', scoreMilli: 100001, attempts: 1, updatedAt: 1 }],
  }), (error) => error.code === 'bad_progress');
  assert.throws(() => mergeSnapshots({}, {
    slides: { level: 'admin' },
  }), (error) => error.code === 'bad_progress');
  assert.throws(() => mergeSnapshots({}, {
    registrations: [{
      id: 'reg-1', jmCd: '1234', catalogId: 'electrician', certName: '전기기사',
      roundLabel: '1회', phase: 'written', status: 'passed',
      scoredTotal: 10, scoredCorrect: 11, updatedAt: 1,
    }],
  }), (error) => error.code === 'bad_progress');
});

test('safe study merge is monotone for slides and tombstones registrations', () => {
  const merged = mergeSnapshots(
    {
      slides: { seen_1: 8, seen_2: 1, lastDay: 1, lastDayUpdatedAt: 200, level: 'standard', levelUpdatedAt: 200 },
      registrations: [{
        id: 'reg-deleted', jmCd: '1234', catalogId: 'electrician', certName: '전기기사',
        roundLabel: '1회', phase: 'written', status: 'planned', updatedAt: 100,
      }],
      deleted: { registrations: ['reg-deleted'] },
    },
    {
      slides: { seen_1: 4, seen_2: 5, lastDay: 3, lastDayUpdatedAt: 201, level: 'fast', levelUpdatedAt: 199 },
      registrations: [
        {
          id: 'reg-deleted', jmCd: '1234', catalogId: 'electrician', certName: '전기기사',
          roundLabel: '1회', phase: 'written', status: 'passed', updatedAt: 999,
        },
        {
          id: 'reg-remote', jmCd: '1234', catalogId: 'electrician', certName: '전기기사',
          roundLabel: '2회', phase: 'practical', status: 'planned', updatedAt: 201,
        },
      ],
    },
  );

  assert.deepEqual(merged.slides, {
    seen_1: 8, seen_2: 5,
    lastDay: 3, lastDayUpdatedAt: 201,
    level: 'standard', levelUpdatedAt: 200,
  });
  assert.deepEqual(merged.registrations.map((item) => item.id), ['reg-remote']);
  assert.ok(merged.deleted.registrations['reg-deleted'] > 0);
});

test('registration can be re-added only with an update newer than its delete', () => {
  const stale = mergeSnapshots(
    {
      registrations: [{
        id: 'reg-1', jmCd: '1234', catalogId: 'electrician', certName: '전기기사',
        roundLabel: '1회', phase: 'written', status: 'planned', updatedAt: 100,
      }],
      deleted: { registrations: { 'reg-1': 200 } },
    },
    {
      registrations: [{
        id: 'reg-1', jmCd: '1234', catalogId: 'electrician', certName: '전기기사',
        roundLabel: '1회', phase: 'written', status: 'taken', updatedAt: 199,
      }],
    },
  );
  assert.deepEqual(stale.registrations, []);
  assert.deepEqual(stale.deleted.registrations, { 'reg-1': 200 });

  const restored = mergeSnapshots(
    { deleted: { registrations: { 'reg-1': 200 } } },
    {
      registrations: [{
        id: 'reg-1', jmCd: '1234', catalogId: 'electrician', certName: '전기기사',
        roundLabel: '1회', phase: 'written', status: 'planned', updatedAt: 201,
      }],
    },
  );
  assert.deepEqual(restored.registrations.map((record) => record.id), ['reg-1']);
  assert.deepEqual(restored.deleted.registrations, {});
});

test('safe record timestamp ties resolve identically regardless of merge order', () => {
  const server = {
    flashcards: [{ id: 'card-q1', box: 1, seen: 2, known: 1, updatedAt: 50 }],
    scores: [{ id: '2026-10-29', scoreMilli: 60000, attempts: 20, updatedAt: 50 }],
    registrations: [{
      id: 'reg-1', jmCd: '1234', catalogId: 'electrician', certName: '전기기사',
      roundLabel: '1회', phase: 'written', status: 'planned', updatedAt: 50,
    }],
  };
  const client = {
    flashcards: [{ id: 'card-q1', box: 3, seen: 4, known: 2, updatedAt: 50 }],
    scores: [{ id: '2026-10-29', scoreMilli: 70000, attempts: 30, updatedAt: 50 }],
    registrations: [{
      id: 'reg-1', jmCd: '1234', catalogId: 'electrician', certName: '전기기사',
      roundLabel: '1회', phase: 'written', status: 'passed', updatedAt: 50,
    }],
  };

  const forward = mergeSnapshots(server, client);
  const reverse = mergeSnapshots(client, server);
  for (const collection of ['flashcards', 'scores', 'registrations']) {
    assert.deepEqual(forward[collection], reverse[collection]);
  }
});

test('invalid item counts and payloads over 5 MiB are rejected', async () => {
  assert.throws(
    () => mergeSnapshots({}, { items: { q1: { wrong: -1 } } }),
    (error) => error.code === 'bad_progress' && error.status === 400,
  );
  await assert.rejects(
    () => putProgress({ DB: fakeDb() }, 'alice', {
      items: { q1: { subject: 'x'.repeat(5 * 1024 * 1024 + 1) } },
    }),
    (error) => error.code === 'progress_too_large' && error.status === 413,
  );
});

test('concurrent D1 writes retry after CAS conflict and keep both question updates', async () => {
  const rows = new Map();
  let initialReads = 0;
  let releaseInitialReads;
  const initialReadsReady = new Promise((resolve) => { releaseInitialReads = resolve; });
  const db = {
    rows,
    prepare(sql) {
      let values = [];
      const statement = {
        bind(...args) { values = args; return statement; },
        async first() {
          if (!sql.includes('SELECT snapshot, updated_at')) throw new Error('unexpected read');
          const [userId] = values;
          if (!rows.has(userId) && initialReads < 2) {
            const observed = rows.get(userId) || null;
            initialReads++;
            if (initialReads === 2) releaseInitialReads();
            await initialReadsReady;
            return observed;
          }
          return rows.get(userId) || null;
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

  const [writeA, writeB] = await Promise.all([
    putProgress({ DB: db }, 'alice', { items: { qA: { updatedAt: 10 } } }),
    putProgress({ DB: db }, 'alice', { items: { qB: { updatedAt: 20 } } }),
  ]);

  assert.equal(initialReads, 2);
  assert.deepEqual(Object.keys(writeA.snapshot.items).sort(), ['qA']);
  assert.deepEqual(Object.keys(writeB.snapshot.items).sort(), ['qA', 'qB']);
  const saved = await getProgress({ DB: db }, 'alice');
  assert.deepEqual(Object.keys(saved.snapshot.items).sort(), ['qA', 'qB']);
});
