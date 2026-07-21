import 'package:flutter/material.dart';
import '../../services/cerebras_service.dart';
import '../../services/study_data.dart';
import '../../widgets/tutor_avatar.dart';
import 'lesson_screen.dart';
import '../../widgets/persistent_nav.dart';

/// 통합 검색 결과 항목
class _SearchHit {
  final String kind; // 강의 / 암기법 / 슬라이드 / 실기
  final String title;
  final String snippet;
  final String subject;
  final Object payload;
  final int score;

  _SearchHit({
    required this.kind,
    required this.title,
    required this.snippet,
    required this.subject,
    required this.payload,
    required this.score,
  });
}

/// 이론 검색 화면 — 로컬 통합 검색 + Cerebras AI 검증·답변
class TheorySearchScreen extends StatefulWidget {
  const TheorySearchScreen({super.key});

  @override
  State<TheorySearchScreen> createState() => _TheorySearchScreenState();
}

class _TheorySearchScreenState extends State<TheorySearchScreen> {
  final _controller = TextEditingController();
  List<_SearchHit> _hits = [];
  bool _searched = false;
  bool _aiLoading = false;
  String? _aiAnswer;
  String? _aiError;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<String> _keywords(String q) => q
      .split(RegExp(r'[\s,·]+'))
      .map((s) => s.trim())
      .where((s) => s.length >= 2)
      .toList();

  int _scoreText(String text, List<String> kws, {int weight = 1}) {
    var s = 0;
    for (final k in kws) {
      if (text.contains(k)) s += weight;
    }
    return s;
  }

  String _makeSnippet(String body, List<String> kws) {
    for (final k in kws) {
      final idx = body.indexOf(k);
      if (idx >= 0) {
        final start = (idx - 30).clamp(0, body.length);
        final end = (idx + 80).clamp(0, body.length);
        return '…${body.substring(start, end).replaceAll('\n', ' ')}…';
      }
    }
    return body.length > 100
        ? '${body.substring(0, 100).replaceAll('\n', ' ')}…'
        : body.replaceAll('\n', ' ');
  }

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    final kws = _keywords(q);
    if (kws.isEmpty) kws.add(q);

    final data = StudyData.instance;
    final lessons = await data.loadLessons();
    final mnemonics = await data.loadMnemonics();
    final decks = await data.loadSlideDecks();
    final silgi = await data.loadSilgi();
    final formulaGuide = await data.loadFormulaGuide();

    final hits = <_SearchHit>[];

    if (formulaGuide != null) {
      for (final f in formulaGuide.formulas) {
        final s =
            _scoreText(f.name, kws, weight: 6) +
            _scoreText(f.expr, kws, weight: 3) +
            _scoreText(f.understand, kws, weight: 2) +
            _scoreText(f.mnemonic, kws, weight: 2) +
            _scoreText(
              f.symbols.map((x) => x.meaning).join(' '),
              kws,
              weight: 1,
            );
        if (s > 0) {
          hits.add(
            _SearchHit(
              kind: '공식',
              title: '${f.name} — ${f.expr}',
              snippet: _makeSnippet('${f.understand} ${f.mnemonic}', kws),
              subject: f.subject,
              payload: f,
              score: s,
            ),
          );
        }
      }
      for (final b in formulaGuide.basics) {
        final s =
            _scoreText(b.term, kws, weight: 6) +
            _scoreText(b.easy, kws, weight: 2) +
            _scoreText(b.detail, kws, weight: 1);
        if (s > 0) {
          hits.add(
            _SearchHit(
              kind: '기초',
              title: b.term,
              snippet: _makeSnippet('${b.easy} ${b.detail}', kws),
              subject: b.category,
              payload: b,
              score: s,
            ),
          );
        }
      }
    }

