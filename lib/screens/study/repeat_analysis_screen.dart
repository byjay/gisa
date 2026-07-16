import 'package:flutter/material.dart';
import '../../services/study_data.dart';
import '../../widgets/tutor_avatar.dart';
import '../../widgets/persistent_nav.dart';
import 'quiz_play_screen.dart';

/// 빈출 유형변형 분석 — 반복출제 클러스터를 출제횟수순으로 보여주고
/// 어떤 식으로 숫자·조건이 변형되는지 + 대비 포인트를 제공
class RepeatAnalysisScreen extends StatefulWidget {
  const RepeatAnalysisScreen({super.key});

  @override
  State<RepeatAnalysisScreen> createState() => _RepeatAnalysisScreenState();
}

class _RepeatAnalysisScreenState extends State<RepeatAnalysisScreen> {
  List<RepeatCluster>? _all;
  String _subject = '전체';
  int _minCount = 2; // 2회+ / 3회+ / 4회+
  bool _variationsOnly = false;

  @override
  void initState() {
    super.initState();
    StudyData.instance.loadRepeats().then((v) {
      if (mounted) setState(() => _all = v);
    });
  }

  Color _countColor(int count) {
    if (count >= 5) return Colors.red.shade700;
    if (count >= 4) return Colors.deepOrange;
    if (count >= 3) return Colors.orange.shade800;
    return Colors.indigo;
  }

  String _countLabel(int count) {
    if (count >= 5) return '초빈출';
    if (count >= 3) return '빈출';
    return '반복';
  }

