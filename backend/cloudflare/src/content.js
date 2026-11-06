// 콘텐츠 조회(view-only) + 채점.
// 🔐 핵심: 정답/해설은 gradeQuiz()에서만 반환한다. 목록/본문 API는 정답을 절대 포함하지 않는다.
import { getEntitlement, allowedQuestionCount } from './entitlement.js';

function httpError(code, status, message) {
  const e = new Error(message || code);
  e.code = code;
  e.status = status;
  return e;
}

const PAGE = 20;
const TRACKS = new Set([
  'electrician', 'elec_construction', 'fire_electric', 'fire_mechanical',
  'info_processing', 'industrial_safety', 'architecture',
  'construction_safety', 'elec_industrial', 'hazmat_industrial',
]);
const STUDY_FILES = new Set([
  'study_plan.json', 'study_guide.json', 'theory_slides.json',
  'subject_summary.json', 'exam_info_2026.json', 'formula_guide.json',
  'silgi.json', 'topic_freq.json', 'solution_recipes.json',
  'mnemonics.json', 'videos.json', 'lessons.json', 'repeat_questions.json',
]);

function validTrack(track) {
  if (!TRACKS.has(track)) throw httpError('unknown_track', 404);
}

/** 종목의 회차 목록. 문항 답·해설은 포함하지 않는다. */
export async function listExams(env, track) {
  validTrack(track);
  const obj = await env.CONTENT.get(`content/${track}/_index.json`);
  if (!obj) throw httpError('content_not_ready', 503, '자격증 자료를 준비하고 있습니다.');
  return await obj.json();
}

/** 앱이 표시할 자격증 카탈로그를 R2에서 읽는다. */
export async function getTrackCatalog(env) {
  const object = await env.CONTENT.get('catalog/tracks.json');
  if (!object) throw httpError('track_catalog_unavailable', 503);
  const catalog = await object.json();
  if (catalog.schemaVersion !== 1 || !Array.isArray(catalog.tracks)) {
    throw httpError('invalid_track_catalog', 503);
  }
  return catalog;
}

/** 회차의 허용된 문제 본문만 일괄 반환한다. 정답/해설은 포함하지 않는다. */
export async function getExamPaper(env, userId, track, examId) {
  validTrack(track);
  if (!/^[A-Za-z0-9_-]{1,80}$/.test(examId)) throw httpError('bad_exam_id', 400);

  const metaRows = await env.DB.prepare(
    `SELECT qid, subject, topic, difficulty, freq_score, has_image, order_idx
     FROM questions_meta WHERE track=? AND exam_id=? ORDER BY order_idx LIMIT 121`
  ).bind(track, examId).all();
  const rows = metaRows.results || [];
  if (rows.length === 0) throw httpError('not_found', 404);
  if (rows.length > 120) throw httpError('paper_too_large', 413);

  const entitlement = await getEntitlement(env, userId);
  const premium = entitlement.tier === 'premium';
  const allowed = allowedQuestionCount(env, rows.length, premium);
  const unlockedRows = rows.slice(0, allowed);
  const paperObject = await env.CONTENT.get(`content/${track}/${examId}/paper.json`);
  if (!paperObject) throw httpError('content_incomplete', 503, '문항 자료를 준비하고 있습니다.');
  const paper = await paperObject.json();
  const bodyByQid = new Map((paper.questions || []).map((body) => [body.qid, body]));
  const items = unlockedRows.map((q) => {
    const body = bodyByQid.get(q.qid);
    if (!body) throw httpError('content_incomplete', 503, '문항 자료를 준비하고 있습니다.');
    delete body.answer;
    delete body.explanation;
    return {
      ...body,
      subject: q.subject,
      topic: q.topic || '기타',
      difficulty: q.difficulty || 2,
      freq_score: Number(q.freq_score || 0),
      has_image: !!q.has_image,
    };
  });
  return { track, examId, total: rows.length, allowed, premium, items };
}

