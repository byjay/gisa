// Gisaclub 운영자 대시보드 런타임 설정 (도메인 비종속 · R58)
//
// [사용법]
//  이 파일을 `config.js`로 복사한 뒤 Worker API 주소를 채워 배포한다.
//  대시보드 코드(app.js)는 window.GISACLUB_CONFIG.apiBase 만 읽으므로,
//  커스텀 도메인 전환 시에도 코드 수정 없이 이 값만 교체하면 된다.
//
//  - 커스텀 도메인 미구매(기본): Cloudflare 무료 주소 사용
//      apiBase: 'https://gisaclub-api.<your-subdomain>.workers.dev'
//  - 커스텀 도메인 구매 후:
//      apiBase: 'https://api.gisa.club'
//
//  대시보드(Pages)와 Worker가 "동일 Zero Trust Access 정책"으로 보호되면
//  credentials:'include' 로 Access 쿠키가 함께 전달되어 인증이 통과된다.
//
//  apiBase 를 빈 문자열('')로 두면 same-origin(상대 경로)으로 호출한다.
window.GISACLUB_CONFIG = {
  apiBase: 'https://gisaclub-api.<your-subdomain>.workers.dev',
};
