// Gisaclub Admin API — 슈퍼 관리자(운영자) 전용 엔드포인트 (R57: Cloudflare Access 기반)
//
// [보안 아키텍처 — 2계층]
//  (A) 관리자 대시보드(Pages, 기본 *.pages.dev)는 Cloudflare Access(Zero Trust) 뒤에 있다.
//      Access가 Google 로그인을 걸고, 지정된 운영자 이메일만 통과시킨다.
//      통과한 요청에는 Cloudflare가 `Cf-Access-Jwt-Assertion` 헤더(서명 JWT)를 실어준다.
//      → Worker는 이 JWT를 Cloudflare의 공개키(JWKS)로 검증하고, aud/email을 확인한다.
//      → 즉 "누가 관리자인가"의 판정은 앱이 아니라 Cloudflare + 서버가 한다.
//
//  (B) 폰 앱 무제한 모드: 대시보드에서 `/v1/admin/issue-app-token`을 호출하면
//      Worker가 **짧은 수명의 앱 토큰**(HMAC 서명, email+exp 포함)을 발급한다.
//      운영자는 이 토큰을 폰 앱에 등록하고, 앱은 `/v1/admin/verify`로 재검증받는다.
//      앱 토큰은 서버가 서명·검증하므로 변조 불가.
//
// [필요 환경변수 / 시크릿]
//   vars:    ACCESS_TEAM_DOMAIN   예: gisaclub.cloudflareaccess.com
//            ACCESS_AUD           Access Application의 Application Audience(AUD) 태그
//            ADMIN_ALLOWED_EMAILS 쉼표구분 허용 이메일(선택, 이중방어). 예: designssir@gmail.com
//   secret:  ADMIN_TOKEN_SECRET   앱 토큰 HMAC 서명 키 (wrangler secret put ADMIN_TOKEN_SECRET)
//
// D1 스키마: users + entitlements (migrations/0001_init.sql)
//   KV: SETTINGS 네임스페이스에 'app_version_manifest' 키로 version.json 저장

const err = (code, message, status) => {
  const e = new Error(message);
  e.code = code;
  e.status = status;
  return e;
};

