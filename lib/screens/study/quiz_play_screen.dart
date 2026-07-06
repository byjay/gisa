import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../services/study_data.dart';

/// 문제풀이 화면: 실전(examMode)/연습 모드, 문제 내 암기법·이론 연동, 채점
class QuizPlayScreen extends StatefulWidget {
  final String title;
  final List<Question> questions;
  final bool examMode;

  const QuizPlayScreen({
    super.key,
    required this.title,
    required this.questions,
    required this.examMode,
  });

  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> {
  int _idx = 0;
  final Map<int, int> _picked = {};
  bool _showAnswer = false;

  Question get _q => widget.questions[_idx];

  @override
  Widget build(BuildContext context) {
    if (widget.questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(child: Text('풀 수 있는 문제가 없습니다.')),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final picked = _picked[_idx];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title,
            style: const TextStyle(fontSize: 15), overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: '관련 암기법',
            icon: const Icon(Icons.lightbulb_outline),
            onPressed: _showMnemonics,
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text('${_idx + 1}/${widget.questions.length}'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(value: (_idx + 1) / widget.questions.length),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _chip(_q.subject),
                        if (_q.topic != '기타') _chip('빈출: ${_q.topic}'),
                        if (_q.examLabel.isNotEmpty) _chip(_q.examLabel),
                        if (_q.hasImage) _chip('그림문제·원본PDF 참고'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${_q.no}. ${_q.question}',
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    for (var i = 0; i < _q.options.length; i++)
                      _optionTile(i + 1, _q.options[i], picked, scheme),
                    if (_showAnswer ||
                        (!widget.examMode && picked != null))
                      _answerBox(scheme),
                  ],
                ),
              ),
            ),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label) => Chip(
        label: Text(label, style: const TextStyle(fontSize: 11)),
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
      );

  Widget _answerBox(ColorScheme scheme) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('정답: ${_q.answer}번',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: scheme.onPrimaryContainer)),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: _showMnemonics,
            icon: const Icon(Icons.lightbulb, size: 18),
            label: const Text('이 토픽 암기법·핵심이론 보기'),
          ),
        ],
      ),
    );
  }

  Widget _optionTile(int n, String text, int? picked, ColorScheme scheme) {
    final reveal = _showAnswer || (!widget.examMode && picked != null);
    Color? bg;
    Color? border;
    if (reveal) {
      if (n == _q.answer) {
        bg = Colors.green.withValues(alpha: 0.15);
        border = Colors.green;
      } else if (picked == n) {
        bg = Colors.red.withValues(alpha: 0.12);
        border = Colors.red;
      }
    } else if (picked == n) {
      bg = scheme.primaryContainer;
      border = scheme.primary;
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: border ?? Colors.transparent, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          setState(() {
            _picked[_idx] = n;
            if (!widget.examMode) _showAnswer = true;
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: picked == n
                    ? scheme.primary
                    : scheme.surfaceContainerHighest,
                child: Text('$n',
                    style: TextStyle(
                        fontSize: 12,
                        color:
                            picked == n ? scheme.onPrimary : scheme.onSurface)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomBar() {
    final isLast = _idx == widget.questions.length - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: _idx > 0
                ? () => setState(() {
                      _idx--;
                      _showAnswer = false;
                    })
                : null,
            icon: const Icon(Icons.chevron_left),
            label: const Text('이전'),
          ),
          const Spacer(),
          if (widget.examMode)
            TextButton(
              onPressed: () => setState(() => _showAnswer = !_showAnswer),
              child: Text(_showAnswer ? '정답 숨김' : '정답 보기'),
            ),
          const Spacer(),
          FilledButton.icon(
            onPressed: () {
              if (isLast) {
                _finish();
              } else {
                setState(() {
                  _idx++;
                  _showAnswer = false;
                });
              }
            },
            icon: Icon(isLast ? Icons.flag : Icons.chevron_right),
            label: Text(isLast ? '채점' : '다음'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMnemonics() async {
    final list =
        await StudyData.instance.mnemonicsFor(_q.subject, _q.topic);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text('${_q.subject} · ${_q.topic} 관련 암기법',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (list.isEmpty) const Text('등록된 암기법이 없습니다.'),
            for (final m in list.take(8))
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.title,
                          style:
                              const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(m.body, style: const TextStyle(height: 1.5)),
                      if (m.tip.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text('TIP: ${m.tip}',
                            style: TextStyle(
                                fontSize: 12,
                                color:
                                    Theme.of(context).colorScheme.primary)),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _finish() {
    var correct = 0;
    final subjectTotal = <String, int>{};
    final subjectCorrect = <String, int>{};
    final wrongList = <Question>[];
    for (var i = 0; i < widget.questions.length; i++) {
      final q = widget.questions[i];
      subjectTotal[q.subject] = (subjectTotal[q.subject] ?? 0) + 1;
      if (_picked[i] == q.answer) {
        correct++;
        subjectCorrect[q.subject] = (subjectCorrect[q.subject] ?? 0) + 1;
      } else {
        wrongList.add(q);
      }
    }
    final total = widget.questions.length;
    final pct = total == 0 ? 0 : (correct * 100 / total).round();

    // 학습 이력 저장 (AppProvider)
    try {
      context.read<AppProvider>().addQuizResult(
            title: widget.title,
            total: total,
            correct: correct,
            wrongQuestions: wrongList
                .map((q) =>
                    '[${q.subject}] ${q.examLabel} ${q.no}번: ${q.question.length > 60 ? q.question.substring(0, 60) : q.question}')
                .toList(),
          );
    } catch (_) {}

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('결과: $correct/$total ($pct점)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final s in subjectTotal.keys)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Text(
                      '$s: ${subjectCorrect[s] ?? 0}/${subjectTotal[s]} '
                      '(${((subjectCorrect[s] ?? 0) * 100 / subjectTotal[s]!).round()}점)'),
                ),
              const SizedBox(height: 8),
              Text(
                pct >= 60 ? '합격권! (평균 60점 이상)' : '조금 더! (평균 60점 목표)',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: pct >= 60 ? Colors.green : Colors.orange),
              ),
              const SizedBox(height: 4),
              const Text('오답은 자동으로 학습이력에 저장되었습니다.',
                  style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('종료'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('계속 보기'),
          ),
        ],
      ),
    );
  }
}
