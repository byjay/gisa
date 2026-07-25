# Cloudflare Access 관리자 인증 설정 가이드 (R57 / R58 개정)

> 방향 전환: Firebase / `google_sign_in` / `google-services.json`을 **전혀 사용하지 않습니다.**
> 관리자 인증은 **Cloudflare Access(Zero Trust)** 가 관리자 대시보드 앞단에서
> Google 로그인 게이트를 걸어 지정된 이메일만 통과시키는 방식입니다.
>
> **R58 — 도메인 비종속**: 커스텀 도메인을 아직 구매하지 않았으므로 **Cloudflare 기본
> 주소**(`*.pages.dev`, `*.workers.dev`)를 그대로 사용합니다. 모든 URL은 코드에
> 하드코딩하지 않고 **환경 변수/설정값**(`API_BASE_URL`, `WEB_BASE_URL`,
> 대시보드 `config.js`)으로만 주입하므로, 나중에 커스텀 도메인으로 바꿀 때
> **코드 수정 없이 설정값만 교체**하면 됩니다.

---

## 0. 전체 그림 (하이브리드 구조)

```
[운영자]
   │  ① 브라우저로 대시보드(https://gisaclub-admin.pages.dev) 접속
   ▼
[Cloudflare Access]  ── Google 로그인 게이트, designssir@gmail.com만 통과
   │  ② 통과하면 대시보드 표시 + Access 쿠키(CF_Authorization) 발급
   ▼
[대시보드(Pages)]  gisaclub-admin.pages.dev
   │  ③ "앱 토큰 발급" 클릭 → <worker>.workers.dev/v1/admin/issue-app-token 호출
   │     (요청에 Cf-Access-Jwt-Assertion 자동 첨부)
   ▼
[Worker]  gisaclub-api.<sub>.workers.dev
   │  ④ Access JWT를 JWKS로 검증 → HMAC 서명된 "앱 토큰"(email+exp) 발급
   ▼
[운영자] 토큰 복사 → 폰 앱 설정 → 슈퍼 관리자 모드에 붙여넣기
   │  ⑤ 앱이 <worker>.workers.dev/v1/admin/verify 로 토큰 재검증
   ▼
[폰 앱]  검증 성공 → isAdmin=true → 모든 콘텐츠/AI 무제한 해금
```

핵심: **앱 안에는 이메일 비교·PIN·비밀번호가 전혀 없다.** 판정은 항상 Cloudflare + 서버.

---

## 1. 주소 준비 (커스텀 도메인 없이 시작 · R58)

커스텀 도메인 구매·연결 단계는 **생략**합니다. 배포하면 Cloudflare가 자동으로 기본
주소를 부여합니다.

| 구성요소 | 기본 주소(무료) | 나중에(도메인 구매 후) |
|---|---|---|
| 관리자 대시보드(Pages) | `https://gisaclub-admin.pages.dev` | `https://admin.gisa.club` |
| Worker API | `https://gisaclub-api.<sub>.workers.dev` | `https://api.gisa.club` |

> `<sub>`는 Cloudflare 계정의 workers.dev 서브도메인(Workers & Pages에서 1회 설정).
> **어느 주소든 아래 §2 리디렉션 URI는 "Access 팀 도메인"만 씁니다(주소 무관).**

---

## 2. Google OAuth 클라이언트 생성 (1회)

Cloudflare Access의 로그인 방식으로 Google을 쓰기 위해 OAuth 클라이언트가 필요합니다.

1. https://console.cloud.google.com → 프로젝트 생성(또는 선택)
2. **API 및 서비스 → OAuth 동의 화면**: External, 앱 이름 "Gisaclub Admin",
   지원 이메일 입력, 테스트 사용자에 `designssir@gmail.com` 추가
3. **사용자 인증 정보 → OAuth 클라이언트 ID**
   - 애플리케이션 유형: **웹 애플리케이션**
   - **승인된 리디렉션 URI**(중요 — 주소가 아니라 Access 팀 도메인):
     ```
     https://<your-team-name>.cloudflareaccess.com/cdn-cgi/access/callback
     ```
   - (선택) **승인된 자바스크립트 원본**에 대시보드 주소를 넣어도 됨:
     ```
     https://gisaclub-admin.pages.dev
     ```
