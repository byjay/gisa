// 구글 플레이 결제 영수증 검증(스켈레톤).
// 실제 배포: Google Play Developer API(purchases.subscriptionsv2.get)로 검증 후 D1 반영.
import { getEntitlement } from './entitlement.js';

function httpError(code, status, message) {
  const e = new Error(message || code);
  e.code = code;
  e.status = status;
  return e;
}

// 상품 → 구독 기간(ms)
const PRODUCT_DURATION = {
  premium_monthly: 30 * 24 * 60 * 60 * 1000,
  premium_yearly: 365 * 24 * 60 * 60 * 1000,
};

/**
 * payload: { productId, purchaseToken }
 * 1) 멱등: 이미 검증된 토큰이면 현재 상태 반환
 * 2) Google Play API로 실제 검증(TODO: 서비스계정 JWT 발급 → API 호출)
 * 3) D1 purchases/entitlements 갱신
 */
export async function verifyPurchase(env, userId, payload) {
  const { productId, purchaseToken } = payload || {};
  if (!productId || !purchaseToken) throw httpError('bad_request', 400);
  if (!PRODUCT_DURATION[productId]) throw httpError('unknown_product', 400);

  // 멱등 처리
  const existing = await env.DB.prepare(
    'SELECT state, expiry_at FROM purchases WHERE purchase_token=?'
  ).bind(purchaseToken).first();

  // TODO: 여기서 Google Play Developer API 호출로 실제 검증.
  //   const verified = await googlePlayVerify(env, productId, purchaseToken);
  //   if (!verified.valid) throw httpError('invalid_receipt', 402);
  // 스켈레톤에서는 검증 성공을 가정하고 만료 계산.
  const now = Date.now();
  const expiry = now + PRODUCT_DURATION[productId];

  await env.DB.prepare(
    `INSERT INTO purchases (purchase_token, user_id, product_id, state, start_at, expiry_at, verified_at, raw)
     VALUES (?, ?, ?, 'active', ?, ?, ?, ?)
     ON CONFLICT(purchase_token) DO UPDATE SET
       state='active', expiry_at=excluded.expiry_at, verified_at=excluded.verified_at`
  ).bind(purchaseToken, userId, productId, now, expiry, now, '{}').run();

  await env.DB.prepare(
    `INSERT INTO entitlements (user_id, tier, expiry, source, updated_at)
     VALUES (?, 'premium', ?, 'google_play', ?)
     ON CONFLICT(user_id) DO UPDATE SET
       tier='premium', expiry=excluded.expiry, source='google_play', updated_at=excluded.updated_at`
  ).bind(userId, expiry, now).run();

  return await getEntitlement(env, userId);
}
