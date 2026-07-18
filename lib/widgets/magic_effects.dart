import 'dart:math' as math;
import 'package:flutter/material.dart';

/// ✨ 순차 등장 애니메이션 — 리스트 아이템에 지연을 주어 부드럽게 떠오르게 함
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final int index; // 순번에 따라 지연
  final Duration baseDelay;

  const FadeSlideIn({
    super.key,
    required this.child,
    this.index = 0,
    this.baseDelay = const Duration(milliseconds: 60),
  });

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));
    Future.delayed(widget.baseDelay * widget.index, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// 🌟 반짝이는 별 파티클 오버레이 (헤더 장식용)
class SparkleOverlay extends StatefulWidget {
  final double width;
  final double height;
  const SparkleOverlay({super.key, this.width = 400, this.height = 180});

  @override
  State<SparkleOverlay> createState() => _SparkleOverlayState();
}

class _SparkleOverlayState extends State<SparkleOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  final _rand = math.Random(7);
  late final List<_Star> _stars;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 5))
      ..repeat();
    _stars = List.generate(14, (i) {
      return _Star(
        x: _rand.nextDouble(),
        y: _rand.nextDouble(),
        size: 1.5 + _rand.nextDouble() * 2.6,
        phase: _rand.nextDouble() * math.pi * 2,
        speed: 0.6 + _rand.nextDouble() * 1.2,
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => CustomPaint(
          size: Size(widget.width, widget.height),
          painter: _StarPainter(_stars, _c.value),
        ),
      ),
    );
  }
}

class _Star {
  final double x, y, size, phase, speed;
  _Star({
    required this.x,
    required this.y,
    required this.size,
    required this.phase,
    required this.speed,
  });
}

class _StarPainter extends CustomPainter {
  final List<_Star> stars;
  final double t;
  _StarPainter(this.stars, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in stars) {
      final tw = (math.sin(t * math.pi * 2 * s.speed + s.phase) + 1) / 2; // 0~1
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.15 + tw * 0.45);
      final cx = s.x * size.width;
      final cy = s.y * size.height;
      final r = s.size * (0.6 + tw * 0.4);
      // 4-point star (diamond sparkle)
      final path = Path()
        ..moveTo(cx, cy - r * 2)
        ..quadraticBezierTo(cx + r * 0.4, cy - r * 0.4, cx + r * 2, cy)
        ..quadraticBezierTo(cx + r * 0.4, cy + r * 0.4, cx, cy + r * 2)
        ..quadraticBezierTo(cx - r * 0.4, cy + r * 0.4, cx - r * 2, cy)
        ..quadraticBezierTo(cx - r * 0.4, cy - r * 0.4, cx, cy - r * 2)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) => old.t != t;
}

/// 💫 은은한 펄스 글로우 (강조 요소 래핑)
class PulseGlow extends StatefulWidget {
  final Widget child;
  final Color color;
  final BorderRadius borderRadius;

  const PulseGlow({
    super.key,
    required this.child,
    required this.color,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  @override
  State<PulseGlow> createState() => _PulseGlowState();
}

class _PulseGlowState extends State<PulseGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final v = Curves.easeInOut.transform(_c.value);
        return Container(
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.18 + v * 0.22),
                blurRadius: 14 + v * 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
