function httpError(code, status, message) {
  const e = new Error(message || code);
  e.code = code;
  e.status = status;
  return e;
}

/**
 * payload: { productId, purchaseToken }
 * 결제 검증 구현 전에는 절대로 구독 권한을 발급하지 않는다.
 */
export async function verifyPurchase(_env, _userId, _payload) {
  throw httpError('billing_verification_unavailable', 503,
    '결제 서버 검증이 설정되지 않아 구독을 활성화할 수 없습니다.');
}
