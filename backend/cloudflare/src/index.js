// Gisaclub API — Cloudflare Worker 엔트리(라우팅)
// 보안 원칙: 정답/해설은 채점 API에서만 반환, 무료 게이트는 서버가 최종 판정.
import { requireSession, revokeSession, signInWithGoogle, signInWithKakao } from './auth.js';
import { getEntitlement } from './entitlement.js';
import {
  getTrackCatalog,
  listQuestions,
  listExams,
  getExamPaper,
  getStudyFile,
  getQuestionImage,
  getQuestion,
  gradeQuiz,
} from './content.js';
import { aiChat } from './ai.js';
import { verifyPurchase } from './billing.js';
import { getProgress, MAX_SNAPSHOT_BYTES, putProgress } from './progress.js';
import { handleGetConfig, handlePutConfig } from './appconfig.js';
import { issueAppToken, verifyAppTokenEndpoint, requireAdmin, adminListUsers, adminSetUserPlan, adminStats, getVersionManifest, adminSetVersionManifest } from './admin.js';
import { isValidServiceState, ServiceControl } from './service-control.js';
import { generateDailyDrafts, listBlogDrafts, reviewBlogDraft } from './blog-drafts.js';

const json = (data, status = 200, extra = {}) =>
  new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      'Cache-Control': 'no-store', // 콘텐츠 캐시/재배포 방지
      'Access-Control-Allow-Origin': '*',
      ...extra,
    },
  });

const serviceDisabled = (message = '') => json({ error: 'service_disabled', message }, 503);

async function getServiceState(env) {
  if (!env.SERVICE_CONTROL) throw new Error('SERVICE_CONTROL binding unavailable');
  const id = env.SERVICE_CONTROL.idFromName('gisaclub-global');
  const response = await env.SERVICE_CONTROL.get(id).fetch('https://service-control/state');
  if (!response.ok) throw new Error('Service control state unavailable');
  const state = await response.json();
  if (!isValidServiceState(state)) throw new Error('Malformed service control state');
  return state;
}

async function updateServiceState(env, input) {
  if (!env.SERVICE_CONTROL) throw new Error('SERVICE_CONTROL binding unavailable');
  const id = env.SERVICE_CONTROL.idFromName('gisaclub-global');
  const response = await env.SERVICE_CONTROL.get(id).fetch('https://service-control/state', {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(input),
  });
  if (!response.ok) throw new Error('Service control state unavailable');
  const state = await response.json();
  if (!isValidServiceState(state)) throw new Error('Malformed service control state');
  return state;
}

