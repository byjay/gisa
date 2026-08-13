import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/admin_service.dart';
import '../services/ads_config.dart';
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

  // ── 광고(AdMob) ────────────────────────────────────────────────
  // 광고 ID 는 운영 중에 바뀌므로 원격설정으로 다룬다(ads_config.dart 주석 참조).
  bool _adsEnabled = false;
  final _adsAppIdCtrl = TextEditingController();
  final _adsBannerCtrl = TextEditingController();
  final _adsInterCtrl = TextEditingController();
  final _adsRewardCtrl = TextEditingController();
  int _adsEveryN = 10;
  bool _adsHomeBanner = true;
  bool _adsQuizBanner = false;
  bool _adsPremiumFree = true;

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
    _adsAppIdCtrl.dispose();
    _adsBannerCtrl.dispose();
    _adsInterCtrl.dispose();
    _adsRewardCtrl.dispose();
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
    _adsEnabled = c.ads.enabled;
    _adsAppIdCtrl.text = c.ads.androidAppId;
    _adsBannerCtrl.text = c.ads.bannerUnitId;
    _adsInterCtrl.text = c.ads.interstitialUnitId;
    _adsRewardCtrl.text = c.ads.rewardedUnitId;
    _adsEveryN = c.ads.interstitialEveryNQuiz;
    _adsHomeBanner = c.ads.showBannerOnHome;
    _adsQuizBanner = c.ads.showBannerOnQuiz;
    _adsPremiumFree = c.ads.removeAdsForPremium;
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
      ads: AdsConfig(
        enabled: _adsEnabled,
        // 비워두면 구글 테스트 ID 로 되돌린다. 빈 문자열을 배포하면
        // 학습앱에서 SDK 초기화가 실패해 광고가 "조용히" 안 나오기 때문이다.
        androidAppId: _orTest(_adsAppIdCtrl.text, AdsConfig.testAppId),
        bannerUnitId: _orTest(_adsBannerCtrl.text, AdsConfig.testBanner),
        interstitialUnitId:
            _orTest(_adsInterCtrl.text, AdsConfig.testInterstitial),
        rewardedUnitId: _orTest(_adsRewardCtrl.text, AdsConfig.testRewarded),
        interstitialEveryNQuiz: _adsEveryN,
        showBannerOnHome: _adsHomeBanner,
        showBannerOnQuiz: _adsQuizBanner,
        removeAdsForPremium: _adsPremiumFree,
      ),
    );
  }

  static String _orTest(String v, String fallback) =>
      v.trim().isEmpty ? fallback : v.trim();

  /// 지금 폼에 입력된 광고 설정. 경고 표시와 배포 차단 판정이 같은 값을 본다.
  AdsConfig get _adsFromForm => _buildFromForm().ads;

  /// 배포 전 광고 설정 검증. 형식이 틀린 ID 를 배포하면 학습앱에서 광고가
  /// 예외 없이 그냥 안 나온다(조용한 실패). 그래서 배포 자체를 막는다.
  /// 광고가 꺼져 있으면 ID 는 쓰이지 않으므로 검사하지 않는다.
  String? _adsValidationError() {
    final a = _adsFromForm;
    if (!a.enabled) return null;
    if (!AdsConfig.isValidAppId(a.androidAppId)) {
      return '앱 ID 형식이 틀립니다: ${a.androidAppId}\n(형식: ca-app-pub-숫자16~숫자10)';
    }
    const units = ['배너', '전면', '보상형'];
    final ids = [a.bannerUnitId, a.interstitialUnitId, a.rewardedUnitId];
    for (var i = 0; i < ids.length; i++) {
      if (!AdsConfig.isValidUnitId(ids[i])) {
        return '${units[i]} 단위 ID 형식이 틀립니다: ${ids[i]}\n(형식: ca-app-pub-숫자16/숫자10)';
      }
    }
    return null;
  }

  Future<void> _publish() async {
    final adsErr = _adsValidationError();
    if (adsErr != null) {
      _snack('❌ 광고 설정 오류 — 배포 중단\n$adsErr', AppTheme.danger);
      return;
    }
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
        _adsCard(),
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

  /// 📣 광고(AdMob) 설정 카드.
  ///
  /// 학습앱에는 광고 설정 화면을 두지 않는다. 사용자가 광고를 끌 수 있으면
  /// 수익 모델이 성립하지 않기 때문이다. 광고는 **관리자 앱에서만** 조종한다.
  Widget _adsCard() {
    final ads = _adsFromForm;
    final err = _adsValidationError();
    return _sectionCard('광고 (AdMob)', Icons.ads_click, [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '학습앱의 광고를 여기서 원격 제어합니다. 앱 재배포 없이 즉시 반영됩니다.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 8),
            // 테스트 ID 경고 — 이 상태로 출시하면 광고는 정상으로 보이지만
            // 수익이 0원이다. 조용한 실패이므로 눈에 띄게 경고한다.
            if (_adsEnabled && ads.usesTestIds)
              _banner(
                Icons.warning_amber_rounded,
                AppTheme.warning,
                '구글 테스트 광고 ID 를 쓰고 있습니다.\n'
                '이대로 출시하면 광고는 정상으로 보이지만 수익은 0원입니다.\n'
                '개발 중에는 정상이며, 출시 전 실 ID 로 바꾸세요.',
              ),
            if (err != null)
              _banner(Icons.error_outline, AppTheme.danger,
                  'ID 형식 오류 — 이대로는 배포되지 않습니다.\n$err'),
            if (_adsEnabled && err == null && !ads.usesTestIds)
              _banner(Icons.verified, AppTheme.success,
                  '실 광고 ID 형식 확인됨 — 배포 가능합니다.'),
          ],
        ),
      ),
      SwitchListTile(
        title: const Text('광고 사용'),
        subtitle: const Text('끄면 학습앱이 광고 SDK 를 아예 초기화하지 않습니다'),
        value: _adsEnabled,
        onChanged: (v) => setState(() => _adsEnabled = v),
      ),
      // 광고가 꺼져 있으면 아래 설정은 아무 효과가 없다. 숨기지 않고
      // 비활성으로 보여줘야 "왜 안 먹지" 하는 혼란이 없다.
      Opacity(
        opacity: _adsEnabled ? 1.0 : 0.45,
        child: IgnorePointer(
          ignoring: !_adsEnabled,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  children: [
                    _adsIdField(
                      _adsAppIdCtrl,
                      '앱 ID (AndroidManifest 와 동일해야 함)',
                      AdsConfig.testAppId,
                      isAppId: true,
                    ),
                    const SizedBox(height: 12),
                    _adsIdField(_adsBannerCtrl, '배너 단위 ID',
                        AdsConfig.testBanner),
                    const SizedBox(height: 12),
                    _adsIdField(_adsInterCtrl, '전면(Interstitial) 단위 ID',
                        AdsConfig.testInterstitial),
                    const SizedBox(height: 12),
                    _adsIdField(_adsRewardCtrl, '보상형(Rewarded) 단위 ID',
                        AdsConfig.testRewarded),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_adsEveryN == 0
                        ? '전면광고: 사용 안 함'
                        : '전면광고 빈도: $_adsEveryN문항마다 1회'),
                    // 하한 5. 그보다 잦으면 학습 흐름이 끊겨 이탈로 이어진다.
                    // 0 은 "전면광고 끄기"라는 별도 의미이므로 따로 둔다.
                    Slider(
                      value: _adsEveryN.toDouble(),
                      min: 0,
                      max: 30,
                      divisions: 30,
                      label: _adsEveryN == 0 ? '끔' : '$_adsEveryN문항',
                      onChanged: (v) {
                        final n = v.round();
                        setState(() => _adsEveryN =
                            (n > 0 && n < 5) ? 5 : n); // 0 또는 5 이상만 허용
                      },
                    ),
                    const Text(
                      '5문항 미만은 허용하지 않습니다 — 학습 흐름이 끊겨 이탈률이 올라갑니다.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              SwitchListTile(
                title: const Text('홈 화면 배너'),
                value: _adsHomeBanner,
                onChanged: (v) => setState(() => _adsHomeBanner = v),
              ),
              SwitchListTile(
                title: const Text('문제풀이 화면 배너'),
                subtitle: const Text('집중을 방해하므로 기본은 꺼짐입니다'),
                value: _adsQuizBanner,
                onChanged: (v) => setState(() => _adsQuizBanner = v),
              ),
              SwitchListTile(
                title: const Text('프리미엄 사용자는 광고 제거'),
                value: _adsPremiumFree,
                onChanged: (v) => setState(() => _adsPremiumFree = v),
              ),
            ],
          ),
        ),
      ),
    ]);
  }

  /// 광고 ID 입력칸. 입력 즉시 형식을 판정해 보여준다(배포 후에 알면 늦다).
  Widget _adsIdField(
    TextEditingController ctrl,
    String label,
    String testValue, {
    bool isAppId = false,
  }) {
    final v = ctrl.text.trim();
    final valid = v.isEmpty ||
        (isAppId ? AdsConfig.isValidAppId(v) : AdsConfig.isValidUnitId(v));
    return TextField(
      controller: ctrl,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        hintText: '비우면 테스트 ID 사용',
        errorText: valid ? null : '형식 오류',
        helperText: v == testValue ? '⚠ 구글 테스트 ID' : null,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          tooltip: '테스트 ID 로 되돌리기',
          icon: const Icon(Icons.restart_alt, size: 20),
          onPressed: () => setState(() => ctrl.text = testValue),
        ),
      ),
    );
  }

  Widget _banner(IconData icon, Color color, String text) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: TextStyle(fontSize: 12, color: color)),
            ),
          ],
        ),
      );

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
