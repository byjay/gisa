import 'package:flutter/material.dart';
import '../services/progress_service.dart';
import '../screens/study/quiz_play_screen.dart';
import '../theme/app_theme.dart';
import 'persistent_nav.dart';

/// 🔁 오늘의 복습 카드 — 간격반복(SRS) 큐에 쌓인 "지금 안 보면 잊어버릴" 문제를
/// 홈 상단에서 숫자로 보여주고 탭 한 번에 시작.
/// 디자인 시스템(PremiumCard/IconBadge) 준수 + 다크모드 대응.
class DueReviewCard extends StatefulWidget {
  const DueReviewCard({super.key});

  @override
  State<DueReviewCard> createState() => _DueReviewCardState();
}

class _DueReviewCardState extends State<DueReviewCard> {
  int _count = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await ProgressService.instance.dueReviewCount();
    if (mounted) {
      setState(() {
        _count = c;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _count == 0) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    const purple = Color(0xFF7C3AED);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: _startReview,
        child: Row(
          children: [
            const IconBadge(
                icon: Icons.replay_rounded, color: purple, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('오늘의 복습 카드',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 7),
                      PillBadge(text: '$_count개', color: purple, filled: true),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text('지금 안 보면 잊어버려요 — 30초면 끝!',
                      style: TextStyle(
                          fontSize: 11.5, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            const Icon(Icons.play_circle_fill, color: purple, size: 30),
          ],
        ),
      ),
    );
  }

  Future<void> _startReview() async {
    final qids = await ProgressService.instance.dueReviewQids();
    final qs = await ProgressService.instance.resolveQuestions(qids);
    if (!mounted) return;
    if (qs.isEmpty) return;
    qs.shuffle();
    await pushWithNav(context, QuizPlayScreen(
          title: '오늘의 복습 카드 (${qs.length}문항)',
          questions: qs,
          examMode: false,
        ), currentSection: 1);
    _load();
  }
}
