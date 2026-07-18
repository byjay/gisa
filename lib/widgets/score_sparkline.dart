import 'package:flutter/material.dart';

/// 미니 추이 그래프 — 외부 차트 패키지 없이 CustomPainter로 직접 그리는
/// 가벼운 스파크라인. "내가 오르고 있다"는 증거를 시각으로 보여준다.
class ScoreSparkline extends StatelessWidget {
  final List<double> values; // 시간순(과거→현재)
  final Color color;
  final double height;
  const ScoreSparkline({
    super.key,
    required this.values,
    required this.color,
    this.height = 46,
  });

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            '데이터가 쌓이면 그래프가 나타나요',
            style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7)),
          ),
        ),
      );
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparklinePainter(values: values, color: color),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;
  _SparklinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).abs() < 1 ? 1.0 : (maxV - minV);
    final dx = size.width / (values.length - 1);

    Offset pt(int i) {
      final v = values[i];
      final ny = 1 - ((v - minV) / range); // 0(위)~1(아래)
      return Offset(dx * i, ny * (size.height - 8) + 4);
    }

    // 채워진 영역 (그라디언트)
    final fillPath = Path()..moveTo(0, size.height);
    for (var i = 0; i < values.length; i++) {
      final p = pt(i);
      if (i == 0) {
        fillPath.lineTo(p.dx, p.dy);
      } else {
        fillPath.lineTo(p.dx, p.dy);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.02)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // 라인
    final linePath = Path();
    for (var i = 0; i < values.length; i++) {
      final p = pt(i);
      if (i == 0) {
        linePath.moveTo(p.dx, p.dy);
      } else {
        linePath.lineTo(p.dx, p.dy);
      }
    }
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, linePaint);

    // 마지막 점 강조
    final last = pt(values.length - 1);
    canvas.drawCircle(last, 4, Paint()..color = color);
    canvas.drawCircle(
      last,
      4,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}