4. 생성된 **클라이언트 ID / 클라이언트 보안 비밀** 복사.

> redirect URI는 `*.pages.dev`가 아니라 **Cloudflare Access 팀 도메인**입니다.
> (Access가 로그인 콜백을 대신 처리하기 때문.) 커스텀 도메인으로 바꿔도 **이 값은 그대로**.

---

## 3. Cloudflare Zero Trust 설정

### 3-1. 팀 도메인 확인
Zero Trust → Settings 에서 `<your-team-name>.cloudflareaccess.com` 팀 도메인 확인/설정.
→ 이 값이 Worker `ACCESS_TEAM_DOMAIN`.

### 3-2. Google 로그인 방식 연동
Zero Trust → **Settings → Authentication → Login methods → Add new → Google**
- App ID: 2단계의 **클라이언트 ID**
- Client secret: 2단계의 **클라이언트 보안 비밀**
- Save → "Test" 로 Google 로그인 정상 확인

### 3-3. Access Application 생성 (대시보드)
Zero Trust → **Access → Applications → Add an application → Self-hosted**
- Application name: `Gisaclub Admin`
- Session Duration: 24h(권장)
- **Application domain**: `gisaclub-admin.pages.dev`  ← 기본(도메인 구매 후 `admin.gisa.club`)
- Identity providers: **Google** 만 체크
- **Policies**: `owner-only` / Action **Allow** / Include → **Emails** → `designssir@gmail.com`
- 저장 후 **Application Audience (AUD) Tag** 복사 → Worker `ACCESS_AUD`.

### 3-4. (권장) API도 Access로 보호
`issue-app-token` 이 대시보드의 Access 쿠키로 인증되려면, 동일 이메일 정책의 Access
Application을 Worker 주소의 `/v1/admin/issue-app-token` 경로에도 적용합니다.
> `/v1/admin/verify`(폰 앱 호출)는 **Access로 보호하지 말 것** — 앱 토큰 자체로 검증하므로
> Access 게이트가 걸리면 앱이 접근 불가. Worker 라우팅에서 verify를 먼저 처리하도록 구성됨.

---

## 4. Worker 배포 & 시크릿

```bash
cd backend/cloudflare

# 리소스 생성(최초 1회) — 각 명령이 출력하는 id를 wrangler.toml에 반영
npx wrangler d1 create gisaclub-db
npx wrangler kv namespace create SESSIONS
npx wrangler kv namespace create SETTINGS
npx wrangler r2 bucket create gisaclub-content

# wrangler.toml 에 채워넣기:
#   database_id, SESSIONS id, SETTINGS id
#   ACCESS_TEAM_DOMAIN = "<team>.cloudflareaccess.com"
#   ACCESS_AUD        = "<3-3에서 복사한 AUD 태그>"
#   ADMIN_ALLOWED_EMAILS = "designssir@gmail.com"

# 시크릿(앱 토큰 HMAC 서명 키) — 임의의 긴 랜덤 문자열
npx wrangler secret put ADMIN_TOKEN_SECRET

# 배포 → 기본 주소 https://gisaclub-api.<sub>.workers.dev 부여됨
npx wrangler deploy
```

> **커스텀 도메인 구매 후에만**: `wrangler.toml` 의 `routes` 주석을 해제하고
> `api.gisa.club/*` 를 채운 뒤 재배포. 그전까지는 workers.dev 주소를 그대로 사용.

---

## 5. 대시보드(Pages) 배포

```bash
cd backend/admin-dashboard/public
cp config.sample.js config.js
# config.js 의 apiBase 를 Worker 주소로:
#   apiBase: 'https://gisaclub-api.<sub>.workers.dev'   (기본)
#   apiBase: 'https://api.gisa.club'                    (도메인 구매 후)

cd ..
npx wrangler pages project create gisaclub-admin --production-branch main
npx wrangler pages deploy public --project-name gisaclub-admin
# → 기본 주소 https://gisaclub-admin.pages.dev
# (도메인 구매 후에만) Pages → Custom domains → admin.gisa.club 추가
```

