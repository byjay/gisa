import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/study_data.dart';
import '../../services/link_launcher.dart';
import '../../services/slide_progress.dart';
import '../../widgets/tutor_avatar.dart';
import '../../widgets/tutor_coach.dart';
import '../../widgets/rich_slide_body.dart';
import '../../widgets/teacher_recipe_box.dart';
import '../../widgets/help_dot.dart';
import 'quiz_play_screen.dart';
import '../../widgets/persistent_nav.dart';

/// 30일 슬라이드 학습 — 덱 목록 화면
class SlidesHomeScreen extends StatefulWidget {
  const SlidesHomeScreen({super.key});

  @override
  State<SlidesHomeScreen> createState() => _SlidesHomeScreenState();
}

class _SlidesHomeScreenState extends State<SlidesHomeScreen> {
  List<SlideDeck>? _decks;
  StudyPlan? _plan;

  @override
  void initState() {
    super.initState();
    SlideProgress.instance.ensureReady().then((_) {
      if (mounted) setState(() {});
    });
    StudyData.instance.loadSlideDecks().then((v) {
      if (mounted) setState(() => _decks = v);
    });
    StudyData.instance.loadPlan().then((v) {
      if (mounted) setState(() => _plan = v);
    });
  }

  void _openDeck(SlideDeck d) {
    pushWithNav(context, SlideDeckScreen(deck: d), currentSection: 1).then((_) {
      if (mounted) setState(() {});
    });
  }

  Color _phaseColor(String phase) {
    if (phase.contains('모의고사')) return Colors.deepOrange;
    if (phase.contains('총정리')) return Colors.purple;
    return Colors.indigo;
  }

