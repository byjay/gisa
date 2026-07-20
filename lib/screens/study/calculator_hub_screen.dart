import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../services/formula_calculators.dart';
import '../../widgets/persistent_nav.dart';
import '../../widgets/tutor_coach.dart';
import '../../widgets/help_dot.dart';
import 'unit_converter_screen.dart';
import 'formula_calc_screen.dart';

/// 계산기 허브 — 단위 환산 + 전기 공식 계산기 + 소방 공식 계산기
class CalculatorHubScreen extends StatelessWidget {
  const CalculatorHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // 현재 종목에 따라 소방 계산기 우선 노출
    final trackId = context.select<AppProvider, String?>(
      (p) => p.selectedTrackId,
    );
    final isFire = trackId == 'fire_electric';

    final entries = <_HubEntry>[
      _HubEntry(
        title: '단위 환산',
        subtitle: '전류·전압·저항·온도·면적·압력 등 13종',
        icon: Icons.swap_horiz_rounded,
        color: const Color(0xFF0891B2),
        builder: () => const UnitConverterHomeScreen(),
      ),
      _HubEntry(
        title: '전기 공식 계산기',
        subtitle: '옴의 법칙·3상 전력·역률개선·전압강하·단락전류·조명설계 등',
        icon: Icons.bolt_rounded,
        color: const Color(0xFF4F46E5),
        builder: () => FormulaCalcListScreen(
          title: '전기 공식 계산기',
          calcs: FormulaCalculators.electrical,
          bannerMsg: '전기기사 실기·필기에 자주 나오는 공식을 값만 넣으면 계산해드려요.',
        ),
      ),
      _HubEntry(
        title: '소방 공식 계산기',
        subtitle: '축전지 용량·감지기 개수·경계구역·전열·전선관·전기분해',
        icon: Icons.local_fire_department_rounded,
        color: const Color(0xFFEF4444),
        builder: () => FormulaCalcListScreen(
          title: '소방 공식 계산기',
          calcs: FormulaCalculators.fire,
          bannerMsg: '소방설비기사(전기) 실기 계산 공식을 값만 넣으면 계산해드려요.',
        ),
      ),
    ];

    // 소방 종목이면 소방 계산기를 전기보다 위로
    if (isFire) {
      final fire = entries.removeAt(2);
      entries.insert(1, fire);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('계산기'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: HelpDot(
              size: 22,
              title: '계산기 안내',
              body: '시험에 자주 나오는 계산 문제를 값만 넣으면 바로 풀어주는 기능이에요.\n\n'
                  '🔄 단위 환산 — 전류·전압·저항·온도·면적·압력 등 13종 단위를 서로 변환해요.\n\n'
                  '⚡ 전기 공식 계산기 — 옴의 법칙, 3상 전력, 역률개선, 전압강하, 단락전류, 조명설계 등 전기기사 필기·실기 핵심 공식을 자동 계산해요.\n\n'
                  '🔥 소방 공식 계산기 — 축전지 용량, 감지기 개수, 경계구역, 전선관 규격 등 소방설비기사(전기) 실기에 필요한 계산을 도와줘요.\n\n'
                  '💡 값을 입력하면 계산 과정과 정답이 함께 나와서, 공식을 외우면서 원리도 같이 이해할 수 있어요!',
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width > 800
              ? (MediaQuery.of(context).size.width - 680) / 2
              : 14,
          vertical: 14,
        ),
        children: [
          const DynamicTutorBanner(
            situation: CoachSituation.formula,
          ),
          const SizedBox(height: 16),
          ...entries.map((e) => _card(context, cs, e)),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, ColorScheme cs, _HubEntry e) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => pushWithNav(context, e.builder(), currentSection: 1),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: e.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(e.icon, color: e.color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      e.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: cs.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HubEntry {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget Function() builder;
  _HubEntry({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.builder,
  });
}