---

## 6. 로컬 개발/테스트

```bash
# Worker 로컬 실행
cd backend/cloudflare && npx wrangler dev   # http://localhost:8787

# 앱은 로컬 Worker로 verify 흐름만 테스트:
flutter build apk --release --dart-define=API_BASE_URL=http://localhost:8787
```
> issue-app-token 은 Access JWT가 없으면 실패 — verify 흐름만 로컬 검증 가능.

---

## 7. 폰 앱 빌드 연결 (환경 변수 · R58)

앱이 서버 주소를 알아야 관리자 토큰을 검증합니다. **URL은 코드가 아니라 dart-define으로**:

```bash
flutter build apk --release \
  --dart-define=API_BASE_URL=https://gisaclub-api.<sub>.workers.dev \
  --dart-define=WEB_BASE_URL=https://gisaclub-admin.pages.dev
# UPDATE_MANIFEST_URL 을 생략하면 API_BASE_URL/v1/app/version 을 자동 사용.
# (선택) 관리자 무제한 AI 전용 키:
#   --dart-define=CEREBRAS_ADMIN_KEY=<관리자 전용 Cerebras 키>
```

**커스텀 도메인 구매 후에는 값만 교체**(코드 수정 없음):
```bash
  --dart-define=API_BASE_URL=https://api.gisa.club \
  --dart-define=WEB_BASE_URL=https://admin.gisa.club
```

> `API_BASE_URL` 이 없는 빌드(사내 테스트)는 관리자 토큰 검증 불가 →
> 슈퍼 관리자 화면에 "서버 주소(API_BASE_URL) 미설정" 경고가 표시됩니다(안전 기본값).
> (하위호환: 이전 `GISACLUB_API_BASE` / `GISACLUB_UPDATE_MANIFEST` 도 계속 인식.)

---

## 8. 운영자 사용 순서 (최종)

1. 브라우저에서 **gisaclub-admin.pages.dev** 접속 → Google 로그인(내 계정)
2. 대시보드에서 **"앱 토큰 발급"** → 토큰 복사
3. 폰 앱 → **설정 → 슈퍼 관리자 모드** → 토큰 붙여넣기 → **등록**
4. "관리자 모드 활성화" → 모든 콘텐츠·AI 무제한 사용
5. 새 빌드 배포 시 대시보드 **"앱 버전 관리"** 에 버전 기록 → 사용자 앱에 원버튼 업데이트 표시

---

## 9. 보안 요약 (왜 안전한가)

| 공격 시나리오 | 이 구조의 방어 |
|---|---|
| APK 디컴파일로 관리자 비밀 탈취 | 앱에 비밀이 **없음**(이메일/PIN/비번 전무) |
| 앱 변조로 isAdmin=true 강제 | 로컬 오버라이드만 켜질 뿐, **서버 자원은 verify 실패로 차단** |
| 관리자 토큰 탈취 | 30일 만료 + 서버에서 언제든 SECRET 교체 시 전량 무효화 |
| 대시보드 무단 접근 | Cloudflare Access가 Google 로그인 + 이메일 화이트리스트로 차단 |
| 피싱으로 Google 비번 탈취 | 운영자 계정 2단계 인증(휴대폰)이 최종 방어선 |

---

## 10. 데이터 저장 정책(SSOT) 연계

서버(D1/KV)가 계정·권한·구독·점수·관리자 판정의 **Single Source of Truth** 입니다.
자세한 분류·규약은 **`docs/DATA_STORAGE_POLICY.md`** 참고. 요약:
- 요금제/권한/관리자 판정 → **서버 응답만 신뢰**(로컬 영속화·판정 금지).
- 문제/콘텐츠/이미지/오디오 → 오프라인 학습을 위해 **로컬 캐시 허용**(판정 근거 아님).
- 학습 진도/점수 → 로컬 write-through 캐시 + `ProgressSyncService` 서버 동기(서버 우선).
