import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../services/study_data.dart';
import '../../theme/app_theme.dart';
import 'quiz_play_screen.dart';
import 'theory_screen.dart';
import 'mnemonics_screen.dart';
import 'videos_screen.dart';
import 'lesson_screen.dart';
import 'slides_screen.dart';
import 'silgi_screen.dart';
import 'search_screen.dart';
import 'repeat_analysis_screen.dart';
import 'circuit_screen.dart';
import 'calculator_hub_screen.dart';
import 'pass_report_screen.dart';
import 'wrong_focus_screen.dart';
import 'visual_repeat_screen.dart';
import 'beginner_roadmap_screen.dart';
import 'formula_guide_screen.dart';
import 'exam_info_screen.dart';
import 'smart_review_screen.dart';
import 'study_guide_screen.dart';
import 'tutor_chat_screen.dart';
import 'auto_study_screen.dart';
import 'speed_memorize_screen.dart';
import '../../widgets/tutor_avatar.dart';
import '../../widgets/persistent_nav.dart';

/// 학습 허브: 탭 구조로 직관적 분류 — 기초학습 / 문제풀이 / 모의고사 / 이력
class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen>
    with SingleTickerProviderStateMixin {
  List<ExamPaper>? _exams;
  Map<String, List<TopicFreq>>? _freq;
  late final TabController _tab;

  static const _subjectColors = [
    Color(0xFF4F46E5),
    Color(0xFF0891B2),
    Color(0xFF7C3AED),
    Color(0xFFD97706),
    Color(0xFF059669),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    StudyData.instance.loadExams().then((v) {
      if (mounted) setState(() => _exams = v);
    });
    StudyData.instance.loadTopicFreq().then((v) {
      if (mounted) setState(() => _freq = v);
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exams = _exams;
    final trackName = StudyData.instance.track.name;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.bolt_rounded, color: AppTheme.accent, size: 24),
            const SizedBox(width: 6),
            Text('$trackName 학습'),
          ],
        ),
        bottom: TabBar(
          controller: _tab,
          isScrollable: false,
          labelStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: '기초학습'),
            Tab(text: '문제풀이'),
            Tab(text: '모의고사'),
            Tab(text: '이력'),
          ],
        ),
      ),
      body: exams == null
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tab,
              children: [
                _basicsTab(context),
                _practiceTab(context),
                _mockExamTab(context, exams),
                _historyTab(context),
              ],
            ),
    );
  }

  EdgeInsets get _pagePadding => EdgeInsets.symmetric(
    horizontal: MediaQuery.of(context).size.width > 900
        ? (MediaQuery.of(context).size.width - 800) / 2
        : 16,
    vertical: 12,
  );

  // ── 탭 1: 기초학습 (강의·이론·암기·도구) ─────────────
  Widget _basicsTab(BuildContext context) {
    return ListView(
      padding: _pagePadding,
      children: [
        TutorBanner(
          mood: TutorMood.cheer,
          message: '지금은 기초를 단단히 할 때예요. 이론을 짧게 보고 쉬운 문제로 바로 확인해 보세요.',
          onTap: () =>
              pushWithNav(context, const SlidesHomeScreen(), currentSection: 1),
        ),
        const SizedBox(height: 12),
        _heroCards(context),
        const SectionHeader(emoji: '✨', title: '핵심 기능'),
        _featureGrid(context),
        const SizedBox(height: 8),
        _beginnerCard(context),
        _examInfoCard(context),
        _cbtTrendCard(context),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── 탭 2: 문제풀이 (빈출순·쉬운순·랜덤) ───────────────
  Widget _practiceTab(BuildContext context) {
    return ListView(
      padding: _pagePadding,
      children: [
        SectionHeader(
          emoji: '🔥',
          title: '빈출순 문제풀기',
          subtitle:
              '${StudyData.instance.track.bankLabel} ${StudyData.instance.track.questionCountLabel}문제를 출제 빈도 높은 토픽 순서로',
        ),
        for (var i = 0; i < kSubjects.length; i++)
          _freqCard(context, kSubjects[i], _subjectColors[i]),
        const SectionHeader(
          emoji: '🌱',
          title: '쉬운 문제부터 풀기',
          subtitle: '난이도 하→중→상 순서로 자신감을 쌓으세요 (초보자 추천)',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in kSubjects)
              ActionChip(
                avatar: const Icon(
                  Icons.stairs_rounded,
                  size: 17,
                  color: AppTheme.success,
                ),
                label: Text(s, style: const TextStyle(fontSize: 12.5)),
                onPressed: () => _startEasyFirst(s),
              ),
          ],
        ),
        const SectionHeader(
          emoji: '🎲',
          title: '과목별 랜덤 연습',
          subtitle: '무작위 20문제로 실력 점검',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in kSubjects)
              ActionChip(
                avatar: const Icon(
                  Icons.shuffle_rounded,
                  size: 17,
                  color: AppTheme.electric,
                ),
                label: Text(s, style: const TextStyle(fontSize: 12.5)),
                onPressed: () => _startRandom(s),
              ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ── 탭 3: 모의고사 ────────────────────────────
  Widget _mockExamTab(BuildContext context, List<ExamPaper> exams) {
    return ListView(
      padding: _pagePadding,
      children: [
        SectionHeader(
          emoji: '📚',
          title: '연도별 기출 세트',
          subtitle: '최근 N년치 기출을 최신 회차부터 몰아서 풀기 · 회독용 추천',
        ),
        _yearRangeCard(
          context,
          5,
          '최근 5년치',
          '핵심 빈출 집중 · 빠른 1회독',
          const Color(0xFF22C55E),
        ),
        _yearRangeCard(
          context,
          7,
          '최근 7년치',
          '출제 경향 폭넓게 · 안정권 목표',
          const Color(0xFF3B82F6),
        ),
        _yearRangeCard(
          context,
          10,
          '최근 10년치',
          '모든 유형 정복 · 완전 마스터',
          const Color(0xFF8B5CF6),
        ),
        const SizedBox(height: 20),
        SectionHeader(
          emoji: '📝',
          title: '회차별 실전 모의고사',
          subtitle:
              '회차당 ${StudyData.instance.track.paperSize}문항 · 문항당 90초 타이머 · 합격 기준 60점',
        ),
        for (final e in exams) _examCard(context, e),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _yearRangeCard(
    BuildContext context,
    int years,
    String title,
    String desc,
    Color c,
  ) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      onTap: () => _startYearRange(years, title),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [c, c.withValues(alpha: 0.65)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(13),
            ),
            alignment: Alignment.center,
            child: Text(
              '$years년',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.3,
                    color: dark ? Colors.white54 : AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 5),
                FutureBuilder<int>(
                  future: StudyData.instance.papersInYearRange(years),
                  builder: (context, snap) {
                    final n = snap.data;
                    return Text(
                      n == null
                          ? '집계 중…'
                          : (n == 0
                                ? '해당 기간 기출 데이터 없음'
                                : '기출 $n회차 · 약 ${n * StudyData.instance.track.paperSize}문항'),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: c,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c),
        ],
      ),
    );
  }

  Future<void> _startYearRange(int years, String title) async {
    final qs = await StudyData.instance.questionsByYearRange(years);
    if (!mounted) return;
    if (qs.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('해당 기간의 기출 데이터가 없습니다.')));
      return;
    }
    pushWithNav(
      context,
      QuizPlayScreen(
        title: '$title 기출 (${qs.length}문제)',
        questions: qs,
        examMode: false,
      ),
      currentSection: 1,
    );
  }

  // ── 탭 4: 학습 이력 ───────────────────────────
  Widget _historyTab(BuildContext context) {
    return ListView(
      padding: _pagePadding,
      children: [_historySection(context), const SizedBox(height: 24)],
    );
  }

  Widget _examCard(BuildContext context, ExamPaper e) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      onTap: () => _startExam(e),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppTheme.heroGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              "'${e.year % 100}",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${StudyData.instance.track.name} ${e.label}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${e.questions.length}문항 · 정답 포함',
                  style: TextStyle(
                    fontSize: 11,
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
    );
  }

  /// 기초 학습 루프 — 이론을 읽고 쉬운 문제로 바로 확인한다.
  Widget _heroCards(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _heroCard(
              context,
              gradient: AppTheme.heroGradient,
              icon: Icons.school_rounded,
              title: '1:1 이론 강의',
              sub: '${StudyData.instance.track.topicCount}토픽 완전 강의\n공식·암기법·함정',
              onTap: () => pushWithNav(
                context,
                const LessonCurriculumScreen(),
                currentSection: 1,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _heroCard(
              context,
              gradient: AppTheme.electricGradient,
              icon: Icons.quiz_rounded,
              title: '기초 문제 확인',
              sub: '과목 선택 후\n쉬운 문제 10개',
              onTap: () => _showFoundationSubjects(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroCard(
    BuildContext context, {
    required Gradient gradient,
    required IconData icon,
    required String title,
    required String sub,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppTheme.rLg),
        boxShadow: AppTheme.glowShadow(
          (gradient as LinearGradient).colors.first,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.rLg),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.rLg),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 22, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  sub,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFoundationSubjects(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '어느 과목부터 확인할까요?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                '쉬운 문제 10개를 풀고, 막히면 해설에서 기초이론으로 돌아갈 수 있어요.',
                style: TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < kSubjects.length; i++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: IconBadge(
                    icon: Icons.stairs_rounded,
                    color: _subjectColors[i],
                    size: 38,
                    iconSize: 19,
                  ),
                  title: Text(
                    kSubjects[i],
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _startBasicCheck(kSubjects[i]);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startBasicCheck(String subject) async {
    final questions = await StudyData.instance.questionsByDifficulty(
      subject,
      easyFirst: true,
    );
    if (!mounted) return;
    if (questions.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('연결된 기초 문제가 없습니다.')));
      return;
    }
    pushWithNav(
      context,
      QuizPlayScreen(
        title: '$subject 기초 확인 10문제',
        questions: questions.take(10).toList(),
        examMode: false,
      ),
      currentSection: 1,
    );
  }

  /// 2026 시험 정보 센터 진입 카드
  Widget _examInfoCard(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      onTap: () =>
          pushWithNav(context, const ExamInfoScreen(), currentSection: 1),
      child: Row(
        children: [
          const IconBadge(
            icon: Icons.event_note_rounded,
            color: AppTheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text(
                      '2026 시험 정보 센터',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                    SizedBox(width: 6),
                    PillBadge(text: 'NEW', color: AppTheme.danger),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '3회차 일정 D-Day · 출제기준 개정 · 합격률 통계 · 점수 전략',
                  style: TextStyle(
                    fontSize: 11,
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
    );
  }

  Widget _cbtTrendCard(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        leading: const IconBadge(
          icon: Icons.insights_rounded,
          color: Color(0xFFF97316),
          size: 38,
          iconSize: 20,
        ),
        title: const Text(
          'CBT 출제경향 · 2개월 합격 로드맵',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
        ),
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: const [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '📌 CBT 문제은행 핵심 사실 (2022년부터 CBT 전환)\n'
              '• CBT 출제문제의 약 50%는 기존 필기 기출의 재출제입니다.\n'
              '• 나머지도 기출 소재의 숫자·조건 변형이 대부분입니다.\n'
              '→ 반복기출 347제 암기 = 실전 50점 확보 전략\n\n'
              '🗓 2개월 합격 로드맵\n'
              '1주차: 1:1 강의로 과목별 빈출 토픽 1~3위 학습\n'
              '2~3주차: 빈출순 문제풀이 + 틀린 문제는 강의 복습\n'
              '4~5주차: 문제-답 암기 347제 3회독\n'
              '6~7주차: 회차별 모의고사 실전 (60점 목표)\n'
              '8주차: 오답 복습 + 암기카드 최종 회독\n\n'
              '합격 기준: 과목별 40점 이상 + 평균 60점 이상',
              style: TextStyle(fontSize: 12.5, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  /// 핵심 기능 그리드 (3x3)
  Widget _featureGrid(BuildContext context) {
    final items = <(String, IconData, Color, Widget)>[
      (
        '🐣 왕초보 로드맵',
        Icons.egg_alt_rounded,
        const Color(0xFF10B981),
        const BeginnerRoadmapScreen(),
      ),
      (
        '10회 반복 합격',
        Icons.repeat_rounded,
        const Color(0xFF4F46E5),
        const VisualRepeatScreen(),
      ),
      (
        '자동학습',
        Icons.auto_awesome_rounded,
        const Color(0xFF7C3AED),
        const AutoStudyScreen(),
      ),
      (
        '볼트쌤 튜터',
        Icons.smart_toy_rounded,
        const Color(0xFF10B981),
        const TutorChatScreen(),
      ),
      (
        '합격 공부법',
        Icons.emoji_events_rounded,
        const Color(0xFFF59E0B),
        const StudyGuideScreen(),
      ),
      (
        '30일 슬라이드',
        Icons.style_rounded,
        AppTheme.primary,
        const SlidesHomeScreen(),
      ),
      (
        '집중 오답노트',
        Icons.psychology_alt_rounded,
        const Color(0xFFDC2626),
        const WrongFocusScreen(),
      ),
      (
        '합격 분석',
        Icons.insights_rounded,
        const Color(0xFF16A34A),
        const PassReportScreen(),
      ),
      (
        '유형변형 분석',
        Icons.track_changes_rounded,
        const Color(0xFFF97316),
        const RepeatAnalysisScreen(),
      ),
      ('실기 대비', Icons.edit_document, AppTheme.accent, const SilgiScreen()),
      (
        '회로도 마스터',
        Icons.schema_rounded,
        const Color(0xFF0891B2),
        const CircuitScreen(),
      ),
      (
        '계산기',
        Icons.calculate_rounded,
        const Color(0xFF14B8A6),
        const CalculatorHubScreen(),
      ),
      (
        '이론 검색·AI',
        Icons.manage_search_rounded,
        AppTheme.electric,
        const TheorySearchScreen(),
      ),
      (
        '스마트 복습',
        Icons.auto_awesome_rounded,
        const Color(0xFFEC4899),
        const SmartReviewScreen(),
      ),
      (
        '공식 마스터',
        Icons.functions_rounded,
        AppTheme.success,
        const FormulaGuideScreen(),
      ),
      (
        '핵심이론서',
        Icons.menu_book_rounded,
        const Color(0xFF0EA5E9),
        const TheoryScreen(),
      ),
      (
        '암기법 사전',
        Icons.lightbulb_rounded,
        const Color(0xFFEAB308),
        const MnemonicsScreen(),
      ),
      (
        '기초강의 TEXT',
        Icons.play_circle_rounded,
        const Color(0xFFEF4444),
        const VideosScreen(),
      ),
      (
        '번개 암기',
        Icons.bolt_rounded,
        const Color(0xFF8B5CF6),
        const SpeedMemorizeScreen(),
      ),
    ];

    Widget cell((String, IconData, Color, Widget) item) {
      final (label, icon, color, screen) = item;
      return Expanded(
        child: PremiumCard(
          padding: const EdgeInsets.symmetric(vertical: 13),
          radius: AppTheme.rMd,
          onTap: () => pushWithNav(context, screen, currentSection: 1),
          child: Column(
            children: [
              IconBadge(icon: icon, color: color, size: 40, iconSize: 21),
              const SizedBox(height: 7),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget row(List<(String, IconData, Color, Widget)> rowItems) {
      // 3열 기준으로 빈 칸을 채워 마지막 행 정렬 유지
      return Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            if (i < rowItems.length)
              cell(rowItems[i])
            else
              const Expanded(child: SizedBox()),
          ],
        ],
      );
    }

    // 3개씩 묶어 동적으로 행 생성 (항목 수 변화에 안전)
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += 3) {
      if (i > 0) rows.add(const SizedBox(height: 8));
      final end = (i + 3 <= items.length) ? i + 3 : items.length;
      rows.add(row(items.sublist(i, end)));
    }

    return Column(children: rows);
  }

  Widget _freqCard(BuildContext context, String subject, Color color) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final top = _freq?[subject]?.take(3).toList() ?? [];
    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      onTap: () => _startFrequency(subject),
      child: Row(
        children: [
          IconBadge(
            icon: Icons.local_fire_department_rounded,
            color: color,
            size: 40,
            iconSize: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (top.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    top.map((t) => '${t.topic}(${t.count})').join(' · '),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: dark ? Colors.white54 : AppTheme.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: dark ? Colors.white38 : AppTheme.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _historySection(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Consumer<AppProvider>(
      builder: (_, p, __) {
        final results = p.quizResults.take(10).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              emoji: '📊',
              title: '학습 이력',
              subtitle: '최근 채점 결과',
            ),
            if (results.isEmpty)
              const PremiumCard(
                child: Row(
                  children: [
                    Icon(Icons.history_rounded, color: AppTheme.textMuted),
                    SizedBox(width: 10),
                    Text(
                      '아직 채점 기록이 없습니다. 문제를 풀어보세요!',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            for (final r in results)
              Builder(
                builder: (context) {
                  final passed =
                      (r['correct'] as int) * 100 >= (r['total'] as int) * 60;
                  final score =
                      ((r['correct'] as int) * 100 / (r['total'] as int))
                          .round();
                  return PremiumCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color:
                                (passed ? AppTheme.success : AppTheme.warning)
                                    .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$score',
                            style: TextStyle(
                              color: passed
                                  ? AppTheme.success
                                  : AppTheme.warning,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r['title'] as String,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${r['correct']}/${r['total']} 정답 · '
                                '${(r['date'] as String).substring(0, 16).replaceAll('T', ' ')}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: dark
                                      ? Colors.white54
                                      : AppTheme.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                          ),
                          tooltip: '이 기록 삭제',
                          color: dark ? Colors.white38 : AppTheme.textMuted,
                          onPressed: () =>
                              p.deleteQuizResult(r['id'] as String),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  void _startExam(ExamPaper e) {
    final qs = e.questions
        .where((q) => q.options.length == 4 && q.answer >= 1)
        .toList();
    for (final q in qs) {
      q.examLabel = e.label;
    }
    pushWithNav(
      context,
      QuizPlayScreen(
        title: '${StudyData.instance.track.name} ${e.label}',
        questions: qs,
        examMode: true,
      ),
      currentSection: 1,
    );
  }

  /// 초보자 배너 — 공식 마스터 진입
  Widget _beginnerCard(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      onTap: () =>
          pushWithNav(context, const FormulaGuideScreen(), currentSection: 1),
      child: Row(
        children: [
          const IconBadge(
            icon: Icons.functions_rounded,
            color: AppTheme.success,
            size: 44,
            iconSize: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text(
                      '공식 마스터 · 왕초보 기초사전',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '공식 읽는법·기호뜻·비유이해·암기법 5단계 — V·A·Ω부터',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: dark ? Colors.white54 : AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.success),
        ],
      ),
    );
  }

  /// 초보자용: 쉬운 문제부터 (난이도 하→중→상)
  Future<void> _startEasyFirst(String subject) async {
    final qs = await StudyData.instance.questionsByDifficulty(
      subject,
      easyFirst: true,
    );
    if (!mounted) return;
    pushWithNav(
      context,
      QuizPlayScreen(
        title: '$subject 쉬운순 (${qs.length}문제)',
        questions: qs,
        examMode: false,
      ),
      currentSection: 1,
    );
  }

  Future<void> _startRandom(String subject) async {
    final all = await StudyData.instance.questionsBySubject(subject);
    all.shuffle(Random());
    if (!mounted) return;
    pushWithNav(
      context,
      QuizPlayScreen(
        title: '$subject 랜덤 20문제',
        questions: all.take(20).toList(),
        examMode: false,
      ),
      currentSection: 1,
    );
  }

  Future<void> _startFrequency(String subject) async {
    final qs = await StudyData.instance.questionsByFrequency(subject);
    if (!mounted) return;
    pushWithNav(
      context,
      QuizPlayScreen(
        title: '$subject 빈출순 전체 (${qs.length}문제)',
        questions: qs,
        examMode: false,
      ),
      currentSection: 1,
    );
  }
}
