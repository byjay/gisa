import 'package:flutter/material.dart';
import '../../services/study_data.dart';
import '../../widgets/tutor_avatar.dart';

/// 회로도 마스터 — 모터 제어반 도면 [보기]와 [작성하기] 서브메뉴
/// 첨부 실무 자료(IEC 60617) 기반. 시험(실기)·실무 도면 해독 모두 대비.
class CircuitScreen extends StatefulWidget {
  const CircuitScreen({super.key});

  @override
  State<CircuitScreen> createState() => _CircuitScreenState();
}

class _CircuitScreenState extends State<CircuitScreen>
    with SingleTickerProviderStateMixin {
  CircuitGuide? _g;
  late final TabController _tab;
  final Set<int> _checked = {}; // 작성 체크리스트 진행상황

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    StudyData.instance.loadCircuitGuide().then((v) {
      if (mounted) setState(() => _g = v);
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = _g;
    return Scaffold(
      appBar: AppBar(
        title: const Text('회로도 마스터'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(icon: Icon(Icons.visibility_rounded), text: '보기'),
            Tab(icon: Icon(Icons.draw_rounded), text: '작성하기'),
          ],
        ),
      ),
      body: g == null
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tab,
              children: [
                _buildViewTab(context, g),
                _buildCreateTab(context, g),
              ],
            ),
    );
  }

  EdgeInsets get _pad => EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width > 900
            ? (MediaQuery.of(context).size.width - 820) / 2
            : 14,
        vertical: 14,
      );

  // ═══════════════════════ 보기 탭 ═══════════════════════
  Widget _buildViewTab(BuildContext context, CircuitGuide g) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: _pad,
      children: [
        TutorBanner(
          mood: TutorMood.teaching,
          message: g.overview.isNotEmpty
              ? g.overview
              : '문자기호·계통번호·전선번호 규칙만 알면 처음 보는 도면도 바로 읽을 수 있어요!',
        ),
        const SizedBox(height: 14),
        _sectionTitle(context, '① 기호 범례 (IEC 60617)', Icons.category_rounded),
        const SizedBox(height: 8),
        ...g.legend.map((l) => _legendCard(context, l)),
        const SizedBox(height: 18),
        _sectionTitle(context, '② 도면 읽기 규칙 6가지', Icons.rule_rounded),
        const SizedBox(height: 8),
        ...g.rules.asMap().entries.map((e) => _ruleCard(context, e.key, e.value)),
        const SizedBox(height: 18),
        _sectionTitle(context, '③ 마스터 태그표 (부품·전선·상호참조)',
            Icons.table_chart_rounded),
        const SizedBox(height: 4),
        Text('실제 제어반 단선도의 모든 부품을 정리한 표입니다. 분기별로 스크롤해서 확인하세요.',
            style: TextStyle(
                fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6))),
        const SizedBox(height: 8),
        ..._buildMasterTable(context, g.master),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _legendCard(BuildContext context, CircuitLegend l) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 기호 심볼
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: CustomPaint(
                painter: _SymbolPainter(l.svg, cs.onSurface),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(l.code,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: cs.primary)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(l.name,
                            style: const TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(l.desc,
                      style: const TextStyle(fontSize: 12.5, height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ruleCard(BuildContext context, int i, CircuitRule r) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 11,
                backgroundColor: cs.primary,
                child: Text('${i + 1}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(r.title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(r.body, style: const TextStyle(fontSize: 12.5, height: 1.55)),
        ],
      ),
    );
  }

  List<Widget> _buildMasterTable(
      BuildContext context, List<CircuitMasterRow> rows) {
    final cs = Theme.of(context).colorScheme;
    final out = <Widget>[];
    for (final r in rows) {
      if (r.isHeader) {
        out.add(Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 10, bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(r.branch,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: cs.primary)),
        ));
      } else {
        out.add(Container(
          margin: const EdgeInsets.only(bottom: 5),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (r.tag.isNotEmpty && r.tag != '—')
                    _chip(context, r.tag, cs.primary, mono: true),
                  if (r.stage.isNotEmpty)
                    Text(r.stage,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface.withValues(alpha: 0.75))),
                  if (r.wire.isNotEmpty && r.wire != '—')
                    _chip(context, '전선 ${r.wire}', Colors.teal),
                  if (r.ref.isNotEmpty && r.ref != '—')
                    _chip(context, '참조 ${r.ref}', Colors.deepPurple),
                ],
              ),
              if (r.desc.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(r.desc,
                    style: const TextStyle(fontSize: 12, height: 1.45)),
              ],
            ],
          ),
        ));
      }
    }
    return out;
  }

  Widget _chip(BuildContext context, String text, Color color,
      {bool mono = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              fontFamily: mono ? 'monospace' : null,
              color: color)),
    );
  }

  // ═══════════════════════ 작성하기 탭 ═══════════════════════
  Widget _buildCreateTab(BuildContext context, CircuitGuide g) {
    final cs = Theme.of(context).colorScheme;
    final total = g.checklist.length;
    final done = _checked.length;
    final progress = total == 0 ? 0.0 : done / total;
    return ListView(
      padding: _pad,
      children: [
        TutorBanner(
          mood: TutorMood.cheer,
          message: '아래 STEP을 순서대로 따라 그리면 완성! 그릴 때마다 체크리스트를 눌러 진행률을 확인하세요. ✏️',
        ),
        const SizedBox(height: 14),
        // 진행률
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('작성 진행률',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800)),
                  Text('$done / $total',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: cs.primary)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                    value: progress, minHeight: 9),
              ),
              if (done == total && total > 0) ...[
                const SizedBox(height: 8),
                const Text('🎉 도면 완성! 실무·실기 어디서든 자신있게 그릴 수 있어요.',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.green)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionTitle(context, '그리기 STEP', Icons.format_list_numbered_rounded),
        const SizedBox(height: 8),
        ...g.steps.asMap().entries.map((e) => _stepCard(context, e.key, e.value)),
        const SizedBox(height: 18),
        _sectionTitle(context, '완성 체크리스트', Icons.checklist_rounded),
        const SizedBox(height: 8),
        ...g.checklist.asMap().entries.map((e) => _checkItem(context, e.key, e.value)),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _stepCard(BuildContext context, int i, CircuitStep s) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: CustomPaint(
                      painter: _SymbolPainter(s.svg, cs.primary)),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(s.title,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(s.body, style: const TextStyle(fontSize: 13, height: 1.55)),
            if (s.tip.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('💡 ', style: TextStyle(fontSize: 13)),
                    Expanded(
                      child: Text(s.tip,
                          style: const TextStyle(
                              fontSize: 12, height: 1.45)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _checkItem(BuildContext context, int i, CircuitChecklist c) {
    final cs = Theme.of(context).colorScheme;
    final on = _checked.contains(i);
    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: () => setState(() {
        if (on) {
          _checked.remove(i);
        } else {
          _checked.add(i);
        }
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: on
              ? Colors.green.withValues(alpha: 0.08)
              : cs.surface,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
              color: on
                  ? Colors.green.withValues(alpha: 0.5)
                  : cs.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(on ? Icons.check_circle_rounded : Icons.circle_outlined,
                size: 22, color: on ? Colors.green : cs.outline),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.item,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          decoration:
                              on ? TextDecoration.lineThrough : null,
                          color: on
                              ? cs.onSurface.withValues(alpha: 0.55)
                              : cs.onSurface)),
                  if (c.done.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(c.done,
                        style: TextStyle(
                            fontSize: 11.5,
                            color: cs.onSurface.withValues(alpha: 0.6))),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 6),
        Text(text,
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w900, color: cs.primary)),
      ],
    );
  }
}

/// 회로 기호를 코드로 직접 그리는 페인터 (SVG 파일 대신 CustomPainter)
class _SymbolPainter extends CustomPainter {
  final String kind;
  final Color color;
  _SymbolPainter(this.kind, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final w = size.width, h = size.height;
    final cx = w / 2, cy = h / 2;

    void vline() => canvas.drawLine(Offset(cx, 6), Offset(cx, h - 6), p);

    switch (kind) {
      case 'breaker':
      case 'breaker_thermal':
        // 세로선 + 사선 접점(차단기)
        canvas.drawLine(Offset(cx, 6), Offset(cx, cy - 8), p);
        canvas.drawLine(Offset(cx, cy - 8), Offset(cx + 9, cy + 8), p);
        canvas.drawLine(Offset(cx, cy + 8), Offset(cx, h - 6), p);
        canvas.drawCircle(Offset(cx, cy - 8), 2, p..style = PaintingStyle.fill);
        p.style = PaintingStyle.stroke;
        if (kind == 'breaker_thermal') {
          // 열동 요소(작은 사각)
          canvas.drawRect(
              Rect.fromCenter(
                  center: Offset(cx + 11, cy), width: 6, height: 10),
              p);
        }
        break;
      case 'contactor':
        // 세로선 + 반원 접점(접촉기)
        canvas.drawLine(Offset(cx, 6), Offset(cx, cy - 7), p);
        final rect = Rect.fromCircle(center: Offset(cx, cy - 2), radius: 8);
        canvas.drawArc(rect, 3.14, 3.14, false, p);
        canvas.drawLine(Offset(cx, cy + 6), Offset(cx, h - 6), p);
        break;
      case 'fuse':
        // 세로선 + 직사각형(퓨즈)
        canvas.drawLine(Offset(cx, 6), Offset(cx, cy - 10), p);
        canvas.drawRect(
            Rect.fromCenter(center: Offset(cx, cy), width: 12, height: 20), p);
        canvas.drawLine(Offset(cx, cy + 10), Offset(cx, h - 6), p);
        break;
      case 'motor':
        // 원 + M
        canvas.drawLine(Offset(cx, 4), Offset(cx, cy - 13), p);
        canvas.drawCircle(Offset(cx, cy + 2), 13, p);
        final tp = TextPainter(
          text: TextSpan(
              text: 'M',
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.bold)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(cx - tp.width / 2, cy + 2 - tp.height / 2));
        break;
      case 'busbar':
        // 3상 버스바 3줄
        for (var i = 0; i < 3; i++) {
          final y = h * 0.28 + i * (h * 0.22);
          canvas.drawLine(Offset(8, y), Offset(w - 8, y), p);
        }
        break;
      case 'terminal':
        // 단자대 원
        vline();
        canvas.drawCircle(Offset(cx, cy), 5, p);
        break;
      case 'cable':
        // 케이블 사선 + 슬래시(심선수)
        canvas.drawLine(Offset(10, h - 10), Offset(w - 10, 10), p);
        canvas.drawLine(Offset(cx - 5, cy + 5), Offset(cx + 1, cy - 3), p);
        break;
      case 'ground':
        // 접지 기호
        canvas.drawLine(Offset(cx, 6), Offset(cx, cy), p);
        canvas.drawLine(Offset(cx - 12, cy), Offset(cx + 12, cy), p);
        canvas.drawLine(Offset(cx - 8, cy + 6), Offset(cx + 8, cy + 6), p);
        canvas.drawLine(Offset(cx - 4, cy + 12), Offset(cx + 4, cy + 12), p);
        break;
      default:
        // 기본: 세로선 + 점
        vline();
        canvas.drawCircle(
            Offset(cx, cy), 3, p..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(covariant _SymbolPainter old) =>
      old.kind != kind || old.color != color;
}
