-- Gisaclub D1 초기 스키마
-- 사용자 · 구독 · AI 사용량 · 결제 영수증 · 콘텐츠 메타

-- 사용자
CREATE TABLE IF NOT EXISTS users (
  id            TEXT PRIMARY KEY,          -- uuid
  email         TEXT UNIQUE,
  created_at    INTEGER NOT NULL,          -- epoch ms
  last_seen_at  INTEGER
);

-- 구독(엔타이틀먼트): tier = 'free' | 'premium'
CREATE TABLE IF NOT EXISTS entitlements (
  user_id     TEXT PRIMARY KEY REFERENCES users(id),
  tier        TEXT NOT NULL DEFAULT 'free',
  expiry      INTEGER,                     -- epoch ms (premium 만료), null=무기한/무료
  source      TEXT,                        -- 'google_play' | 'promo' | 'manual'
  updated_at  INTEGER NOT NULL
);

-- AI 일일 사용량(무료 30% 게이트) — 날짜별 카운트
CREATE TABLE IF NOT EXISTS ai_usage (
  user_id   TEXT NOT NULL REFERENCES users(id),
  day       TEXT NOT NULL,                 -- 'YYYY-MM-DD'
  used      INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, day)
);

-- 구글 플레이 결제 영수증(검증 기록/멱등)
CREATE TABLE IF NOT EXISTS purchases (
  purchase_token  TEXT PRIMARY KEY,
  user_id         TEXT NOT NULL REFERENCES users(id),
  product_id      TEXT NOT NULL,           -- 'premium_monthly' | 'premium_yearly'
  state           TEXT NOT NULL,           -- 'active' | 'canceled' | 'expired'
  start_at        INTEGER,
  expiry_at       INTEGER,
  verified_at     INTEGER NOT NULL,
  raw             TEXT                      -- 검증 응답 원문(감사용)
);

-- 콘텐츠 메타(공개 가능한 최소 정보만). 정답/해설은 여기에 저장하지 않음.
CREATE TABLE IF NOT EXISTS questions_meta (
  qid         TEXT PRIMARY KEY,            -- track|exam|subject|no
  track       TEXT NOT NULL,
  exam_id     TEXT NOT NULL,
  subject     TEXT NOT NULL,
  topic       TEXT,
  difficulty  INTEGER DEFAULT 2,
  freq_score  REAL DEFAULT 0,
  has_image   INTEGER DEFAULT 0,
  order_idx   INTEGER DEFAULT 0            -- 회차 내 문항 순서(10% 게이트 기준)
);

-- 정답(서버 전용). 절대 목록/본문 API로 노출하지 않으며, 채점 API에서만 사용.
CREATE TABLE IF NOT EXISTS answers_private (
  qid         TEXT PRIMARY KEY REFERENCES questions_meta(qid),
  answer      INTEGER NOT NULL,            -- 1-based 정답
  explanation TEXT                          -- 해설(제출 후에만 반환)
);

CREATE INDEX IF NOT EXISTS idx_qmeta_exam ON questions_meta(track, exam_id, order_idx);
CREATE INDEX IF NOT EXISTS idx_qmeta_freq ON questions_meta(track, freq_score);
