-- 비공개 자동 생성 이론 글 검토 큐. 게시/사용자 공개 상태는 두지 않는다.
CREATE TABLE IF NOT EXISTS blog_drafts (
  id                TEXT PRIMARY KEY,
  slot_date         TEXT NOT NULL,
  slot              INTEGER NOT NULL CHECK (slot BETWEEN 0 AND 2),
  track_id          TEXT NOT NULL,
  certificate       TEXT NOT NULL,
  subject           TEXT NOT NULL,
  status            TEXT NOT NULL CHECK (status IN ('generating', 'review', 'approved', 'rejected', 'failed')),
  generation_token  TEXT NOT NULL,
  attempt           INTEGER NOT NULL DEFAULT 1 CHECK (attempt >= 1),
  title             TEXT,
  excerpt           TEXT,
  body_markdown     TEXT,
  editorial_notes   TEXT,
  last_error        TEXT,
  created_at        TEXT NOT NULL,
  updated_at        TEXT NOT NULL,
  UNIQUE (slot_date, slot)
);

CREATE INDEX IF NOT EXISTS idx_blog_drafts_status_created
  ON blog_drafts(status, created_at DESC);
