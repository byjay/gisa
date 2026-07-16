import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../../services/study_data.dart';
import '../../services/progress_service.dart';
import '../../theme/app_theme.dart';

/// 🎯 시각적 10회 반복 합격 트레이너
/// - 빈출 반복문제(RepeatCluster)를 플래시카드로 "보고→답 확인→외웠는지 체크"
/// - 각 카드의 반복 횟수(reps)를 10칸 도트로 시각화 → 10회 채우면 "합격 확정" 도장
/// - CBT 재출제율이 높은 반복문제를 10회 반복하면 합격선(60점) 돌파가 목표
class VisualRepeatScreen extends StatefulWidget {
  const VisualRepeatScreen({super.key});

  @override
  State<VisualRepeatScreen> createState() => _VisualRepeatScreenState();
}

class _VisualRepeatScreenState extends State<VisualRepeatScreen> {
  static const int kGoal = 10; // 목표 반복 횟수

  List<RepeatCluster>? _all;
  String? _subjectFilter;
  int _idx = 0;
  bool _revealed = false;
  final Map<String, int> _reps = {}; // qid -> reps (실시간 반영)

  @override
  void initState() {
    super.initState();
    StudyData.instance.loadRepeats().then((v) async {
      // 빈도(count) 높은 순으로 정렬 → 재출제 확률 높은 문제 먼저
      v.sort((a, b) => b.count.compareTo(a.count));
      // 기존 reps 로드
      for (final c in v) {
        _reps[_qid(c)] = await ProgressService.instance.repsFor(_qid(c));
      }
      if (mounted) setState(() => _all = v);
    });
  }

  String _qid(RepeatCluster c) =>
      'rep|${StudyData.instance.track.id}|${c.subject}|${c.topic}|${c.question.hashCode}';

  List<RepeatCluster> get _cards {
    final all = _all ?? [];
    if (_subjectFilter == null) return all;
    return all.where((r) => r.subject == _subjectFilter).toList();
  }

  RepeatCluster? get _card {
    final c = _cards;
    if (c.isEmpty) return null;
    return c[_idx % c.length];
  }

  ({int total, int mastered, int totalReps}) get _summary =>
      ProgressService.instance
          .repetitionSummary(_cards.map(_qid), goal: kGoal);

  Future<void> _markSeen() async {
    final c = _card;
    if (c == null) return;
    final qid = _qid(c);
    await ProgressService.instance
        .recordExposure(qid, subject: c.subject, topic: c.topic);
    setState(() {
      _reps[qid] = (_reps[qid] ?? 0) + 1;
    });
  }

  void _next() {
    setState(() {
      _revealed = false;
      _idx++;
    });
  }

  void _prev() {
    setState(() {
      _revealed = false;
      _idx = (_idx - 1);
      if (_idx < 0) _idx = _cards.length - 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final all = _all;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎯 10회 반복 합격 트레이너'),
      ),
      body: all == null
          ? const Center(child: CircularProgressIndicator())
          : all.isEmpty
              ? const Center(child: Text('반복 출제 문제 데이터가 없습니다.'))
              : Column(
                  children: [
                    _headerProgress(cs),
                    _subjectChips(),
                    Expanded(child: _cardView(cs)),
                    _controls(cs),
                  ],
                ),
    );
  }

