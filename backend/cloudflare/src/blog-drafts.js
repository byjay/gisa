// 하루 최대 세 개의 비공개 이론 글 초안을 생성·검토한다. 공개 게시 경로는 없다.
import { getTrackCatalog } from './content.js';

export const DAILY_DRAFT_LIMIT = 3;
const CLAIM_STALE_MS = 15 * 60 * 1000;
const MAX_TITLE = 100;
const MAX_EXCERPT = 240;
const MAX_BODY = 8_000;
const MAX_NOTES = 1_200;
const STATUSES = new Set(['generating', 'review', 'approved', 'rejected', 'failed']);

function httpError(code, status, message) {
  const error = new Error(message || code);
  error.code = code;
  error.status = status;
  return error;
}

function requireEnabled(env) {
  if (env.BLOG_DRAFTS_ENABLED !== 'true') {
    throw httpError('blog_drafts_disabled', 503, '이론 글 초안 자동화가 비활성화되어 있습니다.');
  }
  if (!env.DB || !env.CONTENT) {
    throw httpError('blog_drafts_unavailable', 503, '초안 저장소를 사용할 수 없습니다.');
  }
}

function kstDate(scheduledTime) {
  if (!Number.isFinite(scheduledTime)) throw httpError('bad_schedule_time', 400);
  return new Date(scheduledTime + 9 * 60 * 60 * 1000).toISOString().slice(0, 10);
}

function listTopics(catalog) {
  if (catalog?.schemaVersion !== 1 || !Array.isArray(catalog.tracks)) {
    throw httpError('invalid_track_catalog', 503);
  }
  const result = [];
  for (const track of catalog.tracks) {
    if (typeof track?.id !== 'string' || !track.id.trim()
      || typeof track?.name !== 'string' || !track.name.trim()
      || !Array.isArray(track.subjects)) continue;
    const seen = new Set();
    for (const rawSubject of track.subjects) {
      if (typeof rawSubject !== 'string') continue;
      const subject = rawSubject.trim();
      if (!subject || seen.has(subject)) continue;
      seen.add(subject);
      result.push({ trackId: track.id, certificate: track.name.trim(), subject });
    }
  }
  if (result.length < DAILY_DRAFT_LIMIT) {
    throw httpError('insufficient_topics', 503, '서로 다른 초안을 만들 자격증 과목이 세 개보다 적습니다.');
  }
  return result;
}

export function selectDailyTopics(catalog, day) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(day) || !Number.isFinite(Date.parse(`${day}T00:00:00.000Z`))) {
    throw httpError('bad_draft_date', 400);
  }
  const topics = listTopics(catalog);
  const dayNumber = Math.floor(Date.parse(`${day}T00:00:00.000Z`) / 86_400_000);
  const start = (dayNumber * DAILY_DRAFT_LIMIT) % topics.length;
  return Array.from({ length: DAILY_DRAFT_LIMIT }, (_, slot) => topics[(start + slot) % topics.length]);
}

function parseDraft(content) {
  if (typeof content !== 'string') throw httpError('invalid_ai_output', 502);
  let parsed;
  try {
    parsed = JSON.parse(content);
  } catch (_) {
    throw httpError('invalid_ai_output', 502);
  }
  const fields = {
    title: [parsed.title, 10, MAX_TITLE],
    excerpt: [parsed.excerpt, 30, MAX_EXCERPT],
    bodyMarkdown: [parsed.bodyMarkdown, 200, MAX_BODY],
    editorialNotes: [parsed.editorialNotes, 10, MAX_NOTES],
  };
  const output = {};
  for (const [name, [value, min, max]] of Object.entries(fields)) {
    if (typeof value !== 'string' || value.trim().length < min || value.trim().length > max) {
      throw httpError('invalid_ai_output', 502);
    }
    if (/<\/?(?:script|iframe|object|embed|form)\b/i.test(value)) {
      throw httpError('invalid_ai_output', 502);
    }
    output[name] = value.trim();
  }
  return output;
}

