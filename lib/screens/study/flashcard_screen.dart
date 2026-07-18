import 'dart:math';
import 'package:flutter/material.dart';
import '../../services/study_data.dart';
import '../../services/flashcard_srs.dart';
import '../../widgets/tutor_coach.dart';

/// 🃏 플래시카드 암기 모드 — 탭으로 카드를 뒤집어 확인하고
/// "안다/모른다" 두 버튼으로 간격반복(SRS) 스케줄링.
/// 아는 건 멀리 미루고, 모르는 건 자주 다시 보여줘서
/// "암기 과목이 쏙쏙 들어오게" 만드는 핵심 학습 모드.
class FlashcardScreen extends StatefulWidget {
  /// 특정 과목만 학습하고 싶을 때 지정 (null이면 전체)
  final String? subjectFilter;
  const FlashcardScreen({super.key, this.subjectFilter});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen>
    with SingleTickerProviderStateMixin {
  List<Mnemonic>? _queue;
  int _index = 0;
  bool _flipped = false;
  int _knownCount = 0;
  int _unknownCount = 0;
  bool _loading = true;

  String _keyOf(Mnemonic m) => '${m.subject}|${m.title}';

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final all = await StudyData.instance.loadMnemonics();
    final pool = widget.subjectFilter == null
        ? all
        : all.where((m) => m.subject == widget.subjectFilter).toList();

    final due = await FlashcardSrs.instance.dueKeys();
    final seen = await FlashcardSrs.instance.seenKeys();

    final dueCards = <Mnemonic>[];
    final newCards = <Mnemonic>[];
    final laterCards = <Mnemonic>[];

    for (final m in pool) {
      final key = _keyOf(m);
      if (due.contains(key)) {
        dueCards.add(m);
      } else if (!seen.contains(key)) {
        newCards.add(m);
      } else {
        laterCards.add(m);
      }
    }

    final rand = Random();
    dueCards.shuffle(rand);
    newCards.shuffle(rand);

    // 복습 대상 우선, 그다음 신규 카드(최대 20개씩 섞어서 부담 줄이기)
    final queue = <Mnemonic>[...dueCards, ...newCards.take(30)];
    if (queue.isEmpty) {
      // 더 이상 복습/신규가 없으면 전체 중 랜덤으로 가볍게 복습
      laterCards.shuffle(rand);
      queue.addAll(laterCards.take(15));
    }

    if (mounted) {
      setState(() {
        _queue = queue;
        _loading = false;
      });
    }
  }

  void _flip() => setState(() => _flipped = !_flipped);

  Future<void> _mark(bool known) async {
    final m = _queue![_index];
    await FlashcardSrs.instance.mark(_keyOf(m), known);
    if (known) {
      _knownCount++;
    } else {
      _unknownCount++;
    }
    if (_index + 1 >= _queue!.length) {
      setState(() => _index = _queue!.length); // 완료 화면으로
    } else {
      setState(() {
        _index++;
        _flipped = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '플래시카드${widget.subjectFilter != null ? ' · ${widget.subjectFilter}' : ''}',
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_queue == null || _queue!.isEmpty)
            ? _emptyView()
            : (_index >= _queue!.length)
            ? _doneView(theme)
            : _cardView(theme),
      ),
    );
  }

  Widget _emptyView() => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text('암기법 데이터가 없습니다.', textAlign: TextAlign.center),
    ),
  );

  Widget _doneView(ThemeData theme) {
    final total = _knownCount + _unknownCount;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            Text(
              '이번 세트 완료! ($total개)',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '안다 $_knownCount개 · 모른다 $_unknownCount개',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Text(
              _unknownCount == 0
                  ? '완벽해요! 내일 더 늘어난 간격으로 다시 만나요 🔥'
                  : '"모른다"로 표시한 카드는 내일 다시 보여드릴게요',
              style: const TextStyle(fontSize: 12.5, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('닫기'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _index = 0;
                      _knownCount = 0;
                      _unknownCount = 0;
                      _flipped = false;
                      _loading = true;
                    });
                    _prepare();
                  },
                  child: const Text('한 세트 더'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardView(ThemeData theme) {
    final m = _queue![_index];
    final progress = (_index) / _queue!.length;
    return Column(
      children: [
        // 🎓 볼트쌀 암기 코치 — 카드마다 살아있는 암기 팁
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: TutorCoach(
            key: ValueKey('fc_$_index'),
            situation: CoachSituation.flashcard,
            height: 84,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${_index + 1} / ${_queue!.length}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: GestureDetector(
              onTap: _flip,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, anim) {
                  final rotate = Tween(begin: pi, end: 0.0).animate(anim);
                  return AnimatedBuilder(
                    animation: rotate,
                    child: child,
                    builder: (context, child) {
                      final isUnder = (ValueKey(_flipped) != child!.key);
                      var tilt = ((anim.value - 0.5).abs() - 0.5) * 0.003;
                      tilt *= isUnder ? -1.0 : 1.0;
                      final value = isUnder
                          ? min(rotate.value, pi / 2)
                          : rotate.value;
                      return Transform(
                        transform: Matrix4.rotationY(value)
                          ..setEntry(3, 0, tilt),
                        alignment: Alignment.center,
                        child: child,
                      );
                    },
                  );
                },
                layoutBuilder: (widget, list) =>
                    Stack(children: [widget!, ...list]),
                child: _flipped
                    ? _faceCard(
                        key: const ValueKey(true),
                        color: theme.colorScheme.primaryContainer,
                        subject: m.subject,
                        headline: '정답',
                        content: m.body,
                        tip: m.tip,
                      )
                    : _faceCard(
                        key: const ValueKey(false),
                        color: theme.colorScheme.surfaceContainerHighest,
                        subject: m.subject,
                        headline: '탭해서 확인',
                        content: m.title,
                        tip: null,
                      ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: _flipped
              ? Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () => _mark(false),
                        icon: const Icon(Icons.refresh),
                        label: const Text('모른다'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () => _mark(true),
                        icon: const Icon(Icons.check),
                        label: const Text('안다'),
                      ),
                    ),
                  ],
                )
              : SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _flip,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('카드 뒤집기 (탭)'),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _faceCard({
    required Key key,
    required Color color,
    required String subject,
    required String headline,
    required String content,
    String? tip,
  }) {
    return Container(
      key: key,
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Chip(
                label: Text(subject, style: const TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
              Text(
                headline,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Text(
                  content,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          if (tip != null && tip.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '💡 $tip',
                style: const TextStyle(fontSize: 12.5, height: 1.4),
              ),
            ),
        ],
      ),
    );
  }
}
