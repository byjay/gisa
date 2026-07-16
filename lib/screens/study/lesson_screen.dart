import 'package:flutter/material.dart';
import '../../services/study_data.dart';
import '../../widgets/lesson_view.dart';
import '../../widgets/teacher_recipe_box.dart';
import 'quiz_play_screen.dart';
import '../../widgets/persistent_nav.dart';

/// 1:1 강의 커리큘럼 — 과목 선택 → 빈출순 토픽 강의 목록 → 강의 뷰어
/// 46개 토픽 전체 (기출 2,897문항 100% 커버)
class LessonCurriculumScreen extends StatefulWidget {
  const LessonCurriculumScreen({super.key});

  @override
  State<LessonCurriculumScreen> createState() => _LessonCurriculumScreenState();
}

class _LessonCurriculumScreenState extends State<LessonCurriculumScreen> {
  List<Lesson>? _all;

  @override
  void initState() {
    super.initState();
    StudyData.instance.loadLessons().then((v) {
      if (mounted) setState(() => _all = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    final all = _all;
    return DefaultTabController(
      length: kSubjects.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('1:1 이론 강의'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              for (final s in kSubjects)
                Tab(text: s.length > 8 ? '${s.substring(0, 7)}…' : s),
            ],
          ),
        ),
        body: all == null
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  for (final s in kSubjects) _subjectLessonList(s, all),
                ],
              ),
      ),
    );
  }

  Widget _subjectLessonList(String subject, List<Lesson> all) {
    final lessons = all.where((l) => l.subject == subject).toList()
      ..sort((a, b) => b.freq.compareTo(a.freq));
    final total = lessons.fold<int>(0, (p, l) => p + l.freq);
    final width = MediaQuery.of(context).size.width;
    final hPad = width > 900 ? (width - 800) / 2 : 12.0;

    return ListView(
      padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 24),
      children: [
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subject,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  '토픽 ${lessons.length}개 · 기출 $total문항 전체 커버\n'
                  '빈출 순서대로 위에서부터 학습하세요. 상위 3~4개 토픽만 마스터해도 과락은 면합니다.',
                  style: const TextStyle(fontSize: 12.5, height: 1.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < lessons.length; i++)
          _lessonTile(context, i + 1, lessons[i]),
      ],
    );
  }

  Widget _lessonTile(BuildContext context, int order, Lesson l) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          radius: 17,
          backgroundColor:
              order <= 3 ? Colors.deepOrange : scheme.surfaceContainerHighest,
          child: Text('$order',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: order <= 3 ? Colors.white : scheme.onSurface)),
        ),
        title: Text(l.topic,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
        subtitle: Row(
          children: [
            Text('기출 ${l.freq}문항', style: const TextStyle(fontSize: 11.5)),
            const SizedBox(width: 8),
            ...List.generate(
              5,
              (i) => Icon(i < l.importance ? Icons.star : Icons.star_border,
                  size: 12, color: Colors.amber[700]),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => pushWithNav(context, LessonViewerScreen(lesson: l), currentSection: 1),
      ),
    );
  }
}

/// 개별 강의 뷰어 — 전체 강의 + '이 토픽 기출문제 풀기' 연동
class LessonViewerScreen extends StatelessWidget {
  final Lesson lesson;
  const LessonViewerScreen({super.key, required this.lesson});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final hPad = width > 900 ? (width - 800) / 2 : 16.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(lesson.topic,
            style: const TextStyle(fontSize: 15),
            overflow: TextOverflow.ellipsis),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 32),
          children: [
            LessonView(lesson: lesson),
            // 🧑‍🏫 풀이 레시피 — 공식 적용 순서까지 완성 (암기·이론 공존)
            TeacherRecipeBox(
                topic: lesson.topic,
                subject: lesson.subject,
                initiallyExpanded: false),
            const SizedBox(height: 24),
            // 강의 → 바로 문제풀이 연결 (이론-문제 완전 연동)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15)),
              onPressed: () => _startTopicQuiz(context),
              icon: const Icon(Icons.quiz),
              label: Text('이 토픽 기출문제 풀기 (${lesson.freq}문항)',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startTopicQuiz(BuildContext context) async {
    final all = await StudyData.instance.questionsBySubject(lesson.subject);
    final qs = all.where((q) => q.topic == lesson.topic).toList();
    if (!context.mounted) return;
    if (qs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이 토픽의 기출문제가 없습니다.')));
      return;
    }
    pushWithNav(context, QuizPlayScreen(
        title: '${lesson.topic} 기출 ${qs.length}문제',
        questions: qs,
        examMode: false,
      ), currentSection: 1);
  }
}
