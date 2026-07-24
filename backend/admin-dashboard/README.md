# Gisaclub 운영자 대시보드 (admin.gisa.club)

폰 앱과 **완전히 분리된** 정적 웹 대시보드입니다. Cloudflare Access(Zero Trust)
뒤에 배포되어, 지정된 운영자 Google 계정만 접근할 수 있습니다.

## 구성
```
public/
  index.html   대시보드 UI
  app.js       Worker API 호출(토큰 발급·통계·버전·사용자 관리)
  _headers     보안 헤더(noindex 등)
```

## 배포 (Cloudflare Pages)
```bash
# 1) Pages 프로젝트 생성(최초 1회)
npx wrangler pages project create gisaclub-admin --production-branch main

# 2) 배포
cd backend/admin-dashboard
npx wrangler pages deploy public --project-name gisaclub-admin

# 3) 커스텀 도메인 연결: Cloudflare Dashboard → Pages → gisaclub-admin →
#    Custom domains → admin.gisa.club 추가
```

## 접근 보호 (Cloudflare Access)
`docs/CLOUDFLARE_ACCESS_SETUP.md` 참고. 요약:
1. Zero Trust → Access → Applications → Add → Self-hosted
2. Application domain: `admin.gisa.club`
3. Policy: Include → Emails → `designssir@gmail.com`
4. Identity provider: Google (OAuth) 연동
5. Application Audience(AUD) 태그를 복사 → Worker `wrangler.toml` 의 `ACCESS_AUD` 에 기입

## API_BASE
`public/app.js` 상단 `API_BASE = 'https://api.gisa.club'`.
배포 도메인이 다르면 이 값을 수정하세요. `api.gisa.club` 도 동일한 Access 정책으로
보호하거나, 최소한 CORS + Access JWT 검증이 동작해야 합니다.
