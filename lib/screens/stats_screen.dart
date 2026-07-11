import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/badge_collection.dart';
import '../widgets/study_heatmap.dart';
import '../widgets/weekly_report_card.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final last7 = app.lastNDaysMinutes(7);
    final maxVal = last7.fold(0, (a, b) => a > b ? a : b);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('통계 & 목표')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            // ── 🧙 마법사 레벨 카드 ──
            PremiumCard(
              gradient: AppTheme.heroGradient,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B)
                              .withValues(alpha: 0.5),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text('Lv${app.level}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('🧙 ${app.levelTitle}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        Text(
                            '총 ${app.xp} XP · 다음 레벨까지 ${app.xpToNextLevel} XP',
                            style: TextStyle(
                                color:
                                    Colors.white.withValues(alpha: 0.75),
                                fontSize: 11.5)),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: LinearProgressIndicator(
                            value: app.levelProgress,
                            minHeight: 7,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.2),
                            valueColor: const AlwaysStoppedAnimation(
                                Color(0xFFFBBF24)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // ── 📈 주간 성장 리포트 ──
            const WeeklyReportCard(),
            const SizedBox(height: 12),
            // ── 🟩 12주 학습 히트맵 ──
            const StudyHeatmap(),
            const SizedBox(height: 12),
            // ── 🏅 마법 배지 도감 ──
            const BadgeCollection(),
            const SizedBox(height: 12),
            // ── 목표 진행 카드 ──
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const IconBadge(
                          icon: Icons.flag_rounded,
                          color: AppTheme.primary,
                          size: 36,
                          iconSize: 18),
                      const SizedBox(width: 10),
                      const Text('학습 목표',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _showGoalDialog(context),
                        icon: const Icon(Icons.edit_rounded, size: 15),
                        label: const Text('수정',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700)),
                        style: TextButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _goalRow(context, '오늘', app.todayMinutes,
                      app.dailyGoalMinutes, AppTheme.primary),
                  const SizedBox(height: 14),
                  _goalRow(context, '이번 주', app.weekMinutes,
                      app.weeklyGoalMinutes, AppTheme.electric),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── 요약 스탯 2종 ──
            Row(
              children: [
                Expanded(
                    child: _summaryCard(context, '총 학습',
                        _fmtMin(app.totalMinutes),
                        Icons.timer_rounded, AppTheme.primary)),
                const SizedBox(width: 10),
                Expanded(
                    child: _summaryCard(context, '연속 학습', '${app.streak}일',
                        Icons.local_fire_department_rounded,
                        const Color(0xFFF97316))),
              ],
            ),
            const SizedBox(height: 12),

            // ── 주간 바 차트 ──
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      IconBadge(
                          icon: Icons.bar_chart_rounded,
                          color: AppTheme.electric,
                          size: 36,
                          iconSize: 18),
                      SizedBox(width: 10),
                      Text('최근 7일 학습 시간',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 150,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(7, (i) {
                        final day = now.subtract(Duration(days: 6 - i));
                        final val = last7[i];
                        final h = maxVal > 0 ? (val / maxVal) * 100 : 0.0;
                        final isToday = i == 6;
                        return Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(val > 0 ? '$val' : '',
                                  style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isToday
                                          ? AppTheme.primary
                                          : (dark
                                              ? Colors.white54
                                              : AppTheme.textMuted))),
                              const SizedBox(height: 4),
                              TweenAnimationBuilder<double>(
                                tween: Tween(
                                    begin: 0,
                                    end: h < 4 && val > 0 ? 4 : h),
                                duration:
                                    const Duration(milliseconds: 700),
                                curve: Curves.easeOutCubic,
                                builder: (_, v, __) => Container(
                                  height: v,
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 6),
                                  decoration: BoxDecoration(
                                    gradient: isToday
                                        ? AppTheme.heroGradient
                                        : null,
                                    color: isToday
                                        ? null
                                        : AppTheme.primary.withValues(
                                            alpha: dark ? 0.35 : 0.25),
                                    borderRadius:
                                        const BorderRadius.vertical(
                                            top: Radius.circular(6)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(DateFormat('E', 'ko').format(day),
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isToday
                                          ? FontWeight.w800
                                          : FontWeight.w500,
                                      color: isToday
                                          ? AppTheme.primary
                                          : (dark
                                              ? Colors.white54
                                              : AppTheme.textMuted))),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── 시험별 학습 시간 ──
            if (app.exams.isNotEmpty)
              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        IconBadge(
                            icon: Icons.pie_chart_rounded,
                            color: AppTheme.accent,
                            size: 36,
                            iconSize: 18),
                        SizedBox(width: 10),
                        Text('시험별 학습 시간',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ...app.exams.map((e) {
                      final min = app.minutesForExam(e.id);
                      final total = app.totalMinutes;
                      final ratio = total > 0 ? min / total : 0.0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(e.name,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                                Text(_fmtMin(min),
                                    style: TextStyle(
                                        color: dark
                                            ? Colors.white54
                                            : AppTheme.textMuted,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: ratio,
                                minHeight: 7,
                                backgroundColor: dark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : const Color(0xFFEEF0F7),
                                color: e.color,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _fmtMin(int m) => m >= 60 ? '${m ~/ 60}시간 ${m % 60}분' : '$m분';

  Widget _goalRow(BuildContext context, String label, int current, int goal,
      Color color) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ratio = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    final done = ratio >= 1.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            if (done) const PillBadge(text: '달성!', color: AppTheme.success),
            const Spacer(),
            Text('$current',
                style: TextStyle(
                    color: done ? AppTheme.success : color,
                    fontWeight: FontWeight.w900,
                    fontSize: 14)),
            Text(' / $goal분  ·  ${(ratio * 100).toInt()}%',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: dark ? Colors.white54 : AppTheme.textMuted)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ratio),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => LinearProgressIndicator(
              value: v,
              minHeight: 9,
              backgroundColor: dark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFEEF0F7),
              color: done ? AppTheme.success : color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(BuildContext context, String label, String value,
      IconData icon, Color color) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return PremiumCard(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          IconBadge(icon: icon, color: color, size: 40, iconSize: 21),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: dark ? Colors.white54 : AppTheme.textMuted,
                  fontSize: 11.5)),
        ],
      ),
    );
  }

  void _showGoalDialog(BuildContext context) {
    final app = context.read<AppProvider>();
    final dailyCtrl =
        TextEditingController(text: app.dailyGoalMinutes.toString());
    final weeklyCtrl =
        TextEditingController(text: app.weeklyGoalMinutes.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('목표 설정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: dailyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '일일 목표 (분)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: weeklyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '주간 목표 (분)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
            onPressed: () {
              app.setGoals(
                daily: int.tryParse(dailyCtrl.text) ?? 120,
                weekly: int.tryParse(weeklyCtrl.text) ?? 600,
              );
              Navigator.pop(ctx);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}
