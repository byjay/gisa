// User-owned learning progress. The caller must pass the userId from a verified
// session; the client never chooses the D1 owner key.
export const MAX_SNAPSHOT_BYTES = 5 * 1024 * 1024;
const MAX_ITEMS = 30_000;
const MAX_RECORDS = 20_000;
const ITEM_FIELDS = new Set([
  'wrong', 'correct', 'last', 'bookmarked', 'subject', 'topic', 'reps',
  'streak', 'box', 'nextDue', 'updatedAt', 'reasons', 'lastReason',
]);
const STUDY_LEVELS = new Set(['baby', 'standard', 'fast']);

export async function getProgress(env, userId) {
  const row = await env.DB.prepare(
    'SELECT snapshot, updated_at FROM user_progress WHERE user_id = ?'
  )
    .bind(userId)
    .first();
  if (!row) return { snapshot: emptySnapshot(), updatedAt: 0 };
  let snapshot;
  try {
    snapshot = normalizeSnapshot(JSON.parse(row.snapshot || '{}'));
  } catch (_) {
    snapshot = emptySnapshot();
  }
  return { snapshot, updatedAt: Number(row.updated_at) || 0 };
}

/**
 * Compare-and-swap D1 writes prevent concurrent clients from replacing a
 * snapshot based on the same stale version. A retry re-reads and merges.
 */
export async function putProgress(env, userId, incoming) {
  const client = normalizeSnapshot(incoming);
  const clientBytes = new TextEncoder().encode(JSON.stringify(client)).byteLength;
  if (clientBytes > MAX_SNAPSHOT_BYTES) {
    throw Object.assign(new Error('진도 데이터가 허용 크기를 초과했습니다.'), {
      status: 413,
      code: 'progress_too_large',
    });
  }

  for (let attempt = 0; attempt < 5; attempt++) {
    const current = await getProgress(env, userId);
    const merged = mergeSnapshots(current.snapshot, client);
    const body = JSON.stringify(merged);
    const updatedAt = Math.max(Date.now(), current.updatedAt + 1);
    const result = await env.DB.prepare(
      `INSERT INTO user_progress (user_id, snapshot, updated_at)
       VALUES (?, ?, ?)
       ON CONFLICT(user_id) DO UPDATE
         SET snapshot = excluded.snapshot, updated_at = excluded.updated_at
         WHERE user_progress.updated_at = ?`
    )
      .bind(userId, body, updatedAt, current.updatedAt)
      .run();

    if (result?.success === false) throw new Error('진도 데이터를 저장하지 못했습니다.');
    if ((result?.meta?.changes ?? 0) > 0) {
      return { ok: true, snapshot: merged, updatedAt };
    }
  }

  throw Object.assign(new Error('진도 동기화 중 변경 충돌이 반복되었습니다.'), {
    status: 503,
    code: 'progress_conflict',
  });
}

export function mergeSnapshots(serverInput, clientInput) {
  const server = normalizeSnapshot(serverInput);
  const client = normalizeSnapshot(clientInput);
  const deleted = {
    sessions: new Set([...server.deleted.sessions, ...client.deleted.sessions]),
    quizResults: new Set([...server.deleted.quizResults, ...client.deleted.quizResults]),
    registrations: mergeTombstones(server.deleted.registrations, client.deleted.registrations),
  };

  const items = {};
  const qids = new Set([...Object.keys(server.items), ...Object.keys(client.items)]);
  for (const qid of qids) {
    const s = server.items[qid];
    const c = client.items[qid];
    items[qid] = !s ? c : !c ? s : timestamp(c.updatedAt) > timestamp(s.updatedAt) ? c : s;
  }

  const slides = mergeSlides(server.slides, client.slides);
  const registrations = mergeRegistrations(
    server.registrations,
    client.registrations,
    deleted.registrations,
  );
  return {
    items,
    sessions: mergeRecords(server.sessions, client.sessions, deleted.sessions),
    quizResults: mergeRecords(server.quizResults, client.quizResults, deleted.quizResults),
    flashcards: mergeRecords(server.flashcards, client.flashcards, new Set()),
    scores: mergeRecords(server.scores, client.scores, new Set()),
    slides,
    registrations,
    deleted: {
      sessions: [...deleted.sessions].sort(),
      quizResults: [...deleted.quizResults].sort(),
      registrations: Object.fromEntries([...deleted.registrations.entries()].sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0)),
    },
  };
}

function emptySnapshot() {
  return {
    items: {}, sessions: [], quizResults: [], flashcards: [], scores: [],
    slides: {}, registrations: [],
    deleted: { sessions: [], quizResults: [], registrations: [] },
  };
}

