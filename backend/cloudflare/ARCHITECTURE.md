# Gisaclub — Cloudflare 기반 유료 SaaS 백엔드 아키텍처

> 목적: 유료 서비스에 맞는 **보안 수준**을 확보하고, APK 디컴파일로도
> **콘텐츠(문제·해설 110MB)와 소스가 노출되지 않도록** 서버 중심 구조로 전환한다.
> 모든 백엔드는 **Cloudflare** 스택(Workers · D1 · R2 · KV · Access)으로 구성한다.

---

## 1. 문제 정의 (현재 리스크)

| 항목 | 현재 상태 | 리스크 |
|------|-----------|--------|
| 문제/해설 데이터 | `backend/data/study/**` 원본 보관, D1/R2 서버 제공 | APK 압축 해제만으로 데이터 파일 추출 불가 |
| 정답 | 클라이언트 JSON에 평문 포함 | 채점 전에도 정답 확인 가능(치팅) |
| 구독 권한 | 로컬 SharedPreferences | 변조 시 무료→유료 우회 |
| AI 키 | (BYOK) 사용자 키 | 서버 검증 없음 |

**핵심 원칙**
1. **정답·해설은 절대 클라이언트에 동봉하지 않는다.** 서버가 세션 검증 후에만 반환.
2. **무료 10% / AI 30% 게이트는 서버가 최종 판정.** 클라이언트는 UX 캐시.
3. 문제 본문은 **열람 전용(view-only)** 스트리밍. 대량 수집(스크래핑) 방지 레이트리밋.

---

## 2. 컴포넌트 구성 (Cloudflare)

```
┌──────────────┐    HTTPS(TLS)     ┌───────────────────────────────┐
│  Flutter App │ ────────────────▶ │  Cloudflare Worker (api.*)     │
│ (열람 전용)   │ ◀──────────────── │  - 인증/세션/권한 판정          │
└──────────────┘                   │  - 콘텐츠 게이팅(10%/30%)       │
       ▲                           │  - 결제 영수증 검증             │
       │ 서명된 단기 토큰            └──────┬──────────┬──────────────┘
       │                                   │          │
       │                          ┌────────▼───┐ ┌────▼─────┐ ┌──────────┐
       │                          │  D1 (SQL)  │ │  KV      │ │  R2      │
       │                          │ 사용자/구독 │ │ 세션캐시  │ │ 콘텐츠   │
       │                          │ 사용량/영수증│ │ 레이트리밋│ │ 문제/이미지│
       └──────────────────────────┴────────────┴──────────┴──────────┘
```

- **Workers**: 모든 API 진입점(`<worker>.workers.dev(기본) / api.gisa.club(커스텀 도메인 구매 후)`). 라우팅·인증·게이팅·결제검증.
- **D1** (SQLite): 사용자, 구독(entitlement), AI 사용량, 결제 영수증, 콘텐츠 메타.
- **R2** (오브젝트 스토리지): 문제/해설/이미지 원본. 앱에는 동봉하지 않음.
- **KV**: 세션 토큰, 레이트리밋 카운터, 짧은 캐시.
- **Access / WAF / Rate Limiting**: 봇·스크래핑·남용 차단.

---

## 3. 보안 설계 (Defense in Depth)

### 3.1 콘텐츠 보호 (view-only)
- 문제 목록 API는 **문항 메타(과목/토픽/빈도)만** 페이지 단위로 반환.
- 문제 본문은 **1문항씩** 요청 → 서버가 세션·권한 확인 후 반환.
- **정답/해설은 "제출(answer) 이후"에만** 반환(`POST /v1/quiz/grade`).
- 응답에 `no-store`, 짧은 서명 URL(R2 presign, 60초) 사용 → 재배포 어렵게.
- 스크래핑 방지: 문항 조회 레이트리밋(예: 사용자당 분당 N건), 이상 패턴 차단.

### 3.2 권한(무료/유료) 서버 판정
- `GET /v1/entitlement` → `{tier, expiry}` 반환(D1 기준, 앱은 캐시).
- 무료 사용자에게는 서버가 **문항의 10%만** 반환(그 이상 요청 시 402).
- AI 프록시(`POST /v1/ai/chat`)가 **하루 30% 한도**를 서버에서 카운트.

