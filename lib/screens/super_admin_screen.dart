import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/admin_service.dart';
import '../services/app_update_service.dart';
import '../services/cerebras_service.dart';
import '../services/crash_logger.dart';
import '../services/entitlement_service.dart';
import '../services/exam_track.dart';
import 'admin_settings_screen.dart';

/// 🛡️ 슈퍼 관리자(운영자) 대시보드.
///
/// 관리자 로그인 전에는 잠금 화면을, 로그인 후에는 운영 대시보드를 보여준다.
/// - 관리자 오버라이드 상태(AI/프리미엄/전콘텐츠 무제한) 표시
/// - 콘텐츠(종목·과목 노출) 관리 진입
/// - 구독/권한 강제 설정(시연용)
/// - AI 설정(관리자 키 상태)
/// - 앱 자동 업데이트 확인·실행
/// - 시스템 진단(오류 로그, 학습 데이터 통계)
class SuperAdminScreen extends StatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  State<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends State<SuperAdminScreen> {
  final _tokenCtrl = TextEditingController();

  @override
  void dispose() {
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _registerToken() async {
    final admin = AdminService.instance;
    final token = _tokenCtrl.text.trim();
    if (token.isEmpty) {
      setState(() {});
      return;
    }
    final result = await admin.registerToken(token);
    if (!mounted) return;
    switch (result) {
      case AdminAuthResult.success:
        _tokenCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('🛡️ 관리자 모드가 활성화되었습니다. 모든 기능이 무제한입니다.')),
        );
        break;
      case AdminAuthResult.invalidToken:
        _showError('토큰이 유효하지 않거나 만료되었습니다. admin.gisa.club에서 새 토큰을 발급받으세요.');
        break;
      case AdminAuthResult.notConfigured:
        _showError('서버 주소(GISACLUB_API_BASE)가 설정되지 않았습니다. 배포 빌드에서만 사용 가능합니다.');
        break;
      case AdminAuthResult.network:
        _showError('서버에 연결할 수 없습니다. 네트워크 상태를 확인하세요.');
        break;
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700),
    );
  }

  Future<void> _pasteToken() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      _tokenCtrl.text = data.text!.trim();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('슈퍼 관리자'),
        actions: [
          if (admin.isAdmin)
            IconButton(
              tooltip: '관리자 로그아웃',
              icon: const Icon(Icons.logout_rounded),
              onPressed: () async {
                await AdminService.instance.logout();
                if (mounted) setState(() {});
              },
            ),
        ],
      ),
      body: admin.isAdmin ? _dashboard(context) : _lockScreen(context),
    );
  }

  // ─────────────── 잠금(토큰 등록) 화면 ───────────────
  Widget _lockScreen(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final admin = context.watch<AdminService>();
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.admin_panel_settings_rounded,
                  size: 72, color: cs.primary),
              const SizedBox(height: 16),
              Text('운영자 인증',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              // 안내: Access 게이트 방식 설명
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.verified_user_rounded,
                            size: 18, color: cs.primary),
                        const SizedBox(width: 6),
                        Text('토큰 발급 방법',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: cs.primary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '① 브라우저에서 admin.gisa.club 접속\n'
                      '② Google 계정으로 로그인 (Cloudflare Access가 지정된\n'
                      '   운영자 이메일만 통과시킵니다)\n'
                      '③ 대시보드에서 "앱 토큰 발급" → 토큰 복사\n'
                      '④ 아래에 붙여넣고 등록',
                      style: TextStyle(fontSize: 12.5, height: 1.55),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _tokenCtrl,
                maxLines: 3,
                minLines: 1,
                decoration: InputDecoration(
                  labelText: '관리자 토큰',
                  hintText: 'admin.gisa.club 에서 발급받은 토큰 붙여넣기',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: '붙여넣기',
                    icon: const Icon(Icons.content_paste_rounded),
                    onPressed: _pasteToken,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (admin.isVerifying || _tokenCtrl.text.trim().isEmpty)
                      ? null
                      : _registerToken,
                  icon: admin.isVerifying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.lock_open_rounded),
                  label: Text(admin.isVerifying ? '서버 검증 중…' : '관리자 토큰 등록'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!admin.isConfigured)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.errorContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '⚠️ 서버 주소가 설정되지 않은 빌드입니다. 배포 빌드\n'
                    '(--dart-define=GISACLUB_API_BASE=https://api.gisa.club)\n'
                    '에서만 관리자 토큰을 검증할 수 있습니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11.5, color: cs.error),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                '🔒 인증·판정은 Cloudflare Access + 서버가 수행합니다.\n'
                '앱 안에는 비밀번호·이메일 판정 로직이 없습니다.\n'
                '일반 사용자는 이 화면과 무관하게 앱을 그대로 사용합니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    color: cs.onSurface.withValues(alpha: 0.55)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────── 대시보드 ───────────────
  Widget _dashboard(BuildContext context) {
    final app = context.watch<AppProvider>();
    final ent = context.watch<EntitlementService>();
    final update = context.watch<AppUpdateService>();
    final wide = MediaQuery.of(context).size.width > 800;

    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: wide ? (MediaQuery.of(context).size.width - 720) / 2 : 14,
        vertical: 14,
      ),
      children: [
        _overrideBanner(context, ent),
        const SizedBox(height: 16),
        _sectionTitle(context, '운영 요약'),
        _statsCard(context, app),
        const SizedBox(height: 16),
        _sectionTitle(context, '콘텐츠 · 기능 관리'),
        _contentCard(context),
        const SizedBox(height: 16),
        _sectionTitle(context, '구독 · 권한 (시연/테스트)'),
        _entitlementCard(context, ent),
        const SizedBox(height: 16),
        _sectionTitle(context, 'AI 튜터 설정'),
        _aiCard(context),
        const SizedBox(height: 16),
        _sectionTitle(context, '앱 자동 업데이트'),
        _updateCard(context, update),
        const SizedBox(height: 16),
        _sectionTitle(context, '시스템 진단'),
        _diagnosticsCard(context),
        const SizedBox(height: 16),
        _sectionTitle(context, '보안'),
        _securityCard(context),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _overrideBanner(BuildContext context, EntitlementService ent) {
    return Card(
      color: Colors.green.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.verified_user_rounded,
                color: Colors.green, size: 32),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('관리자 오버라이드 활성',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text(
                    'AI 튜터 무제한 · 전 콘텐츠(기출·해설·심화) 잠금 해제 · 프리미엄 전 기능 활성.\n테스트 기간/무료 제한이 운영자 계정에는 적용되지 않습니다.',
                    style: TextStyle(fontSize: 12.5, height: 1.45),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statsCard(BuildContext context, AppProvider app) {
    final items = <(String, String, IconData)>[
      ('총 학습 시간', '${app.totalMinutes}분', Icons.schedule_rounded),
      ('누적 풀이', '${app.lifetimeSolved}문항', Icons.quiz_rounded),
      ('정답률', '${app.overallAccuracy}%', Icons.check_circle_rounded),
      ('연속 학습', '${app.streak}일', Icons.local_fire_department_rounded),
      ('레벨 / XP', 'Lv.${app.level} · ${app.xp}XP', Icons.stars_rounded),
      ('완료 시험세션', '${app.completedQuizSessions}회', Icons.assignment_turned_in_rounded),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final it in items)
              SizedBox(
                width: 210,
                child: Row(
                  children: [
                    Icon(it.$3, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(it.$1,
                              style: const TextStyle(fontSize: 11.5)),
                          Text(it.$2,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _contentCard(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.tune_rounded),
            title: const Text('종목·과목 노출 관리'),
            subtitle: const Text('이론/문제풀이/CBT/암기카드/AI튜터 기능 노출과 과목 활성화'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const AdminSettingsScreen())),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.library_books_rounded),
            title: const Text('등록 종목'),
            subtitle: Text('총 ${kExamTracks.length}개 트랙 탑재'),
            trailing: Text('${kExamTracks.length}',
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _entitlementCard(BuildContext context, EntitlementService ent) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(ent.isPremium
                ? Icons.workspace_premium_rounded
                : Icons.person_outline_rounded),
            title: Text('현재 등급: ${ent.isPremium ? "프리미엄" : "무료"}'
                '${ent.isAdminOverride ? " (관리자 오버라이드)" : ""}'),
            subtitle: Text(ent.expiry != null
                ? '만료: ${ent.expiry!.toLocal().toString().split(" ").first}'
                : '만료일 없음'),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.card_giftcard_rounded),
                    label: const Text('프리미엄 30일 부여'),
                    onPressed: () async {
                      await ent.adminSetPlan(PlanTier.premium,
                          expiry:
                              DateTime.now().add(const Duration(days: 30)));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('프리미엄 30일 부여됨(로컬 시연용)')),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('무료로 초기화'),
                    onPressed: () async {
                      await ent.adminSetPlan(PlanTier.free);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('무료 등급으로 초기화됨')),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              '⚠️ 이 설정은 현재 기기의 로컬 캐시(시연용)입니다. 실제 유료 권한은 서버(Cloudflare)가 최종 판정합니다.',
              style: TextStyle(fontSize: 11.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aiCard(BuildContext context) {
    return Card(
      child: FutureBuilder<bool>(
        future: CerebrasService.instance.hasKey(),
        builder: (context, snap) {
          final hasKey = snap.data ?? false;
          return ListTile(
            leading: Icon(hasKey ? Icons.smart_toy_rounded : Icons.key_off_rounded,
                color: hasKey ? Colors.green : null),
            title: Text(hasKey ? 'AI 튜터 사용 준비 완료' : 'AI 키 미설정'),
            subtitle: Text(hasKey
                ? '관리자 오버라이드 또는 저장된 키로 무제한 사용 가능합니다.'
                : '관리자 키(빌드 주입) 또는 사용자 키 설정 시 활성화됩니다.'),
          );
        },
      ),
    );
  }

  Widget _updateCard(BuildContext context, AppUpdateService update) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(update.updateAvailable
                ? Icons.system_update_rounded
                : Icons.verified_rounded,
                color: update.updateAvailable ? cs.primary : Colors.green),
            title: Text(update.updateAvailable
                ? '새 버전 ${update.latestVersion} 사용 가능'
                : '최신 버전입니다 (v${AppUpdateService.currentVersion})'),
            subtitle: Text(update.updateAvailable
                ? (update.releaseNotes.isEmpty
                    ? '버튼 한 번으로 업데이트하세요.'
                    : update.releaseNotes)
                : update.checked
                    ? '업데이트 확인 완료'
                    : '확인 중...'),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('업데이트 확인'),
                    onPressed: () async {
                      await update.checkForUpdate();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(update.updateAvailable
                                  ? '새 버전이 있습니다: ${update.latestVersion}'
                                  : '이미 최신 버전입니다.')),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('지금 업데이트'),
                    onPressed: update.updateAvailable
                        ? () async {
                            final ok = await update.performUpdate();
                            if (context.mounted && !ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('업데이트 링크를 열 수 없습니다.')),
                              );
                            }
                          }
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _diagnosticsCard(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.bug_report_rounded),
        title: const Text('오류 로그 보기'),
        subtitle: const Text('앱에서 기록된 최근 오류(로컬 저장, 외부 전송 없음)'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _openCrashLogs(context),
      ),
    );
  }

  Widget _securityCard(BuildContext context) {
    final admin = context.watch<AdminService>();
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.verified_user_rounded),
            title: const Text('검증된 관리자 계정'),
            subtitle: Text(admin.email.isEmpty ? '(정보 없음)' : admin.email),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.dns_rounded),
            title: const Text('서버 주소'),
            subtitle: Text(admin.apiBase.isEmpty ? '(미설정)' : admin.apiBase),
          ),
          const Divider(height: 1),
          const ListTile(
            leading: Icon(Icons.security_rounded),
            title: Text('보안 방식 — Cloudflare Access(Zero Trust)'),
            subtitle: Text(
              '앱 안에는 PIN·비밀번호·이메일 판정 로직이 전혀 없습니다.\n'
              'admin.gisa.club 앞단에서 Cloudflare Access가 Google 로그인을 걸고\n'
              '지정된 운영자 이메일만 통과시킨 뒤 앱 토큰을 발급합니다. 앱은 이 토큰을\n'
              '서버(/v1/admin/verify)로 재검증받아야만 무제한 모드가 열립니다.\n'
              '(변조·디컴파일로 우회 불가 — 판정 권한이 항상 서버에 있음)',
            ),
            isThreeLine: true,
          ),
        ],
      ),
    );
  }

  Future<void> _openCrashLogs(BuildContext context) async {
    final records = await CrashLogger.instance.getAll();
    if (!context.mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          builder: (ctx, scroll) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text('오류 로그',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_all_rounded),
                        tooltip: '전체 복사',
                        onPressed: () async {
                          final text =
                              await CrashLogger.instance.exportText();
                          await Clipboard.setData(ClipboardData(text: text));
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('로그를 복사했습니다.')),
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded),
                        tooltip: '전체 삭제',
                        onPressed: () async {
                          await CrashLogger.instance.clear();
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: records.isEmpty
                      ? const Center(child: Text('기록된 오류가 없습니다.'))
                      : ListView.separated(
                          controller: scroll,
                          itemCount: records.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final r = records[records.length - 1 - i];
                            return ListTile(
                              dense: true,
                              title: Text(r.message,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                  r.time.toLocal().toString().split('.').first,
                                  style: const TextStyle(fontSize: 11)),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
      );
}