function buildPrompt(topic) {
  return [
    `자격증: ${topic.certificate}`,
    `과목: ${topic.subject}`,
    '이 두 항목만을 주제로 독립적인 한국어 이론 학습 글 초안을 작성하세요.',
    '문제은행, 정답, 해설, 교재 문장, 법령 조문 원문은 제공되지 않았으므로 만들어 인용하지 마세요.',
    '개념을 정확히 설명하고, 직접 만든 예시와 복습 순서를 포함하세요. 공식 출제 기준·수치·법령은 사람의 확인이 필요하다고 표시하세요.',
    '검색 키워드만 바꾼 반복 글을 만들지 말고, 독자가 실제로 이해할 수 있게 설명하세요.',
    'JSON만 반환하세요. 스키마: {"title":"10~100자","excerpt":"30~240자","bodyMarkdown":"200~8000자 Markdown","editorialNotes":"10~1200자 검토 메모"}',
  ].join('\n');
}

async function generateDraft(env, topic) {
  if (!env.AI_ENDPOINT || !env.CEREBRAS_API_KEY || !env.AI_MODEL) {
    throw httpError('ai_unavailable', 503, '초안 생성 모델 설정이 없습니다.');
  }
  const request = env.fetch || fetch;
  let response;
  try {
    response = await request(env.AI_ENDPOINT, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${env.CEREBRAS_API_KEY}`,
      },
      body: JSON.stringify({
        model: env.AI_MODEL,
        messages: [
          { role: 'system', content: '자격증 학습용 이론 초안 작성기입니다. 사실과 불확실성을 구분하고, 정확한 JSON만 반환하세요.' },
          { role: 'user', content: buildPrompt(topic) },
        ],
        max_tokens: 1600,
        temperature: 0.45,
      }),
    });
  } catch (_) {
    throw httpError('ai_unavailable', 502, '초안 생성 모델에 연결하지 못했습니다.');
  }
  if (!response.ok) throw httpError('ai_unavailable', 502, `초안 생성 모델 요청 실패(${response.status}).`);
  let payload;
  try {
    payload = await response.json();
  } catch (_) {
    throw httpError('invalid_ai_output', 502);
  }
  return parseDraft(payload?.choices?.[0]?.message?.content);
}

async function claimSlot(env, day, slot, topic, now) {
  const id = crypto.randomUUID();
  const token = crypto.randomUUID();
  const timestamp = new Date(now).toISOString();
  const inserted = await env.DB.prepare(
    `INSERT OR IGNORE INTO blog_drafts
       (id, slot_date, slot, track_id, certificate, subject, status, generation_token, attempt, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, 'generating', ?, 1, ?, ?)`
  ).bind(id, day, slot, topic.trackId, topic.certificate, topic.subject, token, timestamp, timestamp).run();
  if (Number(inserted?.meta?.changes || 0) === 1) return { id, token };

  const staleBefore = new Date(now - CLAIM_STALE_MS).toISOString();
  const reclaimed = await env.DB.prepare(
    `UPDATE blog_drafts
        SET generation_token = ?, attempt = attempt + 1, last_error = NULL, updated_at = ?
      WHERE slot_date = ? AND slot = ? AND status = 'generating' AND updated_at <= ?`
  ).bind(token, timestamp, day, slot, staleBefore).run();
  if (Number(reclaimed?.meta?.changes || 0) !== 1) return null;
  const row = await env.DB.prepare(
    'SELECT id FROM blog_drafts WHERE slot_date = ? AND slot = ?'
  ).bind(day, slot).first();
  return row ? { id: row.id, token } : null;
}

async function failClaim(env, id, token, errorCode, now) {
  await env.DB.prepare(
    `UPDATE blog_drafts SET status = ?, last_error = ?, updated_at = ?
      WHERE id = ? AND status = 'generating' AND generation_token = ?`
  ).bind('failed', errorCode, new Date(now).toISOString(), id, token).run();
}

async function finishClaim(env, id, token, draft, now) {
  const result = await env.DB.prepare(
    `UPDATE blog_drafts
        SET status = ?, title = ?, excerpt = ?, body_markdown = ?, editorial_notes = ?,
            last_error = NULL, updated_at = ?
      WHERE id = ? AND status = 'generating' AND generation_token = ?`
  ).bind('review', draft.title, draft.excerpt, draft.bodyMarkdown, draft.editorialNotes, new Date(now).toISOString(), id, token).run();
  return Number(result?.meta?.changes || 0) === 1;
}

async function createSlot(env, day, slot, topic, now) {
  const claim = await claimSlot(env, day, slot, topic, now);
  if (!claim) return 'skipped';
  try {
    const draft = await generateDraft(env, topic);
    return await finishClaim(env, claim.id, claim.token, draft, Date.now()) ? 'created' : 'stale';
  } catch (error) {
    const safeCode = typeof error?.code === 'string' ? error.code : 'generation_failed';
    await failClaim(env, claim.id, claim.token, safeCode, Date.now());
    return 'failed';
  }
}

export async function generateDailyDrafts(env, scheduledTime) {
  requireEnabled(env);
  const day = kstDate(scheduledTime);
  const topics = selectDailyTopics(await getTrackCatalog(env), day);
  const now = Date.now();
  const settled = await Promise.allSettled(topics.map((topic, slot) => createSlot(env, day, slot, topic, now)));
  const results = settled.map((result) => result.status === 'fulfilled' ? result.value : 'failed');
  const failed = results.filter((result) => result === 'failed').length;
  const summary = {
    day,
    created: results.filter((result) => result === 'created').length,
    failed,
    skipped: results.filter((result) => result === 'skipped' || result === 'stale').length,
  };
  if (failed) throw httpError('draft_generation_failed', 503, `초안 ${failed}개 생성에 실패했습니다.`);
  return summary;
}

export async function listBlogDrafts(env, { status = '', limit = 50 } = {}) {
  requireEnabled(env);
  if (status && !STATUSES.has(status)) throw httpError('bad_draft_status', 400);
  const safeLimit = Number.isInteger(limit) ? Math.max(1, Math.min(limit, 100)) : 50;
  const query = status
    ? `SELECT id, slot_date, slot, track_id, certificate, subject, status, title, excerpt,
              body_markdown AS bodyMarkdown, editorial_notes AS editorialNotes, last_error AS lastError,
              created_at AS createdAt, updated_at AS updatedAt
         FROM blog_drafts WHERE status = ? ORDER BY created_at DESC LIMIT ?`
    : `SELECT id, slot_date, slot, track_id, certificate, subject, status, title, excerpt,
              body_markdown AS bodyMarkdown, editorial_notes AS editorialNotes, last_error AS lastError,
              created_at AS createdAt, updated_at AS updatedAt
         FROM blog_drafts ORDER BY created_at DESC LIMIT ?`;
  const statement = env.DB.prepare(query);
  const result = status ? await statement.bind(status, safeLimit).all() : await statement.bind(safeLimit).all();
  return { items: result.results || [] };
}

function reviewText(value, name, min, max, fallback) {
  if (value === undefined) return fallback;
  if (typeof value !== 'string' || value.trim().length < min || value.trim().length > max) {
    throw httpError('bad_review_content', 400, `${name} 길이는 ${min}~${max}자여야 합니다.`);
  }
  if (/<\/?(?:script|iframe|object|embed|form)\b/i.test(value)) {
    throw httpError('bad_review_content', 400, 'HTML 실행 태그는 허용되지 않습니다.');
  }
  return value.trim();
}

export async function reviewBlogDraft(env, id, body) {
  requireEnabled(env);
  if (!/^[A-Za-z0-9_-]{1,80}$/.test(id)) throw httpError('bad_draft_id', 400);
  const decision = body?.decision;
  if (!['approve', 'reject'].includes(decision)) {
    throw httpError('bad_draft_decision', 400, 'decision은 approve 또는 reject만 가능합니다.');
  }
  const current = await env.DB.prepare(
    'SELECT id, status, title, excerpt, body_markdown AS bodyMarkdown FROM blog_drafts WHERE id = ?'
  ).bind(id).first();
  if (!current) throw httpError('draft_not_found', 404);
  if (current.status !== 'review') throw httpError('draft_not_reviewable', 409);
  const title = reviewText(body.title, '제목', 10, MAX_TITLE, current.title);
  const excerpt = reviewText(body.excerpt, '요약', 30, MAX_EXCERPT, current.excerpt);
  const bodyMarkdown = reviewText(body.bodyMarkdown, '본문', 200, MAX_BODY, current.bodyMarkdown);
  const status = decision === 'approve' ? 'approved' : 'rejected';
  const changed = await env.DB.prepare(
    `UPDATE blog_drafts SET status = ?, title = ?, excerpt = ?, body_markdown = ?, updated_at = ?
      WHERE id = ? AND status = 'review'`
  ).bind(status, title, excerpt, bodyMarkdown, new Date().toISOString(), id).run();
  if (Number(changed?.meta?.changes || 0) !== 1) throw httpError('draft_review_conflict', 409);
  return { id, status, title, excerpt, bodyMarkdown, published: false };
}
