# Cloudflare Access 관리자 인증 설정 가이드 (R57)

> 방향 전환: Firebase / `google_sign_in` / `google-services.json`을 **전혀 사용하지 않습니다.**
> 관리자 인증은 **Cloudflare Access(Zero Trust)** 가 `admin.gisa.club` 앞단에서
> Google 로그인 게이트를 걸어 지정된 이메일만 통과시키는 방식입니다.

---

## 0. 전체 그림 (하이브리드 구조)

```
[운영자]
   │  ① 브라우저로 admin.gisa.club 접속
   ▼
[Cloudflare Access]  ── Google 로그인 게이트, designssir@gmail.com만 통과
   │  ② 통과하면 대시보드 표시 + Access 쿠키(CF_Authorization) 발급
   ▼
[대시보드(Pages)]  admin.gisa.club
   │  ③ "앱 토큰 발급" 클릭 → api.gisa.club/v1/admin/issue-app-token 호출
   │     (요청에 Cf-Access-Jwt-Assertion 자동 첨부)
   ▼
[Worker(api.gisa.club)]
   │  ④ Access JWT를 JWKS로 검증 → HMAC 서명된 "앱 토큰"(email+exp) 발급
   ▼
[운영자] 토큰 복사 → 폰 앱 설정 → 슈퍼 관리자 모드에 붙여넣기
   │  ⑤ 앱이 api.gisa.club/v1/admin/verify 로 토큰 재검증
   ▼
[폰 앱]  검증 성공 → isAdmin=true → 모든 콘텐츠/AI 무제한 해금
```

핵심: **앱 안에는 이메일 비교·PIN·비밀번호가 전혀 없다.** 판정은 항상 Cloudflare + 서버.

---

## 1. 도메인 준비 (gisa.club)

1. `gisa.club` 도메인 구매 후 Cloudflare에 사이트 추가(Add a site)
2. 등록기관(레지스트라)에서 네임서버를 Cloudflare가 안내한 2개로 변경
3. DNS 전파 완료(수분~수시간) 후 Cloudflare 대시보드에서 "Active" 확인

### 필요한 DNS/도메인 (Pages·Worker 연결 시 자동 생성되는 항목 포함)
| 호스트 | 용도 | 생성 방법 |
|---|---|---|
| `admin.gisa.club` | 운영자 대시보드(Pages) | Pages 프로젝트 Custom domain 추가 → CNAME 자동 |
| `api.gisa.club` | Worker API | Worker Custom domain(또는 route) 추가 |
| `gisa.club` / `www` | (선택) 서비스 홈/랜딩 | 필요 시 별도 |

---

## 2. Google OAuth 클라이언트 생성 (1회)

Cloudflare Access의 로그인 방식으로 Google을 쓰기 위해 OAuth 클라이언트가 필요합니다.

1. https://console.cloud.google.com → 프로젝트 생성(또는 선택)
2. **API 및 서비스 → OAuth 동의 화면**: External, 앱 이름 "Gisaclub Admin", 지원 이메일 입력, 게시(테스트 사용자에 `designssir@gmail.com` 추가해도 됨)
3. **사용자 인증 정보 → 사용자 인증 정보 만들기 → OAuth 클라이언트 ID**
   - 애플리케이션 유형: **웹 애플리케이션**
   - 승인된 리디렉션 URI(중요):
     ```
     https://<your-team-name>.cloudflareaccess.com/cdn-cgi/access/callback
     ```
     `<your-team-name>`은 Cloudflare Zero Trust의 팀 도메인입니다(3단계에서 확인).
4. 생성된 **클라이언트 ID / 클라이언트 보안 비밀**을 복사해 둡니다.

> 참고: 이 redirect URI는 `admin.gisa.club`이 아니라 **Cloudflare Access 팀 도메인**을 가리킵니다.
> (Access가 로그인 콜백을 대신 처리하기 때문. 앱/대시보드 주소를 넣지 않도록 주의)

---

## 3. Cloudflare Zero Trust 설정

### 3-1. 팀 도메인 확인
Zero Trust 대시보드 → Settings → Custom Pages(또는 처음 진입 시) 에서
`<your-team-name>.cloudflareaccess.com` 형태의 팀 도메인을 확인/설정합니다.
→ 이 값이 Worker `ACCESS_TEAM_DOMAIN` 입니다.

