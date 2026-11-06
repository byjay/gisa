# GISACLUB 서버 원격 차단 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 인증된 운영자가 서비스를 끄면 Worker 데이터·로그인·업데이트 기능을 중앙에서 거부한다.

**Architecture:** 전역 단일 Cloudflare Durable Object가 `{ enabled, message, updatedAt, revision }`를 저장한다. Worker 요청을 라우팅하기 전과 응답을 반환하기 전에 상태를 확인하고, 관리자 서비스 제어·공개 상태·헬스·관리자 토큰 복구 경로만 차단 예외로 둔다.

**Tech Stack:** Cloudflare Workers ES modules, Durable Objects (SQLite migration), Node `node:test`.

**Spec:** `docs/superpowers/specs/2026-10-28-remote-service-control.md`

## Global Constraints

- 기본 상태는 `enabled: true`; 상태 저장 실패는 일반 API에 대해 HTTP 503 fail-closed.
- 관리자 상태 변경은 기존 `requireAdmin(request, env)` 인증 뒤에서만 허용.
- 업데이트 매니페스트는 서비스가 꺼져 있으면 거부.
- 응답은 `Cache-Control: no-store`; 응답 오류는 `{ error, message }` 계약을 따른다.
- 운영 Cloudflare 계정/배포/Durable Object 데이터는 변경하지 않는다.

## Review Focus

- 상태 저장소가 없거나 고장 난 경우 데이터 API가 열리지 않는지 — control-store failure 테스트.
- 비인증 관리자가 상태를 바꾸지 못하는지 — unauthenticated PUT 테스트.
- 상태 off에서 unauthenticated 데이터 API가 401보다 먼저 503으로 차단되는지 — route matrix.
- 응답 생성 중 스위치가 off가 된 경우 콘텐츠가 반환되지 않는지 — deferred DO state response test.
- 관리자 복구 경로가 콘텐츠/API 예외로 확장되지 않는지 — bypass allowlist 테스트.

---

### Task 1: 상태 제어 객체와 Worker gate

**Files:**
- Create: `backend/cloudflare/src/service-control.js`
- Modify: `backend/cloudflare/src/index.js`
- Modify: `backend/cloudflare/wrangler.toml`
- Test: `backend/cloudflare/tests/service-control.test.js`

**Interfaces:**
- `GET /v1/app/service-status` 공개 상태 응답.
- `GET|PUT /v1/admin/service-control` 기존 관리자 인증 사용.
- 상태 객체 필드 `enabled:boolean`, `message:string`, `updatedAt:string`, `revision:integer`.
- Durable Object binding `SERVICE_CONTROL`; class `ServiceControl`; id `gisaclub-global`.

- [ ] **Step 1: 끄기/실패/권한/복구 경로 테스트 작성**
- [ ] **Step 2: Worker 테스트 파일만 실행해 의도한 실패 확인** — `node --test backend/cloudflare/tests/service-control.test.js`.
- [ ] **Step 3: Durable Object 저장·검증·관리자 route와 request/response gate 구현**
- [ ] **Step 4: 새 테스트와 기존 Worker 보안 테스트 실행** — `node --test backend/cloudflare/tests/*.test.js`.
- [ ] **Step 5: Worker 구문/설정·diff 검사** — `node --check backend/cloudflare/src/index.js`; `node --check backend/cloudflare/src/service-control.js`; `git diff --check`.

### Task 2: 서버 결과 및 최종 응답 경계 검토

**Files:** Task 1 files only; add cases to `backend/cloudflare/tests/service-control.test.js`.

**Interfaces:** Task 1 API contract.

- [ ] **Step 1: 응답 직전 재확인 케이스 추가** — 라우트 처리 전 `enabled=true`, 처리 중 `enabled=false`, 완료 응답은 `503`이어야 한다.
- [ ] **Step 2: 테스트가 현재 구현에서 실패함을 확인**.
- [ ] **Step 3: 최소 수정으로 공통 응답 경계를 보장**.
- [ ] **Step 4: 전체 Worker 보안 테스트 재실행**.
