// 세션/인증 — 단기 서명 JWT + KV 화이트리스트.
// (스켈레톤: 실제 배포 시 Play Integrity 검증·리프레시 토큰 추가)

function httpError(code, status, message) {
  const e = new Error(message || code);
  e.code = code;
  e.status = status;
  return e;
}

// base64url 디코드
function b64urlDecode(s) {
  s = s.replace(/-/g, '+').replace(/_/g, '/');
  return atob(s);
}

function b64urlEncode(value) {
  const bytes = new TextEncoder().encode(value);
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
}

function decodeJsonPart(part) {
  const bytes = Uint8Array.from(b64urlDecode(part), (c) => c.charCodeAt(0));
  return JSON.parse(new TextDecoder().decode(bytes));
}

async function verifyJwt(token, secret) {
  const [h, p, sig] = token.split('.');
  if (token.split('.').length !== 3 || !h || !p || !sig) throw httpError('bad_token', 401);
  if (!secret || new TextEncoder().encode(secret).byteLength < 32) {
    throw httpError('auth_not_configured', 503, '인증 서버 설정이 완료되지 않았습니다.');
  }
  const data = new TextEncoder().encode(`${h}.${p}`);
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['verify']
  );
  const sigBytes = Uint8Array.from(b64urlDecode(sig), (c) => c.charCodeAt(0));
  const ok = await crypto.subtle.verify('HMAC', key, sigBytes, data);
  if (!ok) throw httpError('bad_signature', 401);
  const payload = decodeJsonPart(p);
  if (typeof payload.sub !== 'string' || !payload.sub ||
      typeof payload.jti !== 'string' || !payload.jti ||
      !Number.isFinite(payload.exp) || Date.now() / 1000 >= payload.exp) {
    throw httpError('token_expired', 401);
  }
  return payload;
}

