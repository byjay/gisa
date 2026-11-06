# Gisaclub Cloudflare 백엔드 배포 가이드

> 목적: 110MB 로컬 콘텐츠(정답·해설 포함)를 APK에서 분리하여
> **디컴파일·파일 추출로도 정답/해설을 탈취할 수 없게** 하고,
> 무료/유료 게이트를 서버에서 판정한다.
>
> 현 상태: **스켈레톤 + 콘텐츠 분리 검증 완료**. 아래 절차로 실배포한다.

---

## 0. 사전 준비

```bash
npm install -g wrangler
wrangler login          # Cloudflare 계정 인증
cd backend/cloudflare
npm install             # (package.json 있을 경우)
```

## 1. 리소스 생성 (최초 1회)

```bash
# D1 데이터베이스
wrangler d1 create gisaclub-db
# → 출력된 database_id 를 wrangler.toml [[d1_databases]] 에 기입

# R2 버킷 (문제 본문 저장)
wrangler r2 bucket create gisaclub-content

# KV (로그아웃 세션 폐기 목록)
wrangler kv:namespace create SESSIONS
# KV (앱 버전 매니페스트)
wrangler kv:namespace create SETTINGS
# → 두 namespace의 id를 wrangler.toml에 각각 기입
```

## 2. 스키마 마이그레이션

```bash
wrangler d1 migrations apply gisaclub-db --remote
```

## 3. 콘텐츠 분리 산출물 생성

```bash
cd ../scripts
python3 split_content_for_r2.py --data-dir ../data/study --out ./out
# 결과: out/d1_seed.sql, out/r2/{catalog,content,study,theory,images}/ 전체 서버 콘텐츠

# 원본과 catalog·문항·qid·정답 분리·정적 복사본·R2 전체 목록을 확인한다.
# 불일치가 있으면 배포 단계로 넘어가지 않는다.
python3 verify_r2_bundle.py --data-dir ../data/study --bundle ./out --catalog ../catalog/tracks.json --migrations ../cloudflare/migrations
```

`backend/catalog/tracks.json`은 자격증 표시명·과목·이론 경로·콘텐츠 수를 보유한다. 로그인 앱은 Worker `GET /v1/tracks`로 이 카탈로그를 가져오며, APK에는 카탈로그 자료를 넣지 않는다.

**검증(정답 유출 없음)**:
```bash
grep -rl '"answer"' out/r2/content/   # 아무것도 안 나와야 정상 (본문에 정답 미포함)
```

## 4. D1 시딩 + R2 업로드

```bash
cd ../cloudflare
# meta + 정답/해설 → D1
wrangler d1 execute gisaclub-db --remote --file=../scripts/out/d1_seed.sql

# 문제 본문·학습 자료·이론·이미지 전체 → R2
find ../scripts/out/r2 -type f -print0 | while IFS= read -r -d '' f; do
  key="${f#../scripts/out/r2/}"
  wrangler r2 object put "gisaclub-content/$key" --remote --file="$f"
done
```

## 5. 시크릿 설정

```bash
wrangler secret put JWT_SIGNING_KEY       # 최소 32바이트 무작위 키
wrangler secret put ADMIN_TOKEN_SECRET    # 최소 32바이트 무작위 키
wrangler secret put CEREBRAS_API_KEY      # AI 프록시(선택)
```

`GOOGLE_OAUTH_CLIENT_ID`는 Google Cloud의 Web OAuth client ID를 `[vars]`에 설정한다.
`GOOGLE_OAUTH_ANDROID_CLIENT_IDS`에는 토큰 `azp` 검증에 사용할 Android OAuth client ID를
쉼표로 구분해 설정한다. Android OAuth client에는 앱 패키지명과 실제 릴리스 서명
인증서 SHA-1을 등록한다. 서버는 웹 `aud`와 등록된 Android `azp`를 모두 검증한다.
Google Play 결제 검증은 아직 구현 전이며, `/v1/billing/verify`는 권한을 발급하지 않는다.

## 6. 배포

```bash
wrangler deploy
# → https://gisaclub-api.<account>.workers.dev
```

## 7. Flutter 앱 연결

`lib/services/remote_content_api.dart` 는 이미 클라이언트가 준비됨.
빌드 시 API 베이스를 주입:

```bash
export API_BASE_URL="https://gisaclub-api.designssir.workers.dev"
export GOOGLE_OAUTH_CLIENT_ID="실제 Google Cloud Web OAuth client ID"
export WEB_BASE_URL="https://gisaclub-admin.pages.dev"

flutter build apk --release \
  --split-per-abi \
  --dart-define=API_BASE_URL="$API_BASE_URL" \
  --dart-define=GOOGLE_OAUTH_CLIENT_ID="$GOOGLE_OAUTH_CLIENT_ID" \
  --dart-define=WEB_BASE_URL="$WEB_BASE_URL"
```

> **도메인 비종속(R58)**: URL은 코드가 아니라 dart-define로만 주입한다.
> 커스텀 도메인 구매 후에는 값만 교체(`https://api.gisa.club` 등). 상세는
> `lib/services/app_config.dart` 및 `docs/CLOUDFLARE_ACCESS_SETUP.md` §7 참고.

앱은 Google ID token을 `/v1/auth/google`로 보내 서버 세션을 받고,
문제 본문·학습 JSON·이론·이미지를 인증된 API로 요청한다.
학습 원본은 `backend/data/study`와 `backend/data/theory`에 보관하며 Flutter APK 자산 디렉터리와 분리한다.

---

## 보안 설계 요약

| 데이터 | 저장 위치 | 클라이언트 노출 |
|--------|----------|----------------|
| 문제 메타(과목/토픽/빈도) | D1 `questions_meta` | 목록 API로 공개 |
| 문제 본문(지문/보기) | R2 `content/` | 열람 시 스트리밍(무료=10%만) |
| **정답 + 해설** | D1 `answers_private` | **채점 API 응답에서만** 반환 |
| 무료/유료 권한 | D1 `entitlements` | 서버 판정, 위변조 불가 |
| 학습 진도/점수 | D1 `user_progress` | 서버 SSOT, 로컬은 오프라인 캐시(서버 우선 병합) |
| 관리자 권한 판정 | Access JWT / 앱토큰 | 앱 내 판정 로직 없음(서버 전담) |

핵심: 정답·해설은 **절대** 목록/본문 API로 나가지 않고,
사용자가 답안을 제출한 뒤 `/v1/quiz/grade` 응답에서만 반환된다.
학습 진도/점수는 `/v1/progress`(GET pull / POST push)로 동기하며 서버가 최종 병합한다.
