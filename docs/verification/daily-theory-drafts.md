# 일일 이론 초안 자동화 — 구현·검증 결과

**기준일:** 2026-10-28 (Asia/Seoul)
**상태:** 로컬 구현·빌드 검증 완료. Cloudflare 배포와 원격 D1 적용은 미실행.

## 범위와 사용자 요청

사용자는 기사클럽 자격증·과목별 이론 글을 매일 세 편 만들고 서버에서 자동 처리하도록 요청했다. 현재 구현은 모든 카탈로그 과목에서 날짜별 서로 다른 세 과목을 골라 **비공개 검토 초안 세 편**을 생성한다. 자동 네이버 로그인/공개 발행은 없다. 검토·승인한 초안도 이 서비스에서는 `published: false`로 남는다.

## 데이터 흐름

1. `backend/cloudflare/wrangler.toml:29-30`의 Cron `0 23 * * *`가 매일 23:00 UTC, 즉 다음 날짜 08:00 KST에 Worker를 깨운다.
2. `backend/cloudflare/src/index.js:290-294`의 `scheduled()`이 `generateDailyDrafts()`를 기다린다.
3. `backend/cloudflare/src/blog-drafts.js:28-64`가 KST 날짜와 R2 카탈로그의 자격증·과목 이름으로 날짜/슬롯당 세 주제를 선택한다. 프롬프트에는 `buildPrompt()`가 자격증명과 과목명만 넣는다. R2 문제, 정답, 해설, 이론 원문은 AI 요청으로 보내지 않는다.
4. `backend/cloudflare/migrations/0003_blog_drafts.sql:2-22`의 D1 큐가 `(slot_date, slot)`을 유일하게 제한한다. 재시도 중복은 `INSERT OR IGNORE`와 실제 변경 행 수로 거르고, 15분 넘은 생성 lease는 token fencing으로 교체한다.
5. AI JSON의 필드/길이/실행 태그를 `parseDraft()`가 검사한다. 정상 결과만 `review`, 실패는 본문 없는 `failed`에 저장한다.
6. 기존 `requireAdmin()` 뒤의 `GET /v1/admin/blog-drafts` 및 `POST /v1/admin/blog-drafts/:id/review`만 큐를 다룬다. 공개 초안 목록이나 게시 API는 없다.

## 변경 파일

- `backend/cloudflare/src/blog-drafts.js` — 생성·중복 방지·검증·관리자 검토.
- `backend/cloudflare/src/index.js` — 관리자 전용 초안 경로와 Cron handler.
- `backend/cloudflare/migrations/0003_blog_drafts.sql` — 비공개 D1 큐와 unique slot.
- `backend/cloudflare/wrangler.toml` — 매일 08:00 KST Cron, draft feature flag.
- `backend/cloudflare/tests/blog-drafts.test.js` — 자동화/인증/공개 경계 회귀.
- `formal/daily-theory-drafts/` — TLA+ 사양, 설정, 코드 대응표, 정상/결함/도달성 결과.
- `formal/daily-theory-drafts/evidence/gisaclub-release-apk-20261028.rae.json` — 현재 arm64 APK 정적 REA Evidence.
- `formal/daily-theory-drafts/evidence/*-2026-10-28.log` — 최종 테스트와 dry-run 로그.
- `formal/reports/2026-10-28-daily-theory-drafts.html` — 형식 검증 요약 보고서.

## HTTP 엔드포인트 전체 인벤토리

현재 `backend/cloudflare/src/index.js`에서 확인한 HTTP 경로 템플릿이다. 경로 수와 운영검증 수를 혼동하지 않도록 각 그룹의 메서드를 모두 적었다.

