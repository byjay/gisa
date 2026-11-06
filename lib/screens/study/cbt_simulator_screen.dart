import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../services/cbt_grade_summary.dart';
import '../../services/remote_content_api.dart';
import '../../services/study_data.dart';
import '../../widgets/drawing_pad.dart';
import '../../widgets/tutor_avatar.dart';

/// 💻 CBT 체험 모드 — 실제 Q-Net CBT 시험 환경 시뮬레이터.
/// 실전과 동일하게: 2시간 30분 타이머 · 100문항(5과목×20) · 문항 네비게이션
/// 패널 · 답안 표시/미표시 구분 · 과목별 과락(40점 미만) 채점 · 평균 60점 합격.
class CbtSimulatorScreen extends StatefulWidget {
  final String title;
  final List<Question> questions;
  final Duration timeLimit;

  const CbtSimulatorScreen({
    super.key,
    required this.title,
    required this.questions,
    this.timeLimit = const Duration(hours: 2, minutes: 30),
  });

  @override
  State<CbtSimulatorScreen> createState() => _CbtSimulatorScreenState();
}

class _CbtSimulatorScreenState extends State<CbtSimulatorScreen> {
  int _idx = 0;
  final Map<int, int> _picked = {}; // 문항 index → 선택 보기(1-based)
  late Duration _remain;
  Timer? _timer;
  bool _finished = false;
  bool _isSubmitting = false;
  bool _showNav = false;
  CbtGradeSummary? _grade;

  List<Question> get _qs => widget.questions;
  Question get _q => _qs[_idx];

