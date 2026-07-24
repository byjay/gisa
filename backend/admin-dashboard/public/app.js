// Gisaclub 운영자 대시보드 프론트엔드
//
// [인증 흐름]
//  이 페이지(admin.gisa.club)는 Cloudflare Access 뒤에 있으므로, 여기 도달했다는 것
//  자체가 "지정 운영자 Google 로그인 통과"를 의미한다. 브라우저는 Access 쿠키
//  (CF_Authorization)를 보유하며, 같은 Zero Trust로 보호되는 API 호출 시 이 쿠키가
//  Cf-Access-Jwt-Assertion으로 백엔드에 전달된다.
//
// [API_BASE]
//  Worker API 주소. admin.gisa.club 과 api.gisa.club 이 같은 Access 정책으로
//  보호되면 credentials:'include' 로 쿠키가 전달된다.
const API_BASE = 'https://api.gisa.club';

let _lastToken = '';

function toast(msg) {
  const t = document.getElementById('toast');
  t.textContent = msg;
  t.classList.add('show');
  setTimeout(() => t.classList.remove('show'), 2200);
}

async function api(path, opts = {}) {
  const resp = await fetch(API_BASE + path, {
    credentials: 'include', // Access 쿠키 전달
    headers: { 'Content-Type': 'application/json', ...(opts.headers || {}) },
    ...opts,
  });
  if (!resp.ok) {
    const body = await resp.text().catch(() => '');
    throw new Error(`${resp.status} ${body}`);
  }
  return resp.json();
}

// 접속한 운영자 이메일 표시(Access identity)
async function loadWho() {
  try {
    const resp = await fetch('/cdn-cgi/access/get-identity', { credentials: 'include' });
    if (resp.ok) {
      const id = await resp.json();
      document.getElementById('who').textContent = id.email || id.name || '운영자';
      return;
    }
  } catch (_) {}
  document.getElementById('who').textContent = '운영자';
}

// 폰 앱 토큰 발급
async function issueToken() {
  const btn = document.getElementById('issueBtn');
  btn.disabled = true;
  try {
    const data = await api('/v1/admin/issue-app-token', { method: 'POST', body: '{}' });
    _lastToken = data.token || '';
    const box = document.getElementById('tokenBox');
    box.style.display = 'block';
    box.textContent = _lastToken;
    document.getElementById('copyBtn').disabled = false;
    toast('앱 토큰이 발급되었습니다 (유효 30일)');
  } catch (e) {
    toast('발급 실패: ' + e.message);
  } finally {
    btn.disabled = false;
  }
}

async function copyToken() {
  if (!_lastToken) return;
  try {
    await navigator.clipboard.writeText(_lastToken);
    toast('토큰을 클립보드에 복사했습니다');
  } catch (_) {
    toast('복사 실패 — 직접 선택해 복사하세요');
  }
}

// 통계
async function loadStats() {
  try {
    const s = await api('/v1/admin/stats');
    document.getElementById('stTotal').textContent = s.totalUsers ?? '–';
    document.getElementById('stPremium').textContent = s.premiumUsers ?? '–';
    document.getElementById('stFree').textContent = s.freeUsers ?? '–';
  } catch (e) {
    toast('통계 로드 실패: ' + e.message);
  }
}

// 버전 매니페스트
async function loadVersion() {
  try {
    const v = await api('/v1/app/version');
    document.getElementById('vVersion').value = v.latest_version || '';
    document.getElementById('vBuild').value = v.latest_build || 1;
    document.getElementById('vMin').value = v.min_supported_build || 1;
    document.getElementById('vForce').value = String(!!v.force);
    document.getElementById('vStore').value = v.store_url || '';
    document.getElementById('vApk').value = v.apk_url || '';
    document.getElementById('vNotes').value = v.release_notes || '';
    toast('현재 버전 정보를 불러왔습니다');
  } catch (e) {
    toast('불러오기 실패: ' + e.message);
  }
}

async function saveVersion() {
  const body = {
    latest_version: document.getElementById('vVersion').value.trim(),
    latest_build: parseInt(document.getElementById('vBuild').value, 10),
    min_supported_build: parseInt(document.getElementById('vMin').value, 10),
    force: document.getElementById('vForce').value === 'true',
    store_url: document.getElementById('vStore').value.trim(),
    apk_url: document.getElementById('vApk').value.trim(),
    release_notes: document.getElementById('vNotes').value.trim(),
  };
  try {
    await api('/v1/admin/version', { method: 'POST', body: JSON.stringify(body) });
    toast('✅ 버전 매니페스트 저장 완료 — 사용자 앱에 업데이트가 표시됩니다');
  } catch (e) {
    toast('저장 실패: ' + e.message);
  }
}

// 사용자
async function loadUsers() {
  try {
    const data = await api('/v1/admin/users?page=1');
    const tbody = document.querySelector('#usersTbl tbody');
    const users = data.users || [];
    if (!users.length) {
      tbody.innerHTML = '<tr><td colspan="4" class="muted">사용자가 없습니다</td></tr>';
      return;
    }
    tbody.innerHTML = users
      .map((u) => {
        const pill = u.plan === 'premium'
          ? '<span class="pill premium">premium</span>'
          : '<span class="pill free">free</span>';
        return `<tr><td>${u.id ?? ''}</td><td>${u.email ?? ''}</td><td>${pill}</td><td>${u.expiry ?? '-'}</td></tr>`;
      })
      .join('');
    toast(`사용자 ${users.length}명 로드됨 (전체 ${data.total ?? '?'})`);
  } catch (e) {
    toast('사용자 로드 실패: ' + e.message);
  }
}

async function setPlan() {
  const userId = document.getElementById('uId').value.trim();
  const plan = document.getElementById('uPlan').value;
  if (!userId) { toast('사용자 ID를 입력하세요'); return; }
  const expiry = plan === 'premium'
    ? new Date(Date.now() + 365 * 864e5).toISOString()
    : null;
  try {
    await api('/v1/admin/user/plan', {
      method: 'POST',
      body: JSON.stringify({ userId, plan, expiry }),
    });
    toast(`✅ ${userId} → ${plan} 설정 완료`);
    loadUsers();
  } catch (e) {
    toast('설정 실패: ' + e.message);
  }
}

// 초기화
loadWho();
loadStats();
loadVersion();