/** 앱의 이론·강의 JSON만 인증된 세션에 전달한다. */
export async function getStudyFile(env, group, track, filename) {
  if (group === 'track') validTrack(track);
  else if (group === 'theory') {
    validTrack(track);
  } else if (group === 'common') {
    if (track !== 'common') throw httpError('not_found', 404);
  } else if (group === 'qnet') {
    if (track !== 'qnet') throw httpError('not_found', 404);
  } else {
    throw httpError('not_found', 404);
  }
  const allowedFiles = group === 'common'
    ? new Set(['basics_dict.json', 'circuit_guide.json'])
    : group === 'qnet'
      ? new Set(['qnet_schedule.json'])
      : group === 'theory'
        ? new Set(['01.md', '02.md', '03.md', '04.md', '05.md', '06.md'])
        : STUDY_FILES;
  if (!allowedFiles.has(filename) || filename === 'exams.json') {
    throw httpError('not_found', 404);
  }
  const key = group === 'theory'
    ? `theory/${track}/${filename}`
    : group === 'track'
      ? `study/${track}/${filename}`
      : `study/${group}/${filename}`;
  const obj = await env.CONTENT.get(key);
  if (!obj) throw httpError('not_found', 404);
  return new Response(obj.body, {
    headers: { 'Content-Type': filename.endsWith('.md') ? 'text/markdown; charset=utf-8' : 'application/json; charset=utf-8' },
  });
}

/** 인증된 앱 세션에 문항 이미지를 스트리밍한다. */
export async function getQuestionImage(env, track, imagePath) {
  validTrack(track);
  const parts = imagePath.split('/');
  if (parts.some((part) => !part || part === '.' || part === '..' || !/^[A-Za-z0-9_.-]+$/.test(part))) {
    throw httpError('bad_image_path', 400);
  }
  // Source question records store paths relative to backend/data/study/{track}; strip the
  // leading "images/" because the importer copies files under images/{track}/.
  const relativeParts = parts[0] === 'images' ? parts.slice(1) : parts;
  if (relativeParts.length === 0) throw httpError('bad_image_path', 400);
  const obj = await env.CONTENT.get(`images/${track}/${relativeParts.join('/')}`);
  if (!obj) throw httpError('not_found', 404);
  const extension = relativeParts.at(-1).split('.').at(-1).toLowerCase();
  const mime = {
    png: 'image/png', jpg: 'image/jpeg', jpeg: 'image/jpeg',
    webp: 'image/webp', gif: 'image/gif', svg: 'image/svg+xml',
  }[extension] || 'application/octet-stream';
  return new Response(obj.body, {
    headers: {
      'Content-Type': obj.httpMetadata?.contentType || mime,
      'Cache-Control': 'no-store',
    },
  });
}

/**
 * 문제 목록(메타만). 무료는 전체의 10%까지만 노출.
 * 정답·해설·본문 전체는 포함하지 않는다.
 */
export async function listQuestions(env, userId, track, examId, page) {
  const ent = await getEntitlement(env, userId);
  const premium = ent.tier === 'premium';

  const totalRow = await env.DB.prepare(
    'SELECT COUNT(*) AS c FROM questions_meta WHERE track=? AND exam_id=?'
  ).bind(track, examId).first();
  const total = totalRow?.c || 0;
  const allowed = allowedQuestionCount(env, total, premium);

  const offset = (page - 1) * PAGE;
  // 무료: allowed 범위를 넘는 문항은 잠금 표시(메타는 주되 본문 접근은 402).
  const rows = await env.DB.prepare(
    `SELECT qid, subject, topic, difficulty, freq_score, has_image, order_idx
     FROM questions_meta WHERE track=? AND exam_id=?
     ORDER BY order_idx LIMIT ? OFFSET ?`
  ).bind(track, examId, PAGE, offset).all();

  const items = (rows.results || []).map((q) => ({
    qid: q.qid,
    subject: q.subject,
    topic: q.topic,
    difficulty: q.difficulty,
    freqScore: q.freq_score,
    hasImage: !!q.has_image,
    locked: !premium && q.order_idx >= allowed, // 잠금 여부(UI 후킹)
  }));

  return { total, allowed, premium, page, pageSize: PAGE, items };
}

