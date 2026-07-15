import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/study_data.dart';
import '../theme/app_theme.dart';
import '../widgets/pass_prediction_card.dart';
import '../widgets/dday_plan_card.dart';
import '../widgets/due_review_card.dart';
import '../widgets/due_flashcard_card.dart';
import '../widgets/daily_mission_card.dart';
import '../widgets/magic_effects.dart';
import '../widgets/weekly_league_card.dart';
import 'study/smart_review_screen.dart';
import 'study/auto_study_screen.dart';

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
                  FadeSlideIn(
                      index: 0,
                      child: _todayStrip(
                          context, app, dailyRatio, pendingNotes)),
                  const SizedBox(height: 12),
                  FadeSlideIn(
                    index: 1,
                    child: AutoStudyPreviewCard(
                      onOpen: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AutoStudyScreen(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 🔁 긴급 복습 (기억이 사라지기 전 최우선 행동)
                  const FadeSlideIn(index: 2, child: DueReviewCard()),
                  const FadeSlideIn(index: 1, child: DueFlashcardCard()),
                  // 🪄 오늘의 마법 미션
                  const FadeSlideIn(index: 2, child: DailyMissionCard()),
                  const SizedBox(height: 12),
                  // 🏆 위클리 리그 미니 스트립
                  FadeSlideIn(
                      index: 3,
                      child: LeagueMiniStrip(onTap: () => onNavigate(4))),
                  const SizedBox(height: 12),
                  // 🎯 합격 예측
                  const FadeSlideIn(index: 4, child: PassPredictionCard()),
                  const SizedBox(height: 12),
                  FadeSlideIn(
                      index: 5,
                      child: DDayPlanCard(dDay: nearest?.dDay ?? 0)),
                  // 문제은행 배너
                  FadeSlideIn(
                    index: 6,
                    child: SectionHeader(
                      emoji: '⚡',
                      title: '${StudyData.instance.track.name} 문제은행',
                      subtitle: '이론-문제-암기법 완전 연동 학습 시스템',
                    ),
                  ),
                  FadeSlideIn(index: 6, child: _bankBanner(context)),
                  // 빠른 실행
                  const FadeSlideIn(
                      index: 7,
                      child:
                          SectionHeader(emoji: '🚀', title: '빠른 실행')),
                  FadeSlideIn(
                    index: 7,
                    child: Row(
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
                              child: Text(e.name.isEmpty ? '?' : e.name[0],
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

    final timeGrad = AppTheme.timeGradient(now);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        gradient: timeGrad,
        borderRadius: BorderRadius.circular(AppTheme.rXl - 4),
        boxShadow: AppTheme.glowShadow(timeGrad.colors.first),
      ),
      child: Stack(
        children: [
          // ✨ 반짝이는 별 장식
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.rXl - 4),
              child: LayoutBuilder(
                builder: (_, c) => SparkleOverlay(
                    width: c.maxWidth, height: c.maxHeight),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
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
                                color:
                                    Colors.white.withValues(alpha: 0.75),
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
                    // 종목 전환 (다른 시험 고르기)
                    _trackChip(context),
                    const SizedBox(width: 8),
                    // 테마 팔레트 선택
                    _glassIconButton(
                      context,
                      icon: Icons.palette_rounded,
                      onTap: () => _showThemeSheet(context, app),
                    ),
                    const SizedBox(width: 8),
                    // 다크모드 토글
                    _glassIconButton(
                      context,
                      icon: app.darkMode
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      onTap: () =>
                          context.read<AppProvider>().toggleDarkMode(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // 🧙 레벨 & XP 바
                _levelStrip(context, app),
                const SizedBox(height: 12),
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
          ),
        ],
      ),
    );
  }

  // 🧙 레벨 배지 + XP 진행바
  Widget _levelStrip(BuildContext context, AppProvider app) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.rMd),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          // 레벨 원형 배지
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                  blurRadius: 10,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text('Lv${app.level}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('🧙 ${app.levelTitle}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800)),
                    const Spacer(),
                    Text('${app.xp} XP · 다음까지 ${app.xpToNextLevel}',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: app.levelProgress),
                    duration: const Duration(milliseconds: 1100),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => LinearProgressIndicator(
                      value: v,
                      minHeight: 7,
                      backgroundColor:
                          Colors.white.withValues(alpha: 0.18),
                      valueColor: const AlwaysStoppedAnimation(
                          Color(0xFFFBBF24)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 현재 종목 표시 + 탭 시 종목 전환 확인 다이얼로그
  Widget _trackChip(BuildContext context) {
    final track = StudyData.instance.track;
    return Material(
      color: Colors.white.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _confirmTrackChange(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(track.emoji, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 4),
              Text(track.shortName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
              const SizedBox(width: 2),
              const Icon(Icons.swap_horiz_rounded,
                  color: Colors.white, size: 15),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmTrackChange(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('다른 시험으로 바꿀까요?'),
        content: const Text(
            '종목 선택 화면으로 이동합니다.\n학습 기록·XP·스트릭은 그대로 유지돼요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('종목 바꾸기')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AppProvider>().clearTrack();
    }
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

  // ── 🎨 테마 팔레트 선택 바텀시트 ─────────────────────
  void _showThemeSheet(BuildContext context, AppProvider app) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('🎨 테마 컬러',
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('앱 전체 색감을 5가지 중에 골라보세요',
                  style: TextStyle(
                      fontSize: 12.5,
                      color: cs.onSurface.withValues(alpha: 0.6))),
              const SizedBox(height: 18),
              ...AppTheme.palettes.map((p) {
                final selected = p.id == app.themePaletteId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: selected
                        ? p.seed.withValues(alpha: 0.12)
                        : cs.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        app.setThemePalette(p.id);
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected
                                ? p.seed
                                : Colors.transparent,
                            width: 1.6,
                          ),
                        ),
                        child: Row(
                          children: [
                            // 색상 미리보기 (seed + accent)
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(11),
                                gradient: LinearGradient(
                                  colors: [p.seed, p.accent],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(p.emoji,
                                  style: const TextStyle(fontSize: 18)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(p.name,
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: selected
                                          ? FontWeight.w800
                                          : FontWeight.w600)),
                            ),
                            if (selected)
                              Icon(Icons.check_circle_rounded,
                                  color: p.seed, size: 22),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
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
              _miniStat(
                  context,
                  Icons.local_fire_department_rounded,
                  app.shieldCount > 0
                      ? '${app.streak}일 🛡️${app.shieldCount}'
                      : '${app.streak}일',
                  '연속 학습',
                  const Color(0xFFF97316),
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
                    Text('${StudyData.instance.track.bankLabel} 완전 정복',
                        style: const TextStyle(
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
              _bankStat(context, StudyData.instance.track.questionCountLabel,
                  '기출 문항'),
              _bankStat(context, '${StudyData.instance.track.topicCount}',
                  '1:1 강의 토픽'),
              _bankStat(context, '${StudyData.instance.track.repeatCount}',
                  '반복기출 암기'),
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

