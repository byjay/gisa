-- 학습 진도·점수 SSOT (R58) — docs/DATA_STORAGE_POLICY.md §4
-- 앱은 오프라인 학습을 위해 로컬 write-through 캐시를 두지만, 서버(D1)가 SSOT.
-- 사용자별 진도/세션/점수를 JSON 스냅샷으로 보관하고, push 시 서버가 병합한다.

CREATE TABLE IF NOT EXISTS user_progress (
  user_id     TEXT PRIMARY KEY REFERENCES users(id),
  snapshot    TEXT NOT NULL,               -- JSON: { items:{qid:{...,updatedAt}}, sessions:[], quizResults:[] }
  updated_at  INTEGER NOT NULL             -- epoch ms (서버 병합 기준시각)
);

-- 최근 갱신 조회 최적화(관리자 통계/동기화 진단용)
CREATE INDEX IF NOT EXISTS idx_user_progress_updated ON user_progress(updated_at);
