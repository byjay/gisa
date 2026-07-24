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

async function verifyJwt(token, secret) {
  const [h, p, sig] = token.split('.');
  if (!h || !p || !sig) throw httpError('bad_token', 401);
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
  const payload = JSON.parse(b64urlDecode(p));
  if (payload.exp && Date.now() / 1000 > payload.exp) {
    throw httpError('token_expired', 401);
  }
  return payload;
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
