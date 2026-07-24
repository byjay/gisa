// AI 튜터 프록시 — 무료 30% 게이트를 서버가 강제.
// 무료: 하루 N회 + 짧은 답변(토큰↓) + 얕은 추론(low). 유료: 무제한 + 심화(high).
import { getEntitlement } from './entitlement.js';

function httpError(code, status, message) {
  const e = new Error(message || code);
  e.code = code;
  e.status = status;
  return e;
}

function todayKey() {
  const d = new Date();
  const p = (n) => String(n).padStart(2, '0');
  return `${d.getUTCFullYear()}-${p(d.getUTCMonth() + 1)}-${p(d.getUTCDate())}`;
}

export async function aiChat(env, userId, payload) {
  const ent = await getEntitlement(env, userId);
  const premium = ent.tier === 'premium';
  const day = todayKey();

  const dailyLimit = parseInt(env.FREE_AI_DAILY_LIMIT || '5', 10);
  if (!premium) {
    const row = await env.DB.prepare(
      'SELECT used FROM ai_usage WHERE user_id=? AND day=?'
    ).bind(userId, day).first();
    const used = row?.used || 0;
    if (used >= dailyLimit) {
      throw httpError(
        'payment_required',
        402,
        `오늘의 무료 AI 사용 횟수(${dailyLimit}회)를 모두 사용했어요. 프리미엄은 무제한입니다.`
      );
    }
  }

  const maxTokens = premium
    ? parseInt(env.PREMIUM_AI_MAX_TOKENS || '2048', 10)
    : parseInt(env.FREE_AI_MAX_TOKENS || '400', 10);
  const reasoning = premium ? 'high' : 'low';

  const messages = Array.isArray(payload?.messages) ? payload.messages : [];
  const res = await fetch(env.AI_ENDPOINT, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${env.CEREBRAS_API_KEY}`,
    },
    body: JSON.stringify({
      model: env.AI_MODEL,
      messages,
      max_tokens: maxTokens,
      temperature: 0.5,
      reasoning_effort: reasoning,
    }),
  });
  if (!res.ok) {
    throw httpError('ai_error', 502, `AI 호출 실패(${res.status})`);
  }
  const data = await res.json();
  const msg = data?.choices?.[0]?.message || {};
  const answer = (msg.content || '').trim();
  const thinking = (msg.reasoning || msg.reasoning_content || '').trim();

  // 무료 사용량 +1 (멱등 upsert)
  if (!premium) {
    await env.DB.prepare(
      `INSERT INTO ai_usage (user_id, day, used) VALUES (?, ?, 1)
       ON CONFLICT(user_id, day) DO UPDATE SET used = used + 1`
    ).bind(userId, day).run();
  }

  return { answer, thinking, tier: ent.tier };
}
