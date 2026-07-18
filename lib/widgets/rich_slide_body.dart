import 'package:flutter/material.dart';

/// 슬라이드 본문 리치 렌더러
/// 지원 문법:
///  - `| a | b |` 마크다운 표 → 진짜 Flutter Table
///  - `**굵게**` → bold
///  - `■ 섹션제목` → 색상 섹션 헤더 배지
///  - `· 불릿` / `▪ 항목` → 들여쓰기 불릿
///  - `→ 팁` → 강조 화살표 라인
///  - `🔑 암기` → 키 포인트 칩 스타일
///  - `① ② ③` 시험 포인트 → 자동 줄바꿈 강조
class RichSlideBody extends StatelessWidget {
  final String body;
  final Color accent;
  const RichSlideBody({super.key, required this.body, required this.accent});

  @override
  Widget build(BuildContext context) {
    final blocks = _parseBlocks(body);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }

  List<Widget> _parseBlocks(String text) {
    final widgets = <Widget>[];
    final lines = text.split('\n');
    int i = 0;
    final buffer = <String>[];

    void flushParagraph() {
      if (buffer.isEmpty) return;
      final para = buffer.join('\n').trim();
      buffer.clear();
      if (para.isEmpty) return;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _styledText(
            para,
            const TextStyle(fontSize: 14.5, height: 1.65),
          ),
        ),
      );
    }

    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      // 마크다운 표 감지
      if (trimmed.startsWith('|') && trimmed.endsWith('|')) {
        flushParagraph();
        final tableLines = <String>[];
        while (i < lines.length &&
            lines[i].trim().startsWith('|') &&
            lines[i].trim().endsWith('|')) {
          tableLines.add(lines[i].trim());
          i++;
        }
        widgets.add(_buildTable(tableLines));
        continue;
      }

      // ■ 섹션 헤더
      if (trimmed.startsWith('■')) {
        flushParagraph();
        widgets.add(_sectionHeader(trimmed.substring(1).trim()));
        i++;
        continue;
      }

      // · 또는 ▪ 불릿
      if (trimmed.startsWith('·') || trimmed.startsWith('▪')) {
        flushParagraph();
        widgets.add(_bulletLine(trimmed.substring(1).trim()));
        i++;
        continue;
      }

      // → 팁 라인
      if (trimmed.startsWith('→')) {
        flushParagraph();
        widgets.add(_tipLine(trimmed.substring(1).trim()));
        i++;
        continue;
      }

      // 🔑 암기 키
      if (trimmed.startsWith('🔑')) {
        flushParagraph();
        widgets.add(_keyLine(trimmed.substring(2).trim()));
        i++;
        continue;
      }

      // ① 시험 포인트 라인 (자동 분리 강조)
      if (trimmed.startsWith('①')) {
        flushParagraph();
        widgets.add(_examPoints(trimmed));
        i++;
        continue;
      }

      if (trimmed.isEmpty) {
        flushParagraph();
        i++;
        continue;
      }

      buffer.add(line);
      i++;
    }
    flushParagraph();
    return widgets;
  }

  // ---------- 요소 빌더 ----------

  Widget _sectionHeader(String title) {
    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 14,
          color: accent,
        ),
      ),
    );
  }

  Widget _bulletLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 7, right: 8),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Expanded(
            child: _styledText(
              text,
              const TextStyle(fontSize: 14, height: 1.55),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tipLine(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡 ', style: TextStyle(fontSize: 13)),
          Expanded(
            child: _styledText(
              text,
              const TextStyle(
                fontSize: 13.5,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _keyLine(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFE65100).withValues(alpha: 0.14),
            const Color(0xFFE65100).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFE65100).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🔑 ', style: TextStyle(fontSize: 14)),
          Expanded(
            child: _styledText(
              text,
              const TextStyle(
                fontSize: 14.5,
                height: 1.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFFBF360C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// "① a ② b ③ c" 를 줄 단위로 분리 강조
  Widget _examPoints(String text) {
    final parts = <String>[];
    final re = RegExp(r'[①②③④⑤⑥⑦⑧⑨]');
    final matches = re.allMatches(text).toList();
    for (var k = 0; k < matches.length; k++) {
      final start = matches[k].start;
      final end = k + 1 < matches.length ? matches[k + 1].start : text.length;
      parts.add(text.substring(start, end).trim());
    }
    if (parts.isEmpty) parts.add(text);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: parts
            .map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _styledText(
                  p,
                  TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    color: accent.withValues(alpha: 0.95),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildTable(List<String> tableLines) {
    // 구분선 행(|---|---|) 제거
    final rows = tableLines
        .where((l) => !RegExp(r'^\|[\s\-:|]+\|$').hasMatch(l))
        .map((l) {
          final cells = l.split('|');
          return cells
              .sublist(1, cells.length - 1)
              .map((c) => c.trim())
              .toList();
        })
        .toList();
    if (rows.isEmpty) return const SizedBox.shrink();

    final colCount = rows.map((r) => r.length).reduce((a, b) => a > b ? a : b);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Table(
          columnWidths: const {0: FlexColumnWidth(1.2)},
          border: TableBorder(
            horizontalInside: BorderSide(color: accent.withValues(alpha: 0.15)),
            verticalInside: BorderSide(color: accent.withValues(alpha: 0.15)),
          ),
          children: List.generate(rows.length, (r) {
            final isHeader = r == 0;
            final row = rows[r];
            return TableRow(
              decoration: BoxDecoration(
                color: isHeader
                    ? accent.withValues(alpha: 0.14)
                    : (r.isEven
                          ? accent.withValues(alpha: 0.03)
                          : Colors.transparent),
              ),
              children: List.generate(colCount, (c) {
                final cell = c < row.length ? row[c] : '';
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: _styledText(
                    cell,
                    TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: isHeader ? FontWeight.w800 : FontWeight.w500,
                      color: isHeader ? accent : null,
                    ),
                  ),
                );
              }),
            );
          }),
        ),
      ),
    );
  }

  /// **굵게** 인라인 파싱
  Widget _styledText(String text, TextStyle base) {
    if (!text.contains('**')) {
      return SelectableText(text, style: base);
    }
    final spans = <TextSpan>[];
    final re = RegExp(r'\*\*(.+?)\*\*');
    int last = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      spans.add(
        TextSpan(
          text: m.group(1),
          style: TextStyle(fontWeight: FontWeight.w800, color: accent),
        ),
      );
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(text: text.substring(last)));
    }
    return SelectableText.rich(TextSpan(style: base, children: spans));
  }
}