// ─────────────────────────────────────────────────────────────
// base64url 유틸
// ─────────────────────────────────────────────────────────────
function b64urlDecodeToBytes(s) {
  s = s.replace(/-/g, '+').replace(/_/g, '/');
  while (s.length % 4) s += '=';
  const bin = atob(s);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes;
}
function b64urlDecodeToString(s) {
  return new TextDecoder().decode(b64urlDecodeToBytes(s));
}
function b64urlEncodeFromString(str) {
  const bytes = new TextEncoder().encode(str);
  let bin = '';
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
function bytesToB64url(bytes) {
  let bin = '';
  for (const b of new Uint8Array(bytes)) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

// ─────────────────────────────────────────────────────────────
// (A) Cloudflare Access JWT 검증
//   JWKS: https://<team>.cloudflareaccess.com/cdn-cgi/access/certs
// ─────────────────────────────────────────────────────────────
const _jwksCache = { keys: null, ts: 0 };

async function getAccessJWKS(env) {
  const now = Date.now();
  if (_jwksCache.keys && now - _jwksCache.ts < 3600_000) return _jwksCache.keys;
  const team = env.ACCESS_TEAM_DOMAIN;
  if (!team) throw err('config', 'ACCESS_TEAM_DOMAIN 미설정', 500);
  const url = `https://${team}/cdn-cgi/access/certs`;
  const resp = await fetch(url);
  if (!resp.ok) throw err('config', 'Access JWKS 조회 실패', 502);
  const data = await resp.json();
  _jwksCache.keys = data.keys || [];
  _jwksCache.ts = now;
  return _jwksCache.keys;
}

async function importRsaKey(jwk) {
  return crypto.subtle.importKey(
    'jwk',
    { kty: jwk.kty, n: jwk.n, e: jwk.e, alg: 'RS256', ext: true },
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['verify'],
  );
}

// 요청에서 Access JWT를 추출·검증하고, 성공 시 payload(claims)를 반환.
export async function verifyAccessJwt(request, env) {
  const token =
    request.headers.get('Cf-Access-Jwt-Assertion') ||
    (request.headers.get('Cookie') || '')
      .split(';')
      .map((c) => c.trim())
      .find((c) => c.startsWith('CF_Authorization='))
      ?.slice('CF_Authorization='.length);
  if (!token) throw err('unauthorized', 'Access JWT 없음(대시보드 밖 접근)', 401);

  const parts = token.split('.');
  if (parts.length !== 3) throw err('unauthorized', 'JWT 형식 오류', 401);
  const [h, p, s] = parts;
  const header = JSON.parse(b64urlDecodeToString(h));
  const payload = JSON.parse(b64urlDecodeToString(p));

  // aud 검증(Access Application의 AUD 태그와 일치해야 함)
  const aud = env.ACCESS_AUD;
  const audOk = Array.isArray(payload.aud)
    ? payload.aud.includes(aud)
    : payload.aud === aud;
  if (aud && !audOk) throw err('forbidden', 'aud 불일치', 403);

  // exp 검증
  if (payload.exp && Date.now() / 1000 > payload.exp) {
    throw err('unauthorized', 'Access JWT 만료', 401);
  }

  // 서명 검증(JWKS의 kid 매칭)
  const jwks = await getAccessJWKS(env);
  const jwk = jwks.find((k) => k.kid === header.kid);
  if (!jwk) throw err('unauthorized', 'JWKS kid 미발견', 401);
  const key = await importRsaKey(jwk);
  const ok = await crypto.subtle.verify(
    { name: 'RSASSA-PKCS1-v1_5' },
    key,
    b64urlDecodeToBytes(s),
    new TextEncoder().encode(`${h}.${p}`),
  );
  if (!ok) throw err('unauthorized', 'Access JWT 서명 검증 실패', 401);

  // (이중방어) 허용 이메일 화이트리스트가 설정돼 있으면 추가 확인
  const email = (payload.email || '').toLowerCase();
  const allow = (env.ADMIN_ALLOWED_EMAILS || '')
    .split(',')
    .map((e) => e.trim().toLowerCase())
    .filter(Boolean);
  if (allow.length && !allow.includes(email)) {
    throw err('forbidden', '허용되지 않은 관리자 이메일', 403);
  }
  return payload; // { email, sub, aud, exp, ... }
}

// ─────────────────────────────────────────────────────────────
// (B) 앱 토큰(HMAC) 발급/검증
//   포맷: base64url(payloadJSON) + '.' + base64url(HMAC-SHA256)
//   payload: { email, role:'admin', iat, exp }
// ─────────────────────────────────────────────────────────────
async function hmacKey(env) {
  const secret = env.ADMIN_TOKEN_SECRET;
  if (!secret || new TextEncoder().encode(secret).byteLength < 32) {
    throw err('admin_secret_not_configured', '관리자 서명 키가 설정되지 않았습니다.', 503);
  }
  return crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign', 'verify'],
  );
}

async function signAppToken(env, email, ttlSeconds = 60 * 60 * 24 * 30) {
  const now = Math.floor(Date.now() / 1000);
  const payload = { email, role: 'admin', iat: now, exp: now + ttlSeconds };
  const p = b64urlEncodeFromString(JSON.stringify(payload));
  const key = await hmacKey(env);
  const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(p));
  return `${p}.${bytesToB64url(sig)}`;
}

async function verifyAppToken(env, token) {
  if (!token || !token.includes('.')) return null;
  const [p, s] = token.split('.');
  const key = await hmacKey(env);
  const ok = await crypto.subtle.verify(
    'HMAC',
    key,
    b64urlDecodeToBytes(s),
    new TextEncoder().encode(p),
  );
  if (!ok) return null;
  let payload;
  try {
    payload = JSON.parse(b64urlDecodeToString(p));
  } catch (_) {
    return null;
  }
  if (payload.exp && Math.floor(Date.now() / 1000) > payload.exp) return null;
  if (payload.role !== 'admin') return null;
  return payload;
}

// ── 대시보드가 호출: Access JWT로 인증된 운영자에게 폰앱용 토큰 발급
export async function issueAppToken(request, env) {
  const claims = await verifyAccessJwt(request, env); // 실패 시 throw
  const token = await signAppToken(env, claims.email || '');
  return { ok: true, token, email: claims.email || '', expires_in_days: 30 };
}