  @override
  Widget build(BuildContext context) {
    final all = _all;
    final cs = Theme.of(context).colorScheme;
    if (all == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('빈출 유형변형 분석')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // 필터 + 출제횟수순 정렬
    var items = all.where((r) => r.count >= _minCount).toList();
    if (_subject != '전체') {
      items = items.where((r) => r.subject == _subject).toList();
    }
    if (_variationsOnly) {
      items = items.where((r) => r.variations.length >= 2).toList();
    }
    items.sort((a, b) {
      final c = b.count.compareTo(a.count);
      return c != 0 ? c : b.variations.length.compareTo(a.variations.length);
    });

    final subjects = <String>['전체', ...kSubjects];
    final totalAppear =
        items.fold<int>(0, (s, r) => s + r.count);

    return Scaffold(
      appBar: AppBar(title: const Text('빈출 유형변형 분석')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width > 900
                    ? (MediaQuery.of(context).size.width - 800) / 2
                    : 16,
                vertical: 12,
              ),
              children: [
                TutorBanner(
                  mood: TutorMood.thinking,
                  message:
                      'CBT의 절반은 기출 재출제·변형이에요! 몇 번 나왔는지, 숫자·조건이 어떻게 바뀌는지 '
                      '패턴을 알면 변형이 나와도 안 틀립니다.',
                ),
                const SizedBox(height: 10),
                // 요약 통계
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _stat(context, '${items.length}', '유형 수'),
                      _stat(context, '$totalAppear회', '누적 출제'),
                      _stat(context,
                          '${items.where((r) => r.count >= 3).length}', '3회+ 유형'),
                      _stat(context,
                          '${items.where((r) => r.variations.length >= 2).length}',
                          '변형 유형'),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // 과목 필터
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: subjects.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, i) {
                      final s = subjects[i];
                      return ChoiceChip(
                        label: Text(s == '전체' ? s : s.substring(0, 4),
                            style: const TextStyle(fontSize: 12)),
                        selected: s == _subject,
                        onSelected: (_) => setState(() => _subject = s),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 6),
                // 횟수 필터 + 변형만 보기
                Row(
                  children: [
                    for (final c in [2, 3, 4])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text('$c회 이상',
                              style: const TextStyle(fontSize: 12)),
                          selected: _minCount == c,
                          onSelected: (_) => setState(() => _minCount = c),
                        ),
                      ),
                    const Spacer(),
                    FilterChip(
                      label: const Text('변형만', style: TextStyle(fontSize: 12)),
                      selected: _variationsOnly,
                      onSelected: (v) => setState(() => _variationsOnly = v),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 30),
                    child: Column(
                      children: [
                        const TutorAvatar(mood: TutorMood.wrong, size: 90),
                        const SizedBox(height: 8),
                        Text('조건에 맞는 유형이 없어요. 필터를 조정해보세요.',
                            style: TextStyle(
                                fontSize: 13,
                                color: cs.onSurface.withValues(alpha: 0.6))),
                      ],
                    ),
                  ),
                ...items.map((r) => _clusterCard(context, r)),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String value, String label) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: cs.primary)),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: cs.onSurface.withValues(alpha: 0.65))),
      ],
    );
  }

  Widget _clusterCard(BuildContext context, RepeatCluster r) {
    final cc = _countColor(r.count);
    final hasVars = r.variations.length >= 2;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: Container(
          width: 48,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: cc.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Text('${r.count}회',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w900, color: cc)),
              Text(_countLabel(r.count),
                  style: TextStyle(fontSize: 9.5, color: cc)),
            ],
          ),
        ),
        title: Text(
          r.question,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('${r.subject.length > 4 ? r.subject.substring(0, 4) : r.subject} · ${r.topic}',
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.primary)),
              if (hasVars)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('변형 ${r.variations.length}종',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.purple)),
                ),
            ],
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 출제 이력 타임라인
          _sectionLabel(context, '📅 출제 이력 (${r.count}회)'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: r.exams
                .map((e) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: cc.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: cc.withValues(alpha: 0.3)),
                      ),
                      child: Text(e,
                          style: TextStyle(fontSize: 11, color: cc)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 12),
          // 대표 문제 + 정답
          _sectionLabel(context, '✅ 대표 문제 · 정답'),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.teal.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(r.question,
                    style: const TextStyle(fontSize: 13, height: 1.55)),
                const SizedBox(height: 8),
                if (r.options.isNotEmpty && r.answer >= 1)
                  Text('정답: ${r.answer}번 — ${r.answerText}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.teal))
                else if (r.answerText.isNotEmpty)
                  Text('정답: ${r.answerText}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.teal)),
              ],
            ),
          ),
          // 👉 이 유형 문제 풀기 (기존 기출·변형 재활용)
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.play_circle_fill_rounded, size: 18),
              label: Text(
                _solvableCount(r) >= 2
                    ? '이 유형 문제 풀기 (${_solvableCount(r)}문항)'
                    : '이 유형 문제 풀기',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              onPressed: () => _solveCluster(context, r),
            ),
          ),
          // 유형 변형 히스토리
          if (r.variations.isNotEmpty) ...[
            const SizedBox(height: 12),
            _sectionLabel(
                context, '🔀 유형 변형 — 이렇게 바뀌어 나옵니다 (${r.variations.length}종)'),
            const SizedBox(height: 6),
            ...r.variations.map((v) => Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.purple.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(v.exam,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.purple)),
                      const SizedBox(height: 4),
                      SelectableText(v.question,
                          style:
                              const TextStyle(fontSize: 12.5, height: 1.5)),
                      if (v.answerText.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('→ 정답: ${v.answerText}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.purple)),
                      ],
                    ],
                  ),
                )),
            const SizedBox(height: 8),
            // 대비 포인트
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🎯 대비 포인트',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.deepOrange)),
                  const SizedBox(height: 4),
                  Text(
                    _prepTip(r),
                    style: const TextStyle(fontSize: 12.5, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Text(text,
        style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.primary));
  }

  /// 클러스터에서 실제로 풀 수 있는(4지선다) 문항 수
  int _solvableCount(RepeatCluster r) => _clusterQuestions(r).length;

  /// RepeatCluster + 변형을 기존 데이터 그대로 Question 객체로 변환(재활용)
  List<Question> _clusterQuestions(RepeatCluster r) {
    final out = <Question>[];
    // 대표 문제
    if (r.options.length >= 2 && r.answer >= 1) {
      out.add(Question(
        no: 1,
        subject: r.subject,
        topic: r.topic,
        question: r.question,
        options: r.options,
        answer: r.answer,
        hasImage: false,
        explanation: r.answerText.isNotEmpty ? '정답: ${r.answerText}' : '',
        examLabel: r.exams.isNotEmpty ? r.exams.first : '',
      ));
    }
    // 변형 문제 — 보기가 없으면 대표 보기를 재활용해 풀이 가능하게
    var n = out.length;
    for (final v in r.variations) {
      if (v.question.trim().isEmpty) continue;
      final opts = r.options.length >= 2 ? r.options : const <String>[];
      final ans = v.answer >= 1 ? v.answer : r.answer;
      if (opts.length < 2 || ans < 1) continue;
      n++;
      out.add(Question(
        no: n,
        subject: r.subject,
        topic: r.topic,
        question: v.question,
        options: opts,
        answer: ans,
        hasImage: false,
        explanation:
            v.answerText.isNotEmpty ? '정답: ${v.answerText}' : '',
        examLabel: v.exam,
      ));
    }
    return out;
  }

  Future<void> _solveCluster(BuildContext context, RepeatCluster r) async {
    final qs = _clusterQuestions(r);
    if (qs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이 유형은 객관식 보기 데이터가 없어 풀이를 제공할 수 없어요.')),
      );
      return;
    }
    final title = '${r.topic} 유형 (${qs.length}문항)';
    pushWithNav(
      context,
      QuizPlayScreen(title: title, questions: qs, examMode: false),
      currentSection: 1,
    );
  }

  /// 변형 패턴 기반 대비 팁 자동 생성
  String _prepTip(RepeatCluster r) {
    final qs = [r.question, ...r.variations.map((v) => v.question)];
    final hasNumbers = qs.every((q) => RegExp(r'\d').hasMatch(q));
    final numsVary = hasNumbers &&
        qs.map((q) => RegExp(r'[\d.]+').allMatches(q).map((m) => m.group(0)).join(','))
                .toSet()
                .length >
            1;
    if (numsVary) {
      return '숫자·조건만 바꿔서 재출제되는 계산형입니다. 답을 외우지 말고 공식과 풀이 과정을 확실히 익혀두세요. '
          '${r.topic} 공식만 알면 어떤 숫자가 나와도 풀 수 있습니다.';
    }
    return '표현만 살짝 바꿔 나오는 개념형입니다. 정답 키워드("${r.answerText.length > 30 ? '${r.answerText.substring(0, 30)}…' : r.answerText}")를 '
        '확실히 암기하면 어떤 변형이 나와도 맞힐 수 있습니다.';
  }
}
