import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../services/study_data.dart';
import '../../services/progress_service.dart';
import '../../services/pass_prediction.dart';
import '../../widgets/lesson_view.dart';
import '../../widgets/rich_slide_body.dart';
import '../../widgets/teacher_recipe_box.dart';
import 'result_certificate_screen.dart';

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
  final Set<int> _recorded = {}; // 진첩 중복기록 방지
  bool _showAnswer = false;
  bool _bookmarked = false;

  // ⏱ 실전 타이머 (examMode 전용) — 실제 시험 페이스: 문제당 90초
  Timer? _timer;
  int _remainSec = 0;
  int _totalSec = 0;
  bool _timeOver = false;

  Question get _q => widget.questions[_idx];

  /// KEC 개정 위험도: 2 = 폐지·변경된 규정을 직접 다루는 문제(강한 경고),
  /// 1 = 설비 과목 일반 주의, 0 = 해당 없음
  static final RegExp _kecHighRisk = RegExp(
      r'(제\s?[123]종\s?접지|특별\s?제?3종|CD관.{0,40}(굴곡|반경)|굴곡.{0,20}4\s?배|'
      r'(비상|유도등).{0,60}30\s?분|판단기준|개정\s?전)');

  int get _kecRiskLevel {
    if (!_q.subject.contains('설비')) return 0;
    final text = '${_q.question} ${_q.options.join(' ')}';
    return _kecHighRisk.hasMatch(text) ? 2 : 1;
  }

  Widget _kecWarningBanner() {
    final high = _kecRiskLevel == 2;
    final color = high ? Colors.red : Colors.orange;
    final msg = high
        ? '⚠ 이 문제는 폐지·개정된 구규정(종별 접지 등)을 다룹니다. 풀이 원리만 취하고, 현행 KEC 기준은 시험정보 센터 "KEC 2026 개정" 탭에서 반드시 확인하세요.'
        : 'KEC 2026 개정 주의: 구기출 수치(CD관 4배, 비상조명 30분 등)는 현행 규정과 다를 수 있음 → "KEC 2026 개정" 탭 확인';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(high ? Icons.gpp_bad : Icons.warning_amber,
                size: 14, color: color.shade700),
            const SizedBox(width: 5),
            Expanded(
              child: Text(msg,
                  style: TextStyle(
                      fontSize: 11, height: 1.4, color: color.shade800)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _syncBookmark();
    if (widget.examMode && widget.questions.isNotEmpty) {
      _totalSec = widget.questions.length * 90; // 실전 페이스 1문당 1분 30초
      _remainSec = _totalSec;
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() {
          _remainSec--;
          if (_remainSec <= 0) {
            _timeOver = true;
            t.cancel();
          }
        });
        if (_timeOver) _finish(); // 시간 종료 → 자동 채점 (실전과 동일)
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _timeLabel {
    final m = _remainSec ~/ 60;
    final s = _remainSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _syncBookmark() async {
    if (widget.questions.isEmpty) return;
    final b = await ProgressService.instance.isBookmarked(_q.qid);
    if (mounted) setState(() => _bookmarked = b);
  }

  Future<void> _toggleBookmark() async {
    final now = await ProgressService.instance.toggleBookmark(_q);
    if (!mounted) return;
    setState(() => _bookmarked = now);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(now ? '북마크 추가 — 스마트 복습에서 모아 풀 수 있어요' : '북마크 해제'),
      duration: const Duration(seconds: 1),
    ));
  }

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
            tooltip: _bookmarked ? '북마크 해제' : '북마크 (헷갈리는 문제 표시)',
            icon: Icon(
              _bookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: _bookmarked ? Colors.amber : null,
            ),
            onPressed: _toggleBookmark,
          ),
          IconButton(
            tooltip: '이 토픽 1:1 강의',
            icon: const Icon(Icons.school_outlined),
            onPressed: _openLesson,
          ),
          if (widget.examMode && _totalSec > 0)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (_remainSec < _totalSec * 0.2
                          ? Colors.red
                          : Colors.teal)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer,
                        size: 15,
                        color: _remainSec < _totalSec * 0.2
                            ? Colors.red
                            : Colors.teal),
                    const SizedBox(width: 4),
                    Text(_timeLabel,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: _remainSec < _totalSec * 0.2
                                ? Colors.red
                                : Colors.teal)),
                  ],
                ),
              ),
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
                        _difficultyChip(),
                        if (_q.freqScore >= 50) _freqChip(),
                        if (_q.hasImage) _chip('그림문제·원본PDF 참고'),
                      ],
                    ),
                    if (_kecRiskLevel > 0) _kecWarningBanner(),
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

  /// 난이도 배지 — 하(초록)/중(주황)/상(빨강)
  Widget _difficultyChip() {
    final color = _q.difficulty == 1
        ? Colors.green
        : (_q.difficulty == 3 ? Colors.red : Colors.orange);
    return Chip(
      label: Text('난이도 ${_q.difficultyLabel}',
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      side: BorderSide(color: color.withValues(alpha: 0.5)),
      backgroundColor: color.withValues(alpha: 0.08),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }

  /// 빈출 배지 — freq_score 50 이상이면 반복출제 가능성 높음
  Widget _freqChip() {
    final hot = _q.freqScore >= 70;
    final color = hot ? Colors.red.shade700 : Colors.deepOrange;
    return Chip(
      avatar: Icon(Icons.local_fire_department, size: 14, color: color),
      label: Text(hot ? '초빈출' : '빈출문제',
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      side: BorderSide(color: color.withValues(alpha: 0.5)),
      backgroundColor: color.withValues(alpha: 0.08),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }

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
          Row(
            children: [
              Icon(Icons.check_circle,
                  size: 20, color: Colors.green[700]),
              const SizedBox(width: 6),
              Text('정답: ${_q.answer}번',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: scheme.onPrimaryContainer)),
            ],
          ),
          if (_q.explanation.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.menu_book,
                          size: 16, color: scheme.primary),
                      const SizedBox(width: 5),
                      Text('해설',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: scheme.primary)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  RichSlideBody(
                      body: _q.explanation, accent: scheme.primary),
                ],
              ),
            ),
          ],
          // 🧑‍🏫 만능 선생님: 풀이 순서 + 공식 적용법 + 관련 암기법 (이론·암기 공존)
          TeacherRecipeBox(topic: _q.topic, subject: _q.subject),
          const SizedBox(height: 10),
          // 큰 터치 영역의 강의 버튼 — 전체 폭 차지, 확실히 눌림
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _openLesson,
              icon: const Icon(Icons.school, size: 20),
              label: const Text('이 토픽 1:1 강의 보기 (이론·공식·암기법·함정)',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold)),
            ),
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
          // 문제별 진첩 기록 (첨 선택만 기록해 재클릭 왜곡 방지)
          if (_recorded.add(_idx)) {
            ProgressService.instance.record(_q, n == _q.answer);
          }
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
                ? () {
                    setState(() {
                      _idx--;
                      _showAnswer = false;
                    });
                    _syncBookmark();
                  }
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
                _syncBookmark();
              }
            },
            icon: Icon(isLast ? Icons.flag : Icons.chevron_right),
            label: Text(isLast ? '채점' : '다음'),
          ),
        ],
      ),
    );
  }

  /// 정답 아래 버튼 → 해당 토픽의 완전한 1:1 강의 시트 (이론+공식+암기법+함정+전략)
  void _openLesson() {
    showLessonSheet(context, _q.subject, _q.topic);
  }

  bool _finished = false; // 타이마 자동채점·수동채점 중복 방지

  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();
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

    // 🎯 풀 때마다 합격 예측 점수 갱신 — "내 점수가 움직인다"는 중독 루프
    PassPrediction? pred;
    try {
      pred = await PassPredictionEngine.instance.predict();
    } catch (_) {}
    if (!mounted) return;

    // 🏆 100문항 실전 단위(examMode) — 공유하고 싶은 합격 성적표로 진입
    if (widget.examMode && total >= 90) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ResultCertificateScreen(
          examLabel: widget.title.replaceFirst('전기기사 ', ''),
          correct: correct,
          total: total,
          subjectTotal: subjectTotal,
          subjectCorrect: subjectCorrect,
          prediction: pred,
        ),
      ));
      if (mounted) Navigator.of(context).pop();
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_timeOver
            ? '⏰ 시간 종료! 결과: $correct/$total ($pct점)'
            : '결과: $correct/$total ($pct점)'),
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
              if (pred != null && !pred.needsDiagnosis) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (pred.pass ? Colors.green : Colors.orange)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '🎯 합격 예측 점수 갱신: ${pred.overall.round()}점 '
                    '${pred.pass ? "(합격권 유지!)" : "(홈 화면에서 처방전 확인)"}',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: pred.pass
                            ? Colors.green.shade800
                            : Colors.orange.shade900),
                  ),
                ),
              ],
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
            onPressed: () {
              _finished = false; // 계속 보기 후 재채점 허용
              Navigator.of(ctx).pop();
            },
            child: const Text('계속 보기'),
          ),
        ],
      ),
    );
  }
}
