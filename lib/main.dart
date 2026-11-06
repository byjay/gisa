import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'services/admin_service.dart';
import 'services/app_config.dart';
import 'services/app_update_service.dart';
import 'services/auth_service.dart';
import 'services/backup_service.dart';
import 'services/crash_logger.dart';
import 'services/entitlement_service.dart';
import 'services/notification_service.dart';
import 'services/remote_config_service.dart';
import 'services/remote_content_api.dart';
import 'services/service_control_service.dart';
import 'services/track_catalog_service.dart';
import 'services/study_data.dart';
import 'services/exam_track.dart';
import 'theme/app_theme.dart';
import 'screens/exams_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/server_sign_in_screen.dart';
import 'screens/service_maintenance_screen.dart';
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
  await Hive.initFlutter();
  // Q40: 글로벌 에러 훅(FlutterError/PlatformDispatcher) 등록 — 최우선 초기화
  await CrashLogger.instance.init();
  ServiceControlService.instance.setDisabledHandler(() {
    RemoteContentApi.instance.invalidateRequests();
    StudyData.instance.clearSessionCache();
  });
  await ServiceControlService.instance.initialize();
  await initializeDateFormatting('ko');
  // Restore the authenticated owner before opening user-scoped learning boxes.
  await AuthService.instance.init();
  final provider = AppProvider();
  await provider.init(
    initializeHive: false,
    ownerId: AuthService.instance.dataOwnerId,
  );
  AuthService.instance.setDataOwnerChangeHandler(provider.activateUser);
  RemoteContentApi.instance.authToken = AuthService.instance.sessionToken;
  // 원격 자료는 API 설정과 유효한 세션이 있을 때만 요청한다.
  // 서버 전용 APK에는 정적 시험 일정 자산을 포함하지 않는다.
  if (AppConfig.hasApi && AuthService.instance.hasApiSession) {
    unawaited(provider.initSchedule());
  }
  // 🛡️ 슈퍼 관리자 세션 복원 — Entitlement보다 먼저(오버라이드 기준값)
  await AdminService.instance.init();
  // 🔐 구독/권한(Entitlement) 서비스 초기화 — 무료/유료 게이트의 기준
  await EntitlementService.instance.init();
  // 📡 원격 앱 설정(Remote Config) 초기화 — 관리자가 배포한 설정을 자동 반영.
  //    캐시 먼저 적용 → 온라인이면 백그라운드로 서버 최신값 pull(오프라인 관용).
  await RemoteConfigService.instance.init();
  if (AppConfig.hasApi) {
    unawaited(
      EntitlementService.instance.refreshFromServer(
        authToken: AuthService.instance.sessionToken,
      ),
    );
  }
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
        ChangeNotifierProvider.value(value: RemoteConfigService.instance),
        ChangeNotifierProvider.value(value: ServiceControlService.instance),
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
          child: ServiceMaintenanceGate(
            service: ServiceControlService.instance,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      home: const _RootGate(),
    );
  }
}

/// 첫 실행 시에만 온보딩을 보여주는 게이트
class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  Future<void>? _catalogLoad;

  @override
  Widget build(BuildContext context) {
    final onboarded = context.select<AppProvider, bool>((p) => p.onboarded);
    if (!onboarded) {
      return OnboardingScreen(
        onDone: () => context.read<AppProvider>().completeOnboarding(),
      );
    }
    if (!AppConfig.hasApi ||
        !context.select<AuthService, bool>((auth) => auth.hasApiSession)) {
      if (_catalogLoad != null) TrackCatalogService.retry();
      _catalogLoad = null;
      return const ServerSignInScreen();
    }
    final trackId = context.select<AppProvider, String?>(
      (provider) => provider.selectedTrackId,
    );
    _catalogLoad ??= TrackCatalogService.load();
    return FutureBuilder<void>(
      future: _catalogLoad,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_rounded, size: 44),
                    const SizedBox(height: 12),
                    const Text('자격증 목록을 불러오지 못했어요.'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => setState(() {
                        TrackCatalogService.retry();
                        _catalogLoad = TrackCatalogService.load();
                      }),
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData &&
            snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (trackId == null ||
            !kExamTracks.any((track) => track.id == trackId)) {
          return const TrackSelectScreen();
        }
        StudyData.instance.setTrack(trackById(trackId));
        return MainShell(key: ValueKey(trackId));
      },
    );
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
