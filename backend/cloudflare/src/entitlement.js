// 구독 판정 — D1 기준으로 tier/expiry를 반환. 서버가 최종 진실원.

export async function getEntitlement(env, userId) {
  const row = await env.DB.prepare(
    'SELECT tier, expiry FROM entitlements WHERE user_id = ?'
  )
    .bind(userId)
    .first();

  let tier = row?.tier || 'free';
  const expiry = row?.expiry || null;

  // 만료 지난 premium은 free로 강등.
  if (tier === 'premium' && expiry && Date.now() > expiry) {
    tier = 'free';
  }
  return { tier, expiry };
}

/** 무료 사용자가 접근 가능한 문항 수(전체의 10%, 최소 1). */
export function allowedQuestionCount(env, total, isPremium) {
  if (isPremium) return total;
  if (total <= 0) return 0;
  const ratio = parseFloat(env.FREE_QUESTION_RATIO || '0.10');
  const n = Math.floor(total * ratio);
  return n < 1 ? 1 : n;
}

export async function isPremium(env, userId) {
  const e = await getEntitlement(env, userId);
  return e.tier === 'premium';
}
