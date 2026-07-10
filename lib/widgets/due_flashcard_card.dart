import 'package:flutter/material.dart';
import '../services/flashcard_srs.dart';
import '../screens/study/flashcard_screen.dart';

/// 🃏 오늘의 암기카드 — 플래시카드 SRS 큐에 쌓인 복습 대상 개수를
/// 홈에서 바로 보여주고 탭 한 번에 암기 모드로 진입.
/// "암기 과목이 쏙쏙 들어오게" 만드는 진입점.
class DueFlashcardCard extends StatefulWidget {
  const DueFlashcardCard({super.key});

  @override
  State<DueFlashcardCard> createState() => _DueFlashcardCardState();
}

class _DueFlashcardCardState extends State<DueFlashcardCard> {
  int _count = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final due = await FlashcardSrs.instance.dueKeys();
    if (mounted) {
      setState(() {
        _count = due.length;
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
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _start,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('🃏', style: TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('오늘의 암기카드  $_count개',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.deepOrange)),
                      const SizedBox(height: 2),
                      const Text('암기법을 잊기 전에 한 번 더 확인해요',
                          style: TextStyle(fontSize: 11.5, color: Colors.grey)),
                    ],
                  ),
                ),
                const Icon(Icons.play_circle_fill,
                    color: Colors.deepOrange, size: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _start() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const FlashcardScreen()));
    _load();
  }
}