  /// 전체 진도 요약 바
  Widget _overallProgress(List<SlideDeck> decks) {
    int seenCards = 0, totalCards = 0, doneDecks = 0;
    for (final d in decks) {
      final s = SlideProgress.instance.seen(d.day).clamp(0, d.cards.length);
      seenCards += s;
      totalCards += d.cards.length;
      if (d.cards.isNotEmpty && s >= d.cards.length) doneDecks++;
    }
    final pct = totalCards == 0 ? 0.0 : seenCards / totalCards;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.trending_up_rounded,
                  color: Colors.indigo,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  '이론 정복 진도',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                const Spacer(),
                Text(
                  '$doneDecks/${decks.length}일 완료 · ${(pct * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 10,
                color: Colors.indigo,
                backgroundColor: Colors.indigo.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 이어서 학습 카드
  Widget _continueCard(List<SlideDeck> decks) {
    // 마지막 본 덱 또는 첫 미완료 덱
    SlideDeck? target;
    final last = SlideProgress.instance.lastDay;
    if (last != null) {
      for (final d in decks) {
        if (d.day == last &&
            SlideProgress.instance.seen(d.day) < d.cards.length) {
          target = d;
          break;
        }
      }
    }
    target ??= decks
        .where((d) => SlideProgress.instance.seen(d.day) < d.cards.length)
        .firstOrNull;
    if (target == null) return const SizedBox.shrink();
    final t = target;
    final seen = SlideProgress.instance.seen(t.day);
    return Card(
      color: Colors.indigo.withValues(alpha: 0.06),
      child: ListTile(
        leading: const Icon(
          Icons.play_circle_fill,
          color: Colors.indigo,
          size: 36,
        ),
        title: Text(
          seen > 0 ? '이어서 학습: Day ${t.day}' : '오늘의 학습: Day ${t.day}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        subtitle: Text(
          seen > 0 ? '${t.title} · ${seen + 1}장부터 계속' : t.title,
          style: const TextStyle(fontSize: 12.5),
        ),
        trailing: const Icon(Icons.arrow_forward_rounded, color: Colors.indigo),
        onTap: () => _openDeck(t),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final decks = _decks;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('30일 슬라이드 이론'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: HelpDot(
              size: 22,
              title: '30일 슬라이드 이론 안내',
              body: '하루 한 덱씩 스와이프하면 30일 만에 이론을 다 끝낼 수 있는 카드 학습이에요.\n\n'
                  '📅 덱 순서 — 학습 계획(플랜)에 맞춰 순서대로 덱을 진행하면 가장 효율적이에요.\n\n'
                  '🌙 왕초보 모드 — 덱 안 슬라이드마다 핵심만 뽑아 쉬운 말로 풀어줘요.\n\n'
                  '💬 볼트쌤 코치 — 각 덱을 열 때마다 그 덱의 핵심 요점을 먼저 짚어줘요.\n\n'
                  '💡 완료한 덱은 체크 표시되어 어디까지 진행했는지 한눈에 볼 수 있어요!',
            ),
          ),
        ],
      ),
      body: decks == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width > 900
                    ? (MediaQuery.of(context).size.width - 800) / 2
                    : 16,
                vertical: 16,
              ),
              children: [
                DynamicTutorBanner(
                  situation: CoachSituation.theory,
                  overrideMessage: _plan?.description.isNotEmpty == true
                      ? _plan!.description
                      : null,
                ),
                const SizedBox(height: 8),
                if (_plan != null && _plan!.strategy.isNotEmpty)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      '합격 전략 5계명',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: cs.primary,
                      ),
                    ),
                    children: _plan!.strategy
                        .map(
                          (s) => Padding(
                            padding: const EdgeInsets.only(
                              left: 4,
                              right: 4,
                              bottom: 8,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '⚡ ',
                                  style: TextStyle(fontSize: 13),
                                ),
                                Expanded(
                                  child: Text(
                                    s,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                const SizedBox(height: 8),
                _overallProgress(decks),
                const SizedBox(height: 8),
                _continueCard(decks),
                const SizedBox(height: 4),
                ...List.generate(decks.length, (i) {
                  final d = decks[i];
                  final pc = _phaseColor(d.phase);
                  final seen = SlideProgress.instance.seen(d.day);
                  final total = d.cards.length;
                  final done = seen >= total && total > 0;
                  final pct = total == 0 ? 0.0 : (seen / total).clamp(0.0, 1.0);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: SizedBox(
                        width: 48,
                        height: 48,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 46,
                              height: 46,
                              child: CircularProgressIndicator(
                                value: pct,
                                strokeWidth: 3.5,
                                color: done ? Colors.green : pc,
                                backgroundColor: pc.withValues(alpha: 0.15),
                              ),
                            ),
                            done
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Colors.green,
                                    size: 22,
                                  )
                                : Text(
                                    'D${d.day}',
                                    style: TextStyle(
                                      color: pc,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                          ],
                        ),
                      ),
                      title: Text(
                        d.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        done
                            ? '✅ 완료 · ${d.cards.length}장'
                            : seen > 0
                            ? '${d.phase} · $seen/$total장 진행 중'
                            : '${d.phase} · ${d.cards.length}장 카드',
                        style: TextStyle(
                          fontSize: 12,
                          color: done ? Colors.green : pc,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openDeck(d),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}

/// 과목별 핵심요약 — 5과목 요약 덱 목록 화면
/// (빈도순·필수암기 중심 요약. 30일 이론과 진도가 분리됨)
class SubjectSummaryHomeScreen extends StatefulWidget {
  const SubjectSummaryHomeScreen({super.key});

  @override
  State<SubjectSummaryHomeScreen> createState() =>
      _SubjectSummaryHomeScreenState();
}

class _SubjectSummaryHomeScreenState extends State<SubjectSummaryHomeScreen> {
  static const String _prefix = 'summary';
  List<SlideDeck>? _decks;

  @override
  void initState() {
    super.initState();
    SlideProgress.instance.ensureReady().then((_) {
      if (mounted) setState(() {});
    });
    StudyData.instance.loadSubjectSummaries().then((v) {
      if (mounted) setState(() => _decks = v);
    });
  }

  void _openDeck(SlideDeck d) {
    pushWithNav(
      context,
      SlideDeckScreen(deck: d, progressPrefix: _prefix),
      currentSection: 1,
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  Widget _overall(List<SlideDeck> decks) {
    int seen = 0, total = 0, doneDecks = 0;
    for (final d in decks) {
      final s = SlideProgress.instance
          .seen(d.day, prefix: _prefix)
          .clamp(0, d.cards.length);
      seen += s;
      total += d.cards.length;
      if (d.cards.isNotEmpty && s >= d.cards.length) doneDecks++;
    }
    final pct = total == 0 ? 0.0 : seen / total;
    return Card(
      color: Colors.deepPurple.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.summarize_rounded,
                  color: Colors.deepPurple,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  '요약 정복 진도',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                const Spacer(),
                Text(
                  '$doneDecks/${decks.length}과목 · ${(pct * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Colors.deepPurple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 10,
                color: Colors.deepPurple,
                backgroundColor: Colors.deepPurple.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final decks = _decks;
    return Scaffold(
      appBar: AppBar(
        title: const Text('과목별 핵심요약'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: HelpDot(
              size: 22,
              title: '과목별 핵심요약 안내',
              body: '시험 직전 총정리용으로, 과목별 핵심만 압축한 요약 카드예요.\n\n'
                  '📚 과목 목록 — 각 과목의 핵심 개념·공식·주의사항만 뽑아 짧게 정리했어요.\n\n'
                  '⏱️ 짧은 시간 안에 훑어보기 좋아서 시험 며칠 전이나 시험 당일 아침에 보면 효과적이에요.\n\n'
                  '💡 이미 이론을 한 번 배운 뒤 복습용으로 사용하면 가장 효과가 좋아요!',
            ),
          ),
        ],
      ),
      body: decks == null
          ? const Center(child: CircularProgressIndicator())
          : decks.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  '이 트랙의 과목별 핵심요약은 아직 준비 중이에요.\n30일 슬라이드 이론으로 학습을 이어가 보세요!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, height: 1.5),
                ),
              ),
            )
          : ListView(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width > 900
                    ? (MediaQuery.of(context).size.width - 800) / 2
                    : 16,
                vertical: 16,
              ),
              children: [
                const DynamicTutorBanner(
                  situation: CoachSituation.dDayNear,
                ),
                const SizedBox(height: 8),
                _overall(decks),
                const SizedBox(height: 4),
                ...List.generate(decks.length, (i) {
                  final d = decks[i];
                  final seen = SlideProgress.instance.seen(
                    d.day,
                    prefix: _prefix,
                  );
                  final total = d.cards.length;
                  final done = seen >= total && total > 0;
                  final pct = total == 0
                      ? 0.0
                      : (seen / total).clamp(0.0, 1.0);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: SizedBox(
                        width: 48,
                        height: 48,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 46,
                              height: 46,
                              child: CircularProgressIndicator(
                                value: pct,
                                strokeWidth: 3.5,
                                color: done
                                    ? Colors.green
                                    : Colors.deepPurple,
                                backgroundColor: Colors.deepPurple.withValues(
                                  alpha: 0.15,
                                ),
                              ),
                            ),
                            done
                                ? const Icon(
                                    Icons.check_rounded,
                                    color: Colors.green,
                                    size: 22,
                                  )
                                : const Icon(
                                    Icons.summarize_rounded,
                                    color: Colors.deepPurple,
                                    size: 20,
                                  ),
                          ],
                        ),
                      ),
                      title: Text(
                        d.subject,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        done
                            ? '✅ 완료 · ${d.cards.length}장'
                            : seen > 0
                            ? '$seen/$total장 진행 중'
                            : '${d.cards.length}장 요약 카드',
                        style: TextStyle(
                          fontSize: 12,
                          color: done ? Colors.green : Colors.deepPurple,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openDeck(d),
                    ),
                  );
                }),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}

/// 카드 타입별 스타일
class _CardStyle {
  final Color color;
  final IconData icon;
  final String label;
  const _CardStyle(this.color, this.icon, this.label);
}

const Map<String, _CardStyle> _cardStyles = {
  'mission': _CardStyle(Color(0xFF1565C0), Icons.flag_rounded, '오늘의 미션'),
  'concept': _CardStyle(Color(0xFF00897B), Icons.lightbulb_rounded, '개념 이해'),
  'core': _CardStyle(Color(0xFF3949AB), Icons.menu_book_rounded, '핵심 이론'),
  'formula': _CardStyle(Color(0xFF6A1B9A), Icons.functions_rounded, '공식'),
  'mnemonic': _CardStyle(Color(0xFFE65100), Icons.psychology_rounded, '암기법'),
  'trap': _CardStyle(Color(0xFFC62828), Icons.warning_amber_rounded, '함정 주의'),
  'strategy': _CardStyle(
    Color(0xFF2E7D32),
    Icons.military_tech_rounded,
    '출제 전략',
  ),
  'recap': _CardStyle(Color(0xFF00695C), Icons.check_circle_rounded, '오늘 정리'),
};

/// 유튜브 딥링크: "전기기사 <토픽>" 검색 — 단원별 강의가 매우 많음
String topicYoutubeUrl(String topic) {
  final q = Uri.encodeComponent(
    '${StudyData.instance.track.name} ${topic.replaceAll('·', ' ')}',
  );
  return 'https://www.youtube.com/results?search_query=$q';
}

/// 검증된 무료 전기기사 강의 채널 (직접 링크)
const List<(String, String)> kYoutubeChannels = [
  ('전기자격증의모든것 (전병칠)', 'https://www.youtube.com/@elec7'),
  ('전기뿌수기', 'https://www.youtube.com/@electric_crusher'),
  ('다산에듀', 'https://www.youtube.com/@dasan_edu'),
];

/// 슬라이드 카드 뷰어 — PageView 스와이프
class SlideDeckScreen extends StatefulWidget {
  final SlideDeck deck;

  /// 진도 저장 네임스페이스. 기본 30일 이론 덱은 빈 문자열,
  /// 과목별 핵심요약 등 별도 덱은 고유 접두사를 넘겨 진도 키 충돌을 방지.
  final String progressPrefix;
  const SlideDeckScreen({
    super.key,
    required this.deck,
    this.progressPrefix = '',
  });

  @override
  State<SlideDeckScreen> createState() => _SlideDeckScreenState();
}

/// 학습 난이도 모드
enum StudyLevel { baby, standard, fast }

class _SlideDeckScreenState extends State<SlideDeckScreen> {
  late final PageController _pc;
  int _page = 0;
  List<Mnemonic> _subjectMnemonics = [];
  StudyLevel _level = StudyLevel.standard;

  @override
  void initState() {
    super.initState();
    // 이어서 학습: 마지막 본 페이지부터
    final seen = SlideProgress.instance.seen(
      widget.deck.day,
      prefix: widget.progressPrefix,
    );
    final start = (seen > 0 && seen < widget.deck.cards.length) ? seen : 0;
    _page = start;
    _pc = PageController(initialPage: start);
    // 전역 난이도 복원
    switch (SlideProgress.instance.level) {
      case 'baby':
        _level = StudyLevel.baby;
      case 'fast':
        _level = StudyLevel.fast;
      default:
        _level = StudyLevel.standard;
    }
    SlideProgress.instance.markSeen(
      widget.deck.day,
      start,
      widget.deck.cards.length,
      prefix: widget.progressPrefix,
    );
    StudyData.instance.loadMnemonics().then((all) {
      if (!mounted) return;
      setState(() {
        _subjectMnemonics = all
            .where((m) => m.subject == widget.deck.subject || m.subject == '공통')
            .toList();
      });
    });
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  TutorMood _moodFor(String type) {
    switch (type) {
      case 'mission':
        return TutorMood.cheer;
      case 'concept':
        return TutorMood.teaching;
      case 'formula':
      case 'core':
        return TutorMood.thinking;
      case 'mnemonic':
        return TutorMood.happy;
      case 'trap':
        return TutorMood.wrong;
      case 'recap':
        return TutorMood.meditate;
      default:
        return TutorMood.idle;
    }
  }

  Future<void> _openUrl(String url) async {
    final ok = await openInYoutubeApp(url);
    if (!ok) {
      await Clipboard.setData(ClipboardData(text: url));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('링크를 클립보드에 복사했어요. 브라우저에 붙여넣기 하세요.')),
        );
      }
    }
  }

  /// 과목 암기법 노트 바텀시트 (mnemonics.json 연동)
  void _showMnemonicSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (ctx, sc) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.psychology_rounded,
                    color: Color(0xFFE65100),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${widget.deck.subject} 암기법 노트 (${_subjectMnemonics.length}개)',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: sc,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: _subjectMnemonics.length,
                itemBuilder: (ctx, i) {
                  final m = _subjectMnemonics[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: const Color(0xFFE65100).withValues(alpha: 0.05),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: Color(0xFFBF360C),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            m.body,
                            style: const TextStyle(fontSize: 13.5, height: 1.5),
                          ),
                          if (m.tip.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              '💡 ${m.tip}',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Colors.grey.shade700,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.deck.cards;
    final total = cards.length;
    final cur = cards[_page.clamp(0, total - 1)];
    final style = _cardStyles[cur.type] ?? _cardStyles['core']!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Day ${widget.deck.day} · ${widget.deck.subject}',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            tooltip: '이 과목 유튜브 강의 검색',
            icon: const Icon(Icons.ondemand_video_rounded, color: Colors.red),
            onPressed: () => _openUrl(topicYoutubeUrl(widget.deck.subject)),
          ),
          IconButton(
            tooltip: '과목 암기법 노트',
            icon: const Icon(
              Icons.psychology_rounded,
              color: Color(0xFFE65100),
            ),
            onPressed: _subjectMnemonics.isEmpty ? null : _showMnemonicSheet,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 난이도 선택
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<StudyLevel>(
                  style: SegmentedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  segments: const [
                    ButtonSegment(
                      value: StudyLevel.baby,
                      label: Text('🐣 왕초보'),
                      tooltip: '기초체력 0부터 시작 — 비유 + 오늘 딱 1개 미션',
                    ),
                    ButtonSegment(
                      value: StudyLevel.standard,
                      label: Text('📘 표준'),
                      tooltip: '정의→핵심 원리→시험 포인트 전체 학습',
                    ),
                    ButtonSegment(
                      value: StudyLevel.fast,
                      label: Text('⚡ 속성 즉답'),
                      tooltip: '숙달자용 — 패턴 보면 답 바로 나오게 체계 암기',
                    ),
                  ],
                  selected: {_level},
                  onSelectionChanged: (s) {
                    setState(() => _level = s.first);
                    SlideProgress.instance.setLevel(switch (s.first) {
                      StudyLevel.baby => 'baby',
                      StudyLevel.fast => 'fast',
                      StudyLevel.standard => 'standard',
                    });
                  },
                ),
              ),
            ),
            // 진행 바
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (_page + 1) / total,
                        minHeight: 8,
                        color: style.color,
                        backgroundColor: style.color.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${_page + 1} / $total',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: style.color,
                    ),
                  ),
                ],
              ),
            ),
            // 카드 페이지
            Expanded(
              child: PageView.builder(
                controller: _pc,
                itemCount: total,
                onPageChanged: (p) {
                  setState(() => _page = p);
                  SlideProgress.instance.markSeen(
                    widget.deck.day,
                    p,
                    total,
                    prefix: widget.progressPrefix,
                  );
                },
                itemBuilder: (context, i) {
                  final c = cards[i];
                  final s = _cardStyles[c.type] ?? _cardStyles['core']!;
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: _slideCard(context, c, s),
                  );
                },
              ),
            ),
            // 튜터 + 네비게이션
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  TutorAvatar(mood: _moodFor(cur.type), size: 56),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _tutorTip(cur.type),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.75),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: _page > 0
                        ? () => _pc.previousPage(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOut,
                          )
                        : null,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    onPressed: _page < total - 1
                        ? () => _pc.nextPage(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOut,
                          )
                        : () => Navigator.pop(context),
                    icon: Icon(
                      _page < total - 1
                          ? Icons.arrow_forward_rounded
                          : Icons.done_all_rounded,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _tutorTip(String type) {
    switch (type) {
      case 'mission':
        return '오늘 목표부터 확인! 스와이프로 넘겨보세요.';
      case 'concept':
        return '정의→핵심 원리→시험 포인트 순서로 읽으면 완벽 이해!';
      case 'core':
        return '핵심만 압축했어요. 소리내어 읽으면 2배 기억!';
      case 'formula':
        return '공식은 손으로 3번 써보세요. 몸이 기억해요.';
      case 'mnemonic':
        return '두문자 암기법! 상단 🧠 버튼에 과목 암기법이 더 있어요.';
      case 'trap':
        return '여기서 다 틀려요. 함정 포인트 꼭 체크!';
      case 'strategy':
        return '출제 패턴을 알면 반은 먹고 들어갑니다.';
      case 'recap':
        return '수고했어요! 내일 아침 5분 복습이 핵심.';
      default:
        return '한 장씩 차근차근!';
    }
  }

  /// 난이도별 본문 필터링 (■ 섹션 단위)
  String _bodyForLevel(SlideCard c) {
    if (c.type != 'concept') return c.body;
    final parts = c.body.split(RegExp(r'\n\n(?=■ )'));
    final intro = parts.isNotEmpty && !parts.first.startsWith('■')
        ? parts.first
        : '';
    String? sec(String key) {
      for (final p in parts) {
        if (p.startsWith('■') && p.contains(key)) return p;
      }
      return null;
    }

    switch (_level) {
      case StudyLevel.baby:
        final baby = sec('🐣');
        final def = sec('정의');
        return [
          if (intro.isNotEmpty) intro,
          if (baby != null) baby,
          if (def != null) def,
          '→ 이해되면 📘 표준 모드로 올려보세요!',
        ].join('\n\n');
      case StudyLevel.fast:
        final fast = sec('⚡');
        final point = sec('시험 포인트');
        return [
          if (fast != null) fast else c.body,
          if (point != null) point,
        ].join('\n\n');
      case StudyLevel.standard:
        // 표준: 🐣/⚡ 섹션 제외한 전체
        return parts
            .where((p) => !p.contains('🐣') && !p.contains('⚡ 속성'))
            .join('\n\n');
    }
  }

  /// 이 단원 기출문제 바로 풀기 (빈출 순 최대 15문제)
  Future<void> _openTopicQuiz(String topic) async {
    final qs = await StudyData.instance.questionsByTopic(topic);
    if (!mounted) return;
    if (qs.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('‘$topic’ 태그된 기출이 아직 없어요.')));
      return;
    }
    final take = qs.take(15).toList();
    pushWithNav(
      context,
      QuizPlayScreen(
        title: '$topic 기출 (빈출순)',
        questions: take,
        examMode: false,
      ),
      currentSection: 1,
    );
  }

  Widget _slideCard(BuildContext context, SlideCard c, _CardStyle s) {
    final showYoutube =
        c.topic.isNotEmpty && (c.type == 'concept' || c.type == 'core');
    final showMnemonicMore =
        c.type == 'mnemonic' && _subjectMnemonics.isNotEmpty;
    final showQuiz =
        c.topic.isNotEmpty &&
        c.topic != '전과목' &&
        (c.type == 'concept' ||
            c.type == 'core' ||
            c.type == 'formula' ||
            c.type == 'trap');
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            s.color.withValues(alpha: 0.08),
            s.color.withValues(alpha: 0.02),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: s.color.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: s.color.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: s.color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
            ),
            child: Row(
              children: [
                Icon(s.icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  s.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                if (c.topic.isNotEmpty)
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        c.topic,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // 본문 — 리치 렌더링
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: s.color,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  RichSlideBody(body: _bodyForLevel(c), accent: s.color),
                  // 🧑‍🏫 풀이 레시피 — 공식·풀이순서를 이론 옆에 나란히 (암기·이론 공존)
                  if (c.topic.isNotEmpty &&
                      c.topic != '전과목' &&
                      (c.type == 'formula' || c.type == 'core'))
                    TeacherRecipeBox(
                      topic: c.topic,
                      subject: widget.deck.subject,
                      initiallyExpanded: false,
                      showMnemonics: false,
                    ),
                  if (showQuiz) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: s.color,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: const Icon(Icons.quiz_rounded, size: 18),
                        label: Text(
                          '이 단원 기출 바로 풀기 (빈출순 15문제)',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: () => _openTopicQuiz(c.topic),
                      ),
                    ),
                  ],
                  if (showYoutube) ...[
                    const SizedBox(height: 12),
                    _youtubeRow(c.topic),
                  ],
                  if (showMnemonicMore) ...[
                    const SizedBox(height: 16),
                    _mnemonicMoreButton(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 단원별 유튜브 보강 링크 (검색 + 채널 직접링크)
  Widget _youtubeRow(String topic) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.ondemand_video_rounded, color: Colors.red, size: 18),
              SizedBox(width: 6),
              Text(
                '이 단원 유튜브로 보강하기',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ActionChip(
                avatar: const Icon(Icons.search, size: 16, color: Colors.red),
                label: Text(
                  '${StudyData.instance.track.shortName} ${topic.replaceAll('·', ' ')} 검색',
                  style: const TextStyle(fontSize: 12),
                ),
                onPressed: () => _openUrl(topicYoutubeUrl(topic)),
              ),
              ...kYoutubeChannels.map(
                (ch) => ActionChip(
                  avatar: const Icon(
                    Icons.play_circle_fill,
                    size: 16,
                    color: Colors.red,
                  ),
                  label: Text(ch.$1, style: const TextStyle(fontSize: 12)),
                  onPressed: () => _openUrl(ch.$2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mnemonicMoreButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFE65100),
          side: const BorderSide(color: Color(0xFFE65100)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        icon: const Icon(Icons.psychology_rounded),
        label: Text(
          '${widget.deck.subject} 암기법 ${_subjectMnemonics.length}개 전부 보기',
        ),
        onPressed: _showMnemonicSheet,
      ),
    );
  }
}
