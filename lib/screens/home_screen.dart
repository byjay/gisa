import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/pass_prediction_card.dart';
import '../widgets/dday_plan_card.dart';
import '../widgets/due_review_card.dart';
import '../widgets/due_flashcard_card.dart';
import 'study/smart_review_screen.dart';

class HomeScreen extends StatelessWidget {
  final void Function(int) onNavigate;
  const HomeScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final upcoming = app.exams.where((e) => e.dDay >= 0).toList();
    final nearest = upcoming.isNotEmpty ? upcoming.first : null;
    final dailyRatio = app.dailyGoalMinutes > 0
        ? (app.todayMinutes / app.dailyGoalMinutes).clamp(0.0, 1.0)
        : 0.0;
    final pendingNotes = app.notes.where((n) => !n.mastered).length;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── 프리미엄 헤더 ──
            SliverToBoxAdapter(child: _header(context, app, nearest)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // 오늘 학습 진행 스트립
                  _todayStrip(context, app, dailyRatio, pendingNotes),
                  const SizedBox(height: 14),
                  // 복습 카드들
                  const DueReviewCard(),
                  const DueFlashcardCard(),
                  // 🎯 합격 예측
                  const PassPredictionCard(),
                  const SizedBox(height: 12),
                  DDayPlanCard(dDay: nearest?.dDay ?? 0),
                  // 문제은행 배너
                  const SectionHeader(
                    emoji: '⚡',
                    title: '전기기사 문제은행',
                    subtitle: '이론-문제-암기법 완전 연동 학습 시스템',
                  ),
                  _bankBanner(context),
                  // 빠른 실행
                  const SectionHeader(emoji: '🚀', title: '빠른 실행'),
                  Row(
                    children: [
                      Expanded(
                        child: _actionTile(
                          context,
                          icon: Icons.play_circle_fill_rounded,
                          label: '타이머 시작',
                          sub: '집중 학습 기록',
                          gradient: AppTheme.heroGradient,
                          onTap: () => onNavigate(3),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _actionTile(
                          context,
                          icon: Icons.school_rounded,
                          label: '오늘의 학습',
                          sub: '문제·강의·암기',
                          gradient: AppTheme.electricGradient,
                          onTap: () => onNavigate(1),
                        ),
                      ),
                    ],
                  ),
                  // 다가오는 시험
                  if (upcoming.length > 1) ...[
                    SectionHeader(
                      emoji: '🗓',
                      title: '다가오는 시험',
                      actionLabel: '전체 보기',
                      onAction: () => onNavigate(2),
                    ),
                    for (final e in upcoming.skip(1).take(3))
                      PremiumCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        onTap: () => onNavigate(2),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: e.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              alignment: Alignment.center,
                              child: Text(e.name[0],
                                  style: TextStyle(
                                      color: e.color,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14),
                                      overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 2),
                                  Text(
                                      DateFormat('yyyy.MM.dd (E)', 'ko')
                                          .format(e.examDate),
                                      style: TextStyle(
                                          fontSize: 11.5,
                                          color: dark
                                              ? Colors.white54
                                              : AppTheme.textMuted)),
                                ],
                              ),
                            ),
                            PillBadge(
                                text: 'D-${e.dDay}', color: e.color),
                          ],
                        ),
                      ),
                    const SizedBox(height: 4),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 그라디언트 헤더: 인사 + D-Day 히어로 ──────────────
  Widget _header(BuildContext context, AppProvider app, dynamic nearest) {
    final now = DateTime.now();
    final greeting = now.hour < 6
        ? '새벽 공부, 대단해요 🌙'
        : now.hour < 12
            ? '좋은 아침이에요 ☀️'
            : now.hour < 18
                ? '오늘도 화이팅! 💪'
                : '저녁 학습 시간이에요 🌆';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(AppTheme.rXl - 4),
        boxShadow: AppTheme.glowShadow(AppTheme.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('M월 d일 EEEE', 'ko').format(now),
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 3),
                    Text(greeting,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4)),
                  ],
                ),
              ),
              // 다크모드 토글
              _glassIconButton(
                context,
                icon: app.darkMode
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                onTap: () => context.read<AppProvider>().toggleDarkMode(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // D-Day 히어로 영역
          GestureDetector(
            onTap: () => onNavigate(2),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(AppTheme.rMd),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: nearest != null
                  ? Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(nearest.name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800),
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 3),
                              Text(
                                DateFormat('yyyy.MM.dd (E)', 'ko')
                                    .format(nearest.examDate),
                                style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.7),
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            nearest.dDay == 0
                                ? 'D-Day'
                                : 'D-${nearest.dDay}',
                            style: const TextStyle(
                                color: AppTheme.primaryDark,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        const Icon(Icons.add_circle_outline_rounded,
                            color: Colors.white),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('시험을 등록하고 D-Day를 관리하세요',
                              style: TextStyle(
                                  color:
                                      Colors.white.withValues(alpha: 0.9),
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600)),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: Colors.white70),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassIconButton(BuildContext context,
      {required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }

  // ── 오늘 학습 스트립: 목표 진행 + 스탯 3종 ─────────────
  Widget _todayStrip(BuildContext context, AppProvider app,
      double dailyRatio, int pendingNotes) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return PremiumCard(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('오늘의 학습 목표',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13.5)),
              const Spacer(),
              Text('${app.todayMinutes}',
                  style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 16)),
              Text(' / ${app.dailyGoalMinutes}분',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: dark ? Colors.white54 : AppTheme.textMuted)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: dailyRatio),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => LinearProgressIndicator(
                value: v,
                minHeight: 9,
                backgroundColor: dark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFEEF0F7),
                valueColor: AlwaysStoppedAnimation(
                  dailyRatio >= 1.0 ? AppTheme.success : AppTheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            dailyRatio >= 1.0
                ? '오늘 목표 달성! 🎉 내일도 이 기세로!'
                : '목표까지 ${app.dailyGoalMinutes - app.todayMinutes}분 — 조금만 더!',
            style: TextStyle(
                fontSize: 11.5,
                color: dark ? Colors.white54 : AppTheme.textMuted),
          ),
          const SizedBox(height: 12),
          Container(
            height: 1,
            color: dark
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0xFFEEF0F7),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _miniStat(context, Icons.local_fire_department_rounded,
                  '${app.streak}일', '연속 학습', const Color(0xFFF97316),
                  () => onNavigate(4)),
              _vDivider(context),
              _miniStat(context, Icons.schedule_rounded,
                  '${app.weekMinutes}분', '이번 주', AppTheme.electric,
                  () => onNavigate(4)),
              _vDivider(context),
              _miniStat(context, Icons.quiz_rounded, '$pendingNotes개',
                  '복습할 오답', AppTheme.danger, () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const SmartReviewScreen()));
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vDivider(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 1,
      height: 34,
      color: dark
          ? Colors.white.withValues(alpha: 0.06)
          : const Color(0xFFEEF0F7),
    );
  }

  Widget _miniStat(BuildContext context, IconData icon, String value,
      String label, Color color, VoidCallback onTap) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 4),
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 14.5)),
              ],
            ),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 10.5,
                    color: dark ? Colors.white54 : AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }

  // ── 문제은행 배너 ────────────────────────────────
  Widget _bankBanner(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return PremiumCard(
      onTap: () => onNavigate(1),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const IconBadge(
                  icon: Icons.bolt_rounded,
                  color: AppTheme.accent,
                  size: 46,
                  iconSize: 26),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('10년치 기출 완전 정복',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text('CBT 출제의 50%는 기출 재출제 — 여기서 다 잡아요',
                        style: TextStyle(
                            fontSize: 11.5,
                            color: dark
                                ? Colors.white54
                                : AppTheme.textMuted)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: dark ? Colors.white38 : AppTheme.textMuted),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _bankStat(context, '2,897', '기출 문항'),
              _bankStat(context, '46', '1:1 강의 토픽'),
              _bankStat(context, '347', '반복기출 암기'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bankStat(BuildContext context, String num, String label) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: dark
              ? Colors.white.withValues(alpha: 0.05)
              : const Color(0xFFF6F7FB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(num,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primary,
                    letterSpacing: -0.3)),
            const SizedBox(height: 1),
            Text(label,
                style: TextStyle(
                    fontSize: 10.5,
                    color: dark ? Colors.white54 : AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }

  // ── 빠른 실행 그라디언트 타일 ─────────────────────
  Widget _actionTile(BuildContext context,
      {required IconData icon,
      required String label,
      required String sub,
      required Gradient gradient,
      required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppTheme.rMd),
        boxShadow: AppTheme.glowShadow(
            (gradient as LinearGradient).colors.first),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.rMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.rMd),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: Colors.white, size: 26),
                const SizedBox(height: 10),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5)),
                const SizedBox(height: 2),
                Text(sub,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

