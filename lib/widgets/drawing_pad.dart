import 'package:flutter/material.dart';

/// ✍️ 필기 패드 — 태블릿/패드 손글씨 계산·메모용 캔버스.
///
/// - 스타일러스·손가락 자유 필기 (부드러운 곡선 보간)
/// - 펜 색상 6종 · 굵기 3단계 · 지우개 · 되돌리기 · 전체 지우기
/// - 퀴즈/CBT 화면 위에 [showDrawingPad]로 띄워 풀이 중 계산 가능
class DrawingStroke {
  final List<Offset> points;
  final Color color;
  final double width;
  final bool eraser;
  DrawingStroke({
    required this.points,
    required this.color,
    required this.width,
    this.eraser = false,
  });
}

class DrawingPad extends StatefulWidget {
  final Color backgroundColor;
  const DrawingPad({super.key, this.backgroundColor = Colors.transparent});

  @override
  State<DrawingPad> createState() => _DrawingPadState();
}

class _DrawingPadState extends State<DrawingPad> {
  final List<DrawingStroke> _strokes = [];
  DrawingStroke? _current;

  Color _color = const Color(0xFF1E293B);
  double _width = 2.6;
  bool _eraser = false;

  static const _colors = [
    Color(0xFF1E293B), // 잉크
    Color(0xFF2563EB), // 파랑
    Color(0xFFDC2626), // 빨강
    Color(0xFF16A34A), // 초록
    Color(0xFF9333EA), // 보라
    Color(0xFFF59E0B), // 주황
  ];
  static const _widths = [1.8, 2.6, 4.6];

  void _start(Offset p) {
    _current = DrawingStroke(
      points: [p],
      color: _color,
      width: _eraser ? 22 : _width,
      eraser: _eraser,
    );
    setState(() => _strokes.add(_current!));
  }

  void _move(Offset p) {
    if (_current == null) return;
    setState(() => _current!.points.add(p));
  }

  void _end() => _current = null;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? Colors.white : const Color(0xFF1E293B);
    return Column(
      children: [
        // ── 도구 바 ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              // 색상 선택
              for (final c in _colors)
                GestureDetector(
                  onTap: () => setState(() {
                    _color = c;
                    _eraser = false;
                  }),
                  child: Container(
                    width: 26,
                    height: 26,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: c == _colors.first ? ink : c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: !_eraser && _color == c
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey.withValues(alpha: 0.3),
                        width: !_eraser && _color == c ? 2.5 : 1,
                      ),
                    ),
                    child: !_eraser && _color == c
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                ),
              const Spacer(),
              // 굵기
              for (final w in _widths)
                GestureDetector(
                  onTap: () => setState(() {
                    _width = w;
                    _eraser = false;
                  }),
                  child: Container(
                    width: 26,
                    height: 26,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: !_eraser && _width == w
                          ? Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.15)
                          : Colors.transparent,
                    ),
                    alignment: Alignment.center,
                    child: Container(
                      width: w * 2.2,
                      height: w * 2.2,
                      decoration: BoxDecoration(
                        color: ink.withValues(alpha: 0.8),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              // 지우개
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: '지우개',
                icon: Icon(
                  Icons.cleaning_services_rounded,
                  size: 20,
                  color: _eraser
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                onPressed: () => setState(() => _eraser = !_eraser),
              ),
              // 되돌리기
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: '되돌리기',
                icon: const Icon(Icons.undo_rounded, size: 20),
                onPressed: _strokes.isEmpty
                    ? null
                    : () => setState(() => _strokes.removeLast()),
              ),
              // 전체 지우기
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: '전체 지우기',
                icon: const Icon(Icons.delete_sweep_rounded, size: 20),
                onPressed: _strokes.isEmpty
                    ? null
                    : () => setState(_strokes.clear),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // ── 캔버스 ──
        Expanded(
          child: ClipRect(
            child: Listener(
              // Listener는 스타일러스·터치 모두 지연 없이 수신
              onPointerDown: (e) => _start(e.localPosition),
              onPointerMove: (e) => _move(e.localPosition),
              onPointerUp: (_) => _end(),
              child: Container(
                width: double.infinity,
                color: widget.backgroundColor == Colors.transparent
                    ? (dark ? const Color(0xFF1A2233) : const Color(0xFFFDFBF5))
                    : widget.backgroundColor,
                child: CustomPaint(
                  painter: _PadPainter(
                    strokes: _strokes,
                    dark: dark,
                    eraseColor: dark
                        ? const Color(0xFF1A2233)
                        : const Color(0xFFFDFBF5),
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PadPainter extends CustomPainter {
  final List<DrawingStroke> strokes;
  final bool dark;
  final Color eraseColor;
  _PadPainter({
    required this.strokes,
    required this.dark,
    required this.eraseColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 모눈 배경 (계산 연습장 느낌)
    final grid = Paint()
      ..color = (dark ? Colors.white : Colors.blueGrey).withValues(alpha: 0.06)
      ..strokeWidth = 0.7;
    const gap = 26.0;
    for (double x = gap; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = gap; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    for (final s in strokes) {
      final paint = Paint()
        ..color = s.eraser
            ? eraseColor
            : (dark && s.color == const Color(0xFF1E293B)
                  ? Colors.white
                  : s.color)
        ..strokeWidth = s.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      if (s.points.length < 2) {
        canvas.drawCircle(
          s.points.first,
          s.width / 2,
          paint..style = PaintingStyle.fill,
        );
        continue;
      }
      // 이차 베지어 보간으로 부드러운 곡선
      final path = Path()..moveTo(s.points.first.dx, s.points.first.dy);
      for (var i = 1; i < s.points.length - 1; i++) {
        final mid = Offset(
          (s.points[i].dx + s.points[i + 1].dx) / 2,
          (s.points[i].dy + s.points[i + 1].dy) / 2,
        );
        path.quadraticBezierTo(s.points[i].dx, s.points[i].dy, mid.dx, mid.dy);
      }
      path.lineTo(s.points.last.dx, s.points.last.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PadPainter old) => true;
}

/// 문제 풀이 중 아래에서 올라오는 필기 패드 시트.
/// 높이 조절 가능(드래그 핸들) — 문제를 보면서 계산할 수 있게 65% 기본.
Future<void> showDrawingPad(BuildContext context, {String title = '✍️ 필기 연습장'}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          // 핸들 + 제목
          SingleChildScrollView(
            controller: scrollCtrl,
            physics: const ClampingScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                  child: Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '위아래로 드래그해 크기 조절',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Theme.of(
                            ctx,
                          ).colorScheme.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Expanded(child: DrawingPad()),
        ],
      ),
    ),
  );
}
