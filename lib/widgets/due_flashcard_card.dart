import 'package:flutter/material.dart';
import '../services/flashcard_srs.dart';
import '../screens/study/flashcard_screen.dart';
import '../theme/app_theme.dart';
import 'persistent_nav.dart';

/// 🃏 오늘의 암기카드 — 암기법 SRS 큐에 도착한 카드 수를 보여주고 바로 시작.
/// 디자인 시스템(PremiumCard/IconBadge) 준수 + 다크모드 대응.
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
    final scheme = Theme.of(context).colorScheme;
    const orange = Color(0xFFF97316);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: PremiumCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        onTap: _start,
        child: Row(
          children: [
            const IconBadge(icon: Icons.style_rounded, color: orange, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        '오늘의 암기카드',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 7),
                      PillBadge(text: '$_count개', color: orange, filled: true),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '암기법을 잊기 전에 한 번 더 확인해요',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.play_circle_fill, color: orange, size: 30),
          ],
        ),
      ),
    );
  }

  Future<void> _start() async {
    await pushWithNav(context, const FlashcardScreen(), currentSection: 1);
    _load();
  }
}
