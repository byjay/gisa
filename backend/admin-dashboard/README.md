# Gisaclub 운영자 대시보드 (Cloudflare Pages)

폰 앱과 **완전히 분리된** 정적 웹 대시보드입니다. Cloudflare Access(Zero Trust)
뒤에 배포되어, 지정된 운영자 Google 계정만 접근할 수 있습니다.

> **도메인 비종속(R58)**: 커스텀 도메인을 아직 구매하지 않았으므로 기본 배포 주소는
> Cloudflare가 무료로 제공하는 `https://gisaclub-admin.pages.dev` 를 사용합니다.
> Worker API 주소도 `config.js` 로만 주입하며, 코드에는 하드코딩하지 않습니다.
> 나중에 커스텀 도메인을 붙일 때는 `config.js` 값과 Access Application 도메인만
> 교체하면 되고, 대시보드 코드는 전혀 수정할 필요가 없습니다.

## 구성
```
public/
  index.html        대시보드 UI (config.js → app.js 순서로 로드)
  app.js            Worker API 호출(토큰 발급·통계·버전·사용자 관리)
  config.js         (배포 시 생성) window.GISACLUB_CONFIG.apiBase 주입
  config.sample.js  config.js 템플릿 — 복사해서 apiBase 값만 채운다
  _headers          보안 헤더(noindex 등)
```

## 1. Worker API 주소 설정 (config.js)
```bash
cd backend/admin-dashboard/public
cp config.sample.js config.js
# config.js 를 열어 apiBase 를 Worker 주소로 채운다.
#   커스텀 도메인 미구매(기본): https://gisaclub-api.<your-subdomain>.workers.dev
#   커스텀 도메인 구매 후      : https://api.gisa.club
```
`apiBase` 를 비워 두면(`''`) same-origin(상대 경로)으로 호출합니다.

## 2. 배포 (Cloudflare Pages)
```bash
# 1) Pages 프로젝트 생성(최초 1회)
npx wrangler pages project create gisaclub-admin --production-branch main

# 2) 배포 → 기본 주소 https://gisaclub-admin.pages.dev
cd backend/admin-dashboard
npx wrangler pages deploy public --project-name gisaclub-admin

# 3) (선택, 커스텀 도메인 구매 후에만) Cloudflare Dashboard → Pages →
#    gisaclub-admin → Custom domains → admin.gisa.club 추가
```

## 3. 접근 보호 (Cloudflare Access)
`docs/CLOUDFLARE_ACCESS_SETUP.md` 참고. 요약:
1. Zero Trust → Access → Applications → Add → Self-hosted
2. Application domain: `gisaclub-admin.pages.dev` (커스텀 도메인 구매 후 `admin.gisa.club`)
3. Policy: Include → Emails → `designssir@gmail.com`
4. Identity provider: Google (OAuth) 연동
5. Application Audience(AUD) 태그를 복사 → Worker `wrangler.toml` 의 `ACCESS_AUD` 에 기입

## API 주소는 어떻게 결정되나
`public/app.js` 는 `window.GISACLUB_CONFIG.apiBase` 만 읽습니다(하드코딩 없음).
그 값은 `config.js` 가 주입하므로, 배포 도메인이 바뀌어도 `config.js` 한 줄만
고치면 됩니다. Worker(API)와 대시보드(Pages)는 동일한 Access 정책으로 보호되어야
`credentials:'include'` 로 Access 쿠키가 함께 전달됩니다.
