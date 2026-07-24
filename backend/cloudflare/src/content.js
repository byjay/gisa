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

  // R2에서 문제 본문(정답 없는 버전) 로드.
  const obj = await env.CONTENT.get(`content/${meta.track}/${meta.exam_id}/${encodeURIComponent(qid)}.json`);
  if (!obj) throw httpError('not_found', 404);
  const body = await obj.json();
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

  const results = [];
  let correct = 0;
  for (const a of answers) {
    const row = await env.DB.prepare(
      'SELECT answer, explanation FROM answers_private WHERE qid=?'
    ).bind(a.qid).first();
    if (!row) continue;
    const isCorrect = Number(a.picked) === Number(row.answer);
    if (isCorrect) correct++;
    results.push({
      qid: a.qid,
      picked: a.picked,
      answer: row.answer,       // ✅ 제출 이후에만 정답 공개
      explanation: row.explanation,
      correct: isCorrect,
    });
  }
  return { total: results.length, correct, results };
}
