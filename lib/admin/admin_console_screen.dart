import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/admin_service.dart';
import '../services/app_config.dart';
import '../services/remote_config_service.dart';
import '../theme/app_theme.dart';
import 'admin_config_api.dart';

/// 🛠️ 관리자 콘솔 — 알렉스(운영자)가 학습앱을 원격 조종하는 화면.
///
/// 여기서 세팅하고 [배포]를 누르면 서버(`PUT /v1/app/config`)에 저장되고,
/// 학습앱은 다음 실행/새로고침 때 `/v1/app/config`에서 pull 하여 자동 반영한다.
class AdminConsoleScreen extends StatefulWidget {
  const AdminConsoleScreen({super.key});

  @override
  State<AdminConsoleScreen> createState() => _AdminConsoleScreenState();
}

class _AdminConsoleScreenState extends State<AdminConsoleScreen> {
  // 편집 중 상태(로컬). 배포 시 서버로 전송.
  bool _aiTutor = true;
  bool _handwriting = true;
  bool _promoBanner = false;
  int _freePercent = 10;

  final _noticeCtrl = TextEditingController();
  String _noticeLevel = 'info';
  final _noticeLinkCtrl = TextEditingController();

  final _minBuildCtrl = TextEditingController(text: '0');
  final _latestVerCtrl = TextEditingController();
  final _apkUrlCtrl = TextEditingController();
  bool _forcedUpdate = false;

  final _tracksCtrl = TextEditingController(); // 콤마 구분

