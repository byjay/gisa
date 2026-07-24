// Gisaclub Admin API — 슈퍼 관리자(운영자) 전용 엔드포인트
//
// [보안 원칙]
//  - 관리자 인증은 서버가 최종 판정한다. 앱의 로컬 관리자 오버라이드는
//    "운영자 본인 기기의 편의 기능"일 뿐, 서버 자원(관리자 크레딧, 타 사용자
//    데이터)에 접근하려면 반드시 서버 발급 관리자 토큰이 필요하다.
//  - 관리자 비밀번호는 환경변수(secret)로만 보관하고, 해시 비교한다.
//    설정:  wrangler secret put ADMIN_PASSWORD_SHA256
//           wrangler secret put ADMIN_TOKEN_SECRET
//
// [D1 스키마 가정]
//  users(id TEXT PK, email TEXT, plan TEXT, expiry TEXT, created_at TEXT)
//  KV: SETTINGS 네임스페이스에 'app_version_manifest' 키로 version.json 저장

const err = (code, message, status) => {
  const e = new Error(message);
  e.code = code;
  e.status = status;
  return e;
};

async function sha256Hex(text) {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

// 간단한 서명 토큰: base64(payload).hmacHex  — 실제 운영은 JWT 권장
async function signAdminToken(env) {
  const payload = JSON.stringify({ role: 'admin', iat: Date.now() });
  const b64 = btoa(payload);
  const sig = await sha256Hex(b64 + (env.ADMIN_TOKEN_SECRET || 'dev-secret'));
  return `${b64}.${sig}`;
}

async function verifyAdminToken(env, token) {
  if (!token || !token.includes('.')) return false;
  const [b64, sig] = token.split('.');
  const expected = await sha256Hex(b64 + (env.ADMIN_TOKEN_SECRET || 'dev-secret'));
  return sig === expected;
}

// ── 관리자 로그인: 비밀번호 → 관리자 토큰 발급
export async function adminLogin(env, body) {
  const password = (body && body.password) || '';
  if (!password) throw err('bad_request', '비밀번호가 필요합니다.', 400);
  const hash = await sha256Hex(password);
  const stored = env.ADMIN_PASSWORD_SHA256 || '';
  if (!stored || hash !== stored) {
    throw err('unauthorized', '관리자 비밀번호가 올바르지 않습니다.', 401);
  }
  const token = await signAdminToken(env);
  return { ok: true, token, label: '운영자' };
}

// ── 관리자 토큰 검증 미들웨어
export async function requireAdmin(request, env) {
  const auth = request.headers.get('Authorization') || '';
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : '';
  const ok = await verifyAdminToken(env, token);
  if (!ok) throw err('forbidden', '관리자 권한이 필요합니다.', 403);
  return { role: 'admin' };
}

// ── 사용자 목록(페이지네이션)
export async function adminListUsers(env, page = 1) {
  const pageSize = 50;
  const offset = (page - 1) * pageSize;
  const { results } = await env.DB.prepare(
    'SELECT id, email, plan, expiry, created_at FROM users ORDER BY created_at DESC LIMIT ? OFFSET ?'
  )
    .bind(pageSize, offset)
    .all();
  const total = await env.DB.prepare('SELECT COUNT(*) AS c FROM users').first('c');
  return { page, pageSize, total, users: results || [] };
}

// ── 특정 사용자 구독 등급 강제 설정(운영/CS용)
export async function adminSetUserPlan(env, body) {
  const { userId, plan, expiry } = body || {};
  if (!userId || !plan) throw err('bad_request', 'userId, plan 필수', 400);
  await env.DB.prepare('UPDATE users SET plan = ?, expiry = ? WHERE id = ?')
    .bind(plan, expiry || null, userId)
    .run();
  return { ok: true, userId, plan, expiry: expiry || null };
}

// ── 운영 통계 요약
export async function adminStats(env) {
  const totalUsers = await env.DB.prepare('SELECT COUNT(*) AS c FROM users').first('c');
  const premiumUsers = await env.DB.prepare(
    "SELECT COUNT(*) AS c FROM users WHERE plan = 'premium'"
  ).first('c');
  return {
    totalUsers: totalUsers || 0,
    premiumUsers: premiumUsers || 0,
    freeUsers: (totalUsers || 0) - (premiumUsers || 0),
    ts: new Date().toISOString(),
  };
}

// ── 앱 버전 매니페스트 조회(공개) — 앱 자동 업데이트가 읽는다
export async function getVersionManifest(env) {
  const raw = await env.SETTINGS.get('app_version_manifest');
  if (raw) {
    try {
      return JSON.parse(raw);
    } catch (_) {
      /* fallthrough */
    }
  }
  // 기본값(아직 설정 안 됨)
  return {
    latest_version: '1.0.0',
    latest_build: 1,
    min_supported_build: 1,
    apk_url: '',
    store_url: 'https://play.google.com/store/apps/details?id=com.certstudytracker.study',
    release_notes: '',
    force: false,
  };
}

// ── 앱 버전 매니페스트 갱신(관리자) — 새 빌드 배포 시 여기에 기록하면
//    사용자 앱들이 "업데이트" 버튼을 표시하게 된다.
export async function adminSetVersionManifest(env, body) {
  const manifest = {
    latest_version: body.latest_version || '1.0.0',
    latest_build: parseInt(body.latest_build || '1', 10),
    min_supported_build: parseInt(body.min_supported_build || '1', 10),
    apk_url: body.apk_url || '',
    store_url: body.store_url || '',
    release_notes: body.release_notes || '',
    force: body.force === true,
  };
  await env.SETTINGS.put('app_version_manifest', JSON.stringify(manifest));
  return { ok: true, manifest };
}