| 경로 | 메서드 | 권한/범위 | 이번 로컬 검증 |
|---|---|---|---|
| `/v1/health` | GET | 공개 상태 확인 | 모의 Worker 범위 |
| `/v1/app/service-status` | GET | 공개 상태 읽기 | Worker 회귀 |
| `/v1/admin/service-control` | GET, PUT | 관리자 | Worker 회귀, 운영 E2E 미검증 |
| `/v1/app/version` | GET | 공개 앱 버전 | 소스/dry-run, 운영 E2E 미검증 |
| `/v1/admin/verify` | GET | 발급 앱 토큰 검증 | 소스/dry-run, 전체 발급 수명주기 미검증 |
| `/v1/auth/google` | POST | Google ID 토큰 검증·세션 발급 | 코드/기존 Worker 테스트, 실제 OAuth 미검증 |
| `/v1/auth/kakao` | POST | Kakao 토큰 검증·세션 발급 | Worker 테스트, 실제 운영 키/E2E 미검증 |
| `/v1/auth/logout` | POST | 사용자 세션 폐기 | 소스/dry-run, 운영 E2E 미검증 |
| `/v1/admin/issue-app-token` | GET, POST | Access 관리자 | 소스/dry-run, 운영 E2E 미검증 |
| `/v1/admin/users` | GET | 관리자 | 소스/dry-run, 운영 E2E 미검증 |
| `/v1/admin/user/plan` | POST | 관리자 | 소스/dry-run, 운영 E2E 미검증 |
| `/v1/admin/stats` | GET | 관리자 | 소스/dry-run, 운영 E2E 미검증 |
| `/v1/admin/version` | POST | 관리자 | 소스/dry-run, 운영 E2E 미검증 |
| `/v1/admin/blog-drafts` | GET | 관리자, 필터 `status`/`limit` | 신규 모의 인증 API 테스트 통과 |
| `/v1/admin/blog-drafts/:id/review` | POST | 관리자, approve/reject | 신규 approve/reject/거절 테스트 통과 |
| `/v1/tracks` | GET | 로그인 사용자 | 인증 경계 회귀, 운영 E2E 미검증 |
| `/v1/tracks/:track/exams` | GET | 로그인 사용자 | 비인증 401 경계 회귀, 성공 E2E 미검증 |
| `/v1/exams/:track/:exam/paper` | GET | 로그인 사용자 | 비인증 401 경계 회귀, 성공 E2E 미검증 |
| `/v1/exams/:track/:exam/questions` | GET | 로그인 사용자 | 비인증 401 경계 회귀, 성공 E2E 미검증 |
| `/v1/study/:group/:track/:file` | GET | 로그인 사용자 + 파일 허용목록 | 비인증/허용목록 회귀, 운영 R2 미검증 |
| `/v1/question-images/:track/:path` | GET | 로그인 사용자 + 파일 허용목록 | 비인증/캐시 금지 회귀, 운영 R2 미검증 |
| `/v1/questions/:qid` | GET | 로그인 사용자 | 비인증 401 경계 회귀, 성공 E2E 미검증 |
| `/v1/entitlement` | GET | 로그인 사용자 | 비인증 401 경계 회귀, 운영 DB 미검증 |
| `/v1/progress` | GET, POST | 로그인 사용자 | 비인증 401 경계 회귀, 계정별 동기화 미검증 |
| `/v1/quiz/grade` | POST | 로그인 사용자 | 비인증 401 경계 회귀, 운영 채점 E2E 미검증 |
| `/v1/ai/chat` | POST | 로그인·사용량 정책 | 비인증 401 경계 회귀, 실제 공급자 미검증 |
| `/v1/billing/verify` | POST | 로그인·구매 검증 | 비인증 경계 회귀; 실제 결제는 503 fail-closed |
| `*` | OPTIONS | CORS preflight | Worker 회귀 |

경로는 코드 인벤토리 전체이고, 목록만으로 실운영 정상동작을 뜻하지 않는다. 새 자동화 경로 2개는 D1/AI를 모의 처리한 테스트만 통과했다.

## 설정 대조 및 API 계약

| 코드에서 요구 | `wrangler.toml`/빌드 dry-run 관찰 | 결론 |
|---|---|---|
| `BLOG_DRAFTS_ENABLED === "true"` | vars에 `true` | 설정 파일과 일치. 원격 배포값은 확인 안 함 |
| `DB`, `CONTENT` | D1 `gisaclub-db`, R2 `gisaclub-content` 바인딩 표시 | 로컬 dry-run 바인딩 확인, 원격 마이그레이션/콘텐츠 일치 미검증 |
| `AI_ENDPOINT`, `AI_MODEL` | Cerebras endpoint와 `gpt-oss-120b`가 vars에 표시 | 설정 파일 일치 |
| `CEREBRAS_API_KEY` | `wrangler secret put` 비밀 변수로만 선언 | secret이 실제 환경에 있는지 확인하지 않음 |
| Google OAuth / Cloudflare Access | OAuth client ID와 Access team/AUD가 placeholder, Android ID 비어 있음 | 전체 Worker 운영 배포 게이트 실패 |

- `GET /v1/admin/blog-drafts?status=review&limit=50` 응답은 `{ items: [...] }`. 목록에서 `generation_token`은 제외한다.
- `POST /v1/admin/blog-drafts/:id/review` JSON은 `decision: "approve" | "reject"`, 선택적으로 `title`, `excerpt`, `bodyMarkdown`을 받는다. 응답 `{ item: { id, status, title, excerpt, bodyMarkdown, published: false } }`.
- 관리자 여부는 새 코드를 우회하는 별도 인증이 아니다. 기존 `requireAdmin()`이 먼저 실행된다.
- 계정 발급·교환·갱신 전체 운영 검증은 미완료다. 사용자 세션은 7일 만료이고 refresh 경로가 없다. 관리자 토큰은 별도 발급/만료 규칙을 사용한다.

## 검증 증거

