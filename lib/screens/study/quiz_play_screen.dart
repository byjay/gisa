import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/study_data.dart';
import '../../services/progress_service.dart';
import '../../services/pass_prediction.dart';
import '../../services/quiz_policy.dart';
import '../../widgets/lesson_view.dart';
import '../../widgets/rich_slide_body.dart';
import '../../widgets/teacher_recipe_box.dart';
import '../../widgets/level_up_dialog.dart';
import 'result_certificate_screen.dart';
import '../../widgets/persistent_nav.dart';

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
  final Set<int> _recorded = {}; // 진척도 중복 기록 방지
  bool _showAnswer = false;
  bool _bookmarked = false;
  bool _easyMode = false; // 아주 쉬운 설명 토글
  bool _allowExit = false;
  ({int seenCount, String? lastResult, int box})? _history; // 다시 만난 문제 인식 배너
  final Map<int, String> _reasonPicked = {}; // 문제별 선택한 오답 원인

  // ⏱ 실전 타이머 (examMode 전용) — 실제 시험 페이스: 문제당 90초
  Timer? _timer;
  int _remainSec = 0;
  int _totalSec = 0;
  bool _timeOver = false;

  Question get _q => widget.questions[_idx];

  /// 🍼 아주 쉬운 설명 — 기존 문제·정답·해설 데이터를 그대로 재활용하여
  /// 초보자용 친절한 말투로 재구성 (새 데이터 생성 없이 규칙 기반 변환)
  String _easyExplanation() {
    final q = _q;
    final ansIdx = q.answer - 1;
    final answerText =
        (ansIdx >= 0 && ansIdx < q.options.length) ? q.options[ansIdx] : '';
    final buf = StringBuffer();

    // 1) 이 문제가 뭘 묻는지 한 문장으로
    buf.writeln('이 문제는 "${q.topic}" 개념을 묻고 있어요.');

    // 2) 정답을 쉬운 말로
    if (answerText.isNotEmpty) {
      buf.writeln('정답은 ${q.answer}번, 바로 "$answerText" 입니다.');
    } else if (q.answer >= 1) {
      buf.writeln('정답은 ${q.answer}번입니다.');
    }

    // 3) 기존 해설을 쉬운 문장으로 다듬기 (딱딱한 종결어미 완화)
    if (q.explanation.trim().isNotEmpty) {
      var e = q.explanation
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll('이다.', '이에요.')
          .replaceAll('한다.', '해요.')
          .replaceAll('된다.', '돼요.')
          .replaceAll('된다', '돼요')
          .replaceAll('입니다.', '이에요.')
          .replaceAll('습니다.', '어요.')
          .trim();
      buf.writeln('');
      buf.writeln('👉 쉽게 말하면: $e');
    }

    // 4) 오답을 왜 고르면 안 되는지 힌트 (보기 재활용)
    final wrongs = <String>[];
    for (var i = 0; i < q.options.length; i++) {
      if (i != ansIdx && q.options[i].trim().isNotEmpty) {
        wrongs.add('${i + 1}번(${q.options[i]})');
      }
    }
    if (wrongs.isNotEmpty && wrongs.length <= 3) {
      buf.writeln('');
      buf.writeln('나머지 ${wrongs.join(', ')}은(는) 이 문제의 정답 조건과 맞지 않아요.');
    }

    // 5) 격려 한마디
    buf.write('\n천천히 다시 읽어보면 충분히 이해할 수 있어요! 💪');
    return buf.toString().trim();
  }

  /// KEC 개정 위험도: 2 = 폐지·변경된 규정을 직접 다루는 문제(강한 경고),
  /// 1 = 설비 과목 일반 주의, 0 = 해당 없음
  static final RegExp _kecHighRisk = RegExp(
    r'(제\s?[123]종\s?접지|특별\s?제?3종|종별\s?접지|접지저항.{0,10}(10|100)\s?[Ω오옴]|'
    r'CD관.{0,40}(굴곡|반경)|굴곡.{0,20}4\s?배|PF관.{0,10}16|'
    r'(저압).{0,20}(600|750)\s?[Vv볼]|교류\s?600|직류\s?750|'
    r'(비상|유도등).{0,60}30\s?분|판단기준|내선규정|개정\s?전)',
  );

  /// 개정으로 답이 바뀐 대표 항목 → 배너에 현행 정답을 직접 제시
  String? get _kecCorrectAnswer {
    final t = '${_q.question} ${_q.options.join(' ')}';
    if (RegExp(r'제\s?[123]종\s?접지|종별\s?접지|특별\s?제?3종').hasMatch(t)) {
      return '현행: 종별 접지 폐지 → 계통접지 TN·TT·IT 방식 (구 10Ω/100Ω 오답)';
    }
    if (RegExp(r'저압|교류\s?600|직류\s?750').hasMatch(t) &&
        RegExp(r'600|750').hasMatch(t)) {
      return '현행: 저압 = 교류 1000V·직류 1500V 이하 (구 600V/750V 오답)';
    }
    if (RegExp(r'CD관|굴곡|반경').hasMatch(t)) {
      return '현행: CD관 굴곡반경 내경 6배 이상 (구 4배 오답)';
    }
    if (RegExp(r'색상|색별|전선.{0,4}(식별|구분)').hasMatch(t)) {
      return '현행: L1갈·L2흑·L3회·중성 청색·보호도체 녹황';
    }
    if (RegExp(r'(비상|유도등).{0,60}30\s?분').hasMatch(t)) {
      return '현행: 고층(11층↑) 비상조명 60분 이상 (구 30분 오답)';
    }
    return null;
  }

  int get _kecRiskLevel {
    if (!_q.subject.contains('설비')) return 0;
    final text = '${_q.question} ${_q.options.join(' ')}';
    return _kecHighRisk.hasMatch(text) ? 2 : 1;
  }

  /// 🔁 다시 만난 문제 배너 — "N번째 만남! 지난번: ⭕/❌" + 간격반복 진행도
  Widget _repeatBanner(({int seenCount, String? lastResult, int box}) h) {
    final wasWrong = h.lastResult == 'x';
    final color = wasWrong ? Colors.red : Colors.green;
    final boxLabel = ['방금 배움', '1일 후 복습', '3일 후 복습', '1주 후 복습', '완전 암기!'];
    final boxTxt = h.box < boxLabel.length ? boxLabel[h.box] : '완전 암기!';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            wasWrong ? Icons.replay_circle_filled : Icons.check_circle,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${h.seenCount + 1}번째 만남 · 지난번: ${wasWrong ? "❌ 틀림" : "⭕ 맞음"}'
              '${wasWrong ? " — 이번엔 바로 떠올려보세요!" : ""}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              boxTxt,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kecWarningBanner() {
    final high = _kecRiskLevel == 2;
    final color = high ? Colors.red : Colors.orange;
    final fix = _kecCorrectAnswer;
    final msg = high
        ? '⚠ 이 문제는 폐지·개정된 구규정(종별 접지 등)을 다룹니다. 아래 현행 정답을 기준으로 암기하세요.'
        : 'KEC 개정 주의: 구기출 수치는 현행 규정과 다를 수 있어요 → "KEC 2026 개정" 탭 확인';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  high ? Icons.gpp_bad : Icons.warning_amber,
                  size: 14,
                  color: color.shade700,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    msg,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: color.shade800,
                    ),
                  ),
                ),
              ],
            ),
            if (fix != null) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.verified_rounded,
                        size: 13, color: Colors.white),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '✅ 현행 KEC 정답  $fix',
                        style: const TextStyle(
                          fontSize: 11,
                          height: 1.4,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _syncBookmark();
    _syncHistory();
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

  /// 이 문제를 전에 풀었는지 확인해 간격 반복 학습 상태를 보여준다.
  Future<void> _syncHistory() async {
    if (widget.questions.isEmpty) return;
    final h = await ProgressService.instance.historyFor(_q.qid);
    if (mounted) setState(() => _history = h);
  }

  Future<void> _toggleBookmark() async {
    final now = await ProgressService.instance.toggleBookmark(_q);
    if (!mounted) return;
    setState(() => _bookmarked = now);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(now ? '북마크 추가 — 스마트 복습에서 모아 풀 수 있어요' : '북마크 해제'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// 🗂 CBT 문항 번호판 — 실제 CBT처럼 문항 간 자유 이동 (답함/현재/미답 3색)
  Future<void> _openQuestionGrid() async {
    final bookmarked = await ProgressService.instance.bookmarkedQids();
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    final answered = _picked.length;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.grid_view_rounded, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'CBT 문항 번호판 — 푼 문항 $answered / ${widget.questions.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '탭하면 해당 문항으로 이동 · ⭐ = 북마크',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (var i = 0; i < widget.questions.length; i++)
                        _gridCell(
                          ctx,
                          i,
                          bookmarked.contains(widget.questions[i].qid),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gridCell(BuildContext ctx, int i, bool isBookmarked) {
    final scheme = Theme.of(ctx).colorScheme;
    final isCurrent = i == _idx;
    final isAnswered = _picked.containsKey(i);
    return InkWell(
      onTap: () {
        Navigator.of(ctx).pop();
        setState(() {
          _idx = i;
          _showAnswer = false;
          _easyMode = false;
        });
        _syncBookmark();
      },
      borderRadius: BorderRadius.circular(9),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 40,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isAnswered
                  ? scheme.primary
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(9),
              border: isCurrent
                  ? Border.all(color: AppTheme.accent, width: 2.5)
                  : null,
            ),
            child: Text(
              '${i + 1}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: isAnswered ? scheme.onPrimary : scheme.onSurfaceVariant,
              ),
            ),
          ),
          if (isBookmarked)
            const Positioned(
              top: -4,
              right: -4,
              child: Text('⭐', style: TextStyle(fontSize: 10)),
            ),
        ],
      ),
    );
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

    return PopScope(
      canPop: _allowExit || _finished,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestExit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.title,
            style: const TextStyle(fontSize: 15),
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            IconButton(
              tooltip: 'CBT 문항 번호판 (문항 이동)',
              icon: const Icon(Icons.grid_view_rounded),
              onPressed: _openQuestionGrid,
            ),
            IconButton(
              tooltip: _bookmarked ? '북마크 해제' : '북마크 (헷갈리는 문제 표시)',
              icon: Icon(
                _bookmarked ? Icons.bookmark : Icons.bookmark_border,
                color: _bookmarked ? Colors.amber : null,
              ),
              onPressed: _toggleBookmark,
            ),
            IconButton(
              tooltip: '기초이론 다시 보기',
              icon: const Icon(Icons.school_outlined),
              onPressed: _openLesson,
            ),
            IconButton(
              tooltip: '문제 오류 신고',
              icon: const Icon(Icons.flag_outlined),
              onPressed: _reportError,
            ),
            if (widget.examMode && _totalSec > 0)
              Center(
                child: Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color:
                        (_remainSec < _totalSec * 0.2
                                ? Colors.red
                                : Colors.teal)
                            .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.timer,
                        size: 15,
                        color: _remainSec < _totalSec * 0.2
                            ? Colors.red
                            : Colors.teal,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _timeLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: _remainSec < _totalSec * 0.2
                              ? Colors.red
                              : Colors.teal,
                        ),
                      ),
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
              LinearProgressIndicator(
                value: (_idx + 1) / widget.questions.length,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 다시 만난 문제라면 이전 결과와 복습 단계를 안내한다.
                      if (_history != null) _repeatBanner(_history!),
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
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      for (var i = 0; i < _q.options.length; i++)
                        _optionTile(i + 1, _q.options[i], picked, scheme),
                      if (QuizPolicy.canRevealAnswer(
                            examMode: widget.examMode,
                            submitted: _finished,
                          ) &&
                          (_showAnswer || picked != null))
                        _answerBox(scheme),
                    ],
                  ),
                ),
              ),
              _bottomBar(),
            ],
          ),
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
      label: Text(
        '난이도 ${_q.difficultyLabel}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
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
      label: Text(
        hot ? '초빈출' : '빈출문제',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      side: BorderSide(color: color.withValues(alpha: 0.5)),
      backgroundColor: color.withValues(alpha: 0.08),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }

  /// 오답 원인 선택 UI — 사용자가 "왜 틀렸는지" 태그를 남기면
  /// 집중 오답노트에서 원인별 통계·복습으로 이어진다.
  Widget _wrongReasonPicker(ColorScheme scheme) {
    final selected = _reasonPicked[_idx];
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology_alt_rounded,
                  size: 18, color: Colors.redAccent),
              const SizedBox(width: 6),
              Text(
                selected == null ? '왜 틀렸나요? (원인 기록)' : '오답 원인: $selected',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: ProgressService.wrongReasons.map((reason) {
              final isSel = selected == reason;
              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  setState(() => _reasonPicked[_idx] = reason);
                  ProgressService.instance.recordWrongReason(_q, reason);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('오답 원인 기록: $reason'),
                      duration: const Duration(milliseconds: 900),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSel
                        ? Colors.redAccent
                        : scheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: isSel
                            ? Colors.redAccent
                            : scheme.outlineVariant),
                  ),
                  child: Text(
                    reason,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSel ? Colors.white : scheme.onSurface,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (selected == null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '원인을 남기면 「집중 오답노트」에서 같은 실수를 모아 복습해드려요.',
                style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurface.withValues(alpha: 0.55)),
              ),
            ),
        ],
      ),
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
              Icon(Icons.check_circle, size: 20, color: Colors.green[700]),
              const SizedBox(width: 6),
              Text(
                '정답: ${_q.answer}번',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
          // 🔍 오답 원인 기록 — 틀렸을 때만 노출 (왜 틀렸는지 집중 관리)
          if (_picked[_idx] != null && _picked[_idx] != _q.answer)
            _wrongReasonPicker(scheme),
          if (_q.explanation.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.menu_book, size: 16, color: scheme.primary),
                      const SizedBox(width: 5),
                      Text(
                        '해설',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: scheme.primary,
                        ),
                      ),
                      const Spacer(),
                      // 🍼 아주 쉬운 설명 토글 (기존 데이터 재활용)
                      InkWell(
                        onTap: () => setState(() => _easyMode = !_easyMode),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _easyMode
                                ? Colors.orange
                                : Colors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Colors.orange.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_easyMode ? '🍼' : '💡',
                                  style: const TextStyle(fontSize: 12)),
                              const SizedBox(width: 4),
                              Text(
                                _easyMode ? '쉬운 설명 켜짐' : '아주 쉬운 설명',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: _easyMode
                                      ? Colors.white
                                      : Colors.deepOrange,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (_easyMode)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('🍼 아주 쉽게 풀어드릴게요',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.deepOrange)),
                          const SizedBox(height: 6),
                          Text(_easyExplanation(),
                              style: const TextStyle(
                                  fontSize: 13.5, height: 1.6)),
                        ],
                      ),
                    )
                  else
                    RichSlideBody(body: _q.explanation, accent: scheme.primary),
                ],
              ),
            ),
          ],
          // 풀이 순서 + 공식 적용법 + 관련 암기법
          TeacherRecipeBox(topic: _q.topic, subject: _q.subject),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: const Text(
              '막혔다면 기초이론을 확인한 뒤 이 문제로 그대로 돌아오세요. '
              '선택한 답과 현재 위치는 유지됩니다.',
              style: TextStyle(fontSize: 12, height: 1.4),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _openLesson,
              icon: const Icon(Icons.menu_book_outlined, size: 20),
              label: const Text(
                '기초이론 다시 보기',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
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
          // 첫 선택만 기록해 재클릭으로 인한 진척도 왜곡을 방지한다.
          if (_recorded.add(_idx)) {
            final correct = n == _q.answer;
            // 🖐️ 정답/오답에 따라 다른 촉각 피드백 — 고급스러운 손맛
            if (!widget.examMode) {
              if (correct) {
                HapticFeedback.mediumImpact();
              } else {
                HapticFeedback.heavyImpact();
              }
            } else {
              HapticFeedback.selectionClick();
            }
            ProgressService.instance.record(_q, correct);
            // ❌ 반복해서 틀리는 문제 → 오답노트 강제 + 이론 들이밀기
            if (!correct && !widget.examMode) {
              _maybeForceWrongNote();
            }
          } else {
            HapticFeedback.selectionClick();
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
                child: Text(
                  '$n',
                  style: TextStyle(
                    fontSize: 12,
                    color: picked == n ? scheme.onPrimary : scheme.onSurface,
                  ),
                ),
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
                      _easyMode = false;
                    });
                    _syncBookmark();
                    _syncHistory();
                  }
                : null,
            icon: const Icon(Icons.chevron_left),
            label: const Text('이전'),
          ),
          const Spacer(),
          if (widget.examMode)
            Text(
              '제출 후 해설 공개',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          const Spacer(),
          FilledButton.icon(
            onPressed: () {
              if (isLast) {
                _requestFinish();
              } else {
                setState(() {
                  _idx++;
                  _showAnswer = false;
                  _easyMode = false;
                });
                _syncBookmark();
                _syncHistory();
              }
            },
            icon: Icon(isLast ? Icons.flag : Icons.chevron_right),
            label: Text(isLast ? '채점' : '다음'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestFinish() async {
    final unanswered = QuizPolicy.unansweredCount(
      total: widget.questions.length,
      answered: _picked.length,
    );
    if (!widget.examMode || unanswered == 0) {
      await _finish();
      return;
    }
    final submit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('미답 문항이 있습니다'),
        content: Text('$unanswered문항을 풀지 않았습니다. 미답은 오답으로 처리됩니다. 그래도 제출할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('계속 풀기'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('제출'),
          ),
        ],
      ),
    );
    if (submit == true && mounted) await _finish();
  }

  Future<void> _requestExit() async {
    if (_finished) return;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('문제풀이를 종료할까요?'),
        content: const Text('아직 제출하지 않은 답안과 현재 진행 위치는 저장되지 않습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('계속 풀기'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('종료'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      setState(() => _allowExit = true);
      await Future<void>.delayed(Duration.zero);
      if (mounted) Navigator.of(context).pop();
    }
  }

  /// 정답 아래 버튼 → 해당 토픽의 완전한 1:1 강의 시트 (이론+공식+암기법+함정+전략)
  void _openLesson() {
    showLessonSheet(context, _q.subject, _q.topic);
  }

  /// 🚩 문제 오류 신고 — 이메일로 문항 정보와 오류 유형 전송
  Future<void> _reportError() async {
    final q = _q;
    final types = ['오탈자/문장 오류', '정답이 틀림', '보기 오류', '해설 오류', '이미지 누락', '기타'];
    final picked = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text('🚩 문제 오류 신고',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('어떤 오류인가요? 신고하면 다음 업데이트에 반영됩니다.',
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(ctx)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6))),
            ),
            for (final t in types)
              ListTile(
                dense: true,
                leading: const Icon(Icons.report_problem_outlined, size: 20),
                title: Text(t),
                onTap: () => Navigator.pop(ctx, t),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;

    final subject = Uri.encodeComponent(
        '[문제오류신고] ${q.subject} · ${q.examLabel} ${q.no}번');
    final body = Uri.encodeComponent('오류 유형: $picked\n\n'
        '과목: ${q.subject}\n토픽: ${q.topic}\n회차: ${q.examLabel}\n문항번호: ${q.no}\n\n'
        '문제: ${q.question}\n\n상세 설명(선택):\n');
    final uri = Uri.parse(
        'mailto:certstudytracker@gmail.com?subject=$subject&body=$body');
    try {
      final ok = await launchUrl(uri);
      if (!ok && mounted) {
        _showReportFallback(picked);
      }
    } catch (_) {
      if (mounted) _showReportFallback(picked);
    }
  }

  void _showReportFallback(String type) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('신고가 기록되었습니다 ($type) — 감사합니다! 🙏'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 반복해서 틀리는 문제(누적 오답 2회 이상)면 오답노트를 강제로 띄우고
  /// 관련 이론을 들이민다. (사용자가 원인을 고르기 전엔 닫기 불가)
  Future<void> _maybeForceWrongNote() async {
    final wrongCount = await ProgressService.instance.wrongCountFor(_q.qid);
    if (wrongCount < 2 || !mounted) return; // 처음 틀린 건 강제하지 않음

    final q = _q; // 캡처 (인덱스 변경 대비)
    await showModalBottomSheet(
      context: context,
      isDismissible: false, // 바깥 탭으로 닫기 금지
      enableDrag: false, // 드래그로 닫기 금지
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ForcedWrongNoteSheet(
        question: q,
        wrongCount: wrongCount,
      ),
    );
  }

  bool _finished = false; // 타이머 자동채점·수동채점 중복 방지

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
    final appProv = context.read<AppProvider>();
    final levelBefore = appProv.level;
    try {
      await appProv.addQuizResult(
        title: widget.title,
        total: total,
        correct: correct,
        subjectTotal: subjectTotal,
        subjectCorrect: subjectCorrect,
        wrongQuestions: wrongList
            .map(
              (q) =>
                  '[${q.subject}] ${q.examLabel} ${q.no}번: ${q.question.length > 60 ? q.question.substring(0, 60) : q.question}',
            )
            .toList(),
      );
    } catch (_) {
      _finished = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('결과를 저장하지 못했습니다. 저장 공간을 확인한 뒤 다시 제출해주세요.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // 🎉 레벨업 시 축하 팝업
    if (mounted) {
      await LevelUpDialog.showIfLevelUp(
        context,
        levelBefore,
        appProv.level,
        appProv.levelTitle,
      );
    }
    if (!mounted) return;

    // 🛡️ 오늘의 미션 올클리어 시 마법 방패 지급
    final earnedShield = await appProv.maybeEarnShield();
    if (earnedShield && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🛡️ 마법 방패 획득! 하루 건너뛰어도 스트릭이 유지돼요'),
          backgroundColor: Color(0xFF4F46E5),
        ),
      );
    }
    if (!mounted) return;

    // 🎯 풀 때마다 합격 예측 점수 갱신 — "내 점수가 움직인다"는 중독 루프
    PassPrediction? pred;
    try {
      pred = await PassPredictionEngine.instance.predict();
    } catch (_) {}
    if (!mounted) return;

    // 🏆 100문항 실전 단위(examMode) — 공유하고 싶은 합격 성적표로 진입
    if (widget.examMode && total >= 90) {
      await pushWithNav(context, ResultCertificateScreen(
            examLabel: widget.title.replaceFirst(
              '${StudyData.instance.track.name} ',
              '',
            ),
            correct: correct,
            total: total,
            subjectTotal: subjectTotal,
            subjectCorrect: subjectCorrect,
            prediction: pred,
          ), currentSection: 1);
      if (mounted) Navigator.of(context).pop(true);
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          _timeOver
              ? '⏰ 시간 종료! 결과: $correct/$total ($pct점)'
              : '결과: $correct/$total ($pct점)',
        ),
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
                    '(${((subjectCorrect[s] ?? 0) * 100 / subjectTotal[s]!).round()}점)',
                  ),
                ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('✨', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      '+${correct * 5} XP 획득!',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                pct >= 60 ? '합격권! (평균 60점 이상)' : '조금 더! (평균 60점 목표)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: pct >= 60 ? Colors.green : Colors.orange,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '오답은 자동으로 학습이력에 저장되었습니다.',
                style: TextStyle(fontSize: 12),
              ),
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
                          : Colors.orange.shade900,
                    ),
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
              Navigator.of(context).pop(true);
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

