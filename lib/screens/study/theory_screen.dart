import 'package:flutter/material.dart';
import '../../services/study_data.dart';
import '../../services/slide_progress.dart';
import '../../widgets/help_dot.dart';
import 'quiz_play_screen.dart';
import 'slides_screen.dart';
import '../../widgets/persistent_nav.dart';

/// 핵심이론서: 과목 선택 → 슬라이드(PPT) 형태로 버튼 전환하며 학습
///
/// 과목당 최대 30장 안팎의 카드를 버튼으로 한 장씩 넘겨보는 컴팩트한
/// 슬라이드 구조. 내부적으로 30일 이론 카드(theory_slides.json)를
/// 과목 단위로 병합해 [SlideDeckScreen] UI(버튼 네비게이션·왕초보 모드·
/// 암기법 노트·유튜브 연동)를 그대로 재사용한다.
class TheoryScreen extends StatefulWidget {
  const TheoryScreen({super.key});

  @override
  State<TheoryScreen> createState() => _TheoryScreenState();
}

class _TheoryScreenState extends State<TheoryScreen> {
  final Map<String, int> _cardCounts = {};
  bool _loading = true;

  String get _progressPrefix => 'theory_${StudyData.instance.track.id}';

  @override
  void initState() {
    super.initState();
    SlideProgress.instance.ensureReady().then((_) {
      if (mounted) setState(() {});
    });
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    for (final s in kSubjects) {
      final deck = await StudyData.instance.loadSubjectTheoryDeck(s);
      _cardCounts[s] = deck?.cards.length ?? 0;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openSubject(String subject) async {
    final deck = await StudyData.instance.loadSubjectTheoryDeck(subject);
    if (!mounted) return;
    if (deck == null || deck.cards.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$subject 이론 슬라이드가 아직 준비되지 않았어요.')),
      );
      return;
    }
    await pushWithNav(
      context,
      SlideDeckScreen(deck: deck, progressPrefix: _progressPrefix),
      currentSection: 1,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('핵심이론서 (빈출도 반영)'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: HelpDot(
              size: 22,
              title: '핵심이론서 안내',
              body:
                  '과목을 고르면 슬라이드(PPT) 형태로 한 장씩 버튼을 눌러 넘겨보는 이론 카드가 열려요.\n\n'
                  '👉 화면 아래 화살표 버튼으로 이전/다음 장을 넘기고, 스와이프도 가능해요.\n\n'
                  '🐣📘⚡ 상단 난이도 버튼(왕초보/표준/속성)으로 설명 깊이를 바꿀 수 있어요.\n\n'
                  '🧠 각 장마다 공식·암기법·시험 포인트가 색깔별 카드로 구분되어 있어요.\n\n'
                  '💡 다 본 뒤 "이론을 문제로 확인하기"로 바로 기초 문제를 풀어보세요!',
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.slideshow_rounded, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${StudyData.instance.track.bankLabel} ${StudyData.instance.track.questionCountLabel}문제 빈출 분석을 반영한 과목별 슬라이드 이론서입니다. '
                    '버튼으로 한 장씩 넘기며 개념→공식→암기법→시험포인트 순서로 학습하세요.',
                    style: const TextStyle(fontSize: 12.5, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < kSubjects.length; i++)
            _subjectCard(context, i, kSubjects[i]),
        ],
      ),
    );
  }

  Widget _subjectCard(BuildContext context, int i, String subject) {
    final total = _cardCounts[subject] ?? 0;
    final seen = SlideProgress.instance.seen(
      kSubjects.indexOf(subject) + 1,
      prefix: _progressPrefix,
    );
    final done = total > 0 && seen >= total;
    final pct = total == 0 ? 0.0 : (seen / total).clamp(0.0, 1.0);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: SizedBox(
          width: 46,
          height: 46,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  value: total == 0 ? null : pct,
                  strokeWidth: 3.2,
                  color: done ? Colors.green : Colors.indigo,
                  backgroundColor: Colors.indigo.withValues(alpha: 0.15),
                ),
              ),
              done
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.green,
                      size: 20,
                    )
                  : Text(
                      '${i + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.indigo,
                      ),
                    ),
            ],
          ),
        ),
        title: Text(
          subject,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        subtitle: Text(
          _loading
              ? '슬라이드 준비 중…'
              : total == 0
              ? '슬라이드 준비 중 (곧 업데이트)'
              : done
              ? '✅ 완료 · $total장 · 공식·암기법·시험포인트 포함'
              : seen > 0
              ? '$seen/$total장 진행 중 · 버튼으로 이어보기'
              : '$total장 슬라이드 · 빈출 토픽 순위·공식·암기법 포함',
          style: TextStyle(
            fontSize: 12,
            color: done ? Colors.green : Colors.indigo,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: total == 0 ? null : () => _openSubject(subject),
      ),
    );
  }
}

/// (레거시) 마크다운 이론 뷰어 — 슬라이드 데이터가 없는 예외 상황을 위한
/// 폴백 뷰. 현재 UI에서는 직접 노출되지 않지만, 다른 화면에서 참조할 수
/// 있도록 유지한다.
class TheoryMarkdownFallback extends StatefulWidget {
  final String subject;
  const TheoryMarkdownFallback({super.key, required this.subject});

  @override
  State<TheoryMarkdownFallback> createState() => _TheoryMarkdownFallbackState();
}

class _TheoryMarkdownFallbackState extends State<TheoryMarkdownFallback> {
  String? _content;
  bool _startingQuiz = false;

  @override
  void initState() {
    super.initState();
    StudyData.instance.loadTheory(widget.subject).then((value) {
      if (mounted) setState(() => _content = value);
    });
  }

  Future<void> _startBasicQuiz() async {
    if (_startingQuiz) return;
    setState(() => _startingQuiz = true);
    try {
      final questions = await StudyData.instance.questionsByDifficulty(
        widget.subject,
        easyFirst: true,
      );
      if (!mounted) return;
      if (questions.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('연결된 기초 문제가 없습니다.')));
        return;
      }
      await pushWithNav(
        context,
        QuizPlayScreen(
          title: '${widget.subject} 기초 확인 10문제',
          questions: questions.take(10).toList(),
          examMode: false,
        ),
        currentSection: 1,
      );
    } finally {
      if (mounted) setState(() => _startingQuiz = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.subject)),
      body: _content == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                Text(_content!, style: const TextStyle(height: 1.6)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _startingQuiz ? null : _startBasicQuiz,
                  icon: _startingQuiz
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.quiz_outlined),
                  label: Text(_startingQuiz ? '기초 문제 준비 중…' : '이론을 문제로 확인하기'),
                ),
              ],
            ),
    );
  }
}
