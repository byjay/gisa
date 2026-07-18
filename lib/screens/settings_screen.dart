import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart' show Share, XFile;
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import 'legal_screen.dart';
import 'help_faq_screen.dart';
import '../services/auth_service.dart';
import '../services/backup_service.dart';
import '../services/cerebras_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/tutor_avatar.dart';

/// 설정 화면 — 계정(구글 로그인 준비), 테마, 목표 등.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final app = context.watch<AppProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width > 800
              ? (MediaQuery.of(context).size.width - 680) / 2
              : 14,
          vertical: 14,
        ),
        children: [
          _sectionTitle(cs, '계정'),
          const SizedBox(height: 8),
          _accountCard(context),
          const SizedBox(height: 20),
          // 🧪 AI 튜터 API 키 — 테스트 기간에만 노출되는 설정 카드 (잘 보이는 상단 배치)
          if (CerebrasService.isTestPeriod) ...[
            _sectionTitle(cs, 'AI 튜터 (테스트 기간 한정)'),
            const SizedBox(height: 8),
            _aiApiKeyCard(context),
            const SizedBox(height: 20),
          ],
          _sectionTitle(cs, '화면'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(
                    app.darkMode
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                  ),
                  title: const Text('다크 모드'),
                  value: app.darkMode,
                  onChanged: (_) =>
                      context.read<AppProvider>().toggleDarkMode(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle(cs, '접근성'),
          const SizedBox(height: 8),
          _accessibilityCard(context, app),
          const SizedBox(height: 20),
          _sectionTitle(cs, '나의 강사'),
          const SizedBox(height: 8),
          _tutorSelector(context, app),
          const SizedBox(height: 20),
          _sectionTitle(cs, '알림'),
          const SizedBox(height: 8),
          _notificationCard(context, app),
          const SizedBox(height: 20),
          _sectionTitle(cs, '데이터 백업 · 복원'),
          const SizedBox(height: 8),
          _backupCard(context),
          const SizedBox(height: 20),
          _sectionTitle(cs, '응원하기'),
          const SizedBox(height: 8),
          _supportCard(context),
          const SizedBox(height: 20),
          _sectionTitle(cs, '앱 정보 · 법적 고지'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.info_outline_rounded),
                  title: Text('버전'),
                  trailing: Text('1.0.0'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.help_outline_rounded),
                  title: const Text('도움말 · 자주 묻는 질문'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HelpFaqScreen()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('개인정보처리방침'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LegalScreen(initialTab: 0),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.gavel_rounded),
                  title: const Text('이용약관'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LegalScreen(initialTab: 1),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.smart_toy_outlined),
                  title: const Text('AI 생성 콘텐츠 고지'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LegalScreen(initialTab: 2),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.code_rounded),
                  title: const Text('오픈소스 라이선스'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: '볼트쌤',
                    applicationVersion: '1.0.0',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tutorSelector(BuildContext context, AppProvider app) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '함께 공부할 강사를 선택하세요',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final tutor in tutorProfiles)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => context
                            .read<AppProvider>()
                            .setSelectedTutor(tutor.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
                          decoration: BoxDecoration(
                            color: app.selectedTutorId == tutor.id
                                ? cs.primaryContainer
                                : cs.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: app.selectedTutorId == tutor.id
                                  ? cs.primary
                                  : cs.outlineVariant,
                              width: app.selectedTutorId == tutor.id ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              SizedBox(
                                height: 112,
                                child: Image.asset(
                                  tutor.asset,
                                  fit: BoxFit.contain,
                                  alignment: Alignment.bottomCenter,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                tutor.name.replaceAll(' 선생님', ''),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (app.selectedTutorId == tutor.id)
                                Icon(
                                  Icons.check_circle,
                                  size: 16,
                                  color: cs.primary,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              tutorProfileById(app.selectedTutorId).role,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 응원하기 카드 — 리뷰·공유·피드백 (마케팅) ──────────
  Widget _supportCard(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.star_rounded, color: Colors.amber),
            title: const Text('별점으로 응원하기'),
            subtitle: const Text('리뷰 하나가 큰 힘이 됩니다 ⭐'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _openStore(context),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.share_rounded, color: AppTheme.primary),
            title: const Text('친구에게 공유하기'),
            subtitle: const Text('같이 공부하면 합격률 2배'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _shareApp(context),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(
              Icons.mail_outline_rounded,
              color: AppTheme.accent,
            ),
            title: const Text('의견 보내기 · 오류 신고'),
            subtitle: const Text('certstudytracker@gmail.com'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _sendFeedback(context),
          ),
        ],
      ),
    );
  }

  Future<void> _openStore(BuildContext context) async {
    final uri = Uri.parse(
      'https://play.google.com/store/apps/details?id=com.certstudytracker.study',
    );
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('출시 후 플레이스토어에서 리뷰를 남길 수 있어요 ⭐')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('출시 후 플레이스토어에서 리뷰를 남길 수 있어요 ⭐')),
        );
      }
    }
  }

  Future<void> _shareApp(BuildContext context) async {
    const text =
        '⚡ 전기기사·소방 공부는 볼트쌤 하나로 끝!\n'
        '기출 3,700+문제 · 볼트쌤 튜터 · 암기법 · 합격 예측까지 무료.\n'
        '볼트쌤 — Google Play에서 검색!';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('친구에게 공유'),
        content: const SelectableText(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendFeedback(BuildContext context) async {
    final uri = Uri.parse(
      'mailto:certstudytracker@gmail.com?subject=${Uri.encodeComponent('[Cert Study Tracker] 의견/오류 신고')}',
    );
    try {
      final ok = await launchUrl(uri);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('certstudytracker@gmail.com 으로 보내주세요 📧'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('certstudytracker@gmail.com 으로 보내주세요 📧'),
          ),
        );
      }
    }
  }

  /// 🧪 AI 튜터 API 키 설정 카드 — 테스트 기간에만 표시.
  /// 키 등록 상태를 한눈에 보여주고, 탭 하나로 바로 설정할 수 있다.
  Widget _aiApiKeyCard(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<bool>(
      future: CerebrasService.instance.hasKey(),
      builder: (context, snap) {
        final hasKey = snap.data ?? false;
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.teal.withValues(alpha: 0.12),
                  cs.primaryContainer.withValues(alpha: 0.25),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.vpn_key_rounded,
                      color: Colors.teal,
                    ),
                  ),
                  title: const Text(
                    'AI API 키 설정',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    hasKey
                        ? '✅ 키 등록됨 · AI 튜터 사용 가능'
                        : '키 미등록 · 탭해서 키를 입력하면 AI 튜터가 켜져요',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: hasKey ? Colors.teal : cs.error,
                    ),
                  ),
                  trailing: FilledButton.tonalIcon(
                    onPressed: () => _showAiKeyDialog(context),
                    icon: Icon(
                      hasKey ? Icons.edit_rounded : Icons.add_rounded,
                      size: 18,
                    ),
                    label: Text(hasKey ? '변경' : '키 등록'),
                  ),
                  onTap: () => _showAiKeyDialog(context),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '🧪 테스트 기간(~${CerebrasService.testPeriodEndLabel})에만 AI 튜터를 설정·사용할 수 있어요.\n'
                      '키는 이 기기에만 저장되며 외부로 전송되지 않습니다.',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.5,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAiKeyDialog(BuildContext context) async {
    final keyCtrl = TextEditingController(
      text: await CerebrasService.instance.getApiKey(),
    );
    if (!context.mounted) return;
    var obscure = true;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.vpn_key_rounded, color: Colors.teal),
              SizedBox(width: 8),
              Text('AI API 키 설정'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🧪 테스트 기간(~${CerebrasService.testPeriodEndLabel}) 전용 기능입니다.\n'
                  'Cerebras 추론 엔진(gpt-oss-120b)을 사용하며,\n'
                  '본인이 발급한 키만 이 기기에 저장됩니다.',
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: keyCtrl,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'API Key (csk-...)',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        size: 20,
                      ),
                      onPressed: () => setDlg(() => obscure = !obscure),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            if (keyCtrl.text.isNotEmpty)
              TextButton(
                onPressed: () async {
                  await CerebrasService.instance.setApiKey('');
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) setState(() {});
                },
                child: const Text('키 삭제', style: TextStyle(color: Colors.red)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () async {
                await CerebrasService.instance.setApiKey(keyCtrl.text);
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) setState(() {});
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        keyCtrl.text.trim().isEmpty
                            ? 'AI 키가 삭제되었어요'
                            : '✅ AI 키가 저장됐어요! 이제 AI 튜터를 사용할 수 있어요',
                      ),
                    ),
                  );
                }
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(ColorScheme cs, String t) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(
      t,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w900,
        color: cs.primary,
      ),
    ),
  );

  Widget _accountCard(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;

    if (user != null) {
      return Card(
        child: Column(
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                child: Text(
                  user.name.isNotEmpty ? user.name.characters.first : '학',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              title: Text(
                user.name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                user.email.isNotEmpty
                    ? user.email
                    : (user.provider == 'google' ? '구글 계정' : '로컬 프로필'),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppTheme.danger),
              title: const Text('로그아웃'),
              onTap: () => context.read<AuthService>().signOut(),
            ),
          ],
        ),
      );
    }

    // 미로그인 상태 — 완결된 로컬 프로필 온보딩 (미완성 기능 노출 없이)
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconBadge(icon: Icons.person_rounded, color: AppTheme.primary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '닉네임을 설정하면 학습 기록이 더 특별해져요.',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => _onLocalProfileTap(context),
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('닉네임 설정하기'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notificationCard(BuildContext context, AppProvider app) {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_rounded),
            title: const Text('시험 일정 알림'),
            subtitle: const Text('원서접수·시험일·합격발표 D-day를 놓치지 않아요'),
            value: app.notificationsEnabled,
            onChanged: (v) async {
              if (v) {
                final granted = await NotificationService.instance
                    .requestPermission();
                if (!context.mounted) return;
                if (!granted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('알림 권한이 꺼져 있어요. 기기 설정에서 허용해주세요.'),
                    ),
                  );
                }
              }
              if (!context.mounted) return;
              await context.read<AppProvider>().setNotificationsEnabled(v);
            },
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.wb_sunny_rounded),
            title: const Text('매일 학습 리마인드'),
            subtitle: Text('매일 오전 ${app.dailyReminderHour}시에 알려드려요'),
            value: app.dailyReminderEnabled && app.notificationsEnabled,
            onChanged: app.notificationsEnabled
                ? (v) => context.read<AppProvider>().setDailyReminderEnabled(v)
                : null,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.send_rounded),
            title: const Text('알림 테스트'),
            subtitle: const Text('지금 바로 알림을 받아보세요'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              await NotificationService.instance.showTestNotification();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('테스트 알림을 보냈어요! 📬')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // ── ♿ 접근성 카드 (Q47 애니메이션 감소 · Q48 글자 크기) ─────
  Widget _accessibilityCard(BuildContext context, AppProvider app) {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.motion_photos_off_outlined),
            title: const Text('애니메이션 줄이기'),
            subtitle: const Text('화면 전환·효과 애니메이션을 최소화해요'),
            value: app.reduceMotion,
            onChanged: (v) => context.read<AppProvider>().setReduceMotion(v),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.format_size_rounded,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('앱 글자 크기')),
                    Text(
                      '${(app.textScaleFactor * 100).round()}%',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                Semantics(
                  label:
                      '앱 글자 크기 조절 슬라이더, 현재 ${(app.textScaleFactor * 100).round()}퍼센트',
                  slider: true,
                  child: Slider(
                    value: app.textScaleFactor,
                    min: 0.8,
                    max: 1.6,
                    divisions: 8,
                    label: '${(app.textScaleFactor * 100).round()}%',
                    onChanged: (v) =>
                        context.read<AppProvider>().setTextScaleFactor(v),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 데이터 백업/복원 카드 (H2 갭 해소) ─────────────────
  Widget _backupCard(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(
              Icons.upload_file_rounded,
              color: AppTheme.primary,
            ),
            title: const Text('내보내기 (백업 파일 만들기)'),
            subtitle: const Text('학습기록·오답·설정을 파일 하나로 저장해요'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _exportBackup(context),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.download_rounded, color: AppTheme.accent),
            title: const Text('가져오기 (백업 파일 복원)'),
            subtitle: const Text('기기를 바꿔도 학습기록을 그대로 이어가요'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _importBackup(context),
          ),
        ],
      ),
    );
  }

  Future<void> _exportBackup(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('백업 파일을 만들고 있어요…')));
    final result = await BackupService.instance.exportAll();
    if (!result.success) {
      messenger.showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? '백업 실패')),
      );
      return;
    }
    try {
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final file = File('${dir.path}/voltssam_backup_$stamp.json');
      await file.writeAsString(result.data!);
      await Share.shareXFiles([XFile(file.path)], text: '볼트쌤 학습 데이터 백업 파일입니다.');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('파일 공유 중 오류: $e')));
    }
  }

  Future<void> _importBackup(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    FilePickerResult? picked;
    try {
      picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('파일 선택 중 오류: $e')));
      return;
    }
    if (picked == null || picked.files.isEmpty) return;

    String rawJson;
    try {
      final path = picked.files.single.path;
      if (path != null) {
        rawJson = await File(path).readAsString();
      } else {
        final bytes = picked.files.single.bytes;
        if (bytes == null) {
          messenger.showSnackBar(
            const SnackBar(content: Text('파일을 읽을 수 없어요.')),
          );
          return;
        }
        rawJson = utf8.decode(bytes);
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('파일을 읽는 중 오류: $e')));
      return;
    }

    final peek = await BackupService.instance.peek(rawJson);
    if (!peek.success) {
      messenger.showSnackBar(
        SnackBar(content: Text(peek.errorMessage ?? '백업 파일을 확인할 수 없어요.')),
      );
      return;
    }
    final summary = peek.data!;
    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('백업 복원 확인'),
        content: Text(
          '이 백업은 ${summary.createdAt.toLocal().toString().split('.').first}에 만들어졌어요.\n'
          '(퀴즈 기록 ${summary.quizResultCount}건 · 오답노트 ${summary.wrongNoteCount}건)\n\n'
          '지금 기기의 데이터는 이 백업으로 완전히 교체됩니다. 계속할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('복원하기'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;

    messenger.showSnackBar(const SnackBar(content: Text('복원하고 있어요…')));
    final result = await BackupService.instance.importAll(rawJson);
    if (!context.mounted) return;
    if (!result.success) {
      messenger.showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? '복원 실패')),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text('복원 완료! ${result.data}개 데이터 항목이 반영됐어요. 앱을 다시 시작해주세요.'),
      ),
    );
  }

  Future<void> _onLocalProfileTap(BuildContext context) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('닉네임 입력'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '예: 합격러'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('시작'),
          ),
        ],
      ),
    );
    if (name == null) return;
    if (!context.mounted) return;
    await context.read<AuthService>().saveLocalProfile(name: name);
  }
}