function normalizeSnapshot(input) {
  if (!isRecord(input)) throw badProgressInput();
  const serialized = JSON.stringify(input);
  if (serialized === undefined || new TextEncoder().encode(serialized).byteLength > MAX_SNAPSHOT_BYTES) {
    throw Object.assign(new Error('진도 데이터가 허용 크기를 초과했습니다.'), {
      status: 413,
      code: 'progress_too_large',
    });
  }

  const sourceItems = input.items === undefined ? {} : input.items;
  if (!isRecord(sourceItems) || Object.keys(sourceItems).length > MAX_ITEMS) throw badProgressInput();
  const items = {};
  for (const [qid, value] of Object.entries(sourceItems)) {
    if (!isSafeId(qid) || !isRecord(value)) throw badProgressInput();
    const item = {};
    for (const [key, field] of Object.entries(value)) {
      if (!ITEM_FIELDS.has(key)) continue;
      if (!isValidItemField(key, field)) throw badProgressInput();
      item[key] = field;
    }
    if (item.updatedAt === undefined) item.updatedAt = 0;
    items[qid] = item;
  }

  const sessions = normalizeRecords(input.sessions, 'session');
  const quizResults = normalizeRecords(input.quizResults, 'quiz');
  const flashcards = normalizeRecords(input.flashcards, 'flashcard');
  const scores = normalizeRecords(input.scores, 'score');
  const registrations = normalizeRecords(input.registrations, 'registration');
  const slides = normalizeSlides(input.slides);
  const deleted = normalizeDeleted(input.deleted, registrations);
  return { items, sessions, quizResults, flashcards, scores, slides, registrations, deleted };
}

function normalizeRecords(value, kind) {
  if (value === undefined) return [];
  if (!Array.isArray(value) || value.length > MAX_RECORDS) throw badProgressInput();
  return value.map((record) => {
    if (!isRecord(record) || !isSafeId(record.id)) throw badProgressInput();
    if (kind === 'session') {
      if (!isOptionalId(record.examId ?? '') || !isDate(record.date) || !isCount(record.minutes)) {
        throw badProgressInput();
      }
      return {
        id: record.id,
        examId: record.examId ?? '',
        date: record.date,
        minutes: record.minutes,
        updatedAt: normalizeTimestamp(record.updatedAt ?? record.date),
      };
    }
    if (kind === 'quiz') {
      if (
      typeof record.title !== 'string' || record.title.length > 160 ||
      !isCount(record.total) || !isCount(record.correct) || record.correct > record.total ||
      !isDate(record.date)
      ) throw badProgressInput();
      return {
        id: record.id,
        title: record.title,
        total: record.total,
        correct: record.correct,
        date: record.date,
        updatedAt: normalizeTimestamp(record.updatedAt ?? record.date),
        subjectTotal: normalizeCountMap(record.subjectTotal),
        subjectCorrect: normalizeCountMap(record.subjectCorrect),
      };
    }
    if (kind === 'flashcard') {
      if (
        !Number.isSafeInteger(record.box) || record.box < 0 || record.box > 5 ||
        !isCount(record.seen) || !isCount(record.known) || record.known > record.seen ||
        (record.nextDue !== undefined && !isDate(record.nextDue))
      ) throw badProgressInput();
      return {
        id: record.id,
        box: record.box,
        seen: record.seen,
        known: record.known,
        ...(record.nextDue === undefined ? {} : { nextDue: record.nextDue }),
        updatedAt: normalizeTimestamp(record.updatedAt ?? 0),
      };
    }
    if (kind === 'score') {
      if (
        !/^\d{4}-\d{2}-\d{2}$/.test(record.id) ||
        !Number.isSafeInteger(record.scoreMilli) || record.scoreMilli < 0 || record.scoreMilli > 100_000 ||
        !isCount(record.attempts)
      ) throw badProgressInput();
      return {
        id: record.id,
        scoreMilli: record.scoreMilli,
        attempts: record.attempts,
        updatedAt: normalizeTimestamp(record.updatedAt ?? record.id),
      };
    }
    if (kind === 'registration') {
      const scoredTotal = record.scoredTotal ?? undefined;
      const scoredCorrect = record.scoredCorrect ?? undefined;
      const subjectFails = record.subjectFails ?? undefined;
      const scoredAt = record.scoredAt ?? undefined;
      const textFields = ['jmCd', 'catalogId', 'certName', 'roundLabel'];
      if (
        textFields.some((field) => typeof record[field] !== 'string' || record[field].length > 160) ||
        !['written', 'practical'].includes(record.phase) ||
        !['planned', 'registered', 'taken', 'passed', 'failed'].includes(record.status) ||
        (scoredTotal !== undefined && !isCount(scoredTotal)) ||
        (scoredCorrect !== undefined && !isCount(scoredCorrect)) ||
        ((scoredTotal === undefined) !== (scoredCorrect === undefined)) ||
        (scoredTotal !== undefined && scoredCorrect > scoredTotal) ||
        (subjectFails !== undefined && !isCount(subjectFails)) ||
        (scoredAt !== undefined && !isDate(scoredAt))
      ) throw badProgressInput();
      return {
        id: record.id,
        jmCd: record.jmCd,
        catalogId: record.catalogId,
        certName: record.certName,
        roundLabel: record.roundLabel,
        phase: record.phase,
        status: record.status,
        ...(scoredTotal === undefined ? {} : {
          scoredTotal,
          scoredCorrect,
        }),
        ...(subjectFails === undefined ? {} : { subjectFails }),
        ...(scoredAt === undefined ? {} : { scoredAt }),
        updatedAt: normalizeTimestamp(record.updatedAt ?? scoredAt ?? 0),
      };
    }
    throw badProgressInput();
  });
}

