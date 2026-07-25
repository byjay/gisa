// Gisaclub API — Cloudflare Worker 엔트리(라우팅)
// 보안 원칙: 정답/해설은 채점 API에서만 반환, 무료 게이트는 서버가 최종 판정.
import { requireSession } from './auth.js';
import { getEntitlement } from './entitlement.js';
import { listQuestions, getQuestion, gradeQuiz } from './content.js';
import { aiChat } from './ai.js';
import { verifyPurchase } from './billing.js';
import { getProgress, putProgress } from './progress.js';
import { handleGetConfig, handlePutConfig } from './appconfig.js';
import { issueAppToken, verifyAppTokenEndpoint, requireAdmin, adminListUsers, adminSetUserPlan, adminStats, getVersionManifest, adminSetVersionManifest } from './admin.js';

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

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const { pathname } = url;
    const method = request.method;

    if (method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
          'Access-Control-Allow-Headers': 'Authorization,Content-Type',
        },
      });
    }

    try {
      // ── 헬스체크(공개)
      if (pathname === '/v1/health') return json({ ok: true });

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

      // 구독 상태
      if (pathname === '/v1/entitlement' && method === 'GET') {
        return json(await getEntitlement(env, session.userId));
      }

      // 문제 목록(메타만, 무료 10% 게이트 적용)
      let m;
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
        return json(await putProgress(env, session.userId, await request.json()));
      }

      return json({ error: 'not_found' }, 404);
    } catch (e) {
      const status = e.status || 500;
      return json({ error: e.code || 'server_error', message: e.message }, status);
    }
  },
};
