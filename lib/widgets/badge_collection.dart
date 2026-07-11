import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

/// 🏅 마법 배지 도감 — 학습 업적을 배지로 수집
class BadgeCollection extends StatelessWidget {
  const BadgeCollection({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final dark = Theme.of(context).brightness == Brightness.dark;

    final totalCorrect = app.quizResults
        .fold<int>(0, (s, r) => s + ((r['correct'] as int?) ?? 0));
    final totalSolved = app.quizResults
        .fold<int>(0, (s, r) => s + ((r['total'] as int?) ?? 0));
    final passCount = app.quizResults
        .where((r) =>
            ((r['correct'] as int?) ?? 0) * 100 >=
            ((r['total'] as int?) ?? 1) * 60)
        .length;

    final badges = <({String emoji, String name, String desc, bool earned})>[
      (
        emoji: '🔥',
        name: '첫 불꽃',
        desc: '첫 학습 기록',
        earned: app.totalMinutes > 0,
      ),
      (
        emoji: '⚡',
        name: '번개 견습생',
        desc: '문제 50개 풀기',
        earned: totalSolved >= 50,
      ),
      (
        emoji: '🧠',
        name: '지혜의 눈',
        desc: '정답 100개',
        earned: totalCorrect >= 100,
      ),
      (
        emoji: '🌙',
        name: '3일 연속',
        desc: '3일 연속 학습',
        earned: app.streak >= 3,
      ),
      (
        emoji: '☀️',
        name: '7일 연속',
        desc: '일주일 개근',
        earned: app.streak >= 7,
      ),
      (
        emoji: '⏳',
        name: '시간의 마법사',
        desc: '총 10시간 학습',
        earned: app.totalMinutes >= 600,
      ),
      (
        emoji: '🏆',
        name: '합격의 증표',
        desc: '모의고사 합격권 1회',
        earned: passCount >= 1,
      ),
      (
        emoji: '💎',
        name: '다이아 멘탈',
        desc: '합격권 5회 달성',
        earned: passCount >= 5,
      ),
      (
        emoji: '🧙',
        name: '정식 마법사',
        desc: '레벨 5 도달',
        earned: app.level >= 5,
      ),
      (
        emoji: '👑',
        name: '대마법사',
        desc: '레벨 10 도달',
        earned: app.level >= 10,
      ),
    ];
    final earnedCount = badges.where((b) => b.earned).length;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(
                  icon: Icons.military_tech_rounded,
                  color: Color(0xFFF59E0B),
                  size: 36,
                  iconSize: 18),
              const SizedBox(width: 10),
              const Text('마법 배지 도감',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const Spacer(),
              PillBadge(
                text: '$earnedCount / ${badges.length}',
                color: const Color(0xFFF59E0B),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 12,
            children: [
              for (final b in badges) _badge(context, b, dark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(
      BuildContext context,
      ({String emoji, String name, String desc, bool earned}) b,
      bool dark) {
    return Tooltip(
      message: '${b.name} — ${b.desc}',
      triggerMode: TooltipTriggerMode.tap,
      child: SizedBox(
        width: 62,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: b.earned
                    ? const LinearGradient(
                        colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: b.earned
                    ? null
                    : (dark
                        ? Colors.white.withValues(alpha: 0.05)
                        : const Color(0xFFF0F1F7)),
                shape: BoxShape.circle,
                border: Border.all(
                  color: b.earned
                      ? const Color(0xFFF59E0B)
                      : (dark
                          ? Colors.white.withValues(alpha: 0.08)
                          : const Color(0xFFE0E2EC)),
                  width: b.earned ? 2 : 1,
                ),
                boxShadow: b.earned
                    ? [
                        BoxShadow(
                          color: const Color(0xFFF59E0B)
                              .withValues(alpha: 0.35),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Opacity(
                opacity: b.earned ? 1 : 0.3,
                child: Text(b.emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              b.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: b.earned
                    ? (dark ? Colors.white : AppTheme.textStrong)
                    : (dark ? Colors.white30 : AppTheme.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