  // ── 상단: 전체 10회 반복 진행 요약 ─────────────────────
  Widget _headerProgress(ColorScheme cs) {
    final s = _summary;
    final pct = s.total == 0 ? 0.0 : s.mastered / s.total;
    // 컴팩트 한 줄 진행 바 — 문제 영역 확보
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 8,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppTheme.primary),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('${s.mastered}/${s.total} 완성 · 누적 ${s.totalReps}회',
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary)),
        ],
      ),
    );
  }

  // ── 과목 필터 칩 ─────────────────────────────────
  Widget _subjectChips() {
    final subjects = <String?>[null, ...kSubjects];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        itemCount: subjects.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final s = subjects[i];
          final sel = _subjectFilter == s;
          return ChoiceChip(
            label: Text(s ?? '전체',
                style: const TextStyle(fontSize: 12)),
            selected: sel,
            onSelected: (_) => setState(() {
              _subjectFilter = s;
              _idx = 0;
              _revealed = false;
            }),
          );
        },
      ),
    );
  }

  // ── 카드 본문 ─────────────────────────────────────
  Widget _cardView(ColorScheme cs) {
    final c = _card;
    if (c == null) {
      return const Center(child: Text('이 과목의 반복문제가 없습니다.'));
    }
    final qid = _qid(c);
    final reps = _reps[qid] ?? 0;
    final done = reps >= kGoal;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 반복 도트 (10칸)
          _repDots(reps, done),
          const SizedBox(height: 6),
          // 문제 카드
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: done
                  ? Border.all(color: AppTheme.success, width: 2)
                  : Border.all(color: cs.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${c.subject} · ${c.count}회 출제',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primary)),
                    ),
                    const Spacer(),
                    if (done)
                      const Row(children: [
                        Icon(Icons.verified_rounded,
                            size: 16, color: AppTheme.success),
                        SizedBox(width: 3),
                        Text('합격 확정',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.success)),
                      ]),
                  ],
                ),
                const SizedBox(height: 8),
                Text(c.question,
                    style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                // 보기
                for (int i = 0; i < c.options.length; i++)
                  _optionRow(i + 1, c.options[i], c.answer),
                const SizedBox(height: 4),
                // 정답/해설 (뒤집기)
                if (_revealed) _answerBox(c, cs),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _optionRow(int n, String text, int answer) {
    final isAns = _revealed && n == answer;
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isAns ? AppTheme.success.withValues(alpha: 0.13) : null,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isAns
              ? AppTheme.success
              : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: isAns
                ? AppTheme.success
                : Colors.grey.withValues(alpha: 0.3),
            child: Text('$n',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isAns ? Colors.white : Colors.black54)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 12.5,
                    height: 1.3,
                    fontWeight: isAns ? FontWeight.w800 : FontWeight.w500)),
          ),
          if (isAns)
            const Icon(Icons.check_circle,
                size: 18, color: AppTheme.success),
        ],
      ),
    );
  }

  Widget _answerBox(RepeatCluster c, ColorScheme cs) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_rounded,
                  size: 16, color: AppTheme.success),
              const SizedBox(width: 5),
              Text('정답: ${c.answer}번',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.success)),
            ],
          ),
          if (c.answerText.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(c.answerText,
                style: const TextStyle(fontSize: 12.5, height: 1.5)),
          ],
        ],
      ),
    );
  }

  // ── 10칸 반복 도트 ─────────────────────────────────
  Widget _repDots(int reps, bool done) {
    // 한 줄 컴팩트: 라벨 + 도트 나란히
    return Row(
      children: [
        Text('반복 $reps/$kGoal',
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: done ? AppTheme.success : AppTheme.primary)),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            children: List.generate(kGoal, (i) {
              final filled = i < reps;
              return Expanded(
                child: Container(
                  height: 8,
                  margin: EdgeInsets.only(right: i == kGoal - 1 ? 0 : 3),
                  decoration: BoxDecoration(
                    color: filled
                        ? (done ? AppTheme.success : AppTheme.primary)
                        : Colors.grey.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  // ── 하단 컨트롤 ───────────────────────────────────
  Widget _controls(ColorScheme cs) {
    // 한 줄 컴팩트: [이전] [정답 확인/다음] [건너뛰기]
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
        child: Row(
          children: [
            OutlinedButton(
              onPressed: _prev,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: const Icon(Icons.chevron_left_rounded, size: 22),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  if (!_revealed) {
                    HapticFeedback.selectionClick();
                    setState(() => _revealed = true);
                  } else {
                    // 답까지 확인 → 1회 반복 인정 후 다음 카드
                    HapticFeedback.mediumImpact();
                    _markSeen();
                    _next();
                  }
                },
                icon: Icon(
                    _revealed
                        ? Icons.done_all_rounded
                        : Icons.visibility_rounded,
                    size: 18),
                label: Text(_revealed ? '외웠어요! 다음 (+1)' : '정답 확인하기',
                    style: const TextStyle(fontSize: 13.5)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _next,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: const Icon(Icons.chevron_right_rounded, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}
