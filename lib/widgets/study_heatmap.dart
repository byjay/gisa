import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

/// 🟩 GitHub 스타일 12주 학습 히트맵 — 꾸준함이 한눈에 보인다
class StudyHeatmap extends StatelessWidget {
  const StudyHeatmap({super.key});

  static const int _weeks = 12;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // 이번 주 일요일(주 시작)로부터 12주 전 일요일까지
    final thisSunday = today.subtract(Duration(days: today.weekday % 7));
    final start = thisSunday.subtract(const Duration(days: (_weeks - 1) * 7));

    // 활동일 수 계산
    int activeDays = 0;
    for (var d = start; !d.isAfter(today); d = d.add(const Duration(days: 1))) {
      if (app.minutesOnDate(d) > 0) activeDays++;
    }

    Color cellColor(int min) {
      if (min <= 0) {
        return dark
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFFEDEFF5);
      }
      if (min < 15) return AppTheme.primary.withValues(alpha: 0.25);
      if (min < 40) return AppTheme.primary.withValues(alpha: 0.5);
      if (min < 90) return AppTheme.primary.withValues(alpha: 0.75);
      return AppTheme.primary;
    }

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(
                icon: Icons.calendar_view_month_rounded,
                color: AppTheme.success,
                size: 36,
                iconSize: 18,
              ),
              const SizedBox(width: 10),
              const Text(
                '학습 발자국',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              PillBadge(
                text: '최근 12주 · $activeDays일 활동',
                color: AppTheme.success,
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              // 요일 라벨 폭 20 + 셀 간격 고려
              const labelW = 22.0;
              const gap = 3.0;
              final cellSize = ((constraints.maxWidth - labelW) / _weeks) - gap;
              final size = cellSize.clamp(8.0, 22.0);

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 요일 라벨 (일 월 화 수 목 금 토 중 월/수/금만)
                  SizedBox(
                    width: labelW,
                    child: Column(
                      children: [
                        for (var d = 0; d < 7; d++)
                          Container(
                            height: size + gap,
                            alignment: Alignment.centerLeft,
                            child: d == 1 || d == 3 || d == 5
                                ? Text(
                                    ['일', '월', '화', '수', '목', '금', '토'][d],
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: dark
                                          ? Colors.white38
                                          : AppTheme.textMuted,
                                    ),
                                  )
                                : null,
                          ),
                      ],
                    ),
                  ),
                  // 히트맵 그리드
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            for (var w = 0; w < _weeks; w++)
                              Expanded(
                                child: Column(
                                  children: [
                                    for (var d = 0; d < 7; d++)
                                      Builder(
                                        builder: (_) {
                                          final date = start.add(
                                            Duration(days: w * 7 + d),
                                          );
                                          final isFuture = date.isAfter(today);
                                          final min = isFuture
                                              ? -1
                                              : app.minutesOnDate(date);
                                          final isToday = date == today;
                                          return Tooltip(
                                            message: isFuture
                                                ? ''
                                                : '${DateFormat('M/d').format(date)} · $min분',
                                            child: Container(
                                              height: size,
                                              margin: const EdgeInsets.only(
                                                right: gap,
                                                bottom: gap,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isFuture
                                                    ? Colors.transparent
                                                    : cellColor(min),
                                                borderRadius:
                                                    BorderRadius.circular(3),
                                                border: isToday
                                                    ? Border.all(
                                                        color: AppTheme.accent,
                                                        width: 1.5,
                                                      )
                                                    : null,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          // 범례
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                '적음',
                style: TextStyle(
                  fontSize: 9.5,
                  color: dark ? Colors.white38 : AppTheme.textMuted,
                ),
              ),
              const SizedBox(width: 5),
              for (final a in [0.0, 0.25, 0.5, 0.75, 1.0])
                Container(
                  width: 11,
                  height: 11,
                  margin: const EdgeInsets.only(right: 3),
                  decoration: BoxDecoration(
                    color: a == 0
                        ? (dark
                              ? Colors.white.withValues(alpha: 0.05)
                              : const Color(0xFFEDEFF5))
                        : AppTheme.primary.withValues(alpha: a),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              const SizedBox(width: 2),
              Text(
                '많음',
                style: TextStyle(
                  fontSize: 9.5,
                  color: dark ? Colors.white38 : AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
