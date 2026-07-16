import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

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
                  secondary: Icon(app.darkMode
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded),
                  title: const Text('다크 모드'),
                  value: app.darkMode,
                  onChanged: (_) =>
                      context.read<AppProvider>().toggleDarkMode(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _sectionTitle(cs, '알림'),
          const SizedBox(height: 8),
          _notificationCard(context, app),
          const SizedBox(height: 20),
          _sectionTitle(cs, '앱 정보'),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: const [
                ListTile(
                  leading: Icon(Icons.info_outline_rounded),
                  title: Text('버전'),
                  trailing: Text('1.0.0'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(ColorScheme cs, String t) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(t,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: cs.primary)),
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
                      fontWeight: FontWeight.w900, color: AppTheme.primary),
                ),
              ),
              title: Text(user.name,
                  style: const TextStyle(fontWeight: FontWeight.w800)),
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
                  child: Text('닉네임을 설정하면 학습 기록이 더 특별해져요.',
                      style: TextStyle(fontSize: 13, height: 1.4)),
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
                final granted =
                    await NotificationService.instance.requestPermission();
                if (!context.mounted) return;
                if (!granted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('알림 권한이 꺼져 있어요. 기기 설정에서 허용해주세요.')),
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
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('시작')),
        ],
      ),
    );
    if (name == null) return;
    if (!context.mounted) return;
    await context.read<AuthService>().saveLocalProfile(name: name);
  }
}
