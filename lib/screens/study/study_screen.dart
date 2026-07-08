import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../services/study_data.dart';
import 'quiz_play_screen.dart';
import 'theory_screen.dart';
import 'mnemonics_screen.dart';
import 'videos_screen.dart';
import 'lesson_screen.dart';
import 'speed_memorize_screen.dart';
import 'slides_screen.dart';
import 'silgi_screen.dart';
import 'search_screen.dart';
import 'repeat_analysis_screen.dart';
import '../../widgets/tutor_avatar.dart';

/// 학습 허브: CBT 문제풀이 / 빈출순 풀기 / 이론서 / 암기법 / 강의 / 학습이력
class StudyScreen extends StatefulWidget {
  const StudyScreen({super.key});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  List<ExamPaper>? _exams;
  Map<String, List<TopicFreq>>? _freq;

  @override
  void initState() {
    super.initState();
    StudyData.instance.loadExams().then((v) {
      if (mounted) setState(() => _exams = v);
    });
    StudyData.instance.loadTopicFreq().then((v) {
      if (mounted) setState(() => _freq = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final exams = _exams;
    return Scaffold(
      appBar: AppBar(title: const Text('전기기사 학습')),
      body: exams == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width > 900
                    ? (MediaQuery.of(context).size.width - 800) / 2
                    : 16,
                vertical: 16,
              ),
              children: [
                TutorBanner(
                  mood: TutorMood.cheer,
                  message: '30일 슬라이드로 이론 끝내고, 빈출 유형변형 분석으로 실전 대비! 오늘도 함께 달려요 🔥',
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const SlidesHomeScreen())),
                ),
                const SizedBox(height: 12),
                _heroCards(context),
                const SizedBox(height: 8),
                _newFeatureCards(context),
                const SizedBox(height: 8),
                _menuGrid(context),
                const SizedBox(height: 12),
                _cbtTrendCard(context),
                const SizedBox(height: 20),
                Text('빈출순 문제풀기 (출제 빈도 높은 토픽부터)',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('10년치 2,897문제를 빈출 토픽 순서로 정렬해 풀어보세요.',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                for (final s in kSubjects) _freqCard(context, s),
                const SizedBox(height: 20),
                Text('과목별 랜덤 연습 (20문제)',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in kSubjects)
                      ActionChip(
                        avatar: const Icon(Icons.shuffle, size: 18),
                        label: Text(s, style: const TextStyle(fontSize: 13)),
                        onPressed: () => _startRandom(s),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('회차별 실전 모의고사 (100문항)',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final e in exams)
                  Card(
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        child: Text('${e.year % 100}',
                            style: const TextStyle(fontSize: 12)),
                      ),
                      title: Text('전기기사 ${e.label}',
                          style: const TextStyle(fontSize: 14)),
                      subtitle: Text('${e.questions.length}문항 · 정답포함',
                          style: const TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _startExam(e),
                    ),
                  ),
                const SizedBox(height: 20),
                _historySection(context),
              ],
            ),
    );
  }

  /// 핵심 2대 학습 모드 — 1:1 이론강의 + 문제-답 암기
  Widget _heroCards(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Card(
            color: scheme.primaryContainer,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const LessonCurriculumScreen())),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.school, size: 30),
                    SizedBox(height: 8),
                    Text('1:1 이론 강의',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    SizedBox(height: 2),
                    Text('46토픽 완전 강의\n공식·암기법·함정',
                        style: TextStyle(fontSize: 11.5, height: 1.4)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Card(
            color: scheme.tertiaryContainer,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const SpeedMemorizeScreen())),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.bolt, size: 30),
                    SizedBox(height: 8),
                    Text('문제-답 암기',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    SizedBox(height: 2),
                    Text('반복기출 347제\n빈도순 플래시카드',
                        style: TextStyle(fontSize: 11.5, height: 1.4)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// CBT 출제경향 + 2개월 로드맵
  Widget _cbtTrendCard(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading:
            const Icon(Icons.insights, color: Colors.deepOrange),
        title: const Text('CBT 출제경향 · 2개월 합격 로드맵',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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

  /// 신규 핵심 기능 — 30일 슬라이드 / 빈출 유형변형 / 실기 / 검색
  Widget _newFeatureCards(BuildContext context) {
    final items = [
      ('30일 슬라이드', Icons.style_rounded, Colors.indigo,
          const SlidesHomeScreen() as Widget),
      ('유형변형 분석', Icons.track_changes_rounded, Colors.deepOrange,
          const RepeatAnalysisScreen() as Widget),
      ('실기 대비', Icons.edit_document, Colors.purple,
          const SilgiScreen() as Widget),
      ('이론 검색·AI', Icons.manage_search_rounded, Colors.teal,
          const TheorySearchScreen() as Widget),
    ];
    return Row(
      children: [
        for (final (label, icon, color, screen) in items)
          Expanded(
            child: Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => screen)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    children: [
                      Icon(icon, size: 26, color: color),
                      const SizedBox(height: 5),
                      Text(label,
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _menuGrid(BuildContext context) {
    final items = [
      ('핵심이론서', Icons.menu_book, const TheoryScreen()),
      ('암기법 사전', Icons.lightbulb, const MnemonicsScreen()),
      ('추천 강의', Icons.play_circle, const VideosScreen()),
    ];
    return Row(
      children: [
        for (final (label, icon, screen) in items)
          Expanded(
            child: Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => screen)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      Icon(icon,
                          size: 28,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(height: 6),
                      Text(label, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _freqCard(BuildContext context, String subject) {
    final top = _freq?[subject]?.take(3).toList() ?? [];
    return Card(
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.local_fire_department, color: Colors.deepOrange),
        title: Text(subject, style: const TextStyle(fontSize: 14)),
        subtitle: top.isEmpty
            ? null
            : Text(
                top.map((t) => '${t.topic}(${t.count})').join(' · '),
                style: const TextStyle(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _startFrequency(subject),
      ),
    );
  }

  Widget _historySection(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (_, p, __) {
        final results = p.quizResults.take(10).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('학습 이력 (최근 채점 결과)',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (results.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('아직 채점 기록이 없습니다. 문제를 풀어보세요!'),
                ),
              ),
            for (final r in results)
              Card(
                child: ListTile(
                  dense: true,
                  leading: Icon(
                    (r['correct'] as int) * 100 >= (r['total'] as int) * 60
                        ? Icons.check_circle
                        : Icons.cancel,
                    color: (r['correct'] as int) * 100 >=
                            (r['total'] as int) * 60
                        ? Colors.green
                        : Colors.orange,
                  ),
                  title: Text(r['title'] as String,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${r['correct']}/${r['total']} '
                    '(${((r['correct'] as int) * 100 / (r['total'] as int)).round()}점) · '
                    '${(r['date'] as String).substring(0, 16).replaceAll('T', ' ')}',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () => p.deleteQuizResult(r['id'] as String),
                  ),
                ),
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
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QuizPlayScreen(
        title: '전기기사 ${e.label}',
        questions: qs,
        examMode: true,
      ),
    ));
  }

  Future<void> _startRandom(String subject) async {
    final all = await StudyData.instance.questionsBySubject(subject);
    all.shuffle(Random());
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QuizPlayScreen(
        title: '$subject 랜덤 20문제',
        questions: all.take(20).toList(),
        examMode: false,
      ),
    ));
  }

  Future<void> _startFrequency(String subject) async {
    final qs = await StudyData.instance.questionsByFrequency(subject);
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QuizPlayScreen(
        title: '$subject 빈출순 전체 (${qs.length}문제)',
        questions: qs,
        examMode: false,
      ),
    ));
  }
}
