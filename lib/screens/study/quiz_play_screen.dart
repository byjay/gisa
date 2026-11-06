import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../theme/app_theme.dart';
import '../../services/study_data.dart';
import '../../services/app_config.dart';
import '../../services/remote_content_api.dart';
import '../../services/progress_service.dart';
import '../../services/pass_prediction.dart';
import '../../services/quiz_policy.dart';
import '../../services/quiz_grader.dart';
import '../../services/tutor_speech_service.dart';
import '../../widgets/drawing_pad.dart';
import '../../widgets/lesson_view.dart';
import '../../widgets/rich_slide_body.dart';
import '../../widgets/teacher_recipe_box.dart';
import '../../widgets/level_up_dialog.dart';
import 'result_certificate_screen.dart';
import '../../widgets/persistent_nav.dart';
import '../../widgets/tutor_coach.dart';
import '../../services/entitlement_service.dart';
import '../../widgets/premium_gate.dart';

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
  bool _gradingAnswer = false;
  bool _bookmarked = false;
  // 🖼 글·그림 중복 방지: 보기가 텍스트로 완전한 문제는 이미지를 접어두고
  // 버튼으로만 펼친다(이미지에 같은 지문·보기가 또 들어있어 중복되므로).
  bool _showOriginalImage = false;
  bool _easyMode = true; // 초급자 기본값: 모든 문제에 쉬운 설명 자동 노출
  bool _allowExit = false;
  ({int seenCount, String? lastResult, int box})? _history; // 다시 만난 문제 인식 배너
  final Map<int, String> _reasonPicked = {}; // 문제별 선택한 오답 원인

  // ⏱ 실전 타이머 (examMode 전용) — 실제 시험 페이스: 문제당 90초
  Timer? _timer;
  int _remainSec = 0;
  int _totalSec = 0;
  bool _timeOver = false;

  // [P1-B/B7] dispose에서는 BuildContext(특히 context.read)를 사용하지 않는다.
  // initState에서 AppProvider 참조를 필드로 캡처해 dispose에서 안전하게
  // 사용한다. try-catch로 예외를 은닉하지 않고, 실전모드 플래그 해제가
  // 항상 결정적으로 수행되도록 한다.
  late AppProvider _app;

  Question get _q => widget.questions[_idx];

  // ─────────── 💎 무료 10% 게이트 ───────────
  /// 무료 사용자가 접근 가능한 문항 수(전체의 10%, 최소 1).
  int get _allowedCount =>
      EntitlementService.instance.allowedQuestionCount(widget.questions.length);

  /// [target] 인덱스(0-based)로 이동하려 할 때, 무료 한도를 넘으면 페이월을
  /// 띄우고 이동을 막는다. 반환값 true = 이동 허용, false = 잠김.
  bool _guardNavigate(int target) {
    final ent = EntitlementService.instance;
    if (!ent.isQuestionLocked(target, widget.questions.length)) return true;
    // 잠긴 문항 — 결제 유도.
    HapticFeedback.mediumImpact();
    final allowed = _allowedCount;
    openPremiumPaywall(
      context,
      hook:
          '무료로는 전체 ${widget.questions.length}문항 중 '
          '$allowed문항(10%)만 풀 수 있어요.\n'
          '프리미엄으로 업그레이드하면 남은 ${widget.questions.length - allowed}문항과 '
          '전 회차 기출을 100% 무제한으로 풀 수 있습니다.',
    );
    return false;
  }

  /// 보기가 이미지 안에만 있는 문제인지 — 이 경우 이미지가 본문이므로 항상 표시.
  /// 보기가 텍스트로 완전하면 이미지(같은 지문·보기 포함)는 숨겨 중복을 막는다.
  bool get _optionsNeedImage => _q.options.any(
    (o) =>
        o.contains('이미지 참고') ||
        o.contains('위 그림') ||
        o.contains('그림 참조') ||
        o.trim().length <= 2,
  );

  /// 🍼 아주 쉬운 설명 — 기존 문제·정답·해설 데이터를 그대로 재활용하여
  /// 초보자용 친절한 말투로 재구성 (새 데이터 생성 없이 규칙 기반 변환)
  String _easyExplanation() {
    final q = _q;
    final ansIdx = q.answer - 1;
    final answerText = (ansIdx >= 0 && ansIdx < q.options.length)
        ? q.options[ansIdx]
        : '';
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      size: 13,
                      color: Colors.white,
                    ),
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
    // [P1-B/B7] dispose에서 안전하게 쓰기 위해 AppProvider 참조를 여기서
    // 캡처한다. initState 시점의 context는 항상 유효하다.
    _app = context.read<AppProvider>();
    _syncBookmark();
    _syncHistory();
    // 🔒 Q65: 실전모드 진행 중에는 AI 튜터를 통한 정답 유출 우회를 막기 위해
    // 전역 플래그를 세운다. 화면 종료 시(dispose) 반드시 해제한다.
    // ⏱ 모의고사 시작 시 전역 학습 타이머도 자동 시작 — 시험 시간이
    // 상단 TimerRunningBar에 표시되고 종료 시 학습시간으로 기록된다.
    if (widget.examMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _app.setExamInProgress(true);
        if (!_app.timerRunning) {
          _startedGlobalTimer = true;
          _app.startTimer(null);
        }
      });
    }
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

  /// 이 화면이 시작한 전역 타이머인지 — 사용자가 별도로 켜둔 타이머는 건드리지 않는다.
  bool _startedGlobalTimer = false;

  @override
  void dispose() {
    _timer?.cancel();
    // 🔒 Q65: 실전모드 종료 시 AI 튜터 접근 제한 플래그 해제.
    // [P1-B/B7] context.read 대신 initState에서 캡처한 _app 필드를 사용하므로
    // "context가 트리에서 분리됨" 문제가 원천적으로 발생하지 않는다.
    // 따라서 예외를 은닉하는 try-catch도 제거한다 — 이 경로가 실패할 이유가
    // 없으므로 실패한다면 숨기지 않고 드러나야 한다.
    if (widget.examMode) {
      _app.setExamInProgress(false);
      // ⏱ 자동 시작했던 전역 타이머 정지 — 경과 시간은 학습 세션으로 저장된다.
      // stopTimer()는 Future지만 dispose는 동기 함수이므로 결과를
      // await할 수 없다 — fire-and-forget으로 세션 저장을 트리거한다.
      if (_startedGlobalTimer && _app.timerRunning) {
        unawaited(_app.stopTimer());
      }
    }
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
    final locked = EntitlementService.instance.isQuestionLocked(
      i,
      widget.questions.length,
    );
    return InkWell(
      onTap: () {
        Navigator.of(ctx).pop();
        // 💎 잠긴 문항 탭 → 페이월.
        if (!_guardNavigate(i)) return;
        setState(() {
          _idx = i;
          _showAnswer = false;
          _easyMode = true;
        });
        _syncBookmark();
        _syncHistory();
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
              color: locked
                  ? scheme.surfaceContainerHighest.withValues(alpha: 0.45)
                  : isAnswered
                  ? scheme.primary
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(9),
              border: isCurrent
                  ? Border.all(color: AppTheme.accent, width: 2.5)
                  : null,
            ),
            child: locked
                ? const Icon(Icons.lock, size: 13, color: Color(0xFFB45309))
                : Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isAnswered
                          ? scheme.onPrimary
                          : scheme.onSurfaceVariant,
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
              tooltip: '필기 연습장 (계산·메모)',
              icon: const Icon(Icons.draw_rounded),
              onPressed: () => showDrawingPad(context),
            ),
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
                      // 💎 무료 미리보기 한도 안내 칩(프리미엄은 자동 숨김).
                      if (!widget.examMode)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: FreeLimitChip(
                              allowed: _allowedCount,
                              total: widget.questions.length,
                            ),
                          ),
                        ),
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
                      // 📊 기출빈도 상세 — 얼마나 자주, 어떻게 변형 출제되는지.
                      if (_q.freqScore >= 20) _freqDetailPanel(),
                      const SizedBox(height: 12),
                      // 🖼 글·그림 중복 방지 렌더링:
                      // ① 보기가 이미지 안에만 있는 문제 → 이미지가 본문(필수 표시)
                      // ② 텍스트가 완전한 문제 → 텍스트만 보이고 이미지는 버튼으로 펼침
                      Text(
                        '${_q.no}. ${_q.question}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                        ),
                      ),
                      if (_q.hasImage && _q.remoteImagePath != null) ...[
                        const SizedBox(height: 12),
                        if (_optionsNeedImage || _showOriginalImage)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(
                                  color: scheme.outlineVariant,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Image.network(
                                RemoteContentApi.instance
                                    .questionImageUri(
                                      StudyData.instance.track.id,
                                      _q.remoteImagePath!,
                                    )
                                    .toString(),
                                headers: RemoteContentApi.instance.imageHeaders,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stack) =>
                                    const SizedBox.shrink(),
                              ),
                            ),
                          )
                        else
                          // 텍스트 완전 문제: 중복 방지를 위해 원본 그림은 접어둔다
                          OutlinedButton.icon(
                            onPressed: () =>
                                setState(() => _showOriginalImage = true),
                            icon: const Icon(Icons.image_outlined, size: 18),
                            label: const Text(
                              '원본 그림 보기 (지문과 동일 내용)',
                              style: TextStyle(fontSize: 12.5),
                            ),
                          ),
                        if (_optionsNeedImage && _showOriginalImage == false)
                          const SizedBox.shrink(),
                      ],
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

  /// 📊 기출빈도 상세 패널 — "얼마나 자주 / 어떻게 변형 재출제되는지"를
  /// 시각적으로 상세히 보여준다(사용자 요청: 기출빈도 더 자세히).
  Widget _freqDetailPanel() {
    final color = Color(_q.freqColorValue);
    final score = _q.freqScore.round();
    final appears = _q.estimatedAppearances;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.10),
            color.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, size: 18, color: color),
              const SizedBox(width: 6),
              Text(
                '기출빈도 분석',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_q.freqGrade} · $score점',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 출제빈도 게이지
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (score / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.replay_rounded, size: 15, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '최근 10회차 중 약 $appears회 출제(변형 포함)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🔄 ', style: TextStyle(fontSize: 13)),
              Expanded(
                child: Text(
                  _q.reissuePattern,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
              const Icon(
                Icons.psychology_alt_rounded,
                size: 18,
                color: Colors.redAccent,
              ),
              const SizedBox(width: 6),
              Text(
                selected == null ? '왜 틀렸나요? (원인 기록)' : '오답 원인: $selected',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
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
                    horizontal: 11,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSel ? Colors.redAccent : scheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSel ? Colors.redAccent : scheme.outlineVariant,
                    ),
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
                  color: scheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 해당 문항 결과에 맞는 볼트쌀 상황 결정
  CoachSituation get _coachSituation {
    final picked = _picked[_idx];
    if (picked == null) {
      return _q.difficulty == 3
          ? CoachSituation.quizHardQuestion
          : CoachSituation.quizStart;
    }
    if (picked == _q.answer) {
      // 직전 2문항도 정답이면 연속 정답
      var streak = 0;
      for (var i = _idx; i >= 0; i--) {
        if (_picked[i] == widget.questions[i].answer) {
          streak++;
        } else {
          break;
        }
      }
      return streak >= 3
          ? CoachSituation.quizCorrectStreak
          : CoachSituation.quizCorrect;
    }
    return CoachSituation.quizWrong;
  }

  /// 사용자 수준(0왕초보/1중급/2상급) — 현재 세션 정답률 기반
  int get _coachLevel {
    if (_picked.length < 3) return 0;
    var c = 0;
    _picked.forEach((i, v) {
      if (v == widget.questions[i].answer) c++;
    });
    final r = c / _picked.length;
    return r >= 0.75 ? 2 : (r >= 0.45 ? 1 : 0);
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
          // 🎓 볼트쌀 전신 코치 — 정답/오답/연속정답 상황별 1:1 멘트
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TutorCoach(
              key: ValueKey('coach_${_idx}_${_picked[_idx]}'),
              situation: _coachSituation,
              level: _coachLevel,
              height: 96,
            ),
          ),
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
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: '튜터 해설 듣기',
                        icon: const Icon(Icons.volume_up_rounded, size: 19),
                        onPressed: () => TutorSpeechService.instance.speak(
                          _easyMode ? _easyExplanation() : _q.explanation,
                        ),
                      ),
                      // 🍼 아주 쉬운 설명 토글 (기존 데이터 재활용)
                      InkWell(
                        onTap: () => setState(() => _easyMode = !_easyMode),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _easyMode
                                ? Colors.orange
                                : Colors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _easyMode ? '🍼' : '💡',
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _easyMode ? '초급 설명 항상 켜짐' : '일반 해설',
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
                          color: Colors.orange.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '🍼 아주 쉽게 풀어드릴게요',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.deepOrange,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _easyExplanation(),
                            style: const TextStyle(fontSize: 13.5, height: 1.6),
                          ),
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
    final reveal =
        _showAnswer || (!widget.examMode && picked != null && _q.answer > 0);
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
        onTap: _gradingAnswer ? null : () => unawaited(_pickAnswer(n)),
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

  Future<void> _pickAnswer(int picked) async {
    final index = _idx;
    final question = widget.questions[index];
    setState(() {
      _picked[index] = picked;
      _showAnswer = !widget.examMode && question.answer > 0;
    });

    final needsRemoteGrade =
        AppConfig.hasApi && question.remoteQid != null && question.answer <= 0;
    if (needsRemoteGrade && widget.examMode) {
      HapticFeedback.selectionClick();
      return; // 실전 모드는 제출 시 한 번에 서버 채점한다.
    }
    if (needsRemoteGrade) {
      setState(() => _gradingAnswer = true);
      try {
        final response = await RemoteContentApi.instance.grade([
          {'qid': question.qid, 'picked': picked},
        ]);
        final items = (response['results'] as List?) ?? const [];
        final item = items
            .cast<Map>()
            .where((row) => row['qid'] == question.qid)
            .firstOrNull;
        if (item == null) throw StateError('서버가 채점 결과를 반환하지 않았습니다.');
        question
          ..answer = (item['answer'] as num).toInt()
          ..explanation = item['explanation'] as String? ?? '';
        if (mounted && _idx == index) {
          setState(() => _showAnswer = true);
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('서버 채점 실패: $error')));
        }
        return;
      } finally {
        if (mounted) setState(() => _gradingAnswer = false);
      }
    }

    if (!_recorded.add(index)) {
      HapticFeedback.selectionClick();
      return;
    }
    final correct = picked == question.answer;
    if (!widget.examMode && correct) {
      HapticFeedback.mediumImpact();
    } else if (!widget.examMode) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.selectionClick();
    }
    ProgressService.instance.record(question, correct);
    if (!correct && !widget.examMode) unawaited(_maybeForceWrongNote());
  }

  Widget _bottomBar() {
    // 무료 사용자는 허용 문항의 마지막이 곧 "채점" 지점이 된다.
    final effectiveLastIdx = _allowedCount - 1;
    final isLast =
        _idx == widget.questions.length - 1 || _idx == effectiveLastIdx;
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
                      _showOriginalImage = false;
                      _easyMode = true;
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
                // 💎 무료 10% 게이트: 다음 문항이 잠겨 있으면 페이월로.
                if (!_guardNavigate(_idx + 1)) return;
                setState(() {
                  _idx++;
                  _showAnswer = false;
                  _showOriginalImage = false;
                  _easyMode = true;
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
    final answeredCount = _picked.length;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.examMode ? '⚠️ 실전 모의고사를 종료할까요?' : '문제풀이를 종료할까요?'),
        content: Text(
          widget.examMode
              ? '지금까지 푼 $answeredCount / ${widget.questions.length}문항의 답안이'
                    ' 저장되지 않고 사라집니다.\n실전 모드는 중간 저장을 지원하지 않습니다.'
              : '아직 제출하지 않은 답안과 현재 진행 위치는 저장되지 않습니다.',
        ),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                '🚩 문제 오류 신고',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                '어떤 오류인가요? 신고하면 다음 업데이트에 반영됩니다.',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    ctx,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
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
      '[문제오류신고] ${q.subject} · ${q.examLabel} ${q.no}번',
    );
    final body = Uri.encodeComponent(
      '오류 유형: $picked\n\n'
      '과목: ${q.subject}\n토픽: ${q.topic}\n회차: ${q.examLabel}\n문항번호: ${q.no}\n\n'
      '문제: ${q.question}\n\n상세 설명(선택):\n',
    );
    final uri = Uri.parse(
      'mailto:admin@secms.tech?subject=$subject&body=$body',
    );
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
      builder: (ctx) =>
          _ForcedWrongNoteSheet(question: q, wrongCount: wrongCount),
    );
  }

  bool _finished = false; // 타이머 자동채점·수동채점 중복 방지

  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
    _timer?.cancel();

    if (AppConfig.hasApi) {
      final remoteQuestions = widget.questions
          .where((question) => question.remoteQid != null)
          .toList();
      if (remoteQuestions.isNotEmpty) {
        try {
          final answers = <Map<String, dynamic>>[];
          for (final question in remoteQuestions) {
            final index = widget.questions.indexOf(question);
            answers.add({'qid': question.qid, 'picked': _picked[index] ?? 0});
          }
          final response = await RemoteContentApi.instance.gradeMany(answers);
          final byQid = <String, Map>{
            for (final value in (response['results'] as List? ?? const []))
              if (value is Map && value['qid'] is String)
                value['qid'] as String: value,
          };
          for (final question in remoteQuestions) {
            final result = byQid[question.qid];
            if (result == null) throw StateError('채점 결과에서 문항이 누락되었습니다.');
            question
              ..answer = (result['answer'] as num).toInt()
              ..explanation = result['explanation'] as String? ?? '';
          }
          if (widget.examMode) {
            for (var i = 0; i < widget.questions.length; i++) {
              final picked = _picked[i];
              if (picked != null && _recorded.add(i)) {
                ProgressService.instance.record(
                  widget.questions[i],
                  picked == widget.questions[i].answer,
                );
              }
            }
          }
        } catch (error) {
          _finished = false;
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('서버 채점을 완료하지 못했습니다: $error')));
          return;
        }
      }
    }

    if (!mounted) return;

    // [P1-B/T10] 채점 계산은 순수 함수 QuizGrader.grade로 추출했다.
    // 이 화면은 결과를 받아 저장·연출만 담당한다 — 채점 로직은
    // 위젯 없이 test/quiz_grader_test.dart에서 단위 테스트된다.
    final grade = QuizGrader.grade(widget.questions, _picked);
    final total = grade.total;
    final correct = grade.correct;
    final pct = grade.percent;
    final subjectTotal = grade.subjectTotal;
    final subjectCorrect = grade.subjectCorrect;

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
        wrongQuestions: grade.wrongSummaries(),
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
      await pushWithNav(
        context,
        ResultCertificateScreen(
          examLabel: widget.title.replaceFirst(
            '${StudyData.instance.track.name} ',
            '',
          ),
          correct: correct,
          total: total,
          subjectTotal: subjectTotal,
          subjectCorrect: subjectCorrect,
          prediction: pred,
        ),
        currentSection: 1,
      );
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
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
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
                  border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.report_problem_rounded,
                      color: Colors.red,
                      size: 30,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '이 문제, 벌써 ${widget.wrongCount}번째 오답!',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            '그냥 넘기면 시험장에서 또 틀립니다. 원인을 짚고 이론을 확인하세요.',
                            style: TextStyle(fontSize: 11.5, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // 문제 요약
              Text(
                '[${q.subject}] ${q.topic}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                q.question,
                style: const TextStyle(fontSize: 13.5, height: 1.5),
              ),
              const SizedBox(height: 6),
              Text(
                '✅ 정답: ${q.answer}번  ${q.answer <= q.options.length ? q.options[q.answer - 1] : ""}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.success,
                ),
              ),
              const Divider(height: 26),
              // 1단계: 원인 선택 (필수)
              Row(
                children: [
                  _stepBadge('1', _reason != null),
                  const SizedBox(width: 8),
                  const Text(
                    '왜 틀렸나요? (필수)',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
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
                  const Text(
                    '관련 이론 확인 (필수)',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: _openedTheory
                        ? AppTheme.success
                        : cs.primary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: () {
                    showLessonSheet(context, q.subject, q.topic);
                    setState(() => _openedTheory = true);
                  },
                  icon: Icon(
                    _openedTheory
                        ? Icons.check_circle_rounded
                        : Icons.menu_book_rounded,
                  ),
                  label: Text(
                    _openedTheory ? '이론 확인 완료 — 다시 보려면 탭' : '이 주제 이론 펼쳐보기',
                  ),
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
                  child: Text(
                    canClose ? '이해했어요! 계속 풀기' : '원인 선택 + 이론 확인을 완료하세요',
                  ),
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
          : Text(
              n,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
    );
  }
}