  @override
  void initState() {
    super.initState();
    _remain = widget.timeLimit;
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _isSubmitting || _finished) return;
      var submit = false;
      setState(() {
        if (_remain.inSeconds <= 1) {
          _remain = Duration.zero;
          submit = true;
        } else {
          _remain -= const Duration(seconds: 1);
        }
      });
      if (submit) unawaited(_submit(auto: true));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _timeLabel {
    final h = _remain.inHours;
    final m = _remain.inMinutes % 60;
    final s = _remain.inSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _submit({bool auto = false}) async {
    if (_finished || _isSubmitting || _qs.isEmpty) return;
    _timer?.cancel();
    setState(() => _isSubmitting = true);

    late final CbtGradeSummary summary;
    try {
      final answers = <Map<String, dynamic>>[
        for (var i = 0; i < _qs.length; i++)
          {'qid': _qs[i].remoteQid!, 'picked': _picked[i] ?? 0},
      ];
      final response = await RemoteContentApi.instance.gradeMany(answers);
      summary = CbtGradeSummary.fromResponse(
        questions: _qs,
        picked: _picked,
        response: response,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      if (_remain.inSeconds > 0) _startTimer();
      final message = error is RemoteContentException
          ? error.message
          : '채점 서버에 연결하지 못했어요. 답안은 유지했으니 다시 제출해 주세요.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _finished = true;
      _grade = summary;
    });

    // 과목별 채점 (과락 40점 미만·평균 60점 이상 합격)
    final scores = summary.subjectScores;
    final avg = summary.average;
    final failSubjects = summary.failedSubjects;
    final pass = avg >= 60 && failSubjects.isEmpty;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              pass ? Icons.emoji_events_rounded : Icons.replay_rounded,
              color: pass ? const Color(0xFFF59E0B) : Colors.redAccent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                pass ? '합격 기준 통과!' : (auto ? '시간 종료 — 자동 제출' : '채점 결과'),
                style: const TextStyle(fontSize: 17),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (pass ? Colors.green : Colors.red).withValues(
                    alpha: 0.1,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    TutorAvatar(
                      mood: pass ? TutorMood.happy : TutorMood.wrong,
                      size: 72,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '평균 ${avg.toStringAsFixed(1)}점',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: pass ? Colors.green : Colors.redAccent,
                      ),
                    ),
                    Text(
                      pass
                          ? '실전이었다면 합격입니다! 🎉'
                          : failSubjects.isNotEmpty
                          ? '과락: ${failSubjects.join(', ')} (40점 미만)'
                          : '평균 60점 미만 — 조금만 더!',
                      style: const TextStyle(fontSize: 12.5),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              for (final e in scores.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          e.key,
                          style: const TextStyle(fontSize: 12.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: e.value < 40
                              ? Colors.red.withValues(alpha: 0.12)
                              : e.value >= 60
                              ? Colors.green.withValues(alpha: 0.12)
                              : Colors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${e.value.toStringAsFixed(0)}점',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: e.value < 40
                                ? Colors.red
                                : e.value >= 60
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                '응답 ${_picked.length}/${_qs.length}문항 · '
                '소요 ${_fmtUsed(widget.timeLimit - _remain)}',
                style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('종료'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {}); // 리뷰 모드로 전환 (오답 확인)
            },
            child: const Text('오답 확인'),
          ),
        ],
      ),
    );
  }

  String _fmtUsed(Duration d) {
    final m = d.inMinutes;
    return m >= 60 ? '${m ~/ 60}시간 ${m % 60}분' : '$m분';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final urgent = _remain.inMinutes < 10 && !_finished;

    return PopScope(
      canPop: _finished,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('시험을 중단할까요?'),
            content: const Text('실제 CBT처럼 중단하면 기록이 저장되지 않습니다.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('계속 응시'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text('중단', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      child: Scaffold(
        // ── 실제 CBT 스타일 상단 바: 남은시간 + 진행 현황 ──
        appBar: AppBar(
          automaticallyImplyLeading: false,
          titleSpacing: 12,
          title: Row(
            children: [
              // 남은 시간 (실제 CBT처럼 큼직하게)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: urgent
                      ? Colors.red.withValues(alpha: 0.15)
                      : cs.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.timer_rounded,
                      size: 16,
                      color: urgent ? Colors.red : cs.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _timeLabel,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: urgent ? Colors.red : cs.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_idx + 1} / ${_qs.length}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: '필기 연습장 (계산·메모)',
              icon: const Icon(Icons.draw_rounded),
              onPressed: () => showDrawingPad(context, title: '✍️ CBT 연습장'),
            ),
            // 문항 네비게이션 패널 토글 (실제 CBT의 답안표시 현황판)
            IconButton(
              tooltip: '답안 표시 현황',
              icon: Badge(
                label: Text('${_picked.length}'),
                child: const Icon(Icons.grid_view_rounded),
              ),
              onPressed: () => setState(() => _showNav = !_showNav),
            ),
            if (!_finished)
              TextButton(
                onPressed: _isSubmitting
                    ? null
                    : () => showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('답안을 제출할까요?'),
                          content: Text(
                            '응답 ${_picked.length} / ${_qs.length}문항\n'
                            '${_picked.length < _qs.length ? '⚠️ 미응답 ${_qs.length - _picked.length}문항은 오답 처리됩니다.' : '모든 문항에 응답했습니다.'}',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('취소'),
                            ),
                            FilledButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _submit();
                              },
                              child: const Text('제출'),
                            ),
                          ],
                        ),
                      ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        '제출',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
              ),
          ],
        ),
        body: Column(
          children: [
            // 진행 바
            LinearProgressIndicator(
              value: (_idx + 1) / max(1, _qs.length),
              minHeight: 3,
            ),
            // 문항 네비게이션 그리드 (펼침형)
            if (_showNav) _navPanel(cs),
            Expanded(child: _questionArea(cs)),
            _bottomBar(cs),
          ],
        ),
      ),
    );
  }

  // ── 문항 네비게이션 패널 — 실제 CBT의 좌측 현황판 재현 ──
  Widget _navPanel(ColorScheme cs) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 210),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _legend(cs.primary, '응답'),
              const SizedBox(width: 10),
              _legend(cs.outlineVariant, '미응답'),
              if (_finished) ...[
                const SizedBox(width: 10),
                _legend(Colors.red, '오답'),
              ],
              const Spacer(),
              Text(
                '미응답 ${_qs.length - _picked.length}',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 10,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: _qs.length,
              itemBuilder: (_, i) {
                final answered = _picked.containsKey(i);
                final wrong =
                    _finished && _grade?.resultFor(_qs[i])?['correct'] != true;
                final current = i == _idx;
                return InkWell(
                  onTap: () => setState(() {
                    _idx = i;
                    _showNav = false;
                  }),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: wrong
                          ? Colors.red.withValues(alpha: 0.85)
                          : answered
                          ? cs.primary
                          : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                      border: current
                          ? Border.all(color: cs.tertiary, width: 2)
                          : null,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: (answered || wrong)
                            ? Colors.white
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(Color c, String label) => Row(
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 3),
      Text(label, style: const TextStyle(fontSize: 10.5)),
    ],
  );

  // ── 문제 영역 ──
  Widget _questionArea(ColorScheme cs) {
    final picked = _picked[_idx];
    final result = _grade?.resultFor(_q);
    final correctAnswer = (result?['answer'] as num?)?.toInt();
    final explanation = result?['explanation'] as String? ?? '';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 과목 배지
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: cs.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _q.subject,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: cs.onSecondaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${_idx + 1}. ${_q.question}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 1; i <= _q.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: _finished || _isSubmitting
                    ? null
                    : () => setState(() {
                        if (_picked[_idx] == i) {
                          _picked.remove(_idx); // 재탭 시 선택 해제 (실제 CBT 동일)
                        } else {
                          _picked[_idx] = i;
                        }
                      }),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _optionColor(i, picked, cs),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: picked == i ? cs.primary : cs.outlineVariant,
                      width: picked == i ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: picked == i ? cs.primary : Colors.transparent,
                          border: Border.all(
                            color: picked == i ? cs.primary : cs.outline,
                          ),
                        ),
                        child: Text(
                          '$i',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: picked == i ? cs.onPrimary : cs.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _q.options[i - 1],
                          style: const TextStyle(fontSize: 14.5, height: 1.4),
                        ),
                      ),
                      if (_finished && i == correctAnswer)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.green,
                          size: 20,
                        ),
                      if (_finished && picked == i && i != correctAnswer)
                        const Icon(
                          Icons.cancel_rounded,
                          color: Colors.red,
                          size: 20,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          // 리뷰 모드: 해설 표시
          if (_finished && explanation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.tertiaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                explanation,
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Color _optionColor(int i, int? picked, ColorScheme cs) {
    if (_finished) {
      if (i == _grade?.resultFor(_q)?['answer']) {
        return Colors.green.withValues(alpha: 0.1);
      }
      if (picked == i) return Colors.red.withValues(alpha: 0.08);
    }
    return picked == i
        ? cs.primaryContainer.withValues(alpha: 0.5)
        : cs.surface;
  }

  // ── 하단 이전/다음 바 ──
  Widget _bottomBar(ColorScheme cs) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: cs.outlineVariant)),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _idx > 0 && !_isSubmitting
                    ? () => setState(() => _idx--)
                    : null,
                icon: const Icon(Icons.chevron_left_rounded),
                label: const Text('이전'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _idx < _qs.length - 1
                    ? (_isSubmitting ? null : () => setState(() => _idx++))
                    : (_finished || _isSubmitting ? null : () => _submit()),
                icon: Icon(
                  _idx < _qs.length - 1
                      ? Icons.chevron_right_rounded
                      : Icons.task_alt_rounded,
                ),
                label: Text(_idx < _qs.length - 1 ? '다음 문항' : '답안 제출'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
