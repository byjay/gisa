import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

/// 🪄 오늘의 마법 미션 — 자동으로 달성 체크되는 3가지 데일리 퀘스트
class DailyMissionCard extends StatelessWidget {
  const DailyMissionCard({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final dark = Theme.of(context).brightness == Brightness.dark;

    final missions =
        <({String label, String reward, bool done, double progress})>[
          (
            label: '학습 30분 채우기',
            reward: '+60 XP',
            done: app.todayMinutes >= 30,
            progress: (app.todayMinutes / 30).clamp(0.0, 1.0),
          ),
          (
            label: '문제 10개 풀기',
            reward: '+50 XP',
            done: app.todayQuizSolved >= 10,
            progress: (app.todayQuizSolved / 10).clamp(0.0, 1.0),
          ),
          (
            label: '정답 5개 맞히기',
            reward: '+25 XP',
            done: app.todayQuizCorrect >= 5,
            progress: (app.todayQuizCorrect / 5).clamp(0.0, 1.0),
          ),
        ];
    final doneCount = missions.where((m) => m.done).length;
    final allDone = doneCount == missions.length;

    return PremiumCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🪄', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 7),
              const Text(
                '오늘의 마법 미션',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              const Spacer(),
              PillBadge(
                text: allDone ? '올 클리어! ✨' : '$doneCount / ${missions.length}',
                color: allDone ? AppTheme.success : AppTheme.accent,
                filled: allDone,
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < missions.length; i++) ...[
            if (i > 0) const SizedBox(height: 9),
            _missionRow(context, missions[i], dark),
          ],
        ],
      ),
    );
  }

  Widget _missionRow(
    BuildContext context,
    ({String label, String reward, bool done, double progress}) m,
    bool dark,
  ) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            gradient: m.done ? AppTheme.successGradient : null,
            color: m.done
                ? null
                : (dark
                      ? Colors.white.withValues(alpha: 0.07)
                      : const Color(0xFFEEF0F7)),
            borderRadius: BorderRadius.circular(7),
          ),
          child: m.done
              ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                m.label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  decoration: m.done ? TextDecoration.lineThrough : null,
                  color: m.done
                      ? (dark ? Colors.white38 : AppTheme.textMuted)
                      : (dark ? Colors.white : AppTheme.textStrong),
                ),
              ),
              if (!m.done) ...[
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: m.progress,
                    minHeight: 4,
                    backgroundColor: dark
                        ? Colors.white.withValues(alpha: 0.06)
                        : const Color(0xFFF0F1F7),
                    color: AppTheme.accent,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          m.reward,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: m.done ? AppTheme.success : AppTheme.accent,
          ),
        ),
      ],
    );
  }
}
