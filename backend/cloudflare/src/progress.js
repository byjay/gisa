// 학습 진도·점수 SSOT (R58) — 서버가 최종 진실원.
//
// [정책] docs/DATA_STORAGE_POLICY.md §4
//  앱은 오프라인 학습을 위해 진도/점수를 로컬 write-through 캐시로 두지만,
//  서버(D1)가 SSOT다. 앱은 pull로 서버 스냅샷을 받아 병합하고, push로 로컬
//  변경분을 올린다. **충돌 시 서버가 최종 병합·판정한다.**
//
//  중요: 진도/점수는 권한·구독·관리자 판정과 무관하다. 여기서 요금제/관리자
//  여부를 판단하지 않는다(그 판정은 entitlement.js / admin.js 전담).
//
// [D1 스키마]  (migrations/에 반영)
//   CREATE TABLE IF NOT EXISTS user_progress (
//     user_id    TEXT PRIMARY KEY,
//     snapshot   TEXT NOT NULL,          -- JSON 문자열(문제별 진도/세션/점수)
//     updated_at INTEGER NOT NULL        -- epoch ms (서버 병합 기준)
//   );

/** ⬇️ pull: 사용자 진도 스냅샷 조회. 없으면 빈 스냅샷. */
export async function getProgress(env, userId) {
  const row = await env.DB.prepare(
    'SELECT snapshot, updated_at FROM user_progress WHERE user_id = ?'
  )
    .bind(userId)
    .first();
  if (!row) return { snapshot: {}, updatedAt: 0 };
  let snapshot = {};
  try {
    snapshot = JSON.parse(row.snapshot || '{}');
  } catch (_) {
    snapshot = {};
  }
  return { snapshot, updatedAt: row.updated_at || 0 };
}

/**
 * ⬆️ push: 로컬 변경분 반영. 서버가 **필드 단위 최신 우선(last-write-wins by
 * per-item updatedAt)** 으로 병합한다. 스냅샷 형식:
 *   { items: { [qid]: {..., updatedAt}}, sessions: [...], quizResults: [...], updatedAt }
 * 병합 규칙:
 *  - items: qid별 updatedAt이 더 최신인 쪽 채택(서버 동률 시 서버 유지 = 서버 우선).
 *  - sessions/quizResults: id 기준 합집합(중복 id는 서버 유지).
 */
export async function putProgress(env, userId, incoming) {
  const now = Date.now();
  const current = await getProgress(env, userId);
  const merged = mergeSnapshots(current.snapshot, incoming || {});
  const body = JSON.stringify(merged);

  await env.DB.prepare(
    `INSERT INTO user_progress (user_id, snapshot, updated_at)
     VALUES (?, ?, ?)
     ON CONFLICT(user_id) DO UPDATE SET snapshot = excluded.snapshot, updated_at = excluded.updated_at`
  )
    .bind(userId, body, now)
    .run();

  return { ok: true, snapshot: merged, updatedAt: now };
}

/** 서버 우선(last-write-wins) 병합. */
export function mergeSnapshots(server, client) {
  const out = { items: {}, sessions: [], quizResults: [] };

  // items: qid별 updatedAt 최신 우선(동률/무값이면 서버 유지).
  const sItems = (server && server.items) || {};
  const cItems = (client && client.items) || {};
  const qids = new Set([...Object.keys(sItems), ...Object.keys(cItems)]);
  for (const qid of qids) {
    const s = sItems[qid];
    const c = cItems[qid];
    if (!s) { out.items[qid] = c; continue; }
    if (!c) { out.items[qid] = s; continue; }
    const sU = tsOf(s.updatedAt);
    const cU = tsOf(c.updatedAt);
    out.items[qid] = cU > sU ? c : s; // 동률이면 서버(s) 우선
  }

  out.sessions = unionById(server && server.sessions, client && client.sessions);
  out.quizResults = unionById(server && server.quizResults, client && client.quizResults);
  return out;
}

/** id(없으면 date+내용 해시 대용) 기준 합집합. 서버 항목을 우선 유지. */
function unionById(serverArr, clientArr) {
  const seen = new Set();
  const out = [];
  const push = (arr) => {
    if (!Array.isArray(arr)) return;
    for (const it of arr) {
      const key = (it && (it.id || it.qid)) || JSON.stringify(it);
      if (seen.has(key)) continue;
      seen.add(key);
      out.push(it);
    }
  };
  push(serverArr); // 서버 먼저 → 중복 시 서버 유지
  push(clientArr);
  return out;
}

function tsOf(v) {
  if (typeof v === 'number') return v;
  if (typeof v === 'string') {
    const n = Date.parse(v);
    return Number.isNaN(n) ? 0 : n;
  }
  return 0;
}
