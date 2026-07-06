import 'package:flutter/material.dart';
import '../services/study_data.dart';

/// 1:1 강의 노트 렌더러 — intro/sections/formulas/mnemonics/traps/strategy 전체 표시
/// **볼드** 마크다운, | 표 | 마크다운 지원
class LessonView extends StatelessWidget {
  final Lesson lesson;
  final bool showHeader;
  const LessonView({super.key, required this.lesson, this.showHeader = true});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  lesson.topic,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              _importanceStars(lesson.importance),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            children: [
              Chip(
                label: Text(lesson.subject,
                    style: const TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
              ),
              Chip(
                label: Text('기출 ${lesson.freq}문항',
                    style: const TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                backgroundColor: scheme.primaryContainer,
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
        // ── 도입부 (강사 오프닝 멘트)
        if (lesson.intro.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.record_voice_over,
                    size: 20, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(child: _richText(context, lesson.intro)),
              ],
            ),
          ),
        // ── 본문 섹션들 (강의 챕터)
        for (var i = 0; i < lesson.sections.length; i++) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Text('${i + 1}',
                    style: TextStyle(
                        color: scheme.onPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(lesson.sections[i].title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: _bodyContent(context, lesson.sections[i].body),
          ),
        ],
        // ── 핵심 공식 카드
        if (lesson.formulas.isNotEmpty) ...[
          const SizedBox(height: 20),
          _sectionLabel(context, Icons.functions, '핵심 공식', scheme.tertiary),
          const SizedBox(height: 8),
          for (final f in lesson.formulas)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: scheme.tertiaryContainer.withValues(alpha: 0.4),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(f.expr,
                          style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                    ),
                    if (f.note.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(f.note,
                          style: TextStyle(
                              fontSize: 12, color: scheme.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
            ),
        ],
        // ── 암기법
        if (lesson.mnemonics.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionLabel(context, Icons.lightbulb, '암기법', Colors.amber[800]!),
          const SizedBox(height: 8),
          for (final m in lesson.mnemonics)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.5)),
              ),
              child: _richText(context, m),
            ),
        ],
        // ── 출제 함정
        if (lesson.traps.isNotEmpty) ...[
          const SizedBox(height: 16),
          _sectionLabel(
              context, Icons.warning_amber, '출제 함정 주의', Colors.red[700]!),
          const SizedBox(height: 8),
          for (final t in lesson.traps)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.dangerous_outlined,
                      size: 16, color: Colors.red[700]),
                  const SizedBox(width: 6),
                  Expanded(child: _richText(context, t)),
                ],
              ),
            ),
        ],
        // ── 합격 전략
        if (lesson.strategy.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: Colors.green.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.flag, size: 18, color: Colors.green[700]),
                    const SizedBox(width: 6),
                    Text('합격 전략',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green[800])),
                  ],
                ),
                const SizedBox(height: 6),
                _richText(context, lesson.strategy),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _importanceStars(int n) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          5,
          (i) => Icon(
            i < n ? Icons.star : Icons.star_border,
            size: 16,
            color: Colors.amber[700],
          ),
        ),
      );

  Widget _sectionLabel(
          BuildContext context, IconData icon, String label, Color color) =>
      Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        ],
      );

  /// body 텍스트: 마크다운 표(|...|) 블록과 일반 텍스트 분리 렌더
  Widget _bodyContent(BuildContext context, String body) {
    final lines = body.split('\n');
    final children = <Widget>[];
    final buffer = <String>[];
    final tableLines = <String>[];

    void flushText() {
      if (buffer.isEmpty) return;
      children.add(_richText(context, buffer.join('\n')));
      buffer.clear();
    }

    void flushTable() {
      if (tableLines.isEmpty) return;
      children.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: _buildTable(context, tableLines),
      ));
      tableLines.clear();
    }

    for (final line in lines) {
      final t = line.trim();
      if (t.startsWith('|') && t.endsWith('|')) {
        flushText();
        // 구분선(|---|)은 스킵
        if (!RegExp(r'^\|[\s\-:|]+\|$').hasMatch(t)) tableLines.add(t);
      } else {
        flushTable();
        buffer.add(line);
      }
    }
    flushText();
    flushTable();

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget _buildTable(BuildContext context, List<String> rows) {
    final scheme = Theme.of(context).colorScheme;
    final parsed = rows
        .map((r) => r
            .substring(1, r.length - 1)
            .split('|')
            .map((c) => c.trim())
            .toList())
        .toList();
    if (parsed.isEmpty) return const SizedBox.shrink();
    final cols = parsed.map((r) => r.length).reduce((a, b) => a > b ? a : b);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(
            color: scheme.outlineVariant, borderRadius: BorderRadius.circular(6)),
        children: [
          for (var i = 0; i < parsed.length; i++)
            TableRow(
              decoration: i == 0
                  ? BoxDecoration(color: scheme.surfaceContainerHighest)
                  : null,
              children: [
                for (var c = 0; c < cols; c++)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    child: Text(
                      c < parsed[i].length ? parsed[i][c] : '',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.3,
                        fontWeight:
                            i == 0 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  /// **볼드** 인라인 마크다운 지원 텍스트
  Widget _richText(BuildContext context, String text) {
    final spans = <TextSpan>[];
    final re = RegExp(r'\*\*(.+?)\*\*');
    var last = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      spans.add(TextSpan(
          text: m.group(1),
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary)));
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }
    return Text.rich(
      TextSpan(
          children: spans,
          style: TextStyle(
              fontSize: 14,
              height: 1.65,
              color: Theme.of(context).colorScheme.onSurface)),
    );
  }
}

/// 어디서든 강의를 바텀시트로 여는 헬퍼 (퀴즈·암기 화면 공용)
Future<void> showLessonSheet(
    BuildContext context, String subject, String topic) async {
  final lesson = await StudyData.instance.lessonFor(subject, topic);
  final mnemonics = await StudyData.instance.mnemonicsFor(subject, topic);
  if (!context.mounted) return;

  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (ctx, controller) {
        final width = MediaQuery.of(ctx).size.width;
        final hPad = width > 900 ? (width - 800) / 2 : 16.0;
        return ListView(
          controller: controller,
          padding: EdgeInsets.fromLTRB(hPad, 0, hPad, 32),
          children: [
            if (lesson != null)
              LessonView(lesson: lesson)
            else
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('이 토픽의 강의 자료를 준비 중입니다.'),
              ),
            // 추가 암기법 (mnemonics.json 연동 — 강의에 없는 보조 자료)
            if (mnemonics.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 8),
              Text('보조 암기 카드',
                  style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              for (final m in mnemonics.take(4))
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(m.body,
                            style: const TextStyle(
                                fontSize: 13, height: 1.5)),
                        if (m.tip.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text('TIP: ${m.tip}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(ctx)
                                      .colorScheme
                                      .primary)),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    ),
  );
}
