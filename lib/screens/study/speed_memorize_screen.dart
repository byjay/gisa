import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import '../../services/study_data.dart';
import '../../services/entitlement_service.dart';
import '../../widgets/lesson_view.dart';
import '../../widgets/tutor_avatar.dart';
import '../../widgets/premium_gate.dart';

/// 문제-답 스피드 암기 모드
/// 10년 기출에서 2회 이상 반복 출제된 347개 클러스터를 빈도순 플래시카드로 암기.
/// CBT 문제은행의 약 50%가 기존 기출 재출제 → 반복문제 암기가 합격 최단 경로.
class SpeedMemorizeScreen extends StatefulWidget {
  const SpeedMemorizeScreen({super.key});

  @override
  State<SpeedMemorizeScreen> createState() => _SpeedMemorizeScreenState();
}

class _SpeedMemorizeScreenState extends State<SpeedMemorizeScreen> {
  List<RepeatCluster>? _all;
  String? _subjectFilter; // null = 전체
  int _idx = 0;
  bool _showExplain = false; // 하단 설명 토글
  final Set<int> _memorized = {}; // 외운 카드 인덱스 (필터 내)

  // ⚡ 속독 강화: 자동 재생(오토플레이) + 셀프테스트(정답 가리기)
  bool _autoPlay = false; // 자동 넘김 on/off
  double _autoSec = 3.0; // 카드당 노출 시간(초): 1.5 / 3 / 5
  bool _hideAnswer = false; // 셀프테스트: 정답을 가리고 스스로 떠올리기
  bool _revealed = false; // 셀프테스트 중 현재 카드 정답 공개 여부
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    StudyData.instance.loadRepeats().then((v) {
      if (mounted) setState(() => _all = v);
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    super.dispose();
  }

  /// 💎 무료 티어: 반복문제 카드도 10%만 열람 가능(나머지는 프리미엄).
  int get _allowedCount => EntitlementService.instance
      .allowedQuestionCount(_rawCards.length);

  List<RepeatCluster> get _rawCards {
    final all = _all ?? [];
    if (_subjectFilter == null) return all;
    return all.where((r) => r.subject == _subjectFilter).toList();
  }

  /// 실제로 화면에 노출되는 카드(무료는 10%까지만).
  List<RepeatCluster> get _cards {
    final raw = _rawCards;
    if (EntitlementService.instance.isPremium) return raw;
    final n = _allowedCount;
    return raw.length <= n ? raw : raw.sublist(0, n);
  }

  // ─────────── ⚡ 오토플레이 제어 ───────────
  void _toggleAutoPlay() {
    setState(() => _autoPlay = !_autoPlay);
    if (_autoPlay) {
      _startAutoTimer();
    } else {
      _autoTimer?.cancel();
    }
  }

  void _startAutoTimer() {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(
      Duration(milliseconds: (_autoSec * 1000).round()),
      (_) {
        if (!mounted) return;
        final total = _cards.length;
        if (_idx >= total - 1) {
          // 마지막 카드 → 정지.
          setState(() => _autoPlay = false);
          _autoTimer?.cancel();
          return;
        }
        setState(() {
          _memorized.add(_idx);
          _idx++;
          _showExplain = false;
          _revealed = false;
        });
      },
    );
  }

  void _setAutoSec(double s) {
    setState(() => _autoSec = s);
    if (_autoPlay) _startAutoTimer(); // 속도 즉시 반영
  }

  @override
  Widget build(BuildContext context) {
    final all = _all;
    return Scaffold(
      appBar: AppBar(
        title: const Text('문제-답 스피드 암기'),
        actions: [
          // 셀프테스트: 정답 가리고 스스로 떠올리기
          if (all != null)
            IconButton(
              tooltip: _hideAnswer ? '정답 표시 모드' : '셀프테스트(정답 가리기)',
              icon: Icon(
                _hideAnswer ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () => setState(() {
                _hideAnswer = !_hideAnswer;
                _revealed = false;
              }),
            ),
          if (all != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Text('${_idx + 1}/${_cards.length}'),
              ),
            ),
        ],
      ),
      body: all == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    final cards = _cards;
    if (cards.isEmpty) {
      return const Center(child: Text('반복 출제 문제가 없습니다.'));
    }
    if (_idx >= cards.length) _idx = cards.length - 1;
    final card = cards[_idx];
    final width = MediaQuery.of(context).size.width;
    final hPad = width > 900 ? (width - 760) / 2 : 16.0;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 0),
          child: Row(
            children: [
              const TutorAvatar(mood: TutorMood.cheer, size: 46),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '번개처럼 빠르게! ${_idx + 1}번째 · 리듬 타면서 외워봐요 ⚡',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        // 과목 필터
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: hPad),
            children: [
              _filterChip(null, '전체'),
              for (final s in kSubjects) _filterChip(s, s),
            ],
          ),
        ),
        LinearProgressIndicator(value: (_idx + 1) / cards.length),
        // ⚡ 속독 컨트롤 바 (오토플레이 + 속도)
        _speedControlBar(hPad),
        // 💎 무료 한도 안내
        if (!EntitlementService.instance.isPremium)
          Padding(
            padding: EdgeInsets.fromLTRB(hPad, 4, hPad, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FreeLimitChip(
                allowed: _allowedCount,
                total: _rawCards.length,
              ),
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 12),
            child: _flashCard(context, card),
          ),
        ),
        _bottomBar(context, cards.length),
      ],
    );
  }

  Widget _filterChip(String? value, String label) {
    final selected = _subjectFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => setState(() {
          _subjectFilter = value;
          _idx = 0;
          _showExplain = false;
          _memorized.clear();
        }),
      ),
    );
  }

  /// ⚡ 속독 컨트롤 바 — 자동재생 토글 + 속도(1.5/3/5초) 선택.
  Widget _speedControlBar(double hPad) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(hPad, 8, hPad, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            FilledButton.tonalIcon(
              onPressed: _toggleAutoPlay,
              style: FilledButton.styleFrom(
                backgroundColor: _autoPlay
                    ? cs.primary
                    : cs.surfaceContainerHighest,
                foregroundColor: _autoPlay ? cs.onPrimary : cs.onSurface,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              icon: Icon(
                _autoPlay ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 18,
              ),
              label: Text(
                _autoPlay ? '자동재생 중' : '자동속독',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text('속도', style: TextStyle(fontSize: 11.5)),
            const SizedBox(width: 4),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _speedPill(1.5, '빠름'),
                    _speedPill(3.0, '보통'),
                    _speedPill(5.0, '느림'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _speedPill(double sec, String label) {
    final selected = _autoSec == sec;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: ChoiceChip(
        label: Text(
          '$label ${sec % 1 == 0 ? sec.toInt() : sec}s',
          style: const TextStyle(fontSize: 11),
        ),
        selected: selected,
        onSelected: (_) => _setAutoSec(sec),
        visualDensity: VisualDensity.compact,
        selectedColor: cs.primaryContainer,
      ),
    );
  }

  Widget _flashCard(BuildContext context, RepeatCluster card) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 반복 출제 배지
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            Chip(
              avatar: const Icon(
                Icons.local_fire_department,
                size: 16,
                color: Colors.deepOrange,
              ),
              label: Text(
                '${card.count}회 반복 출제',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: Colors.deepOrange.withValues(alpha: 0.12),
              visualDensity: VisualDensity.compact,
            ),
            Chip(
              label: Text(card.subject, style: const TextStyle(fontSize: 11)),
              visualDensity: VisualDensity.compact,
            ),
            if (card.topic != '기타')
              Chip(
                label: Text(card.topic, style: const TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '출제: ${card.exams.join(", ")}',
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        // ── 문제 카드
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Q. ${card.question}',
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w600,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 12),
                // 🧠 셀프테스트 모드: 정답을 가리고 스스로 떠올린 뒤 탭해서 확인.
                if (_hideAnswer && !_revealed) ...[
                  InkWell(
                    onTap: () => setState(() => _revealed = true),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 22),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.touch_app_rounded,
                              size: 26, color: Colors.green),
                          SizedBox(height: 6),
                          Text(
                            '정답을 떠올려 보세요\n(탭하면 정답 공개)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else
                // 문제-답 외우기: 정답을 항상 표시 (녹색 강조 + 체크)
                for (var i = 0; i < card.options.length; i++)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: i + 1 == card.answer
                        ? BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.green.withValues(alpha: 0.55),
                            ),
                          )
                        : null,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${i + 1}. ',
                          style: TextStyle(
                            fontWeight: i + 1 == card.answer
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: i + 1 == card.answer
                                ? Colors.green[700]
                                : null,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            card.options[i],
                            style: TextStyle(
                              height: 1.4,
                              fontWeight: i + 1 == card.answer
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: i + 1 == card.answer
                                  ? Colors.green[700]
                                  : null,
                            ),
                          ),
                        ),
                        if (i + 1 == card.answer)
                          Icon(
                            Icons.check_circle,
                            size: 18,
                            color: Colors.green[600],
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // ── 하단: 설명 버튼 (토글) — 정답은 이미 위에 표시됨
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => setState(() => _showExplain = !_showExplain),
            icon: Icon(
              _showExplain
                  ? Icons.expand_less_rounded
                  : Icons.menu_book_rounded,
            ),
            label: Text(
              _showExplain ? '설명 접기' : '설명 보기',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        if (_showExplain) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '정답: ${card.answer}번',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  card.answerText,
                  style: const TextStyle(fontSize: 14.5, height: 1.4),
                ),
              ],
            ),
          ),
          // 변형 출제 이력 (같은 소재, 숫자·조건만 바뀐 문제들)
          if (card.variations.isNotEmpty) ...[
            const SizedBox(height: 10),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                '변형 출제 ${card.variations.length}건 (숫자·조건 변경 대비)',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              children: [
                for (final v in card.variations)
                  Card(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            v.exam,
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            v.question,
                            style: const TextStyle(fontSize: 13, height: 1.4),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '→ 정답: ${v.answer}번. ${v.answerText}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () =>
                  showLessonSheet(context, card.subject, card.topic),
              icon: const Icon(Icons.school, size: 18),
              label: const Text('이 토픽 1:1 강의 보기'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _bottomBar(BuildContext context, int total) {
    final isLast = _idx == total - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: _idx > 0
                ? () => setState(() {
                    _idx--;
                    _showExplain = false;
                    _revealed = false;
                  })
                : null,
            icon: const Icon(Icons.chevron_left),
            label: const Text('이전'),
          ),
          const Spacer(),
          Text(
            '암기 ${_memorized.length}/$total',
            style: const TextStyle(fontSize: 12),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: () {
              HapticFeedback.mediumImpact();
              setState(() {
                _memorized.add(_idx);
                if (!isLast) {
                  _idx++;
                  _showExplain = false;
                  _revealed = false;
                } else {
                  _showDone(total);
                }
              });
            },
            icon: Icon(isLast ? Icons.flag : Icons.chevron_right),
            label: Text(isLast ? '완료' : '외웠음·다음'),
          ),
        ],
      ),
    );
  }

  void _showDone(int total) {
    final isFree = !EntitlementService.instance.isPremium;
    final rawTotal = _rawCards.length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('암기 세션 완료!'),
        content: Text(
          isFree
              ? '무료로 열람 가능한 $total개 카드를 모두 확인했습니다.\n'
                  '전체 반복문제는 $rawTotal개예요. 나머지 ${rawTotal - total}개 카드와 '
                  '자동속독·셀프테스트를 무제한으로 쓰려면 프리미엄으로 업그레이드하세요.\n\n'
                  'CBT 문제은행의 약 50%는 기존 기출 재출제 — 이 카드들이 합격 최단 경로입니다.'
              : '$total개 반복문제 카드를 모두 확인했습니다.\n'
                  'CBT 문제은행의 약 50%는 기존 기출 재출제입니다. '
                  '이 카드들을 3회독 하면 실전에서 절반은 자동으로 맞힙니다.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('종료'),
          ),
          if (isFree)
            FilledButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                openPremiumPaywall(
                  context,
                  hook: '반복문제 $rawTotal개 전체 + 자동속독/셀프테스트 무제한',
                );
              },
              icon: const Icon(Icons.workspace_premium, size: 18),
              label: const Text('전체 카드 열기'),
            )
          else
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                setState(() {
                  _idx = 0;
                  _showExplain = false;
                  _revealed = false;
                });
              },
              child: const Text('처음부터 복습'),
            ),
        ],
      ),
    );
  }
}
