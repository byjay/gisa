import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

/// 🧭 앱 전역 탭 전환 컨트롤러.
///
/// MainShell 이 이 컨트롤러에 콜백을 등록하면, 어느 화면(push 된 하위 페이지
/// 포함)에서든 [go] 를 호출해 루트 탭으로 즉시 이동할 수 있다.
/// 이로써 "모든 페이지에서 하단 메뉴탭 고정" 요구를 만족한다.
class AppTabs {
  AppTabs._();

  static const int home = 0;
  static const int study = 1;
  static const int exams = 2;
  static const int timer = 3;
  static const int stats = 4;

  /// MainShell 이 등록하는 탭 전환 함수.
  static void Function(int index)? _switcher;

  /// 루트 화면까지 pop 하고 탭을 전환하는 네비게이터 키.
  static final GlobalKey<NavigatorState> rootNavKey =
      GlobalKey<NavigatorState>();

  static void register(void Function(int index) fn) => _switcher = fn;

  /// 어느 화면에서든 호출: 하위 페이지를 모두 닫고 [index] 탭으로 이동.
  static void go(BuildContext context, int index) {
    // 현재 라우트 위에 push 된 페이지가 있으면 루트까지 모두 닫는다.
    Navigator.of(context).popUntil((r) => r.isFirst);
    _switcher?.call(index);
  }
}

/// 📌 하위 페이지를 열 때 자동으로 상단 타이머바 + 하단 메뉴바를 붙여주는 헬퍼.
///
/// 기존 `Navigator.push(MaterialPageRoute(builder: ...))` 를 이 함수로 바꾸면
/// 열리는 페이지 어디서나 하단 네비게이션이 유지된다(#6).
///
/// [currentSection] 은 하단바에서 강조할 탭 인덱스(선택).
Future<T?> pushWithNav<T>(
  BuildContext context,
  Widget page, {
  int? currentSection,
}) {
  return Navigator.of(context).push<T>(
    MaterialPageRoute(
      builder: (_) => PersistentChromeScaffold(
        currentSection: currentSection,
        child: page,
      ),
    ),
  );
}

/// 하위 페이지를 감싸 상단 타이머바 + 하단 메뉴바를 제공하는 스캐폴드.
class PersistentChromeScaffold extends StatelessWidget {
  final Widget child;
  final int? currentSection;
  const PersistentChromeScaffold({
    super.key,
    required this.child,
    this.currentSection,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const TimerRunningBar(),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: SubPageNavBar(currentSection: currentSection),
    );
  }
}

/// ⏱️ 상단 타이머 실행 인디케이터 (얇은 바).
///
/// 타이머가 돌아가는 동안 모든 화면 상단에 작게 경과 시간을 표시한다(#3).
/// 탭하면 타이머 탭으로 이동한다.
class TimerRunningBar extends StatelessWidget {
  const TimerRunningBar({super.key});

  String _fmt(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${sec.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final running =
        context.select<AppProvider, bool>((p) => p.timerRunning);
    if (!running) return const SizedBox.shrink();
    final seconds =
        context.select<AppProvider, int>((p) => p.elapsedSeconds);
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.primary,
      child: InkWell(
        onTap: () => AppTabs.go(context, AppTabs.timer),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                // 깜빡이는 녹색 점
                const _PulseDot(),
                const SizedBox(width: 8),
                Text(
                  '학습 타이머 진행 중',
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  _fmt(seconds),
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: scheme.onPrimary.withValues(alpha: 0.9)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot();
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
      child: Container(
        width: 9,
        height: 9,
        decoration: const BoxDecoration(
          color: Color(0xFF4ADE80),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// 🧭 하위(push) 페이지용 하단 네비게이션 바.
///
/// push 된 상세 페이지에서도 하단 메뉴가 항상 보이도록 하는 공용 바(#6).
/// 탭을 누르면 [AppTabs.go] 로 루트 탭으로 이동한다.
class SubPageNavBar extends StatelessWidget {
  /// 현재 페이지가 속한 섹션(선택 표시용). null 이면 아무것도 선택 안 함.
  final int? currentSection;
  const SubPageNavBar({super.key, this.currentSection});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
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
        selectedIndex: currentSection ?? 0,
        onDestinationSelected: (i) => AppTabs.go(context, i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: '홈'),
          NavigationDestination(
              icon: Icon(Icons.school_outlined),
              selectedIcon: Icon(Icons.school_rounded),
              label: '학습'),
          NavigationDestination(
              icon: Icon(Icons.event_outlined),
              selectedIcon: Icon(Icons.event_rounded),
              label: '시험'),
          NavigationDestination(
              icon: Icon(Icons.timer_outlined),
              selectedIcon: Icon(Icons.timer_rounded),
              label: '타이머'),
          NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights_rounded),
              label: '통계'),
        ],
      ),
    );
  }
}
