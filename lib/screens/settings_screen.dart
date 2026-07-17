import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import 'legal_screen.dart';
import '../services/auth_service.dart';
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
          _sectionTitle(cs, '나의 강사'),
          const SizedBox(height: 8),
          _tutorSelector(context, app),
          const SizedBox(height: 20),
          _sectionTitle(cs, '알림'),
          const SizedBox(height: 8),
          _notificationCard(context, app),
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
