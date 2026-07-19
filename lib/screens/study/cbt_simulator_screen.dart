import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../services/study_data.dart';

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
  bool _showNav = false;

  List<Question> get _qs => widget.questions;
  Question get _q => _qs[_idx];

  @override
  void initState() {
    super.initState();
    _remain = widget.timeLimit;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remain -= const Duration(seconds: 1);
        if (_remain.inSeconds <= 0) {
          _remain = Duration.zero;
          _submit(auto: true);
        }
      });
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

  void _submit({bool auto = false}) {
    if (_finished) return;
    _timer?.cancel();
    setState(() => _finished = true);

    // 과목별 채점 (과락 40점 미만·평균 60점 이상 합격)
    final bySubject = <String, List<int>>{}; // subject → [정답수, 문항수]
    for (var i = 0; i < _qs.length; i++) {
      final q = _qs[i];
      final e = bySubject.putIfAbsent(q.subject, () => [0, 0]);
      e[1]++;
      if (_picked[i] == q.answer) e[0]++;
    }
    final scores = <String, double>{};
    bySubject.forEach((s, v) => scores[s] = v[1] == 0 ? 0 : v[0] / v[1] * 100);
    final avg = scores.values.isEmpty
        ? 0.0
        : scores.values.reduce((a, b) => a + b) / scores.length;
    final failSubjects = scores.entries
        .where((e) => e.value < 40)
        .map((e) => e.key)
        .toList();
    final pass = avg >= 60 && failSubjects.isEmpty;

    showDialog(
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
                onPressed: () => showDialog(
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
                child: const Text(
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
                final wrong = _finished && _picked[i] != _qs[i].answer;
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
                onTap: _finished
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
                      if (_finished && i == _q.answer)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.green,
                          size: 20,
                        ),
                      if (_finished && picked == i && i != _q.answer)
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
          if (_finished && _q.explanation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.tertiaryContainer.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _q.explanation,
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
      if (i == _q.answer) return Colors.green.withValues(alpha: 0.1);
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
                onPressed: _idx > 0 ? () => setState(() => _idx--) : null,
                icon: const Icon(Icons.chevron_left_rounded),
                label: const Text('이전'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _idx < _qs.length - 1
                    ? () => setState(() => _idx++)
                    : (_finished ? null : () => _submit()),
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
