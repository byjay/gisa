import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

/// 📈 주간 성장 리포트 — 지난주 대비 이번 주 성장을 코칭 멘트와 함께
class WeeklyReportCard extends StatelessWidget {
  const WeeklyReportCard({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final monday = todayStart.subtract(Duration(days: now.weekday - 1));
    final lastMonday = monday.subtract(const Duration(days: 7));

    int rangeMinutes(DateTime from, int days) {
      var total = 0;
      for (var i = 0; i < days; i++) {
        total += app.minutesOnDate(from.add(Duration(days: i)));
      }
      return total;
    }

    int rangeQuiz(DateTime from, DateTime to, bool correctOnly) {
      return app.quizResults
          .where((r) {
            final d = DateTime.tryParse(r['date'] as String? ?? '');
            return d != null && !d.isBefore(from) && d.isBefore(to);
          })
          .fold<int>(
            0,
            (s, r) =>
                s + ((correctOnly ? r['correct'] : r['total']) as int? ?? 0),
          );
    }

    // 이번 주는 경과일수만큼, 지난주는 같은 요일수로 공정 비교
    final daysPassed = now.weekday;
    final thisMin = rangeMinutes(monday, daysPassed);
    final lastMinSame = rangeMinutes(lastMonday, daysPassed);
    final thisSolved = rangeQuiz(
      monday,
      todayStart.add(const Duration(days: 1)),
      false,
    );
    final lastSolvedFull = rangeQuiz(lastMonday, monday, false);

    final diffMin = thisMin - lastMinSame;
    final up = diffMin >= 0;

    String coach;
    if (thisMin == 0 && lastMinSame == 0) {
      coach = '이번 주 첫 학습을 시작해 보세요. 작은 시작이 마법의 첫 주문이에요 🪄';
    } else if (up && diffMin >= 30) {
      coach = '지난주보다 $diffMin분 더 공부했어요! 성장 곡선이 아름다워요 🚀';
    } else if (up) {
      coach = '지난주와 비슷한 페이스 유지 중. 꾸준함이 실력이 됩니다 💪';
    } else {
      coach = '지난주 대비 ${-diffMin}분 부족해요. 오늘 20분만 채워볼까요? ⏰';
    }

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(
                icon: Icons.trending_up_rounded,
                color: AppTheme.electric,
                size: 36,
                iconSize: 18,
              ),
              const SizedBox(width: 10),
              const Text(
                '주간 성장 리포트',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              PillBadge(
                text: up ? '▲ $diffMin분' : '▼ ${-diffMin}분',
                color: up ? AppTheme.success : AppTheme.danger,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _metric(
                context,
                '이번 주 학습',
                '$thisMin분',
                '지난주 같은 기간 $lastMinSame분',
                up,
              ),
              Container(
                width: 1,
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: dark
                    ? Colors.white.withValues(alpha: 0.06)
                    : const Color(0xFFEEF0F7),
              ),
              _metric(
                context,
                '이번 주 문제',
                '$thisSolved개',
                '지난주 $lastSolvedFull개',
                thisSolved >= lastSolvedFull,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: (up ? AppTheme.success : AppTheme.warning).withValues(
                alpha: dark ? 0.12 : 0.08,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              coach,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: dark
                    ? Colors.white70
                    : (up ? const Color(0xFF065F46) : const Color(0xFF92400E)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(
    BuildContext context,
    String label,
    String value,
    String sub,
    bool up,
  ) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: dark ? Colors.white54 : AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(width: 5),
              Icon(
                up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                size: 15,
                color: up ? AppTheme.success : AppTheme.danger,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: TextStyle(
              fontSize: 10,
              color: dark ? Colors.white38 : AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