function isControlPlane(pathname, method) {
  return (pathname === '/v1/health' && method === 'GET')
    || (pathname === '/v1/app/service-status' && method === 'GET')
    || (pathname === '/v1/admin/verify' && method === 'GET')
    || (pathname === '/v1/admin/issue-app-token' && ['GET', 'POST'].includes(method))
    || (pathname === '/v1/admin/service-control' && ['GET', 'PUT'].includes(method))
    || (pathname === '/v1/admin/blog-drafts' && method === 'GET')
    || (/^\/v1\/admin\/blog-drafts\/[A-Za-z0-9_-]{1,80}\/review$/.test(pathname) && method === 'POST')
    || (pathname === '/v1/auth/logout' && method === 'POST');
}

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const { pathname } = url;
    const method = request.method;

    if (method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET,POST,PUT,OPTIONS',
          'Access-Control-Allow-Headers': 'Authorization,Content-Type',
        },
      });
    }

    const controlPlane = isControlPlane(pathname, method);
    if (!controlPlane) {
      try {
        const state = await getServiceState(env);
        if (!state.enabled) return serviceDisabled(state.message);
      } catch (_) {
        return json({ error: 'service_control_unavailable', message: '서비스 상태를 확인할 수 없습니다.' }, 503);
      }
    }

    const response = await (async () => {
      try {
      // ── 헬스체크(공개)
      if (pathname === '/v1/health') return json({ ok: true });

      // 공개 서비스 상태 확인
      if (pathname === '/v1/app/service-status' && method === 'GET') {
        try {
          return json(await getServiceState(env));
        } catch (_) {
          return json({ error: 'service_control_unavailable', message: '서비스 상태를 확인할 수 없습니다.' }, 503);
        }
      }

      // 관리자 서비스 제어는 기존 관리자 인증을 먼저 통과해야 한다.
      if (pathname === '/v1/admin/service-control') {
        await requireAdmin(request, env);
        if (method === 'GET') {
          try {
            return json(await getServiceState(env));
          } catch (_) {
            return json({ error: 'service_control_unavailable', message: '서비스 상태를 확인할 수 없습니다.' }, 503);
          }
        }
        if (method === 'PUT') {
          let input;
          try {
            input = await request.json();
          } catch (_) {
            return json({ error: 'bad_request', message: '올바른 JSON이 필요합니다.' }, 400);
          }
          if (!input || typeof input.enabled !== 'boolean' || typeof input.message !== 'string') {
            return json({ error: 'bad_request', message: 'enabled와 message가 필요합니다.' }, 400);
          }
          try {
            return json(await updateServiceState(env, input));
          } catch (_) {
            return json({ error: 'service_control_unavailable', message: '서비스 상태를 저장할 수 없습니다.' }, 503);
          }
        }
        return json({ error: 'method_not_allowed' }, 405);
      }

      // ── 앱 버전 매니페스트(공개) — 앱 자동 업데이트 확인용
      if (pathname === '/v1/app/version' && method === 'GET') {
        return json(await getVersionManifest(env));
      }

      // ── 원격 앱 설정(공개 GET) — 학습앱이 시작 시 pull → 관리자 설정 자동 반영
      //    (권한/구독/점수 판정값은 포함하지 않음. 기능 플래그/공지/최소버전/활성트랙만.)
      if (pathname === '/v1/app/config' && method === 'GET') {
        return json(await handleGetConfig(env));
      }

      // ── 폰 앱 토큰 검증(Access 불필요, 앱 토큰 자체 검증) — 앱이 무제한 모드 켤 때 호출
      //    반드시 /v1/admin/* 일반 처리보다 먼저 둔다(앱 토큰 경로).
      if (pathname === '/v1/admin/verify' && method === 'GET') {
        return json(await verifyAppTokenEndpoint(request, env));
      }

      // 앱 로그인: Google ID token을 서버에서 검증한 뒤 API 세션을 발급한다.
      if (pathname === '/v1/auth/google' && method === 'POST') {
        return json(await signInWithGoogle(env, await request.json()));
      }
      if (pathname === '/v1/auth/kakao' && method === 'POST') {
        return json(await signInWithKakao(env, await request.json()));
      }

      // ── 폰앱용 토큰 발급(대시보드가 호출, Cloudflare Access JWT 필요)
      if (pathname === '/v1/admin/issue-app-token' && (method === 'POST' || method === 'GET')) {
        return json(await issueAppToken(request, env));
      }

      // ── 관리자 전용 라우트(Access JWT[대시보드] 또는 앱 토큰[폰] 필요)
      if (pathname.startsWith('/v1/admin/')) {
        await requireAdmin(request, env); // 실패 시 throw 403
        if (pathname === '/v1/admin/users' && method === 'GET') {
          const page = parseInt(url.searchParams.get('page') || '1', 10);
          return json(await adminListUsers(env, page));
        }
        if (pathname === '/v1/admin/user/plan' && method === 'POST') {
          return json(await adminSetUserPlan(env, await request.json()));
        }
        if (pathname === '/v1/admin/stats' && method === 'GET') {
          return json(await adminStats(env));
        }
        if (pathname === '/v1/admin/blog-drafts' && method === 'GET') {
          const limitValue = url.searchParams.get('limit');
          const limit = limitValue === null ? 50 : parseInt(limitValue, 10);
          return json(await listBlogDrafts(env, {
            status: url.searchParams.get('status') || '',
            limit,
          }));
        }
        const draftReviewMatch = pathname.match(/^\/v1\/admin\/blog-drafts\/([A-Za-z0-9_-]{1,80})\/review$/);
        if (draftReviewMatch && method === 'POST') {
          let body;
          try {
            body = await request.json();
          } catch (_) {
            return json({ error: 'bad_request', message: 'JSON 본문이 필요합니다.' }, 400);
          }
          return json({ item: await reviewBlogDraft(env, draftReviewMatch[1], body) });
        }
        if (pathname === '/v1/admin/version' && method === 'POST') {
          return json(await adminSetVersionManifest(env, await request.json()));
        }
        return json({ error: 'not_found' }, 404);
      }

      // ── 원격 앱 설정 배포(관리자 전용) — 관리자 콘솔의 "배포" 버튼이 호출.
      //    /v1/admin/* 접두사가 아니므로 여기서 명시적으로 requireAdmin 게이트를 건다.
      if (pathname === '/v1/app/config' && (method === 'PUT' || method === 'POST')) {
        await requireAdmin(request, env); // 실패 시 throw 403
        return json(await handlePutConfig(env, await request.json()));
      }

      // ── 인증 필요 라우트
      const session = await requireSession(request, env); // 실패 시 throw 401
      let m;

      if (pathname === '/v1/tracks' && method === 'GET') {
        return json(await getTrackCatalog(env));
      }

      if (pathname === '/v1/auth/logout' && method === 'POST') {
        return json(await revokeSession(env, session.claims));
      }

      if ((m = pathname.match(/^\/v1\/tracks\/([^/]+)\/exams$/)) && method === 'GET') {
        return json(await listExams(env, m[1]));
      }

      if ((m = pathname.match(/^\/v1\/exams\/([^/]+)\/([^/]+)\/paper$/)) && method === 'GET') {
        return json(await getExamPaper(env, session.userId, m[1], m[2]));
      }

      if ((m = pathname.match(/^\/v1\/study\/([^/]+)\/([^/]+)\/([^/]+)$/)) && method === 'GET') {
        const response = await getStudyFile(env, m[1], m[2], m[3]);
        return new Response(response.body, {
          status: response.status,
          headers: {
            'Content-Type': response.headers.get('Content-Type') || 'application/json',
            'Cache-Control': 'no-store',
            'Access-Control-Allow-Origin': '*',
          },
        });
      }

      if ((m = pathname.match(/^\/v1\/question-images\/([^/]+)\/(.+)$/)) && method === 'GET') {
        return await getQuestionImage(env, m[1], decodeURIComponent(m[2]));
      }

      // 구독 상태
      if (pathname === '/v1/entitlement' && method === 'GET') {
        return json(await getEntitlement(env, session.userId));
      }

      // 문제 목록(메타만, 무료 10% 게이트 적용)
      if ((m = pathname.match(/^\/v1\/exams\/([^/]+)\/([^/]+)\/questions$/)) && method === 'GET') {
        const page = parseInt(url.searchParams.get('page') || '1', 10);
        return json(await listQuestions(env, session.userId, m[1], m[2], page));
      }

      // 단일 문제 본문(정답 제외)
      if ((m = pathname.match(/^\/v1\/questions\/(.+)$/)) && method === 'GET') {
        return json(await getQuestion(env, session.userId, decodeURIComponent(m[1])));
      }

      // 채점(정답/해설은 여기서만 반환)
      if (pathname === '/v1/quiz/grade' && method === 'POST') {
        return json(await gradeQuiz(env, session.userId, await request.json()));
      }

      // AI 튜터 프록시(무료 30% 게이트)
      if (pathname === '/v1/ai/chat' && method === 'POST') {
        return json(await aiChat(env, session.userId, await request.json()));
      }

      // 결제 영수증 검증
      if (pathname === '/v1/billing/verify' && method === 'POST') {
        return json(await verifyPurchase(env, session.userId, await request.json()));
      }

      // 학습 진도·점수 (SSOT) — pull/push. 서버가 최종 병합·판정.
      if (pathname === '/v1/progress' && method === 'GET') {
        return json(await getProgress(env, session.userId));
      }
      if (pathname === '/v1/progress' && method === 'POST') {
        let input;
        try {
          input = await readJsonBodyLimited(request, MAX_SNAPSHOT_BYTES);
        } catch (error) {
          return json(
            { error: error.code || 'bad_request', message: error.message },
            error.status || 400,
          );
        }
        return json(await putProgress(env, session.userId, input));
      }

      return json({ error: 'not_found' }, 404);
    } catch (e) {
      const status = e.status || 500;
      return json({ error: e.code || 'server_error', message: e.message }, status);
    }
    })();

    if (controlPlane) return response;
    try {
      const state = await getServiceState(env);
      return state.enabled ? response : serviceDisabled(state.message);
    } catch (_) {
      return json({ error: 'service_control_unavailable', message: '서비스 상태를 확인할 수 없습니다.' }, 503);
    }
  },
  async scheduled(controller, env, ctx) {
    const task = generateDailyDrafts(env, controller.scheduledTime);
    if (ctx?.waitUntil) ctx.waitUntil(task);
    return await task;
  },
};

async function readJsonBodyLimited(request, maxBytes) {
  const declaredLength = request.headers.get('Content-Length');
  if (declaredLength !== null) {
    const length = Number(declaredLength);
    if (Number.isSafeInteger(length) && length > maxBytes) {
      throw Object.assign(new Error('진도 데이터가 허용 크기를 초과했습니다.'), {
        status: 413,
        code: 'progress_too_large',
      });
    }
  }

  const reader = request.body?.getReader();
  if (!reader) throw Object.assign(new Error('올바른 JSON 본문이 필요합니다.'), {
    status: 400,
    code: 'bad_request',
  });

  const chunks = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > maxBytes) {
      await reader.cancel();
      throw Object.assign(new Error('진도 데이터가 허용 크기를 초과했습니다.'), {
        status: 413,
        code: 'progress_too_large',
      });
    }
    chunks.push(value);
  }

  const bytes = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  try {
    return JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(bytes));
  } catch (_) {
    throw Object.assign(new Error('올바른 JSON 본문이 필요합니다.'), {
      status: 400,
      code: 'bad_request',
    });
  }
}

export { ServiceControl };
