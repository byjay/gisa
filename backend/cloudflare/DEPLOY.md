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

# KV (세션/레이트리밋)
wrangler kv:namespace create SESSIONS
wrangler kv:namespace create RATELIMIT
# → 출력된 id 를 wrangler.toml [[kv_namespaces]] 에 기입
```

## 2. 스키마 마이그레이션

```bash
wrangler d1 execute gisaclub-db --file=migrations/0001_init.sql
```

## 3. 콘텐츠 분리 산출물 생성

```bash
cd ../scripts
python3 split_content_for_r2.py --data-dir ../../assets/data --out ./out
# 결과: out/d1_seed.sql (meta + answers_private) , out/r2/content/**/*.json (본문, 정답 없음)
```

**검증(정답 유출 없음)**:
```bash
grep -rl '"answer"' out/r2/content/   # 아무것도 안 나와야 정상 (본문에 정답 미포함)
```

## 4. D1 시딩 + R2 업로드

```bash
cd ../cloudflare
# meta + 정답/해설 → D1
wrangler d1 execute gisaclub-db --file=../scripts/out/d1_seed.sql

# 문제 본문 → R2 (정답 없는 파일만 업로드됨)
find ../scripts/out/r2/content -name '*.json' | while read f; do
  key=${f#../scripts/out/r2/}
  wrangler r2 object put gisaclub-content/$key --file="$f"
done
```

## 5. 시크릿 설정

```bash
wrangler secret put JWT_SECRET            # 세션 서명 키
wrangler secret put CEREBRAS_API_KEY      # AI 프록시(무료 티어 서버 대납용, 선택)
wrangler secret put GOOGLE_PLAY_KEY       # 인앱결제 영수증 검증(서비스 계정 JSON)
```

## 6. 배포

```bash
wrangler deploy
# → https://gisaclub-api.<account>.workers.dev
```

## 7. Flutter 앱 연결

`lib/services/remote_content_api.dart` 는 이미 클라이언트가 준비됨.
빌드 시 API 베이스를 주입:

```bash
flutter build apk --release --dart-define=GISACLUB_API_BASE=https://gisaclub-api.<account>.workers.dev
```

이후 콘텐츠 로딩을 로컬 assets → `RemoteContentApi` 로 전환하면
APK에서 정답/해설 데이터를 제거할 수 있다(APK 크기도 대폭 감소).

---

## 보안 설계 요약

| 데이터 | 저장 위치 | 클라이언트 노출 |
|--------|----------|----------------|
| 문제 메타(과목/토픽/빈도) | D1 `questions_meta` | 목록 API로 공개 |
| 문제 본문(지문/보기) | R2 `content/` | 열람 시 스트리밍(무료=10%만) |
| **정답 + 해설** | D1 `answers_private` | **채점 API 응답에서만** 반환 |
| 무료/유료 권한 | D1 `entitlements` | 서버 판정, 위변조 불가 |

핵심: 정답·해설은 **절대** 목록/본문 API로 나가지 않고,
사용자가 답안을 제출한 뒤 `/v1/quiz/grade` 응답에서만 반환된다.