  int _serverVersion = 0;
  int _serverUpdatedAt = 0;
  bool _loading = true;
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCurrent());
  }

  @override
  void dispose() {
    _noticeCtrl.dispose();
    _noticeLinkCtrl.dispose();
    _minBuildCtrl.dispose();
    _latestVerCtrl.dispose();
    _apkUrlCtrl.dispose();
    _tracksCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCurrent() async {
    setState(() => _loading = true);
    final cfg = await AdminConfigApi.instance.fetch();
    if (cfg != null) _applyToForm(cfg);
    if (mounted) setState(() => _loading = false);
  }

  void _applyToForm(RemoteAppConfig c) {
    _aiTutor = c.features.aiTutorEnabled;
    _handwriting = c.features.handwritingEnabled;
    _promoBanner = c.features.promoBannerEnabled;
    _freePercent = c.features.freeQuestionPercent;
    _noticeCtrl.text = c.notice.text;
    _noticeLevel = c.notice.level;
    _noticeLinkCtrl.text = c.notice.linkUrl;
    _minBuildCtrl.text = c.update.minSupportedBuild.toString();
    _latestVerCtrl.text = c.update.latestVersion;
    _apkUrlCtrl.text = c.update.apkUrl;
    _forcedUpdate = c.update.forced;
    _tracksCtrl.text = c.activeTracks.join(', ');
    _serverVersion = c.version;
    _serverUpdatedAt = c.updatedAt;
  }

  RemoteAppConfig _buildFromForm() {
    final tracks = _tracksCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return RemoteAppConfig(
      version: _serverVersion,
      updatedAt: _serverUpdatedAt,
      features: RemoteFeatures(
        aiTutorEnabled: _aiTutor,
        handwritingEnabled: _handwriting,
        freeQuestionPercent: _freePercent,
        promoBannerEnabled: _promoBanner,
      ),
      notice: RemoteNotice(
        text: _noticeCtrl.text.trim(),
        level: _noticeLevel,
        linkUrl: _noticeLinkCtrl.text.trim(),
      ),
      update: RemoteUpdateGate(
        minSupportedBuild: int.tryParse(_minBuildCtrl.text.trim()) ?? 0,
        latestBuild: int.tryParse(_minBuildCtrl.text.trim()) ?? 0,
        latestVersion: _latestVerCtrl.text.trim(),
        apkUrl: _apkUrlCtrl.text.trim(),
        forced: _forcedUpdate,
      ),
      activeTracks: tracks,
    );
  }

  Future<void> _publish() async {
    setState(() => _publishing = true);
    final result = await AdminConfigApi.instance.publish(_buildFromForm());
    if (!mounted) return;
    setState(() => _publishing = false);
    if (result.ok && result.config != null) {
      _applyToForm(result.config!);
      _snack('✅ 배포 완료 (v$_serverVersion) — 학습앱이 다음 실행 때 자동 반영됩니다.',
          AppTheme.success);
    } else {
      _snack('❌ ${result.message}', AppTheme.danger);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('관리자 콘솔 · 원격 설정'),
        actions: [
          IconButton(
            tooltip: '현재 서버값 새로고침',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadCurrent,
          ),
        ],
      ),
      body: !AppConfig.hasApi
          ? _notConfigured()
          : !admin.isAdmin
              ? _needAuth()
              : _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _form(),
      bottomNavigationBar: (AppConfig.hasApi && admin.isAdmin && !_loading)
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: _publishing ? null : _publish,
                  icon: _publishing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_upload),
                  label: Text(_publishing ? '배포 중…' : '학습앱에 배포하기'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _notConfigured() => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            '서버(API_BASE_URL)가 설정되지 않았습니다.\n\n'
            '관리자 앱을 다음처럼 빌드하세요:\n'
            'flutter build apk --release --flavor admin \\\n'
            '  --dart-define=API_BASE_URL=https://<worker>.workers.dev \\\n'
            '  --dart-define=WEB_BASE_URL=https://<pages>.pages.dev',
            textAlign: TextAlign.center,
          ),
        ),
      );

  Widget _needAuth() => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 56, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            const Text(
              '관리자 인증이 필요합니다.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '관리자 대시보드에서 발급받은 토큰을 등록하세요.\n'
              '${AdminService.instance.dashboardUrl.isNotEmpty ? AdminService.instance.dashboardUrl : "(대시보드 URL 미설정)"}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _promptToken,
              icon: const Icon(Icons.vpn_key),
              label: const Text('관리자 토큰 등록'),
            ),
          ],
        ),
      );

  Future<void> _promptToken() async {
    final ctrl = TextEditingController();
    final token = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('관리자 토큰 등록'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: '대시보드에서 발급받은 토큰 붙여넣기',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('등록'),
          ),
        ],
      ),
    );
    if (token == null || token.trim().isEmpty) return;
    final result = await AdminService.instance.registerToken(token);
    if (!mounted) return;
    switch (result) {
      case AdminAuthResult.success:
        _snack('✅ 관리자 인증 성공', AppTheme.success);
        _loadCurrent();
        break;
      case AdminAuthResult.invalidToken:
        _snack('❌ 토큰이 유효하지 않습니다.', AppTheme.danger);
        break;
      case AdminAuthResult.notConfigured:
        _snack('❌ 서버가 설정되지 않았습니다.', AppTheme.danger);
        break;
      case AdminAuthResult.network:
        _snack('❌ 네트워크 오류. 다시 시도하세요.', AppTheme.danger);
        break;
    }
  }

  Widget _form() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _versionBadge(),
        const SizedBox(height: 12),
        _sectionCard('기능 스위치', Icons.toggle_on, [
          SwitchListTile(
            title: const Text('AI 튜터 사용'),
            subtitle: const Text('학습앱에서 AI 튜터 노출/사용 여부'),
            value: _aiTutor,
            onChanged: (v) => setState(() => _aiTutor = v),
          ),
          SwitchListTile(
            title: const Text('필기 인식 사용'),
            value: _handwriting,
            onChanged: (v) => setState(() => _handwriting = v),
          ),
          SwitchListTile(
            title: const Text('프리미엄 프로모션 배너'),
            subtitle: const Text('학습앱 홈에 프로모션 배너 표시'),
            value: _promoBanner,
            onChanged: (v) => setState(() => _promoBanner = v),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('무료 사용자 문항 노출: $_freePercent%'),
                Slider(
                  value: _freePercent.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 20,
                  label: '$_freePercent%',
                  onChanged: (v) =>
                      setState(() => _freePercent = v.round()),
                ),
              ],
            ),
          ),
        ]),
        _sectionCard('공지 배너', Icons.campaign, [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _noticeCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '공지 문구 (비우면 미표시)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _noticeLevel,
                  decoration: const InputDecoration(
                    labelText: '중요도',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'info', child: Text('일반(info)')),
                    DropdownMenuItem(value: 'warn', child: Text('주의(warn)')),
                    DropdownMenuItem(
                        value: 'urgent', child: Text('긴급(urgent)')),
                  ],
                  onChanged: (v) =>
                      setState(() => _noticeLevel = v ?? 'info'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _noticeLinkCtrl,
                  decoration: const InputDecoration(
                    labelText: '링크 URL (선택)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ]),
        _sectionCard('업데이트 게이트', Icons.system_update, [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _minBuildCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '최소 지원 빌드번호 (미만이면 강제 업데이트)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _latestVerCtrl,
                  decoration: const InputDecoration(
                    labelText: '최신 버전명 (예: 1.1.0)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _apkUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'APK 다운로드 URL',
                    border: OutlineInputBorder(),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('강제 업데이트'),
                  value: _forcedUpdate,
                  onChanged: (v) => setState(() => _forcedUpdate = v),
                ),
              ],
            ),
          ),
        ]),
        _sectionCard('활성 자격증 트랙', Icons.school, [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _tracksCtrl,
              decoration: const InputDecoration(
                labelText: '트랙 ID 콤마 구분 (비우면 앱 내장 기본값)',
                hintText: 'electrical, fire, ...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _versionBadge() {
    final when = _serverUpdatedAt > 0
        ? DateTime.fromMillisecondsSinceEpoch(_serverUpdatedAt)
        : null;
    return Card(
      color: AppTheme.primary.withValues(alpha: 0.08),
      child: ListTile(
        leading: const Icon(Icons.verified, color: AppTheme.primary),
        title: Text('현재 배포 버전: v$_serverVersion'),
        subtitle: Text(when != null
            ? '마지막 배포: ${when.toString().substring(0, 16)}'
            : '아직 배포된 설정이 없습니다 (기본값 사용 중)'),
      ),
    );
  }

  Widget _sectionCard(String title, IconData icon, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                Icon(icon, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
