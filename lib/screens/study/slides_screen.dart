import 'package:flutter/material.dart';
import '../../services/study_data.dart';
import '../../widgets/tutor_avatar.dart';

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
    StudyData.instance.loadSlideDecks().then((v) {
      if (mounted) setState(() => _decks = v);
    });
    StudyData.instance.loadPlan().then((v) {
      if (mounted) setState(() => _plan = v);
    });
  }

  Color _phaseColor(String phase) {
    if (phase.contains('모의고사')) return Colors.deepOrange;
    if (phase.contains('총정리')) return Colors.purple;
    return Colors.indigo;
  }

  @override
  Widget build(BuildContext context) {
    final decks = _decks;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('30일 슬라이드 이론')),
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
                TutorBanner(
                  mood: TutorMood.teaching,
                  message: _plan?.description.isNotEmpty == true
                      ? _plan!.description
                      : '하루 한 덱! 비유→핵심→공식→암기법→함정 순서로 스와이프하면 30일 만에 이론이 끝나요.',
                ),
                const SizedBox(height: 8),
                if (_plan != null && _plan!.strategy.isNotEmpty)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text('합격 전략 5계명',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: cs.primary)),
                    children: _plan!.strategy
                        .map((s) => Padding(
                              padding: const EdgeInsets.only(
                                  left: 4, right: 4, bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('⚡ ', style: TextStyle(fontSize: 13)),
                                  Expanded(
                                      child: Text(s,
                                          style: const TextStyle(
                                              fontSize: 13, height: 1.4))),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                const SizedBox(height: 8),
                ...List.generate(decks.length, (i) {
                  final d = decks[i];
                  final pc = _phaseColor(d.phase);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [pc, pc.withValues(alpha: 0.65)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text('D${d.day}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14)),
                      ),
                      title: Text(d.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text(
                        '${d.phase} · ${d.cards.length}장 카드',
                        style: TextStyle(fontSize: 12, color: pc),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => SlideDeckScreen(deck: d)),
                      ),
                    ),
                  );
                }),
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
  'concept': _CardStyle(Color(0xFF00897B), Icons.lightbulb_rounded, '비유로 이해'),
  'core': _CardStyle(Color(0xFF3949AB), Icons.menu_book_rounded, '핵심 이론'),
  'formula': _CardStyle(Color(0xFF6A1B9A), Icons.functions_rounded, '공식'),
  'mnemonic': _CardStyle(Color(0xFFE65100), Icons.psychology_rounded, '암기법'),
  'trap': _CardStyle(Color(0xFFC62828), Icons.warning_amber_rounded, '함정 주의'),
  'strategy': _CardStyle(Color(0xFF2E7D32), Icons.military_tech_rounded, '출제 전략'),
  'recap': _CardStyle(Color(0xFF00695C), Icons.check_circle_rounded, '오늘 정리'),
};

/// 슬라이드 카드 뷰어 — PageView 스와이프
class SlideDeckScreen extends StatefulWidget {
  final SlideDeck deck;
  const SlideDeckScreen({super.key, required this.deck});

  @override
  State<SlideDeckScreen> createState() => _SlideDeckScreenState();
}

class _SlideDeckScreenState extends State<SlideDeckScreen> {
  late final PageController _pc;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _pc = PageController();
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

  @override
  Widget build(BuildContext context) {
    final cards = widget.deck.cards;
    final total = cards.length;
    final cur = cards[_page.clamp(0, total - 1)];
    final style = _cardStyles[cur.type] ?? _cardStyles['core']!;

    return Scaffold(
      appBar: AppBar(
        title: Text('Day ${widget.deck.day} · ${widget.deck.subject}',
            style: const TextStyle(fontSize: 16)),
      ),
      body: SafeArea(
        child: Column(
          children: [
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
                  Text('${_page + 1} / $total',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: style.color)),
                ],
              ),
            ),
            // 카드 페이지
            Expanded(
              child: PageView.builder(
                controller: _pc,
                itemCount: total,
                onPageChanged: (p) => setState(() => _page = p),
                itemBuilder: (context, i) {
                  final c = cards[i];
                  final s = _cardStyles[c.type] ?? _cardStyles['core']!;
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.75)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: _page > 0
                        ? () => _pc.previousPage(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOut)
                        : null,
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    onPressed: _page < total - 1
                        ? () => _pc.nextPage(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOut)
                        : () => Navigator.pop(context),
                    icon: Icon(_page < total - 1
                        ? Icons.arrow_forward_rounded
                        : Icons.done_all_rounded),
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
        return '비유로 큰 그림 먼저! 이해가 암기를 이깁니다.';
      case 'core':
        return '핵심만 압축했어요. 소리내어 읽으면 2배 기억!';
      case 'formula':
        return '공식은 손으로 3번 써보세요. 몸이 기억해요.';
      case 'mnemonic':
        return '두문자 암기법! 시험장에서 바로 튀어나옵니다.';
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

  Widget _slideCard(BuildContext context, SlideCard c, _CardStyle s) {
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
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Row(
              children: [
                Icon(s.icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(s.label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13)),
                const Spacer(),
                if (c.topic.isNotEmpty)
                  Flexible(
                    child: Text(c.topic,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11.5),
                        overflow: TextOverflow.ellipsis),
                  ),
              ],
            ),
          ),
          // 본문
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.title,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: s.color,
                          height: 1.3)),
                  const SizedBox(height: 12),
                  SelectableText(
                    c.body,
                    style: const TextStyle(fontSize: 14.5, height: 1.65),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
