import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

/// 리그 순위 계산 공용 로직 (카드/미니 스트립에서 공유)
({int rank, int gapToNext, int total}) leagueStanding(AppProvider app) {
  final now = DateTime.now();
  final myXp = app.weekXp;
  final rivals = WeeklyLeagueCard.rivalsFor(now);
  final xps = [myXp, ...rivals.map((r) => r.xp)]..sort((a, b) => b - a);
  final rank = xps.indexOf(myXp) + 1;
  final gap = rank > 1 ? xps[rank - 2] - myXp + 1 : 0;
  return (rank: rank, gapToNext: gap, total: xps.length);
}

/// 🏠 홈 상단용 리그 미니 스트립 — 탭하면 통계 탭으로 이동
class LeagueMiniStrip extends StatelessWidget {
  const LeagueMiniStrip({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final s = leagueStanding(app);
    final promoted = s.rank <= 3;
    final medal = switch (s.rank) { 1 => '🥇', 2 => '🥈', 3 => '🥉', _ => '🏆' };
    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      onTap: onTap,
      child: Row(
        children: [
          Text(medal, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '위클리 리그 ${s.rank}위 / ${s.total}명',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13.5),
                ),
                Text(
                  promoted
                      ? '승급권 안! 이대로 지켜내세요'
                      : '${s.gapToNext}XP 더 모으면 ${s.rank - 1}위 탈환',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          PillBadge(
            text: '${app.weekXp} XP',
            color: promoted ? AppTheme.success : AppTheme.accent,
            filled: promoted,
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

/// 🏆 위클리 마법 리그 — Duolingo 리그 시스템의 오프라인 재해석.
/// 같은 주차 시드로 생성되는 가상 라이벌 9명과 주간 XP 경쟁.
/// 라이벌들은 요일이 지날수록 점수가 차오르므로 "지금 안 하면 밀린다"는 긴장감을 만든다.
class WeeklyLeagueCard extends StatelessWidget {
  const WeeklyLeagueCard({super.key});

  static const _rivalNames = [
    '번개술사 김도윤', '회로마녀 이서연', '자기장기사 박지호', '전압술사 최하은',
    '옴의현자 정시우', '주파수요정 강민서', '변압마스터 조은우', '플럭스몽크 윤지아',
    '키르히호프 한결', '테슬라도제 오유진', '패러데이 신아린', '맥스웰견습 임준서',
  ];

  /// 주차 시드 → 이번 주 내내 같은 라이벌·같은 성장 곡선 (결정적)
  static List<({String name, int xp})> rivalsFor(DateTime now) {
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final seed = monday.year * 10000 + monday.month * 100 + monday.day;
    final rng = Random(seed);

    // 주 진행률: 월요일 0.05 → 일요일 밤 1.0 (라이벌 점수가 매일 차오름)
    final weekStart = monday;
    final elapsed = now.difference(weekStart).inMinutes;
    final progress = (elapsed / (7 * 24 * 60)).clamp(0.05, 1.0);

    final names = List<String>.from(_rivalNames)..shuffle(rng);
    return List.generate(9, (i) {
      // 주간 최종 목표 XP: 상위권은 빡세게, 하위권은 느슨하게
      final weeklyTarget = 250 + rng.nextInt(1800);
      final pace = 0.7 + rng.nextDouble() * 0.6; // 개인별 페이스 편차
      final xp = (weeklyTarget * progress * pace).round();
      return (name: names[i], xp: xp);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    final myXp = app.weekXp;
    final entries = <({String name, int xp, bool me})>[
      (name: '나 (${app.levelTitle})', xp: myXp, me: true),
      for (final r in rivalsFor(now)) (name: r.name, xp: r.xp, me: false),
    ]..sort((a, b) => b.xp.compareTo(a.xp));

    final myRank = entries.indexWhere((e) => e.me) + 1;
    final promoted = myRank <= 3;
    final daysLeft = 8 - now.weekday; // 일요일 마감

    // 다음 순위까지 필요한 XP
    final myIdx = myRank - 1;
    final gapToNext =
        myIdx > 0 ? entries[myIdx - 1].xp - myXp + 1 : 0;

    return PremiumCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🏆', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 7),
              const Text('위클리 마법 리그',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              const Spacer(),
              PillBadge(
                text: promoted ? '승급권 🎉' : '$myRank위',
                color: promoted ? AppTheme.success : AppTheme.accent,
                filled: promoted,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            daysLeft <= 1
                ? '오늘 밤 마감! ${promoted ? "승급권을 지켜내세요" : "막판 스퍼트 찬스"}'
                : gapToNext > 0
                    ? '마감까지 $daysLeft일 · ${gapToNext}XP 더 모으면 ${myRank - 1}위'
                    : '마감까지 $daysLeft일 · 1위 수성 중!',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < entries.length && i < 6; i++)
            _row(context, i + 1, entries[i], dark),
          if (myRank > 6) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Center(
                child: Text('⋯',
                    style: TextStyle(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
            ),
            _row(context, myRank, entries[myIdx], dark),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, int rank,
      ({String name, int xp, bool me}) e, bool dark) {
    final scheme = Theme.of(context).colorScheme;
    final medal = switch (rank) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => null,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: e.me
            ? AppTheme.primary.withValues(alpha: dark ? 0.22 : 0.09)
            : (dark
                ? Colors.white.withValues(alpha: 0.03)
                : const Color(0xFFF7F8FC)),
        borderRadius: BorderRadius.circular(11),
        border: e.me
            ? Border.all(color: AppTheme.primary.withValues(alpha: 0.5))
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 30,
            child: Text(
              medal ?? '$rank',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: medal != null ? 15 : 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              e.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: e.me ? FontWeight.w800 : FontWeight.w600,
                color: e.me ? AppTheme.primary : null,
              ),
            ),
          ),
          Text(
            '${e.xp} XP',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: e.me ? AppTheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