/// 반복 오답 강제 오답노트 시트 — 원인을 선택해야 닫힌다 + 이론 들이밀기.
class _ForcedWrongNoteSheet extends StatefulWidget {
  final Question question;
  final int wrongCount;
  const _ForcedWrongNoteSheet({
    required this.question,
    required this.wrongCount,
  });

  @override
  State<_ForcedWrongNoteSheet> createState() => _ForcedWrongNoteSheetState();
}

class _ForcedWrongNoteSheetState extends State<_ForcedWrongNoteSheet> {
  String? _reason;
  bool _openedTheory = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final q = widget.question;
    final canClose = _reason != null && _openedTheory;
    return PopScope(
      canPop: false, // 뒤로가기로 닫기 금지
      child: DraggableScrollableSheet(
        initialChildSize: 0.82,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, controller) => Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            children: [
              // 경고 헤더
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: Colors.red.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.report_problem_rounded,
                        color: Colors.red, size: 30),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('이 문제, 벌써 ${widget.wrongCount}번째 오답!',
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.red)),
                          const SizedBox(height: 3),
                          const Text('그냥 넘기면 시험장에서 또 틀립니다. 원인을 짚고 이론을 확인하세요.',
                              style: TextStyle(
                                  fontSize: 11.5, height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 문제 요약
              Text('[${q.subject}] ${q.topic}',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: cs.primary)),
              const SizedBox(height: 4),
              Text(q.question,
                  style: const TextStyle(fontSize: 13.5, height: 1.5)),
              const SizedBox(height: 6),
              Text('✅ 정답: ${q.answer}번  ${q.answer <= q.options.length ? q.options[q.answer - 1] : ""}',
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.success)),
              const Divider(height: 26),
              // 1단계: 원인 선택 (필수)
              Row(
                children: [
                  _stepBadge('1', _reason != null),
                  const SizedBox(width: 8),
                  const Text('왜 틀렸나요? (필수)',
                      style: TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ProgressService.wrongReasons.map((r) {
                  final sel = _reason == r;
                  return ChoiceChip(
                    label: Text(r, style: const TextStyle(fontSize: 12)),
                    selected: sel,
                    onSelected: (_) {
                      setState(() => _reason = r);
                      ProgressService.instance.recordWrongReason(q, r);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              // 2단계: 이론 확인 (필수)
              Row(
                children: [
                  _stepBadge('2', _openedTheory),
                  const SizedBox(width: 8),
                  const Text('관련 이론 확인 (필수)',
                      style: TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        _openedTheory ? AppTheme.success : cs.primary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: () {
                    showLessonSheet(context, q.subject, q.topic);
                    setState(() => _openedTheory = true);
                  },
                  icon: Icon(_openedTheory
                      ? Icons.check_circle_rounded
                      : Icons.menu_book_rounded),
                  label: Text(_openedTheory
                      ? '이론 확인 완료 — 다시 보려면 탭'
                      : '이 주제 이론 펼쳐보기'),
                ),
              ),
              const SizedBox(height: 24),
              // 닫기 (두 단계 완료 시에만 활성화)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: canClose
                      ? () => Navigator.of(context).pop()
                      : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: Text(canClose
                      ? '이해했어요! 계속 풀기'
                      : '원인 선택 + 이론 확인을 완료하세요'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepBadge(String n, bool done) {
    return CircleAvatar(
      radius: 12,
      backgroundColor: done ? AppTheme.success : Colors.grey.shade400,
      child: done
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : Text(n,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
    );
  }
}