### 3-2. Google 로그인 방식 연동
Zero Trust → **Settings → Authentication → Login methods → Add new → Google**
- App ID: 2단계의 **클라이언트 ID**
- Client secret: 2단계의 **클라이언트 보안 비밀**
- Save → "Test" 로 Google 로그인 정상 확인

### 3-3. Access Application 생성 (admin.gisa.club)
Zero Trust → **Access → Applications → Add an application → Self-hosted**
- Application name: `Gisaclub Admin`
- Session Duration: 24h(권장)
- **Application domain**: `admin.gisa.club`
- Identity providers: **Google** 만 체크(또는 One-time PIN 병행 가능)
- **Policies**:
  - Policy name: `owner-only`
  - Action: **Allow**
  - Include → **Emails** → `designssir@gmail.com`
- 저장 후, Application 상세의 **Application Audience (AUD) Tag** 값을 복사
  → 이 값이 Worker `ACCESS_AUD` 입니다.

### 3-4. (권장) API도 Access로 보호
`api.gisa.club/v1/admin/issue-app-token` 이 대시보드에서 Access 쿠키로 인증되려면,
동일 이메일 정책의 Access Application을 `api.gisa.club` 경로에도 적용하거나,
최소한 `/v1/admin/issue-app-token` 만 보호합니다.
> `/v1/admin/verify`(폰 앱 호출)는 **Access로 보호하지 말 것** — 앱 토큰 자체로 검증하므로
> Access 게이트가 걸리면 앱이 접근 불가. Worker 라우팅에서 verify를 먼저 처리하도록 이미 구성됨.

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

# 배포
npx wrangler deploy

# api.gisa.club 커스텀 도메인 연결(대시보드 UI 또는):
#   Workers & Pages → gisaclub-api → Settings → Domains & Routes → Add → api.gisa.club
```

---

## 5. 대시보드(Pages) 배포

```bash
cd backend/admin-dashboard
npx wrangler pages project create gisaclub-admin --production-branch main
npx wrangler pages deploy public --project-name gisaclub-admin
# Custom domain: Pages → gisaclub-admin → Custom domains → admin.gisa.club
```

---

## 6. 로컬 개발/테스트 (cloudflared tunnel)

로컬에서 대시보드/Worker를 임시 도메인에 붙여 동일한 Access 게이트를 그대로 테스트합니다.

```bash
# cloudflared 설치 후
cloudflared tunnel login
cloudflared tunnel create gisaclub-dev

# 로컬 대시보드(예: python -m http.server 8080 in public/) 를 임시 호스트에 연결
cloudflared tunnel route dns gisaclub-dev admin-dev.gisa.club
cloudflared tunnel --url http://localhost:8080 run gisaclub-dev

# Zero Trust에서 admin-dev.gisa.club 에도 동일한 Access Application/Policy 적용
```

> 개발 중 Access를 잠깐 우회하려면 로컬에서 Worker를 `wrangler dev` 로 띄우고
> 앱은 `--dart-define=GISACLUB_API_BASE=http://localhost:8787` 로 빌드해 verify만 테스트할 수 있습니다.
> (단, issue-app-token 은 Access JWT가 없으면 실패 — verify 흐름만 로컬 검증)

---

## 7. 폰 앱 빌드 연결

앱이 서버 주소를 알아야 관리자 토큰을 검증합니다:

```bash
flutter build apk --release \
  --dart-define=GISACLUB_API_BASE=https://api.gisa.club \
  --dart-define=GISACLUB_UPDATE_MANIFEST=https://api.gisa.club/v1/app/version
# (선택) 관리자 무제한 AI에 별도 키를 쓰려면:
#   --dart-define=CEREBRAS_ADMIN_KEY=<관리자 전용 Cerebras 키>
```

`GISACLUB_API_BASE`가 없는 빌드(예: 사내 테스트)는 관리자 토큰 검증이 불가능하며,
슈퍼 관리자 화면에 "서버 주소 미설정" 경고가 표시됩니다(안전 기본값).

---

## 8. 운영자 사용 순서 (최종)

1. 폰이든 PC든 브라우저에서 **admin.gisa.club** 접속 → Google 로그인(내 계정)
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
