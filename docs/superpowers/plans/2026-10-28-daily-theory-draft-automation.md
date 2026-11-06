# 일일 이론 글 초안 자동화 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 한국시간 하루 세 개의 자격증 이론 글 초안을 비공개 서버 큐에 자동 생성한다.

**Architecture:** Cloudflare Cron이 R2 자격증 카탈로그의 종목·과목만 고르고, 기존 서버 AI 공급자에 최소한의 주제값만 보내 D1 검토 대기 큐에 결과를 저장한다. 날짜·슬롯 키와 상태 조건부 갱신으로 재시도 중복을 막고, 목록/검토 API는 기존 관리자 인증 뒤에 둔다. 공개 발행 기능은 만들지 않는다.

**Tech Stack:** Cloudflare Workers, D1, R2, JavaScript, Node built-in test, TLA+/TLC.

**Spec:** `docs/superpowers/specs/2026-10-28-daily-theory-draft-automation.md`

## Global Constraints

- 프롬프트에 문제 원문, 정답, 해설, 교재 내용을 포함하지 않는다.
- 외부 게시를 자동화하지 않고 사용자 블로그 계정의 쿠키/비밀정보를 저장하지 않는다.
- 초안 상태는 관리자 인증 API로만 노출한다.
- Cron은 한 날짜에 서로 다른 세 과목을 선택하고 날짜/슬롯 기준으로 멱등이어야 한다.
- 실제 Worker 배포와 원격 D1 변경은 하지 않는다.

## Review Focus

1. Cron 중복/재시도 — 날짜·슬롯 유일성과 상태 조건부 업데이트 검증
2. AI 키 누락/오류 — 초안이 공개되거나 빈 초안으로 승인되지 않음
3. 악성/비정상 모델 응답 — 길이·필드 검사 실패 시 실패 상태로 보관
4. 관리자 권한 누락 — 초안 경로는 세션/공개 API에서 보이지 않음
5. 과목 수 부족 — 하루 세 개 조건을 충족하지 못하면 중복 주제를 만들지 않고 실패를 보고

---

### Task 1: D1 초안 상태와 생성기

**Files:** `backend/cloudflare/migrations/0003_blog_drafts.sql`, `backend/cloudflare/src/blog-drafts.js`, `backend/cloudflare/tests/blog-drafts.test.js`

- [x] 날짜·슬롯 유일키, 상태, 검토 본문, 생성/갱신 시간을 저장하는 D1 테이블 작성
- [x] 테스트: 같은 날짜·슬롯 두 번 신청해도 초안이 한 건만 생성됨
- [x] 테스트: 모델 키 누락/응답 오류가 게시 가능한 결과를 반환하지 않음
- [x] 테스트: 프롬프트 입력에 과목명만 포함하고 문제/정답/해설 원문을 받지 않음
- [x] 테스트: 비정상 JSON/과도한 본문은 `review` 상태로 저장되지 않음
- [x] Worker generation function 구현; topic list is at least 3 and all distinct
- [x] 목표 테스트와 Node syntax check 실행

### Task 2: 관리자 큐 API

**Files:** `backend/cloudflare/src/index.js`, `backend/cloudflare/src/blog-drafts.js`, `backend/cloudflare/tests/blog-drafts.test.js`

- [x] 테스트: 비관리자 목록/검토 요청은 인증 거절
- [x] 테스트: 관리자 목록은 세션/일반 콘텐츠 경로에서 보이지 않음
- [x] 테스트: review/edit transition only accepts allowed status and body length bounds
- [x] 기존 `requireAdmin` 뒤에 GET list / POST review route 연결
- [x] 대상 Worker tests 및 syntax check 실행

### Task 3: Cron과 정식 상태 모델

**Files:** `backend/cloudflare/src/index.js`, `backend/cloudflare/wrangler.toml`, `formal/daily-theory-drafts/DailyTheoryDrafts.tla`, `formal/daily-theory-drafts/DailyTheoryDrafts.cfg`

- [x] 한국 시간 08:00 실행 Cron 식을 `wrangler.toml`에 추가
- [x] Worker `scheduled` handler가 generation task를 기다리고 오류를 숨기지 않게 처리
- [x] TLA+에서 중복 Cron, AI 지연/실패, 관리자 검토가 교차해도 슬롯당 초안은 최대 한 개이고 미검토 초안은 게시되지 않는 불변식 모델링
- [x] 정상 모델 전체 탐색, 의도적 공개 결함 반례, 속성 도달성 sanity 점검 실행
- [x] 모델 상태/가정과 `index.js`·`blog-drafts.js` 라인 대응 기록

### Task 4: 핸드오프와 검증

**Files:** `docs/HANDOFF.md`, `docs/SEPARATION_CHECKLIST.md`, `docs/verification/daily-theory-drafts.md`

- [x] Worker 전체 단위 테스트, `node --check`, dry-run 빌드, `git diff --check` 수행
- [x] 핸드오프에 실행 날짜, 최대 3개/일, 관리자 전용, 자동 게시 안 함, 실제 미검증 범위 기록
- [x] 변경 파일/검증 결과만 기록하고 Worker나 원격 D1은 건드리지 않음

## 완료 판정 (2026-10-28)

- 로컬 구현 및 검증 계획은 완료했다. Worker 테스트/형식 모델/CodeB 제품 페이지/REA 산출물/핸드오프가 갱신되었다.
- 배포 게이트는 별도다. 실 secret/Access/OAuth, 원격 D1 migration, 전체 endpoint E2E, Cloudflare 배포는 미완료이며 이번 완료 체크에 포함하지 않는다.