- Worker: `node --test tests/` **25/25 통과**; 출력 `formal/daily-theory-drafts/evidence/worker-tests-2026-10-28.log`.
- 신규 자동화 회귀 8개: 하루 3개 제한/동일 Cron 중복/원문 비전송/AI 실패·비정상 JSON/15분 lease 재점유와 오래된 결과 차단/관리자 접근/공개 경로 없음/초과 길이 검토 본문 거절.
- SQLite 메모리에서 `0003_blog_drafts.sql` 실행: 16개 열과 `(slot_date, slot)` unique index 확인.
- `npx wrangler deploy --dry-run --config wrangler.toml`: 번들 65.86 KiB (gzip 16.12 KiB), 바인딩 검사 완료. `--dry-run`로 끝났으며 원격 배포·D1 적용은 하지 않았다.
- CodeB: `npm test` **43/43 통과**; 격리 산출물 `E:\code-project\codeb\_verify\gisaclub-all-requests-20261028`에 42페이지/42 sitemap URL. `products/gisaclub/#problem`은 실제 개발 빌드 캡처 2장과 캡션/alt text 포함.
- APK REA: `app-release.apk` SHA-256 `89a31bbb7549a92e1ae3b2b9a87127e08d7965719b3885c52a9af0ce47f3970c`; 627 nodes/687 occurrences/686 edges, 0 integrity contradictions. Flutter 내장 경로 `assets/flutter_assets/assets/data/`와 `assets/flutter_assets/assets/theory/` 일치 항목 0. REA는 정적 인벤토리이며 실행동작/Android manifest 의미 분석은 아니다.
- TLA+: `2 Worker × 3 slot` 유한 모델, 정상 상태 9,261개·깊이 13 전부 탐색. `SlotLimit`, `OwnerValid`, `NoPublicPost` 불변식 통과. 의도적 `PublishBug`는 `NoPublicPost` 반례를 검출했고, `NoReviewReached`는 도달성 sanity 반례를 검출했다. 로그와 trace JSON은 `formal/daily-theory-drafts/evidence/`에 있다.
- 운영 전수 검증: 전체 HTTP endpoint E2E, 원격 D1/R2, provider key 존재, OAuth 발급→전송→검증→갱신→만료, Pages/Worker 공개 빌드는 미검증 또는 미실행.
- 게시 제한 근거: [네이버 웹 콘텐츠 스팸 사례](https://searchadvisor.naver.com/guide/content-abusing)는 자동화 프로그램을 통한 대량 게시를 제한 대상으로 적는다. 그래서 서버 초안 생성과 사람의 게시를 분리했다.

## A~E 단일 에이전트 검토

- **A 작성자:** 실제 Worker/Admin/R2/D1 코드를 읽고 새 경로와 Cron을 구현했다.
- **B 비평자:** 같은 날 세 주제의 중복·지연 AI 응답·프롬프트에 원문 유입·관리자 토큰 노출·자동 공개 가능성을 반대로 추적했다. unique slot, token fencing, 입력 제한, 관리자 목록 직렬화, 게시 route 부재로 검증했다.
- **C 판정자:** SQL unique 제약과 D1 `meta.changes`, 15분 조건, 상태 전이를 구현 및 모의 DB 테스트와 대조했다. 원격 Cloudflare 설정 값은 로컬 dry-run이 증명하지 않으므로 출시 가능 판정에서 제외했다.
- **D 역추적자:** Cron 시간→KST date→slot→프롬프트→AI JSON 파싱→D1 `review`→관리자 승인 응답을 반대로 되짚었다. `approved` 뒤에도 `published:false`이고 공개 조회 route가 없음을 확인했다.
- **E 서명자:** 25/25 Worker tests, SQLite migration, Wrangler dry-run, REA inventory, TLC 정상/반례/sanity와 문서가 같은 범위를 말하는지 대조했다. 로컬 구현만 완료로 서명; 배포 게이트는 미통과.

## 재현 명령과 롤백 기준

```powershell
Set-Location E:\gisaclub\backend\cloudflare
node --test tests/
node --check src/index.js
node --check src/blog-drafts.js
npx wrangler deploy --dry-run --config wrangler.toml
```

형식 모델 재실행에는 `formal/daily-theory-drafts/`의 `.tla`와 `.cfg` 및 설치된 `tla2tools.jar`가 필요하다. 사양 상태공간은 문서의 `SCOPE.md`에 제한했다.

**코드 롤백 기준:** `c22faadbdaed9a040a11e582d36a05a301f51e45`.
**기존 Cloudflare 배포 ID:** `0746602b-4893-491b-9def-2dea06c50e75`. 새 코드 배포 ID는 없다.

## 봉인 판정

`Gate 1` 실제 운영 secret/환경 설정과 Google OAuth/Access placeholder 불일치, `Gate 2` 신규 두 관리자 경로 외 전체 endpoint 운영 E2E 미실행, `Gate 3` 인증 갱신이 없고 전체 인증 수명주기 미검증으로 배포 5/5 게이트를 통과하지 못했다. 원격 D1 migration·Worker 배포는 하지 않았고, 이 결과는 운영 자동화가 켜졌다는 뜻이 아니다. 배포 완료/출시 봉인 아님.