async function verifyGoogleIdToken(idToken, clientId) {
  if (typeof idToken !== 'string' || idToken.length > 8192) {
    throw httpError('bad_google_token', 401);
  }
  const parts = idToken.split('.');
  if (parts.length !== 3) throw httpError('bad_google_token', 401);

  let header;
  let claims;
  try {
    header = decodeJsonPart(parts[0]);
    claims = decodeJsonPart(parts[1]);
  } catch (_) {
    throw httpError('bad_google_token', 401);
  }
  if (header.alg !== 'RS256' || typeof header.kid !== 'string') {
    throw httpError('bad_google_token', 401);
  }

  const keysResponse = await fetch('https://www.googleapis.com/oauth2/v3/certs', {
    cf: { cacheTtl: 3600, cacheEverything: true },
  });
  if (!keysResponse.ok) throw httpError('identity_provider_unavailable', 503);
  const keySet = await keysResponse.json();
  const jwk = (keySet.keys || []).find((key) => key.kid === header.kid && key.kty === 'RSA');
  if (!jwk) throw httpError('bad_google_token', 401);

  const publicKey = await crypto.subtle.importKey(
    'jwk', jwk, { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['verify'],
  );
  const signature = Uint8Array.from(b64urlDecode(parts[2]), (c) => c.charCodeAt(0));
  const verified = await crypto.subtle.verify(
    'RSASSA-PKCS1-v1_5', publicKey, signature,
    new TextEncoder().encode(`${parts[0]}.${parts[1]}`),
  );
  const now = Math.floor(Date.now() / 1000);
  const audiences = Array.isArray(claims.aud) ? claims.aud : [claims.aud];
  if (!verified ||
      !['accounts.google.com', 'https://accounts.google.com'].includes(claims.iss) ||
      !audiences.includes(clientId) ||
      typeof claims.sub !== 'string' || !claims.sub ||
      typeof claims.exp !== 'number' || claims.exp <= now ||
      typeof claims.iat !== 'number' || claims.iat > now + 60 ||
      claims.email_verified !== true || typeof claims.email !== 'string') {
    throw httpError('bad_google_token', 401);
  }
  return claims;
}

function randomJti() {
  const bytes = crypto.getRandomValues(new Uint8Array(24));
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
}

async function signSession(userId, env) {
  const secret = env.JWT_SIGNING_KEY;
  if (!secret || new TextEncoder().encode(secret).byteLength < 32) {
    throw httpError('auth_not_configured', 503, '인증 서버 설정이 완료되지 않았습니다.');
  }
  const now = Math.floor(Date.now() / 1000);
  const header = b64urlEncode(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const payload = b64urlEncode(JSON.stringify({
    sub: userId,
    iat: now,
    exp: now + 7 * 24 * 60 * 60,
    jti: randomJti(),
  }));
  const data = `${header}.${payload}`;
  const key = await crypto.subtle.importKey(
    'raw', new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'],
  );
  const signature = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(data));
  let binary = '';
  for (const byte of new Uint8Array(signature)) binary += String.fromCharCode(byte);
  return `${data}.${btoa(binary).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')}`;
}

/** Google ID token → verified D1 identity and short-lived API session. */
export async function signInWithGoogle(env, payload) {
  const clientId = env.GOOGLE_OAUTH_CLIENT_ID;
  if (!clientId || clientId.startsWith('REPLACE_WITH_')) {
    throw httpError('auth_not_configured', 503, 'Google 웹 OAuth 클라이언트 설정이 완료되지 않았습니다.');
  }
  const claims = await verifyGoogleIdToken(payload?.idToken, clientId);
  const allowedAndroidClientIds = new Set(
    String(env.GOOGLE_OAUTH_ANDROID_CLIENT_IDS || '')
      .split(',')
      .map((value) => value.trim())
      .filter((value) => value && !value.startsWith('REPLACE_WITH_')),
  );
  if (claims.azp && claims.azp !== clientId && !allowedAndroidClientIds.has(claims.azp)) {
    throw httpError('bad_google_token', 401, 'Google 토큰의 Android OAuth 클라이언트가 허용되지 않았습니다.');
  }
  const now = Date.now();
  const email = claims.email.toLowerCase();
  await env.DB.prepare(
    `INSERT INTO users (id, email, created_at, last_seen_at) VALUES (?, ?, ?, ?)
     ON CONFLICT(id) DO UPDATE SET email=excluded.email, last_seen_at=excluded.last_seen_at`
  ).bind(claims.sub, email, now, now).run();
  const accessToken = await signSession(claims.sub, env);
  return {
    accessToken,
    expiresIn: 7 * 24 * 60 * 60,
    profile: {
      id: claims.sub,
      email,
      name: typeof claims.name === 'string' ? claims.name : email.split('@')[0],
      photoUrl: typeof claims.picture === 'string' ? claims.picture : null,
      provider: 'google',
    },
  };
}

async function kakaoApiJson(url, accessToken) {
  let response;
  try {
    response = await fetch(url, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
  } catch (_) {
    throw httpError(
      'identity_provider_unavailable',
      503,
      '카카오 인증 서버에 연결할 수 없습니다.',
    );
  }
  if (response.status === 400 || response.status === 401) {
    throw httpError('bad_kakao_token', 401, '카카오 로그인 토큰이 유효하지 않습니다.');
  }
  if (!response.ok) {
    throw httpError(
      'identity_provider_unavailable',
      503,
      '카카오 인증 서버에서 응답하지 않았습니다.',
    );
  }
  try {
    return await response.json();
  } catch (_) {
    throw httpError(
      'identity_provider_unavailable',
      503,
      '카카오 인증 응답을 읽을 수 없습니다.',
    );
  }
}

function kakaoMemberId(value) {
  if (typeof value === 'string' && /^[1-9]\d{0,19}$/.test(value)) return value;
  if (typeof value === 'number' && Number.isSafeInteger(value) && value > 0) {
    return String(value);
  }
  return null;
}

/** Kakao SDK access token → Kakao-verified identity → Gisaclub API session. */
export async function signInWithKakao(env, payload) {
  const appId = String(env.KAKAO_APP_ID || '').trim();
  if (!/^\d{1,20}$/.test(appId)) {
    throw httpError('auth_not_configured', 503, '카카오 앱 ID 설정이 완료되지 않았습니다.');
  }
  if (!env.DB || typeof env.DB.prepare !== 'function') {
    throw httpError('auth_not_configured', 503, '사용자 데이터베이스 설정이 완료되지 않았습니다.');
  }

  const accessToken = payload?.accessToken;
  if (typeof accessToken !== 'string' || !accessToken.trim() || accessToken.length > 8192) {
    throw httpError('bad_kakao_token', 401, '카카오 로그인 토큰이 필요합니다.');
  }
  const normalizedAccessToken = accessToken.trim();

  const tokenInfo = await kakaoApiJson(
    'https://kapi.kakao.com/v1/user/access_token_info',
    normalizedAccessToken,
  );
  if (String(tokenInfo.app_id ?? '') !== appId) {
    throw httpError('bad_kakao_token', 401, '다른 카카오 앱에서 발급된 로그인 토큰입니다.');
  }
  const tokenUserId = kakaoMemberId(tokenInfo.id);
  if (!tokenUserId || !Number.isFinite(tokenInfo.expires_in) || tokenInfo.expires_in <= 0) {
    throw httpError('bad_kakao_token', 401, '카카오 로그인 토큰 정보가 올바르지 않습니다.');
  }

  const kakaoUser = await kakaoApiJson(
    'https://kapi.kakao.com/v2/user/me',
    normalizedAccessToken,
  );
  if (!kakaoUser || typeof kakaoUser !== 'object' || Array.isArray(kakaoUser)) {
    throw httpError('identity_provider_unavailable', 503, '카카오 사용자 응답을 읽을 수 없습니다.');
  }
  const memberId = kakaoMemberId(kakaoUser.id);
  if (!memberId || memberId !== tokenUserId) {
    throw httpError('bad_kakao_token', 401, '카카오 사용자 확인에 실패했습니다.');
  }

  // Provider prefix prevents collisions with Google subject IDs. Kakao email is
  // intentionally not requested or stored; it is optional and not needed to log in.
  const userId = `kakao:${memberId}`;
  const now = Date.now();
  await env.DB.prepare(
    `INSERT INTO users (id, email, created_at, last_seen_at) VALUES (?, NULL, ?, ?)
     ON CONFLICT(id) DO UPDATE SET last_seen_at=excluded.last_seen_at`
  ).bind(userId, now, now).run();

  const account = kakaoUser.kakao_account && typeof kakaoUser.kakao_account === 'object'
    ? kakaoUser.kakao_account
    : {};
  const profile = account.profile && typeof account.profile === 'object'
    ? account.profile
    : {};
  const properties = kakaoUser.properties && typeof kakaoUser.properties === 'object'
    ? kakaoUser.properties
    : {};
  const rawPhoto = profile.profile_image_url || profile.thumbnail_image_url || properties.profile_image;
  let photoUrl = null;
  if (typeof rawPhoto === 'string') {
    try {
      const parsed = new URL(rawPhoto);
      if (parsed.protocol === 'https:') photoUrl = parsed.href;
    } catch (_) {}
  }

  const rawName = typeof profile.nickname === 'string'
    ? profile.nickname
    : typeof properties.nickname === 'string'
      ? properties.nickname
      : '카카오 사용자';

  return {
    accessToken: await signSession(userId, env),
    expiresIn: 7 * 24 * 60 * 60,
    profile: {
      id: userId,
      email: '',
      name: rawName.slice(0, 80),
      photoUrl,
      provider: 'kakao',
    },
  };
}

/**
 * Authorization: Bearer <jwt> 검증 → { userId } 반환.
 * KV(SESSIONS)에 화이트리스트가 있으면 즉시 폐기(로그아웃) 가능.
 */
export async function requireSession(request, env) {
  const auth = request.headers.get('Authorization') || '';
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : '';
  if (!token) throw httpError('unauthorized', 401, '로그인이 필요합니다.');

  const payload = await verifyJwt(token, env.JWT_SIGNING_KEY);

  // 폐기 목록 확인(선택): 로그아웃/기기 변경 시 무효화
  const revoked = await env.SESSIONS.get(`revoked:${payload.jti || ''}`);
  if (revoked) throw httpError('token_revoked', 401);

  return { userId: payload.sub, claims: payload };
}

export async function revokeSession(env, claims) {
  const remaining = Math.ceil(Number(claims.exp) - Date.now() / 1000);
  if (!claims.jti || remaining <= 0) return { ok: true };
  await env.SESSIONS.put(`revoked:${claims.jti}`, '1', { expirationTtl: remaining });
  return { ok: true };
}
