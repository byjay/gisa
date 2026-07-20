import 'package:flutter/material.dart';

/// ❓ 기능별 도움말 점 — 메뉴/섹션 옆에 붙이는 작은 물음표.
/// 탭하면 해당 기능의 아주 상세한 설명 팝업이 뜬다.
class HelpDot extends StatelessWidget {
  final String title;
  final String body;
  final double size;

  const HelpDot({
    super.key,
    required this.title,
    required this.body,
    this.size = 17,
  });

  void _show(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.help_rounded, size: 20, color: cs.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.55,
          ),
          child: SingleChildScrollView(
            child: Text(
              body,
              style: const TextStyle(fontSize: 13.5, height: 1.65),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('알겠어요!'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => _show(context),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(4), // 터치 영역 확보
        child: Icon(
          Icons.help_outline_rounded,
          size: size,
          color: cs.primary.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}