### 3.3 결제 검증
- 구글 플레이 결제 → 클라이언트가 `purchaseToken` 전송.
- Worker가 **Google Play Developer API로 영수증 검증** → D1에 구독 기록.
- 만료/취소 웹훵(RTDN) 수신 → D1 갱신. 앱은 다음 `entitlement` 갱신 시 반영.

### 3.4 앱 무결성
- Worker는 `X-App-Attest`(Play Integrity 토큰) 검증(선택) → 변조 앱 차단.
- 세션 토큰은 **단기(예: 30분) 서명 JWT**, KV에 화이트리스트.

---

## 4. 데이터 흐름 (핵심 시나리오)

### 4.1 문제 풀이 (무료 10% 게이트)
```
App  GET /v1/exams/{track}/{examId}/questions?page=1
Worker → D1: 사용자 tier 조회
        무료면 allowedCount = floor(total*0.10)
        page 범위가 allowed 초과 → 402 Payment Required (+paywall hint)
        범위 내 → R2에서 문제 본문(정답 제외) 조회 → 반환
App  POST /v1/quiz/grade  { examId, answers[] }
Worker → 채점 후 정답/해설 반환 (제출 이후에만!)
```

### 4.2 AI 튜터 (무료 30% 게이트)
```
App  POST /v1/ai/chat  { messages[] }
Worker → D1: 오늘 사용량 조회. 무료 && used>=5 → 402
        무료: max_tokens=400, reasoning=low
        유료: max_tokens=2048, reasoning=high
        Cerebras 호출(서버측 키) → 응답 반환, 사용량+1
```
> BYOK와 병행 가능: 사용자가 자기 키를 넣으면 앱→Cerebras 직결(무료 한도만 로컬 표시),
> 서버 프록시를 쓰면 서버가 키를 관리하고 한도를 강제.

---

## 5. 마이그레이션 계획 (110MB → 서버)

1. `backend/data/study/**`의 문제 JSON을 **빌드 스크립트로 분해** →
   - 문항 메타(공개) / 문제 본문(권한) / 정답·해설(제출 후) 3계층 분리.
2. R2에 업로드(`content/{track}/{examId}/q{n}.json` 등).
3. D1에 메타(과목·토픽·freq_score·정답인덱스[서버 전용]) 적재.
4. Flutter APK는 원본 문제·이론 자료와 별도 구성해 UI와 API 클라이언트만 포함한다.
5. 앱은 `RemoteContentApi`로 전환(로컬 로더는 오프라인 캐시 폴백만).
6. 이미지: R2 presign URL(단기)로 로드.

> **단계적 적용**: 신규 종목/신규 회차부터 서버 콘텐츠로, 기존은 점진 이전.
> 오프라인 UX가 필요하면 "구매한 회차"만 암호화 캐시 허용.

---

## 6. 배포

```bash
# 1) wrangler 설치 & 로그인
npm i -g wrangler && wrangler login
# 2) D1 생성 + 마이그레이션
wrangler d1 create gisaclub-db
wrangler d1 migrations apply gisaclub-db
# 3) R2 버킷 & KV 네임스페이스
wrangler r2 bucket create gisaclub-content
wrangler kv namespace create SESSIONS
# 4) 시크릿(구글 결제 검증 키, Cerebras 키 등)
wrangler secret put GOOGLE_PLAY_SA_JSON
wrangler secret put CEREBRAS_API_KEY
wrangler secret put JWT_SIGNING_KEY
# 5) 배포
wrangler deploy
```

앱 빌드 시 서버 주소 주입:
```bash
flutter build apk --release --dart-define=API_BASE_URL=https://gisaclub-api.<sub>.workers.dev
```

---

## 7. 파일 맵 (이 디렉토리)

| 파일 | 역할 |
|------|------|
| `wrangler.toml` | Worker/D1/R2/KV 바인딩 설정 |
| `src/index.js` | Worker 엔트리(라우팅) |
| `src/auth.js` | 세션/JWT/Play Integrity |
| `src/entitlement.js` | 구독 판정 + 무료 게이트 |
| `src/content.js` | 문제 조회(view-only) + 채점 |
| `src/ai.js` | AI 프록시 + 30% 한도 |
| `src/billing.js` | 구글 결제 영수증 검증 |
| `migrations/0001_init.sql` | D1 스키마 |
| `../scripts/split_content_for_r2.py` | 110MB 자산 분해·업로드 준비 |
