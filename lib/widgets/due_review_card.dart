import 'package:flutter/material.dart';
import '../services/progress_service.dart';
import '../screens/study/quiz_play_screen.dart';

/// 🔁 오늘의 복습 카드 — 간격반복(SRS) 큐에 쌓인 "지금 안 보면 잊어버릴" 문제를
/// 홈 최상단 가까이에서 숫자로 보여주고 탭 한 번에 시작.
/// "봤던 문제 또 보면 바로 정답" 훈련의 진입점.
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.deepPurple.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _startReview,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.deepPurple.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('🔁', style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '오늘의 복습카드  $_count개',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.deepPurple,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '지금 안 보면 잊어버려요 — 30초면 끝!',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.play_circle_fill,
                  color: Colors.deepPurple,
                  size: 30,
                ),
              ],
            ),
          ),
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
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizPlayScreen(
          title: '오늘의 복습 카드 (${qs.length}문항)',
          questions: qs,
          examMode: false,
        ),
      ),
    );
    _load();
  }
}