    for (final l in lessons) {
      var s =
          _scoreText(l.topic, kws, weight: 6) +
          _scoreText(l.intro, kws, weight: 2) +
          _scoreText(
            l.sections.map((e) => '${e.title} ${e.body}').join(' '),
            kws,
            weight: 1,
          ) +
          _scoreText(
            l.formulas.map((f) => '${f.name} ${f.expr}').join(' '),
            kws,
            weight: 2,
          );
      if (s > 0) {
        hits.add(
          _SearchHit(
            kind: '강의',
            title: '${l.topic} (${l.subject})',
            snippet: _makeSnippet(
              '${l.intro} ${l.sections.map((e) => e.body).join(' ')}',
              kws,
            ),
            subject: l.subject,
            payload: l,
            score: s,
          ),
        );
      }
    }

    for (final m in mnemonics) {
      final s =
          _scoreText(m.title, kws, weight: 5) +
          _scoreText(m.body, kws, weight: 2) +
          _scoreText(m.tip, kws, weight: 1);
      if (s > 0) {
        hits.add(
          _SearchHit(
            kind: '암기법',
            title: m.title,
            snippet: _makeSnippet('${m.body} ${m.tip}', kws),
            subject: m.subject,
            payload: m,
            score: s,
          ),
        );
      }
    }

    for (final d in decks) {
      for (final c in d.cards) {
        if (c.type == 'mission' || c.type == 'recap') continue;
        final s =
            _scoreText(c.title, kws, weight: 4) +
            _scoreText(c.body, kws, weight: 1);
        if (s > 0) {
          hits.add(
            _SearchHit(
              kind: '슬라이드',
              title: '${c.title} (Day ${d.day})',
              snippet: _makeSnippet(c.body, kws),
              subject: d.subject,
              payload: c,
              score: s,
            ),
          );
        }
      }
    }

    if (silgi != null) {
      for (final it in silgi.items) {
        final s =
            _scoreText(it.title, kws, weight: 5) +
            _scoreText(it.question, kws, weight: 2) +
            _scoreText(it.answer, kws, weight: 2) +
            _scoreText(it.memo, kws, weight: 1);
        if (s > 0) {
          hits.add(
            _SearchHit(
              kind: '실기',
              title: it.title,
              snippet: _makeSnippet('${it.question} ${it.answer}', kws),
              subject: it.linkSubject,
              payload: it,
              score: s,
            ),
          );
        }
      }
    }

