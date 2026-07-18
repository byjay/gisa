import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/study_data.dart';
import '../services/exam_track.dart';
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
import 'study/beginner_roadmap_screen.dart';
import 'study/theory_screen.dart';
import 'study/flashcard_screen.dart';
import 'study/quiz_play_screen.dart';
import 'settings_screen.dart';
import '../widgets/persistent_nav.dart';
import '../widgets/tutor_coach.dart';

class HomeScreen extends StatelessWidget {
  final void Function(int) onNavigate;
  const HomeScreen({super.key, required this.onNavigate});

  /// 시간대·스트릭 기반 볼트쌤 상황 결정
  Widget _homeCoach(AppProvider app) {
    final hour = DateTime.now().hour;
    CoachSituation s;
    if (app.streak >= 3) {
      s = CoachSituation.homeStreak;
    } else if (hour < 12) {
      s = CoachSituation.homeMorning;
    } else if (hour < 18) {
      s = CoachSituation.homeAfternoon;
    } else {
      s = CoachSituation.homeNight;
    }
    return TutorCoach(situation: s);
  }

  /// Q56: 스트릭이 3일 이상 쌓여 있고, 저녁(18시 이후) 이후인데
  /// 아직 오늘 학습을 안 했다면 "오늘 스트릭이 끊긴다"는 손실회피 경고를 띄운다.
  bool _showStreakWarning(AppProvider app) {
    final hour = DateTime.now().hour;
    return app.streak >= 2 && hour >= 18 && app.todayMinutes < 5;
  }

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
                  // 📚 과목(종목) 변경 — 홈 메인에 배치(#2)
                  FadeSlideIn(
                    index: 0,
                    child: _SubjectSwitcher(onNavigate: onNavigate),
                  ),
                  const SizedBox(height: 12),
                  // 🎓 볼트쌀 1:1 코치 — 시간대별 살아있는 멘트
                  FadeSlideIn(index: 0, child: _homeCoach(app)),
                  const SizedBox(height: 12),
                  // 🔥 스트릭 손실회피 경고 (밤 시간대 + 오늘 미학습 시)
                  if (_showStreakWarning(app))
                    const FadeSlideIn(index: 0, child: _StreakWarningBanner()),
                  if (_showStreakWarning(app)) const SizedBox(height: 12),
                  // 📊 사회적 증거 — 함께 공부하는 학습자 지표
                  const FadeSlideIn(index: 0, child: _SocialProofCard()),
                  const SizedBox(height: 12),
                  // 🐣 왕초보 로드맵 배너 (지식 0 시작자용)
                  const FadeSlideIn(index: 0, child: _BeginnerBanner()),
                  const SizedBox(height: 12),
                  // 🎯 과목 선택 허브 — 과목별로 바로 이론/기출/암기 진입
                  const FadeSlideIn(index: 1, child: _SubjectHub()),
                  const SizedBox(height: 12),
                  // 오늘 학습 진행 스트립
                  FadeSlideIn(
                    index: 0,
                    child: _todayStrip(context, app, dailyRatio, pendingNotes),
                  ),
                  const SizedBox(height: 12),
                  FadeSlideIn(
                    index: 1,
                    child: AutoStudyPreviewCard(
                      onOpen: () => pushWithNav(
                        context,
                        const AutoStudyScreen(),
                        currentSection: 1,
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
                    child: LeagueMiniStrip(onTap: () => onNavigate(4)),
                  ),
                  const SizedBox(height: 12),
                  // 🎯 합격 예측
                  const FadeSlideIn(index: 4, child: PassPredictionCard()),
                  const SizedBox(height: 12),
                  FadeSlideIn(
                    index: 5,
                    child: DDayPlanCard(dDay: nearest?.dDay ?? 0),
                  ),
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
                    child: SectionHeader(emoji: '🚀', title: '빠른 실행'),
                  ),
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
                          horizontal: 14,
                          vertical: 12,
                        ),
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
                              child: Text(
                                e.name.isEmpty ? '?' : e.name[0],
                                style: TextStyle(
                                  color: e.color,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat(
                                      'yyyy.MM.dd (E)',
                                      'ko',
                                    ).format(e.examDate),
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: dark
                                          ? Colors.white54
                                          : AppTheme.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PillBadge(text: 'D-${e.dDay}', color: e.color),
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
                builder: (_, c) =>
                    SparkleOverlay(width: c.maxWidth, height: c.maxHeight),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1행: 날짜 + 액션 버튼 (좁은 화면에서도 안전)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        DateFormat('M월 d일 EEEE', 'ko').format(now),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // 종목 전환 (다른 시험 고르기)
                    _trackChip(context),
                    const SizedBox(width: 8),
                    // 테마 팔레트 선택
                    _glassIconButton(
                      context,
                      icon: Icons.palette_rounded,
                      semanticLabel: '테마 색상 선택',
                      onTap: () => _showThemeSheet(context, app),
                    ),
                    const SizedBox(width: 8),
                    // 다크모드 토글
                    _glassIconButton(
                      context,
                      icon: app.darkMode
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      semanticLabel: app.darkMode ? '라이트 모드로 전환' : '다크 모드로 전환',
                      onTap: () => context.read<AppProvider>().toggleDarkMode(),
                    ),
                    const SizedBox(width: 8),
                    // 설정 (계정·로그인)
                    _glassIconButton(
                      context,
                      icon: Icons.settings_rounded,
                      semanticLabel: '설정 화면 열기',
                      onTap: () => pushWithNav(
                        context,
                        const SettingsScreen(),
                        currentSection: 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 2행: 인사말 (전체 폭 사용 → 세로 깨짐 방지)
                Text(
                  greeting,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
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
                        color: Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: nearest != null
                        ? Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      nearest.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      DateFormat(
                                        'yyyy.MM.dd (E)',
                                        'ko',
                                      ).format(nearest.examDate),
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
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
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              const Icon(
                                Icons.add_circle_outline_rounded,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '시험을 등록하고 D-Day를 관리하세요',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.white70,
                              ),
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
            child: Text(
              'Lv${app.level}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '🧙 ${app.levelTitle}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${app.xp} XP · 다음까지 ${app.xpToNextLevel}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                      valueColor: const AlwaysStoppedAnimation(
                        Color(0xFFFBBF24),
                      ),
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
              Text(
                track.shortName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.swap_horiz_rounded,
                color: Colors.white,
                size: 15,
              ),
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
        content: const Text('종목 선택 화면으로 이동합니다.\n학습 기록·XP·스트릭은 그대로 유지돼요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('종목 바꾸기'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<AppProvider>().clearTrack();
    }
  }

  Widget _glassIconButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
    String? semanticLabel,
  }) {
    final button = Material(
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
    if (semanticLabel == null) return button;
    return Tooltip(
      message: semanticLabel,
      child: Semantics(button: true, label: semanticLabel, child: button),
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
              const Text(
                '🎨 테마 컬러',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                '앱 전체 색감을 5가지 중에 골라보세요',
                style: TextStyle(
                  fontSize: 12.5,
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
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
                          horizontal: 14,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selected ? p.seed : Colors.transparent,
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
                              child: Text(
                                p.emoji,
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                p.name,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                ),
                              ),
                            ),
                            if (selected)
                              Icon(
                                Icons.check_circle_rounded,
                                color: p.seed,
                                size: 22,
                              ),
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
  Widget _todayStrip(
    BuildContext context,
    AppProvider app,
    double dailyRatio,
    int pendingNotes,
  ) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return PremiumCard(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '오늘의 학습 목표',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
              const Spacer(),
              Text(
                '${app.todayMinutes}',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              Text(
                ' / ${app.dailyGoalMinutes}분',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: dark ? Colors.white54 : AppTheme.textMuted,
                ),
              ),
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
              color: dark ? Colors.white54 : AppTheme.textMuted,
            ),
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
                () => onNavigate(4),
              ),
              _vDivider(context),
              _miniStat(
                context,
                Icons.schedule_rounded,
                '${app.weekMinutes}분',
                '이번 주',
                AppTheme.electric,
                () => onNavigate(4),
              ),
              _vDivider(context),
              _miniStat(
                context,
                Icons.quiz_rounded,
                '$pendingNotes개',
                '복습할 오답',
                AppTheme.danger,
                () {
                  pushWithNav(
                    context,
                    const SmartReviewScreen(),
                    currentSection: 1,
                  );
                },
              ),
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

  Widget _miniStat(
    BuildContext context,
    IconData icon,
    String value,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Semantics(
        button: true,
        label: '$label $value',
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
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  color: dark ? Colors.white54 : AppTheme.textMuted,
                ),
              ),
            ],
          ),
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
                iconSize: 26,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${StudyData.instance.track.bankLabel} 완전 정복',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'CBT 출제의 50%는 기출 재출제 — 여기서 다 잡아요',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: dark ? Colors.white54 : AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: dark ? Colors.white38 : AppTheme.textMuted,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _bankStat(
                context,
                StudyData.instance.track.questionCountLabel,
                '기출 문항',
              ),
              _bankStat(
                context,
                '${StudyData.instance.track.topicCount}',
                '1:1 강의 토픽',
              ),
              _bankStat(
                context,
                '${StudyData.instance.track.repeatCount}',
                '반복기출 암기',
              ),
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
            Text(
              num,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppTheme.primary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                color: dark ? Colors.white54 : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 빠른 실행 그라디언트 타일 ─────────────────────
  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String sub,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppTheme.rMd),
        boxShadow: AppTheme.glowShadow(
          (gradient as LinearGradient).colors.first,
        ),
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
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 📚 홈 메인 과목(종목) 변경 카드 (#2)
///
/// 현재 학습 중인 종목을 크게 보여주고, 가로 스크롤로 다른 종목을
/// 즉시 전환한다. 학습 기록/XP/스트릭은 그대로 유지된다.
class _SubjectSwitcher extends StatelessWidget {
  final void Function(int) onNavigate;
  const _SubjectSwitcher({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    // provider 변경(종목 전환) 시 리빌드되도록 watch
    context.watch<AppProvider>();
    final current = StudyData.instance.track;
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFEDEFF6),
        ),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book_rounded, size: 17, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                '학습 과목 변경',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface.withValues(alpha: 0.85),
                ),
              ),
              const Spacer(),
              Text(
                '탭하여 전환',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 92,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.zero,
              itemCount: kExamTracks.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final t = kExamTracks[i];
                final selected = t.id == current.id;
                return _SubjectChip(
                  track: t,
                  selected: selected,
                  onTap: () async {
                    if (selected) return;
                    await context.read<AppProvider>().selectTrack(t.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${t.name}(으)로 전환했어요'),
                          duration: const Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectChip extends StatelessWidget {
  final ExamTrack track;
  final bool selected;
  final VoidCallback onTap;
  const _SubjectChip({
    required this.track,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 108,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [cs.primary, cs.primary.withValues(alpha: 0.78)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected
              ? null
              : (dark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFF4F5FA)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : (dark
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFFE6E8F0)),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(track.emoji, style: const TextStyle(fontSize: 20)),
                const Spacer(),
                if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              track.shortName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: selected
                    ? Colors.white
                    : cs.onSurface.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 🐣 왕초보 로드맵 배너 ─────────────────────────────────
class _BeginnerBanner extends StatelessWidget {
  const _BeginnerBanner();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => pushWithNav(
          context,
          const BeginnerRoadmapScreen(),
          currentSection: 0,
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              const Text('🐣', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '처음이라 뭐부터 할지 모르겠다면',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '지식 0 → 합격, 왕초보 6단계 로드맵',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 🎯 과목 선택 허브 — 과목별로 이론/기출/암기 바로 진입 ──
class _SubjectHub extends StatelessWidget {
  const _SubjectHub();

  static const _palette = [
    Color(0xFF4F46E5),
    Color(0xFF0891B2),
    Color(0xFFDC2626),
    Color(0xFFF59E0B),
    Color(0xFF10B981),
  ];

  @override
  Widget build(BuildContext context) {
    context.watch<AppProvider>();
    final track = StudyData.instance.track;
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 8),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.06)
              : const Color(0xFFEDEFF6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.category_rounded, size: 17, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                '과목별 바로 공부',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface.withValues(alpha: 0.85),
                ),
              ),
              const Spacer(),
              Text(
                '과목을 탭하세요',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < track.subjects.length; i++)
            _subjectRow(
              context,
              i,
              track.subjects[i],
              _palette[i % _palette.length],
            ),
        ],
      ),
    );
  }

  Widget _subjectRow(BuildContext context, int idx, String subject, Color c) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openSubjectSheet(context, subject, c),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [c, c.withValues(alpha: 0.65)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                '${idx + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                subject,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: cs.onSurface.withValues(alpha: 0.35),
            ),
          ],
        ),
      ),
    );
  }

  void _openSubjectSheet(BuildContext context, String subject, Color c) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subject,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '무엇부터 할까요?',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Theme.of(
                    sheetCtx,
                  ).colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _sheetIcon(Icons.menu_book_rounded, c),
                title: const Text(
                  '기초 이론 배우기',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('처음이라면 여기부터'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  pushWithNav(context, const TheoryScreen(), currentSection: 1);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _sheetIcon(Icons.quiz_rounded, c),
                title: const Text(
                  '과목 기출 풀기',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('이 과목 문제만 모아서'),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  final qs = await StudyData.instance.questionsBySubject(
                    subject,
                  );
                  if (!context.mounted) return;
                  if (qs.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('이 과목의 기출 데이터가 없습니다.')),
                    );
                    return;
                  }
                  pushWithNav(
                    context,
                    QuizPlayScreen(
                      title: '$subject 기출',
                      questions: qs,
                      examMode: false,
                    ),
                    currentSection: 1,
                  );
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: _sheetIcon(Icons.style_rounded, c),
                title: const Text(
                  '플래시카드 암기',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text('핵심 개념 반복 암기'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  pushWithNav(
                    context,
                    FlashcardScreen(subjectFilter: subject),
                    currentSection: 1,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetIcon(IconData ic, Color c) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: c.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(ic, color: c, size: 21),
  );
}

// ── 🔥 Q56: 스트릭 손실회피 경고 배너 ─────────────────────
/// 연속 학습 스트릭이 끊기기 직전(저녁인데 오늘 미학습)임을 알려
/// 손실회피 심리로 마지막 학습 동기를 유도한다.
class _StreakWarningBanner extends StatelessWidget {
  const _StreakWarningBanner();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    return Semantics(
      label: '경고: ${app.streak}일 연속 학습 스트릭이 오늘 끊길 위험이 있습니다',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => pushWithNav(
            context,
            const SmartReviewScreen(),
            currentSection: 1,
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFF97316)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${app.streak}일 연속 스트릭이 곧 끊겨요!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '5분만 공부해도 오늘 스트릭이 유지돼요',
                        style: TextStyle(color: Colors.white, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 📊 Q59: 사회적 증거 카드 ───────────────────────────────
/// 검증 가능한 자체 지표(문항 수·토픽 수 등)를 노출해
/// "많은 사람이 쓰는 신뢰할 만한 앱"이라는 사회적 증거를 제공한다.
/// (허위 수치 대신 앱 내에 이미 존재하는 실제 데이터 기반 지표만 사용)
class _SocialProofCard extends StatelessWidget {
  const _SocialProofCard();

  @override
  Widget build(BuildContext context) {
    final track = StudyData.instance.track;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label:
          '${track.name} 학습 콘텐츠 지표: 기출 ${track.questionCountLabel}, 1대1 강의 ${track.topicCount}개',
      child: PremiumCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(
              Icons.verified_rounded,
              color: AppTheme.primary,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '검증된 ${track.questionCountLabel} 기출 문항으로 준비 중',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${track.topicCount}개 1:1 강의 토픽 · ${track.repeatCount}개 반복기출 암기',
                    style: TextStyle(
                      fontSize: 11,
                      color: dark ? Colors.white54 : AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