// ── 폰 앱이 호출: 앱 토큰 검증(무제한 모드 활성화 근거)
export async function verifyAppTokenEndpoint(request, env) {
  const auth = request.headers.get('Authorization') || '';
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : '';
  const payload = await verifyAppToken(env, token);
  if (!payload) throw err('forbidden', '유효하지 않은 관리자 토큰', 403);
  return { ok: true, email: payload.email || '', role: 'admin', exp: payload.exp };
}

// ── 관리자 권한 미들웨어: Access JWT(대시보드) 또는 앱 토큰(폰) 둘 중 하나면 통과
export async function requireAdmin(request, env) {
  // 1) 대시보드 경로: Access JWT
  try {
    const claims = await verifyAccessJwt(request, env);
    return { role: 'admin', email: claims.email || '', via: 'access' };
  } catch (_) {
    // 2) 폰 앱 경로: 앱 토큰
    const auth = request.headers.get('Authorization') || '';
    const token = auth.startsWith('Bearer ') ? auth.slice(7) : '';
    const payload = await verifyAppToken(env, token);
    if (payload) return { role: 'admin', email: payload.email || '', via: 'app_token' };
  }
  throw err('forbidden', '관리자 권한이 필요합니다.', 403);
}

// ── 사용자 목록(페이지네이션)
export async function adminListUsers(env, page = 1) {
  const pageSize = 50;
  const safePage = Number.isInteger(page) && page > 0 ? Math.min(page, 100000) : 1;
  const offset = (safePage - 1) * pageSize;
  const { results } = await env.DB.prepare(
    `SELECT u.id, u.email, COALESCE(e.tier, 'free') AS plan,
            CASE WHEN e.expiry IS NULL THEN NULL
                 ELSE strftime('%Y-%m-%dT%H:%M:%fZ', e.expiry / 1000, 'unixepoch') END AS expiry,
            u.created_at
     FROM users u LEFT JOIN entitlements e ON e.user_id = u.id
     ORDER BY u.created_at DESC LIMIT ? OFFSET ?`
  )
    .bind(pageSize, offset)
    .all();
  const count = await env.DB.prepare('SELECT COUNT(*) AS c FROM users').first();
  return { page: safePage, pageSize, total: Number(count?.c || 0), users: results || [] };
}

// ── 특정 사용자 구독 등급 강제 설정(운영/CS용)
export async function adminSetUserPlan(env, body) {
  const { userId, plan, expiry } = body || {};
  if (typeof userId !== 'string' || !userId || !['free', 'premium'].includes(plan)) {
    throw err('bad_request', '유효한 userId와 free 또는 premium plan이 필요합니다.', 400);
  }
  const expiryAt = plan === 'premium' && expiry ? Date.parse(expiry) : null;
  if (expiryAt !== null && !Number.isFinite(expiryAt)) {
    throw err('bad_expiry', '만료일 형식이 올바르지 않습니다.', 400);
  }
  const user = await env.DB.prepare('SELECT id FROM users WHERE id=?').bind(userId).first();
  if (!user) throw err('not_found', '사용자를 찾을 수 없습니다.', 404);
  const now = Date.now();
  await env.DB.prepare(
    `INSERT INTO entitlements (user_id, tier, expiry, source, updated_at)
     VALUES (?, ?, ?, 'manual', ?)
     ON CONFLICT(user_id) DO UPDATE SET
       tier=excluded.tier, expiry=excluded.expiry, source='manual', updated_at=excluded.updated_at`
  )
    .bind(userId, plan, expiryAt, now)
    .run();
  return { ok: true, userId, plan, expiry: expiryAt ? new Date(expiryAt).toISOString() : null };
}

// ── 운영 통계 요약
export async function adminStats(env) {
  const totalRow = await env.DB.prepare('SELECT COUNT(*) AS c FROM users').first();
  const premiumRow = await env.DB.prepare(
    `SELECT COUNT(*) AS c FROM entitlements
     WHERE tier='premium' AND (expiry IS NULL OR expiry > ?)`
  ).bind(Date.now()).first();
  const totalUsers = Number(totalRow?.c || 0);
  const premiumUsers = Number(premiumRow?.c || 0);
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
