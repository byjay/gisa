import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// 🎉 레벨업 축하 팝업 — 마법 파티클과 함께 새 레벨/칭호 공개
class LevelUpDialog extends StatefulWidget {
  final int newLevel;
  final String title;

  const LevelUpDialog({
    super.key,
    required this.newLevel,
    required this.title,
  });

  /// 레벨업 감지 후 표시 (이전 레벨 < 새 레벨일 때만)
  static Future<void> showIfLevelUp(
      BuildContext context, int before, int after, String title) async {
    if (after > before && context.mounted) {
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (_) => LevelUpDialog(newLevel: after, title: title),
      );
    }
  }

  @override
  State<LevelUpDialog> createState() => _LevelUpDialogState();
}

class _LevelUpDialogState extends State<LevelUpDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 🎆 파티클 버스트
          AnimatedBuilder(
            animation: _c,
            builder: (_, __) => CustomPaint(
              size: const Size(320, 340),
              painter: _BurstPainter(_c.value),
            ),
          ),
          // 본문 카드
          Container(
            width: 280,
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
            decoration: BoxDecoration(
              gradient: AppTheme.heroGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: AppTheme.glowShadow(AppTheme.accent),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 회전+확대 등장하는 레벨 배지
                ScaleTransition(
                  scale: CurvedAnimation(
                      parent: _c,
                      curve: const Interval(0, 0.45,
                          curve: Curves.elasticOut)),
                  child: Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B)
                              .withValues(alpha: 0.6),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text('Lv${widget.newLevel}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('🎉 레벨 업!',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5)),
                const SizedBox(height: 6),
                Text('🧙 ${widget.title}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('꾸준한 학습이 마법을 만들어요',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 11.5)),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppTheme.primaryDark,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('계속 성장하기 ✨',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  final double t;
  _BurstPainter(this.t);

  static final _rand = math.Random(11);
  static final List<({double angle, double speed, double size, Color color})>
      _particles = List.generate(26, (i) {
    const colors = [
      Color(0xFFFBBF24),
      Color(0xFFF472B6),
      Color(0xFF34D399),
      Color(0xFF60A5FA),
      Color(0xFFA78BFA),
    ];
    return (
      angle: _rand.nextDouble() * math.pi * 2,
      speed: 60 + _rand.nextDouble() * 110,
      size: 3 + _rand.nextDouble() * 4,
      color: colors[i % colors.length],
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (t < 0.05) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final progress = Curves.easeOutCubic.transform(t.clamp(0.0, 1.0));
    final fade = (1 - t).clamp(0.0, 1.0);

    for (final p in _particles) {
      final dist = p.speed * progress;
      final x = cx + math.cos(p.angle) * dist;
      final y = cy + math.sin(p.angle) * dist + 20 * progress * progress;
      final paint = Paint()
        ..color = p.color.withValues(alpha: 0.9 * fade);
      canvas.drawCircle(Offset(x, y), p.size * (1 - progress * 0.4), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) => old.t != t;
}
