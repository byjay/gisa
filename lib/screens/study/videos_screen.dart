import 'package:flutter/material.dart';

import '../../services/study_data.dart';
import '../../widgets/persistent_nav.dart';
import 'lesson_screen.dart';
import 'quiz_play_screen.dart';

/// 강의 음성의 핵심 흐름을 시험 출제 기준에 맞게 다시 구성하는 학습 화면.
/// 외부 영상 링크나 전사 원문을 노출하지 않고, 중복 제거된 독자적 학습 자료만 제공한다.
class VideosScreen extends StatefulWidget {
  const VideosScreen({super.key});

  @override
  State<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends State<VideosScreen> {
  List<Lesson>? _all;
  String _filter = '전체';

  @override
  void initState() {
    super.initState();
    StudyData.instance.loadLessons().then((lessons) {
      if (mounted) setState(() => _all = _deduplicate(lessons));
    });
  }

  List<Lesson> _deduplicate(List<Lesson> source) {
    final seen = <String>{};
    final result = <Lesson>[];
    for (final lesson in source) {
      final normalized = lesson.topic
          .replaceAll(RegExp(r'[^가-힣a-zA-Z0-9]'), '')
          .toLowerCase();
      final key = '${lesson.subject}:$normalized';
      if (normalized.isNotEmpty && seen.add(key)) result.add(lesson);
    }
    result.sort((a, b) => b.freq.compareTo(a.freq));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final all = _all;
    final filters = ['전체', ...kSubjects];
    final lessons = all == null
        ? <Lesson>[]
        : all.where((lesson) {
            return _filter == '전체' || lesson.subject == _filter;
          }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('전사·검증 재구성 강의')),
      body: SafeArea(
        child: all == null
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _methodCard(context, lessons.length),
                  SizedBox(
                    height: 52,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      children: [
                        for (final filter in filters)
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(
                                filter,
                                style: const TextStyle(fontSize: 12),
                              ),
                              selected: _filter == filter,
                              onSelected: (_) =>
                                  setState(() => _filter = filter),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
                      itemCount: lessons.length,
                      itemBuilder: (_, index) =>
                          _lectureCard(context, lessons[index], index + 1),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _methodCard(BuildContext context, int count) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primaryContainer, cs.secondaryContainer],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.fact_check_outlined, size: 20),
              SizedBox(width: 7),
              Expanded(
                child: Text(
                  '원문 복제가 아닌 시험형 강의 재구성',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          const Text(
            '음성에서 개념 단위를 분리하고 반복·잡담을 제거한 뒤, 기출 빈도와 공식·함정·실기 연결 순서로 다시 구성합니다. 같은 토픽은 한 번만 제공합니다.',
            style: TextStyle(fontSize: 12.5, height: 1.45),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _statusChip('중복 제거 $count개'),
              _statusChip('기출 빈도 연결'),
              _statusChip('법령·수치 검증 대상 표시'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
    ),
  );

  Widget _lectureCard(BuildContext context, Lesson lesson, int rank) {
    final cs = Theme.of(context).colorScheme;
    final memory = <String>[
      ...lesson.must,
      ...lesson.mnemonics,
    ].where((text) => text.trim().isNotEmpty).take(3).toList();
    final deepCount = lesson.advanced.length + (lesson.silgi.isEmpty ? 0 : 1);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
        leading: CircleAvatar(
          backgroundColor: rank <= 5 ? cs.primary : cs.surfaceContainerHighest,
          foregroundColor: rank <= 5 ? cs.onPrimary : cs.onSurface,
          child: Text(
            '$rank',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
        ),
        title: Text(
          lesson.topic,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 5,
            runSpacing: 4,
            children: [
              Text(lesson.subject, style: const TextStyle(fontSize: 11.5)),
              Text(
                '기출 ${lesson.freq}문항',
                style: TextStyle(
                  fontSize: 11.5,
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (deepCount > 0)
                const Text('심화·실기', style: TextStyle(fontSize: 11.5)),
            ],
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.bolt_rounded, '1단계 · 30초 문제·정답 잠금'),
          const SizedBox(height: 7),
          if (memory.isEmpty)
            Text(
              lesson.strategy,
              style: const TextStyle(fontSize: 13, height: 1.5),
            )
          else
            for (final item in memory) _bullet(item, cs.primary),
          const SizedBox(height: 13),
          _sectionTitle(Icons.menu_book_outlined, '2단계 · 원할 때 핵심 이론'),
          const SizedBox(height: 7),
          Text(
            lesson.basicExplain.isNotEmpty ? lesson.basicExplain : lesson.intro,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
          if (deepCount > 0) ...[
            const SizedBox(height: 13),
            _sectionTitle(Icons.engineering_outlined, '3단계 · 심화와 실기 연결'),
            const SizedBox(height: 7),
            Text(
              lesson.silgi.isNotEmpty ? lesson.silgi : lesson.advanced.first,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, height: 1.5),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _startQuiz(lesson),
                  icon: const Icon(Icons.flash_on_rounded, size: 18),
                  label: const Text('바로 암기 문제'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => pushWithNav(
                    context,
                    LessonViewerScreen(lesson: lesson),
                    currentSection: 1,
                  ),
                  icon: const Icon(Icons.auto_stories_rounded, size: 18),
                  label: const Text('전체 강의'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(IconData icon, String text) => Row(
    children: [
      Icon(icon, size: 18),
      const SizedBox(width: 6),
      Text(
        text,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900),
      ),
    ],
  );

  Widget _bullet(String text, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, height: 1.45)),
        ),
      ],
    ),
  );

  Future<void> _startQuiz(Lesson lesson) async {
    final all = await StudyData.instance.questionsByTopic(lesson.topic);
    if (!mounted) return;
    final questions = all.take(12).toList();
    if (questions.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('연결된 기출문제를 준비 중입니다.')));
      return;
    }
    pushWithNav(
      context,
      QuizPlayScreen(
        title: '${lesson.topic} 초고속 암기',
        questions: questions,
        examMode: false,
      ),
      currentSection: 1,
    );
  }
}