function normalizeDeleted(value, registrations) {
  if (value === undefined) return { sessions: [], quizResults: [], registrations: {} };
  if (!isRecord(value)) throw badProgressInput();
  return {
    sessions: normalizeIdList(value.sessions),
    quizResults: normalizeIdList(value.quizResults),
    registrations: normalizeRegistrationTombstones(value.registrations, registrations),
  };
}

function normalizeRegistrationTombstones(value, registrations) {
  if (value === undefined) return {};
  let entries;
  if (Array.isArray(value)) {
    if (value.length > MAX_RECORDS || !value.every(isSafeId)) throw badProgressInput();
    entries = value.map((id) => {
      const matchingAt = registrations
        .filter((record) => record.id === id)
        .reduce((latest, record) => Math.max(latest, timestamp(record.updatedAt)), 0);
      return [id, Math.max(Date.now(), matchingAt)];
    });
  } else if (isRecord(value)) {
    if (Object.keys(value).length > MAX_RECORDS) throw badProgressInput();
    entries = Object.entries(value);
  } else {
    throw badProgressInput();
  }
  const tombstones = {};
  for (const [id, deletedAt] of entries) {
    if (!isSafeId(id) || !isTimestamp(deletedAt)) throw badProgressInput();
    tombstones[id] = normalizeTimestamp(deletedAt);
  }
  return Object.fromEntries(Object.entries(tombstones).sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0));
}

function normalizeSlides(value) {
  if (value === undefined) return {};
  if (!isRecord(value) || Object.keys(value).length > MAX_ITEMS) throw badProgressInput();
  const slides = {};
  for (const [key, item] of Object.entries(value)) {
    if (/^seen_[a-zA-Z0-9_-]*\d+$/.test(key) && key.length <= 200) {
      if (!isCount(item)) throw badProgressInput();
      slides[key] = item;
    } else if (key === 'lastDay' || key === 'lastDayUpdatedAt' || key === 'levelUpdatedAt') {
      if (key.endsWith('UpdatedAt') ? !isTimestamp(item) : !isCount(item)) throw badProgressInput();
      slides[key] = key.endsWith('UpdatedAt') ? normalizeTimestamp(item) : item;
    } else if (key === 'level') {
      if (!STUDY_LEVELS.has(item)) throw badProgressInput();
      slides.level = item;
    }
  }
  if (slides.lastDay === undefined) delete slides.lastDayUpdatedAt;
  if (slides.level === undefined) delete slides.levelUpdatedAt;
  return slides;
}

function mergeSlides(server, client) {
  const merged = {};
  const countKeys = new Set([
    ...Object.keys(server).filter((key) => key.startsWith('seen_')),
    ...Object.keys(client).filter((key) => key.startsWith('seen_')),
  ]);
  for (const key of countKeys) merged[key] = Math.max(server[key] ?? 0, client[key] ?? 0);

  if (server.lastDay !== undefined || client.lastDay !== undefined) {
    const serverAt = server.lastDayUpdatedAt ?? 0;
    const clientAt = client.lastDayUpdatedAt ?? 0;
    const useClient = clientAt > serverAt || (clientAt === serverAt && (client.lastDay ?? -1) > (server.lastDay ?? -1));
    merged.lastDay = useClient ? client.lastDay : server.lastDay;
    merged.lastDayUpdatedAt = useClient ? clientAt : serverAt;
  }
  if (server.level !== undefined || client.level !== undefined) {
    const serverAt = server.levelUpdatedAt ?? 0;
    const clientAt = client.levelUpdatedAt ?? 0;
    const useClient = clientAt > serverAt || (clientAt === serverAt && (client.level ?? '') > (server.level ?? ''));
    merged.level = useClient ? client.level : server.level;
    merged.levelUpdatedAt = useClient ? clientAt : serverAt;
  }
  return merged;
}