/**
 * 단일 문제 본문(정답 제외). 무료 잠금 문항이면 402.
 */
export async function getQuestion(env, userId, qid) {
  const meta = await env.DB.prepare(
    'SELECT track, exam_id, order_idx FROM questions_meta WHERE qid=?'
  ).bind(qid).first();
  if (!meta) throw httpError('not_found', 404);

  const ent = await getEntitlement(env, userId);
  const premium = ent.tier === 'premium';
  if (!premium) {
    const totalRow = await env.DB.prepare(
      'SELECT COUNT(*) AS c FROM questions_meta WHERE track=? AND exam_id=?'
    ).bind(meta.track, meta.exam_id).first();
    const allowed = allowedQuestionCount(env, totalRow?.c || 0, false);
    if (meta.order_idx >= allowed) {
      throw httpError('payment_required', 402, '프리미엄에서 전체 문항을 열람할 수 있습니다.');
    }
  }

  // R2의 회차 묶음에서 허용된 문제 본문을 찾는다.
  const obj = await env.CONTENT.get(`content/${meta.track}/${meta.exam_id}/paper.json`);
  if (!obj) throw httpError('not_found', 404);
  const paper = await obj.json();
  const body = (paper.questions || []).find((question) => question.qid === qid);
  if (!body) throw httpError('not_found', 404);
  // 방어적으로 정답/해설 필드 제거(본문에는 애초에 없어야 함).
  delete body.answer;
  delete body.explanation;
  return body;
}

/**
 * 채점 — 여기서만 정답/해설을 반환한다.
 * answers: [{ qid, picked }] (picked=1-based 사용자 선택)
 */
export async function gradeQuiz(env, userId, payload) {
  const answers = Array.isArray(payload?.answers) ? payload.answers : [];
  if (answers.length === 0) throw httpError('bad_request', 400);
  if (answers.length > 50) throw httpError('too_many_answers', 413);

  const entitlement = await getEntitlement(env, userId);
  const premium = entitlement.tier === 'premium';
  const seen = new Set();
  const allowedByExam = new Map();

  const results = [];
  let correct = 0;
  for (const a of answers) {
    const qid = typeof a?.qid === 'string' ? a.qid : '';
    const picked = Number(a?.picked);
    if (!qid || qid.length > 200 || !Number.isInteger(picked) || picked < 0 || picked > 8 || seen.has(qid)) {
      throw httpError('bad_answer', 400, '문항 답안 형식이 올바르지 않습니다.');
    }
    seen.add(qid);

    const meta = await env.DB.prepare(
      'SELECT track, exam_id, order_idx FROM questions_meta WHERE qid=?'
    ).bind(qid).first();
    if (!meta) throw httpError('unknown_question', 400, '문항을 찾을 수 없습니다.');

    if (!premium) {
      const examKey = `${meta.track}|${meta.exam_id}`;
      let allowed = allowedByExam.get(examKey);
      if (allowed === undefined) {
        const totalRow = await env.DB.prepare(
          'SELECT COUNT(*) AS c FROM questions_meta WHERE track=? AND exam_id=?'
        ).bind(meta.track, meta.exam_id).first();
        allowed = allowedQuestionCount(env, Number(totalRow?.c || 0), false);
        allowedByExam.set(examKey, allowed);
      }
      if (Number(meta.order_idx) >= allowed) {
        throw httpError('payment_required', 402, '무료 이용 범위 밖의 문항입니다.');
      }
    }

    const row = await env.DB.prepare(
      'SELECT answer, explanation FROM answers_private WHERE qid=?'
    ).bind(qid).first();
    if (!row) throw httpError('content_incomplete', 503, '문항 채점 자료를 준비하고 있습니다.');
    const isCorrect = picked > 0 && picked === Number(row.answer);
    if (isCorrect) correct++;
    results.push({
      qid,
      picked,
      answer: row.answer,       // ✅ 제출 이후에만 정답 공개
      explanation: row.explanation,
      correct: isCorrect,
    });
  }
  return { total: results.length, correct, results };
}
