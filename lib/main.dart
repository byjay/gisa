import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'services/admin_service.dart';
import 'services/app_update_service.dart';
import 'services/auth_service.dart';
import 'services/backup_service.dart';
import 'services/crash_logger.dart';
import 'services/entitlement_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'screens/exams_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/track_select_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/study/study_screen.dart';
import 'screens/timer_screen.dart';
import 'widgets/persistent_nav.dart';

Future<void> main() async {
  // Q40: 앱 전역을 가드 존으로 감싸 처리되지 않은 비동기 오류를 로컬에 기록한다.
  runZonedGuarded(_bootstrap, (error, stack) {
    unawaited(
      CrashLogger.instance.record(error.toString(), stack: stack.toString()),
    );
  });
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Q40: 글로벌 에러 훅(FlutterError/PlatformDispatcher) 등록 — 최우선 초기화
  await CrashLogger.instance.init();
  await initializeDateFormatting('ko');
  final provider = AppProvider();
  await provider.init();
  // 실시간 시험일정은 백그라운드로 로드(앱 시작 지연 방지)
  unawaited(provider.initSchedule());
  // 인증(구글 로그인 준비) 서비스 초기화
  await AuthService.instance.init();
  // 🛡️ 슈퍼 관리자 세션 복원 — Entitlement보다 먼저(오버라이드 기준값)
  await AdminService.instance.init();
  // 🔐 구독/권한(Entitlement) 서비스 초기화 — 무료/유료 게이트의 기준
  await EntitlementService.instance.init();
  // 🔄 앱 업데이트 서비스 초기화(백그라운드로 최신 버전 확인)
  unawaited(AppUpdateService.instance.init());
  // 🔔 로컬 알림 서비스 초기화 (시험 D-day, 학습 리마인드) — 백그라운드로 준비
  unawaited(NotificationService.instance.init());
  // 💾 Q80: 7일 이상 경과 시 자동 백업 파일 생성(백그라운드, 실패해도 앱 구동에 영향 없음)
  unawaited(_maybeAutoBackup(provider));
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: provider),
        ChangeNotifierProvider.value(value: AuthService.instance),
        ChangeNotifierProvider.value(value: AdminService.instance),
        ChangeNotifierProvider.value(value: EntitlementService.instance),
        ChangeNotifierProvider.value(value: AppUpdateService.instance),
      ],
      child: const CertStudyApp(),
    ),
  );
}

/// 💾 Q80: 마지막 자동 백업이 7일 이상 지났으면 로컬 파일로 새 백업을 만든다.
Future<void> _maybeAutoBackup(AppProvider provider) async {
  try {
    final last = provider.lastAutoBackupAt;
    final lastDate = last != null ? DateTime.tryParse(last) : null;
    final due =
        lastDate == null || DateTime.now().difference(lastDate).inDays >= 7;
    if (!due) return;
    final result = await BackupService.instance.autoBackupToLocalFile();
    if (result.success) {
      await provider.markAutoBackupNow();
    }
  } catch (_) {
    // 자동 백업 실패는 앱 사용에 영향을 주지 않도록 무시(수동 백업으로 대체 가능)
  }
}

class CertStudyApp extends StatelessWidget {
  const CertStudyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = context.select<AppProvider, bool>((p) => p.darkMode);
    final paletteId = context.select<AppProvider, String>(
      (p) => p.themePaletteId,
    );
    final textScale = context.select<AppProvider, double>(
      (p) => p.textScaleFactor,
    );
    final reduceMotion = context.select<AppProvider, bool>(
      (p) => p.reduceMotion,
    );
    final palette = AppTheme.paletteById(paletteId);
    return MaterialApp(
      title: 'Gisaclub',
      debugShowCheckedModeBanner: false,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      theme: AppTheme.light(palette),
      darkTheme: AppTheme.dark(palette),
      // ♿ Q47/Q48: 애니메이션 감소 + 앱 내 글자 크기 배율(설정에서 조절)
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reduceMotion,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const _RootGate(),
    );
  }
}

/// 첫 실행 시에만 온보딩을 보여주는 게이트
class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final onboarded = context.select<AppProvider, bool>((p) => p.onboarded);
    if (!onboarded) {
      return OnboardingScreen(
        onDone: () => context.read<AppProvider>().completeOnboarding(),
      );
    }
    // 온보딩 후 종목 미선택이면 큰 버튼 3개 진입 화면
    final trackId = context.select<AppProvider, String?>(
      (p) => p.selectedTrackId,
    );
    if (trackId == null) {
      return const TrackSelectScreen();
    }
    // 종목이 바뀌면 MainShell 하위 상태가 새 데이터로 초기화되도록 key 부여
    return MainShell(key: ValueKey(trackId));
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  void _navigate(int i) {
    if (!mounted) return;
    setState(() => _index = i);
  }

  @override
  void initState() {
    super.initState();
    // 하위 페이지에서도 탭 전환을 요청할 수 있도록 전역 등록(#6)
    AppTabs.register(_navigate);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onNavigate: _navigate),
      const StudyScreen(),
      const ExamsScreen(),
      const TimerScreen(),
      const StatsScreen(),
      const StudyScreen(mockExamOnly: true),
    ];

    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Column(
        children: [
          // 타이머가 돌아가면 최상단에 작은 진행 바 표시(#3)
          const TimerRunningBar(),
          Expanded(
            child: IndexedStack(index: _index, children: screens),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: dark
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFE8EAF2),
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _navigate,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded, weight: 650),
              label: '홈',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_stories_outlined),
              selectedIcon: Icon(Icons.auto_stories_rounded, weight: 650),
              label: '학습',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month_rounded, weight: 650),
              label: '시험',
            ),
            NavigationDestination(
              icon: Icon(Icons.timer_outlined),
              selectedIcon: Icon(Icons.timer_rounded, weight: 650),
              label: '타이머',
            ),
            NavigationDestination(
              icon: Icon(Icons.query_stats_outlined),
              selectedIcon: Icon(Icons.query_stats_rounded, weight: 650),
              label: '통계',
            ),
            NavigationDestination(
              icon: Icon(Icons.computer_outlined),
              selectedIcon: Icon(Icons.computer_rounded, weight: 650),
              label: 'CBT',
            ),
          ],
        ),
      ),
    );
  }
}
