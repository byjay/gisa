import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/app_provider.dart';
import '../../services/study_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/persistent_nav.dart';
import '../../widgets/tutor_coach.dart';
import 'theory_screen.dart';
import 'quiz_play_screen.dart';
import 'tutor_chat_screen.dart';
import 'flashcard_screen.dart';
import 'formula_guide_screen.dart';
import 'study_guide_screen.dart';

/// 🐣 왕초보 로드맵 — 아무 지식이 없는 사람이 0에서 합격까지 가는 단계별 가이드
/// "모든 공부를 처음 시작하는, 아무 지식이 없는 사람" 기준으로 설계.
class BeginnerRoadmapScreen extends StatefulWidget {
  const BeginnerRoadmapScreen({super.key});

  @override
  State<BeginnerRoadmapScreen> createState() => _BeginnerRoadmapScreenState();
}

class _BeginnerRoadmapScreenState extends State<BeginnerRoadmapScreen> {
  static const _prefsKey = 'beginner_roadmap_done_steps';
  Set<int> _done = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_prefsKey) ?? const [];
    if (mounted) {
      setState(() => _done = raw.map(int.parse).toSet());
    }
  }

  Future<void> _toggle(int step) async {
    setState(() {
      if (_done.contains(step)) {
        _done.remove(step);
      } else {
        _done.add(step);
      }
    });
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
        _prefsKey, _done.map((e) => e.toString()).toList());
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppProvider>();
    final track = StudyData.instance.track;
    final steps = _buildSteps(context, track.name, track.subjects);
    final progress = steps.isEmpty ? 0.0 : _done.length / steps.length;

    return Scaffold(
      appBar: AppBar(title: const Text('🐣 왕초보 로드맵')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _heroCard(context, track.name, progress),
          const SizedBox(height: 12),
          // 🎓 볼트쌀 로드맵 코치 — 진행도별 멘트
          TutorCoach(
            situation: progress >= 1.0
                ? CoachSituation.roadmapDone
                : (progress > 0
                    ? CoachSituation.roadmapProgress
                    : CoachSituation.roadmapStart),
            height: 104,
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < steps.length; i++) ...[
            _stepCard(context, i, steps[i]),
            const SizedBox(height: 12),
          ],
          _finalCheer(context),
        ],
      ),
    );
  }

  // ── 단계 데이터 ────────────────────────────────────────
  List<_RoadStep> _buildSteps(
      BuildContext context, String trackName, List<String> subjects) {
    final firstSubject = subjects.isNotEmpty ? subjects.first : '기초 과목';
    return [
      _RoadStep(
        emoji: '🌱',
        title: 'STEP 0 · 마음 준비 (1일)',
        why: '$trackName은(는) 비전공자도 합격하는 시험이에요. "나는 아무것도 모른다"는 지금이 가장 정상적인 출발점입니다.',
        todos: const [
          '시험이 객관식(CBT) 4지선다라는 것만 기억하기 — 100점이 아니라 평균 60점이면 합격',
          '하루 30분부터 시작 — 습관이 실력보다 먼저',
          '모르는 단어가 나와도 당황하지 않기 — 어차피 다 처음 봅니다',
        ],
        actions: [
          _StepAction('합격 공부법 읽기', Icons.emoji_events_rounded,
              () => pushWithNav(context, const StudyGuideScreen(), currentSection: 1)),
        ],
      ),
      _RoadStep(
        emoji: '📖',
        title: 'STEP 1 · 용어와 친해지기 (1주)',
        why: '전기 공부의 80%는 "단어 낯섦"입니다. 이론을 외우지 말고 그림책 보듯 훑어보세요. 2번째 볼 때부터 갑자기 쉬워집니다.',
        todos: [
          '기초 이론에서 $firstSubject 첫 단원만 가볍게 훑기 (외우기 금지!)',
          '모르는 단어는 볼트쌤에게 "초등학생도 알게 설명해줘"라고 묻기',
          '하루에 이론 1개 단원 = 충분히 훌륭한 진도',
        ],
        actions: [
          _StepAction('기초 이론 보기', Icons.menu_book_rounded,
              () => pushWithNav(context, const TheoryScreen(), currentSection: 1)),
          _StepAction('볼트쌤에게 질문', Icons.smart_toy_rounded,
              () => pushWithNav(context, const TutorChatScreen(), currentSection: 1)),
        ],
      ),
      _RoadStep(
        emoji: '✏️',
        title: 'STEP 2 · 일단 문제 구경하기 (1주)',
        why: '이론을 다 알고 문제를 푸는 게 아니라, 문제를 보면서 이론이 필요해지는 순서가 맞습니다. 틀려도 됩니다 — 지금은 "시험이 뭘 묻는지" 구경하는 단계예요.',
        todos: const [
          '기출 10문제만 풀어보기 (정답률 0%여도 정상)',
          '해설을 읽고 "아 이런 걸 묻는구나"만 느끼기',
          '문제 속 "아주 쉬운 설명" 토글 활용하기',
        ],
        actions: [
          _StepAction('기출 10문제 맛보기', Icons.quiz_rounded, () async {
            final qs = await StudyData.instance.questionsByYearRange(3);
            if (!context.mounted) return;
            if (qs.isEmpty) return;
            pushWithNav(
                context,
                QuizPlayScreen(
                    title: '왕초보 맛보기 10문제',
                    questions: qs.take(10).toList(),
                    examMode: false),
                currentSection: 1);
          }),
        ],
      ),
      _RoadStep(
        emoji: '🔁',
        title: 'STEP 3 · 암기 루틴 만들기 (2~4주)',
        why: '기사 시험은 "이해 30% + 반복 70%"입니다. 플래시카드와 암기법으로 매일 10분씩만 반복하면 뇌가 알아서 외워줍니다.',
        todos: const [
          '매일 플래시카드 10장 — 아침·저녁 5분씩',
          '공식은 공식 가이드에서 "왜 이렇게 생겼는지"부터 이해',
          '틀린 문제는 자동으로 복습 큐에 쌓이니 홈의 긴급 복습만 따라가기',
        ],
        actions: [
          _StepAction('플래시카드 시작', Icons.style_rounded,
              () => pushWithNav(context, const FlashcardScreen(), currentSection: 1)),
          _StepAction('공식 가이드', Icons.functions_rounded,
              () => pushWithNav(context, const FormulaGuideScreen(), currentSection: 1)),
        ],
      ),
      _RoadStep(
        emoji: '🎯',
        title: 'STEP 4 · 과목별 정복 (4~8주)',
        why: '이제 과목 단위로 기출을 돌릴 차례입니다. 홈에서 과목을 골라 과목별 문제를 풀고, 정답률 60%가 넘으면 다음 과목으로 넘어가세요.',
        todos: [
          for (final s in subjects.take(3)) '「$s」 과목 기출 1회독',
          '과락(40점 미만) 위험 과목은 볼트쌤과 집중 보강',
        ],
        actions: [
          _StepAction('홈에서 과목 선택', Icons.home_rounded,
              () => Navigator.of(context).popUntil((r) => r.isFirst)),
        ],
      ),
      _RoadStep(
        emoji: '🏆',
        title: 'STEP 5 · 실전 모드 (시험 2주 전)',
        why: '마지막 2주는 새로운 걸 배우지 않습니다. 실전 모의(시간 제한)로 시험 감각을 만들고, 틀린 문제만 반복하세요.',
        todos: const [
          '실전 모의(시간 제한) 주 2회',
          '오답 집중 공략으로 틀린 문제만 재도전',
          '시험 전날은 요약·암기법만 가볍게 훑기',
        ],
        actions: [
          _StepAction('학습 탭에서 실전 모의', Icons.timer_rounded,
              () => Navigator.of(context).popUntil((r) => r.isFirst)),
        ],
      ),
    ];
  }

  // ── UI ────────────────────────────────────────────────
  Widget _heroCard(BuildContext context, String trackName, double progress) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('아무것도 몰라도 괜찮아요',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(
            '$trackName, 지식 0에서 합격까지 6단계.\n체크하며 한 칸씩만 가면 됩니다.',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 13,
                height: 1.5),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
          const SizedBox(height: 6),
          Text('${(progress * 100).round()}% 진행',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _stepCard(BuildContext context, int idx, _RoadStep s) {
    final cs = Theme.of(context).colorScheme;
    final done = _done.contains(idx);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(s.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(s.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        decoration:
                            done ? TextDecoration.lineThrough : null,
                        color: done
                            ? cs.onSurface.withValues(alpha: 0.45)
                            : cs.onSurface,
                      )),
                ),
                Checkbox(
                  value: done,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                  onChanged: (_) => _toggle(idx),
                ),
              ],
            ),
            Text(s.why,
                style: TextStyle(
                    fontSize: 12.5,
                    height: 1.55,
                    color: cs.onSurface.withValues(alpha: 0.7))),
            const SizedBox(height: 10),
            for (final t in s.todos)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 15,
                        color: cs.primary.withValues(alpha: 0.7)),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(t,
                            style: TextStyle(
                                fontSize: 12.5,
                                height: 1.45,
                                color:
                                    cs.onSurface.withValues(alpha: 0.85)))),
                  ],
                ),
              ),
            if (s.actions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final a in s.actions)
                    ActionChip(
                      avatar: Icon(a.icon, size: 16, color: cs.primary),
                      label: Text(a.label,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                      onPressed: a.onTap,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _finalCheer(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '💡 합격자의 90%가 "처음엔 아무것도 몰랐다"고 말합니다.\n차이는 재능이 아니라, 오늘 STEP 0에 체크했는지 뿐이에요.',
        style: TextStyle(
            fontSize: 13,
            height: 1.6,
            fontWeight: FontWeight.w600,
            color: cs.onSurface.withValues(alpha: 0.8)),
      ),
    );
  }
}

class _RoadStep {
  final String emoji;
  final String title;
  final String why;
  final List<String> todos;
  final List<_StepAction> actions;
  _RoadStep(
      {required this.emoji,
      required this.title,
      required this.why,
      required this.todos,
      required this.actions});
}

class _StepAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  _StepAction(this.label, this.icon, this.onTap);
}