function normalizeIdList(value) {
  if (value === undefined) return [];
  if (!Array.isArray(value) || value.length > MAX_RECORDS || !value.every(isSafeId)) {
    throw badProgressInput();
  }
  return [...new Set(value)].sort();
}

function normalizeCountMap(value) {
  if (value === undefined) return {};
  if (!isRecord(value) || Object.keys(value).length > 40) throw badProgressInput();
  const out = {};
  for (const [key, count] of Object.entries(value)) {
    if (key.length > 120 || !isCount(count)) throw badProgressInput();
    out[key] = count;
  }
  return out;
}

function mergeRecords(server, client, deleted) {
  const records = new Map();
  for (const record of server) records.set(record.id, record);
  for (const record of client) {
    if (deleted.has(record.id)) continue;
    const previous = records.get(record.id);
    const recordAt = timestamp(record.updatedAt);
    const previousAt = previous ? timestamp(previous.updatedAt) : -1;
    if (
      !previous || recordAt > previousAt ||
      (recordAt === previousAt && canonicalJson(record) > canonicalJson(previous))
    ) {
      records.set(record.id, record);
    }
  }
  for (const id of deleted) records.delete(id);
  return [...records.values()];
}

function mergeTombstones(server, client) {
  const merged = { ...server };
  for (const [id, deletedAt] of Object.entries(client)) {
    merged[id] = Math.max(merged[id] ?? -1, deletedAt);
  }
  return new Map(Object.entries(merged));
}

function mergeRegistrations(server, client, deleted) {
  const records = new Map();
  for (const record of [...server, ...client]) {
    const previous = records.get(record.id);
    const recordAt = timestamp(record.updatedAt);
    const previousAt = previous ? timestamp(previous.updatedAt) : -1;
    if (
      !previous || recordAt > previousAt ||
      (recordAt === previousAt && canonicalJson(record) > canonicalJson(previous))
    ) {
      records.set(record.id, record);
    }
  }
  for (const [id, deletedAt] of deleted) {
    const record = records.get(id);
    if (record && timestamp(record.updatedAt) > deletedAt) {
      deleted.delete(id);
    } else {
      records.delete(id);
    }
  }
  return [...records.values()].sort((a, b) => a.id < b.id ? -1 : a.id > b.id ? 1 : 0);
}

function canonicalJson(value) {
  if (Array.isArray(value)) return `[${value.map(canonicalJson).join(',')}]`;
  if (isRecord(value)) {
    const fields = Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${canonicalJson(value[key])}`);
    return `{${fields.join(',')}}`;
  }
  return JSON.stringify(value);
}

function isValidItemField(key, value) {
  if (['wrong', 'correct', 'reps', 'streak', 'box'].includes(key)) return isCount(value);
  if (key === 'last') return value === '' || value === 'o' || value === 'x';
  if (key === 'bookmarked') return typeof value === 'boolean';
  if (['subject', 'topic'].includes(key)) return typeof value === 'string' && value.length <= 120;
  if (['nextDue', 'lastReason'].includes(key)) return typeof value === 'string' && value.length <= 120;
  if (key === 'updatedAt') return isTimestamp(value);
  if (key === 'reasons') return normalizeCountMap(value) !== null;
  return false;
}

function isRecord(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function isSafeId(value) {
  return typeof value === 'string' && value.length > 0 && value.length <= 200 &&
    !['__proto__', 'constructor', 'prototype'].includes(value);
}

function isOptionalId(value) {
  return typeof value === 'string' && value.length <= 200 &&
    !['__proto__', 'constructor', 'prototype'].includes(value);
}

function isCount(value) {
  return Number.isSafeInteger(value) && value >= 0 && value <= 1_000_000_000;
}

function isDate(value) {
  return typeof value === 'string' && value.length <= 64 && Number.isFinite(Date.parse(value));
}

function isTimestamp(value) {
  return Number.isSafeInteger(value) && value >= 0 ||
    typeof value === 'string' && value.length <= 64 && Number.isFinite(Date.parse(value));
}

function normalizeTimestamp(value) {
  if (Number.isSafeInteger(value) && value >= 0) return value;
  const parsed = Date.parse(value);
  if (!Number.isFinite(parsed)) throw badProgressInput();
  return parsed;
}

function timestamp(value) {
  return typeof value === 'number' ? value : typeof value === 'string' ? Date.parse(value) || 0 : 0;
}

function badProgressInput() {
  return Object.assign(new Error('진도 데이터 형식이 올바르지 않습니다.'), {
    status: 400,
    code: 'bad_progress',
  });
}
