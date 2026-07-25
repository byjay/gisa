// 원격 앱 설정(Remote Config) — 관리자가 세팅한 값을 학습앱이 자동 반영한다.
//
// [설계 — R59]
// - 저장소: KV(SETTINGS). 단일 키 `app_config` 에 JSON 스냅샷 저장.
// - GET /v1/app/config  : 공개(세션/권한 불필요). 학습앱이 시작 시 pull → 자동 반영.
//                          단, 정답/권한/구독 판정값은 절대 포함하지 않는다(SSOT는 각 API가 담당).
// - PUT /v1/app/config  : 관리자 전용(requireAdmin). 관리자 콘솔의 "배포" 버튼이 호출.
//
// [SSOT 경계]
//   여기 담기는 값은 "표현/기능 스위치"뿐이다: 기능 플래그, 공지, 최소버전, 활성 트랙 등.
//   개별 사용자의 권한/구독/점수는 여기에 담지 않는다(그건 entitlement/progress API가 판정).

const CONFIG_KEY = 'app_config';

function httpError(code, status, message) {
  const e = new Error(message || code);
  e.code = code;
  e.status = status;
  return e;
}

/** 관리자가 아무것도 설정하지 않았을 때의 안전 기본값(학습앱이 이 값으로 동작). */
export function defaultConfig() {
  return {
    version: 0, // 배포 시마다 서버가 증가 → 학습앱이 변경 감지
    updatedAt: 0,
    // 기능 플래그(학습앱이 UI/동작을 켜고 끔)
    features: {
      aiTutorEnabled: true, // AI 튜터 노출 여부
      handwritingEnabled: true, // 필기 인식 기능
      freeQuestionPercent: 10, // 무료 사용자 문항 노출 비율(%)
      promoBannerEnabled: false, // 프리미엄 프로모션 배너
    },
    // 공지(학습앱 홈 상단 배너). text 비면 미표시.
    notice: {
      text: '',
      level: 'info', // info | warn | urgent
      linkUrl: '',
    },
    // 강제/권장 업데이트 게이트
    update: {
      minSupportedBuild: 0, // 이 빌드 미만은 강제 업데이트 요구
      latestBuild: 0,
      latestVersion: '',
      apkUrl: '',
      forced: false,
    },
    // 활성 자격증 트랙(학습앱 트랙 선택 화면이 이 목록만 노출)
    activeTracks: [], // 비면 앱 내장 기본값 사용
  };
}

/** 학습앱/대시보드 공개 조회. 저장된 값이 없으면 기본값 반환. */
export async function getAppConfig(env) {
  const raw = await env.SETTINGS.get(CONFIG_KEY);
  if (!raw) return defaultConfig();
  try {
    const parsed = JSON.parse(raw);
    // 방어적으로 기본 키를 채워 반환(부분 저장 대비).
    return { ...defaultConfig(), ...parsed };
  } catch (_) {
    return defaultConfig();
  }
}

/**
 * 관리자 배포(PUT). 들어온 값과 기존 값을 병합하고 version/updatedAt을 서버가 증가시킨다.
 * incoming: 관리자 콘솔이 보낸 부분/전체 설정.
 */
export async function putAppConfig(env, incoming) {
  const current = await getAppConfig(env);
  const next = mergeConfig(current, incoming || {});
  next.version = (current.version || 0) + 1; // 서버가 단조 증가 관리
  next.updatedAt = Date.now();
  await env.SETTINGS.put(CONFIG_KEY, JSON.stringify(next));
  return next;
}

/** 얕은-깊은 병합: 하위 오브젝트(features/notice/update)는 키 단위로 덮어쓴다. */
function mergeConfig(base, patch) {
  const out = { ...base };
  for (const k of ['features', 'notice', 'update']) {
    if (patch[k] && typeof patch[k] === 'object') {
      out[k] = { ...base[k], ...patch[k] };
    }
  }
  if (Array.isArray(patch.activeTracks)) {
    out.activeTracks = patch.activeTracks;
  }
  return out;
}

/** 라우트 핸들러(공개 GET). */
export async function handleGetConfig(env) {
  return getAppConfig(env);
}

/** 라우트 핸들러(관리자 PUT). */
export async function handlePutConfig(env, payload) {
  if (!payload || typeof payload !== 'object') {
    throw httpError('bad_request', 400, '설정 본문이 필요합니다.');
  }
  return putAppConfig(env, payload);
}