    hits.sort((a, b) => b.score.compareTo(a.score));
    setState(() {
      _hits = hits.take(30).toList();
      _searched = true;
      _aiAnswer = null;
      _aiError = null;
    });
  }

  Future<void> _askAi() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    // 🧪 테스트 기간 종료 시 AI 검증 차단 (로컬 검색은 계속 사용 가능)
    if (!CerebrasService.isTestPeriod) {
      setState(() {
        _aiError = 'AI 튜터 테스트 기간이 종료되었어요. 로컬 자료 검색 결과를 이용해주세요.';
      });
      return;
    }
    final hasKey = await CerebrasService.instance.hasKey();
    if (!mounted) return;
    if (!hasKey) {
      setState(() {
        _aiError = 'AI 검증을 사용할 수 없습니다. 로컬 자료 검색 결과를 이용해주세요.';
      });
      return;
    }
    setState(() {
      _aiLoading = true;
      _aiAnswer = null;
      _aiError = null;
    });
    try {
      // 로컬 검색 상위 결과를 컨텍스트로 전달 → 검증 + 보강
      final ctx = _hits
          .take(3)
          .map((h) => '[${h.kind}] ${h.title}: ${h.snippet}')
          .join('\n');
      final ans = await CerebrasService.instance.askTheory(
        '${StudyData.instance.track.name} 시험 관련 질문: $q',
        context: ctx.isEmpty ? null : ctx,
      );
      if (mounted) {
        setState(() {
          _aiAnswer = ans;
          _aiLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiError = e.toString();
          _aiLoading = false;
        });
      }
    }
  }

  Color _kindColor(String kind) {
    switch (kind) {
      case '강의':
        return Colors.indigo;
      case '암기법':
        return Colors.orange.shade800;
      case '슬라이드':
        return Colors.teal;
      case '실기':
        return Colors.purple;
      case '공식':
        return Colors.green.shade700;
      case '기초':
        return Colors.blue.shade700;
      default:
        return Colors.blueGrey;
    }
  }

  void _openHit(_SearchHit h) {
    final p = h.payload;
    if (p is Lesson) {
      pushWithNav(context, LessonViewerScreen(lesson: p), currentSection: 1);
    } else if (p is Mnemonic) {
      _showDetailSheet(h.title, '${p.body}\n\n💡 ${p.tip}');
    } else if (p is SlideCard) {
      _showDetailSheet(h.title, p.body);
    } else if (p is SilgiItem) {
      _showDetailSheet(
        h.title,
        'Q. ${p.question}\n\nA. ${p.answer}\n\n💡 ${p.memo}',
      );
    } else if (p is FormulaGuide) {
      _showDetailSheet(
        '${p.name}\n${p.expr}',
        '🗣 읽기: ${p.read}\n\n'
            '🔤 기호:\n${p.symbols.map((s) => '• ${s.sym} = ${s.meaning}').join('\n')}\n\n'
            '💡 이해: ${p.understand}\n\n'
            '🧠 암기법: ${p.mnemonic}\n\n'
            '✏️ 예제: ${p.example}',
      );
    } else if (p is BasicTerm) {
      _showDetailSheet(p.term, '${p.easy}\n\n${p.detail}');
    }
  }

  void _showDetailSheet(String title, String body) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (ctx, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            SelectableText(
              body,
              style: const TextStyle(fontSize: 14.5, height: 1.6),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('이론 검색 · AI 검증'), actions: const []),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  hintText: '예: 변압기 효율, 페란티 현상, 단락전류…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded),
                    tooltip: '검색',
                    onPressed: _search,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  isDense: true,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _search,
                      icon: const Icon(Icons.library_books_rounded, size: 18),
                      label: const Text(
                        '자료 검색',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _aiLoading ? null : _askAi,
                      icon: _aiLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: Text(
                        _aiLoading ? 'AI 분석중…' : 'AI 검증·답변',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                children: [
                  if (!_searched && _aiAnswer == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Column(
                        children: [
                          const TutorAvatar(
                            mood: TutorMood.thinking,
                            size: 110,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '궁금한 이론·공식·암기법을 검색해보세요!\n'
                            '강의노트·암기법·슬라이드·실기자료를 한 번에 찾고,\n'
                            '볼트쌤이 내용을 검증·보강해드려요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              height: 1.6,
                              color: cs.onSurface.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_aiError != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _aiError!,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_aiAnswer != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            cs.primaryContainer.withValues(alpha: 0.6),
                            cs.tertiaryContainer.withValues(alpha: 0.4),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: cs.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const TutorAvatar(
                                mood: TutorMood.happy,
                                size: 44,
                                headOnly: true,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '볼트쌤 검증 답변',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: cs.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SelectableText(
                            _aiAnswer!,
                            style: const TextStyle(fontSize: 14, height: 1.65),
                          ),
                        ],
                      ),
                    ),
                  if (_searched && _hits.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Column(
                        children: [
                          const TutorAvatar(mood: TutorMood.wrong, size: 90),
                          const SizedBox(height: 8),
                          Text(
                            '로컬 자료에서 결과를 찾지 못했어요.\n검색어를 짧게 바꾸거나 API 키 설정 후 AI에 질문해보세요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: cs.onSurface.withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ..._hits.map((h) {
                    final kc = _kindColor(h.kind);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: kc.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            h.kind,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: kc,
                            ),
                          ),
                        ),
                        title: Text(
                          h.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          h.snippet,
                          style: const TextStyle(fontSize: 12, height: 1.4),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _openHit(h),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
