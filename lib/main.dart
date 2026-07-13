import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'theme/app_theme.dart';
import 'screens/exams_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/track_select_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/study/study_screen.dart';
import 'screens/timer_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko');
  final provider = AppProvider();
  await provider.init();
  runApp(
    ChangeNotifierProvider.value(
      value: provider,
      child: const CertStudyApp(),
    ),
  );
}

class CertStudyApp extends StatelessWidget {
  const CertStudyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = context.select<AppProvider, bool>((p) => p.darkMode);
    return MaterialApp(
      title: 'Cert Study Tracker',
      debugShowCheckedModeBanner: false,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const _RootGate(),
    );
  }
}

/// 첫 실행 시에만 온보딩을 보여주는 게이트
class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final onboarded =
        context.select<AppProvider, bool>((p) => p.onboarded);
    if (!onboarded) {
      return OnboardingScreen(
        onDone: () => context.read<AppProvider>().completeOnboarding(),
      );
    }
    // 온보딩 후 종목 미선택이면 큰 버튼 3개 진입 화면
    final trackId =
        context.select<AppProvider, String?>((p) => p.selectedTrackId);
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

  void _navigate(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(onNavigate: _navigate),
      const StudyScreen(),
      const ExamsScreen(),
      const TimerScreen(),
      const StatsScreen(),
    ];

    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
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
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: '홈'),
            NavigationDestination(icon: Icon(Icons.school_outlined), selectedIcon: Icon(Icons.school_rounded), label: '학습'),
            NavigationDestination(icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event_rounded), label: '시험'),
            NavigationDestination(icon: Icon(Icons.timer_outlined), selectedIcon: Icon(Icons.timer_rounded), label: '타이머'),
            NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights_rounded), label: '통계'),
          ],
        ),
      ),
    );
  }
}
