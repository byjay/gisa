import 'package:flutter/material.dart';
import '../../services/study_data.dart';
import 'quiz_play_screen.dart';

/// 핵심이론서: 과목 선택 → 마크다운 이론서 열람 (간이 렌더러)
class TheoryScreen extends StatelessWidget {
  const TheoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('핵심이론서 (빈출도 반영)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${StudyData.instance.track.bankLabel} ${StudyData.instance.track.questionCountLabel}문제 빈출 분석을 반영한 과목별 핵심이론서입니다. '
            '실기 연계 포인트도 함께 정리했습니다.',
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < kSubjects.length; i++)
            Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${i + 1}')),
                title: Text(kSubjects[i]),
                subtitle: const Text('빈출 토픽 순위 · 공식 · 암기법 · 강의링크 포함'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TheoryViewer(subject: kSubjects[i]),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class TheoryViewer extends StatefulWidget {
  final String subject;
  const TheoryViewer({super.key, required this.subject});

  @override
  State<TheoryViewer> createState() => _TheoryViewerState();
}

class _TheoryViewerState extends State<TheoryViewer> {
  String? _content;
  String? _loadError;
  bool _startingQuiz = false;

  @override
  void initState() {
    super.initState();
    StudyData.instance
        .loadTheory(widget.subject)
        .then((value) {
          if (!mounted) return;
          setState(() {
            _content = value;
            if (value.contains('불러올 수 없습니다')) {
              _loadError = '이론 자료를 불러오지 못했습니다.';
            }
          });
        })
        .catchError((Object error) {
          if (!mounted) return;
          setState(() => _loadError = '이론 자료를 불러오지 못했습니다.');
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.subject)),
      body: _loadError != null
          ? _errorView()
          : _content == null
          ? const Center(child: CircularProgressIndicator())
          : Scrollbar(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _learningLoopGuide(context),
                  const SizedBox(height: 8),
                  ..._renderMarkdown(context, _content!),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _startingQuiz ? null : _startBasicQuiz,
                    icon: _startingQuiz
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.quiz_outlined),
                    label: Text(_startingQuiz ? '기초 문제 준비 중…' : '이론을 문제로 확인하기'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _learningLoopGuide(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.sync_rounded, color: scheme.onSecondaryContainer),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '기초를 짧게 읽고 문제로 확인하세요. 막히면 문제 해설의 '
              '‘기초이론 다시 보기’로 돌아올 수 있습니다.',
              style: TextStyle(fontSize: 12.5, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 42),
            const SizedBox(height: 12),
            Text(_loadError!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () {
                setState(() {
                  _loadError = null;
                  _content = null;
                });
                StudyData.instance.loadTheory(widget.subject).then((value) {
                  if (mounted) setState(() => _content = value);
                });
              },
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startBasicQuiz() async {
    if (_startingQuiz) return;
    setState(() => _startingQuiz = true);
    try {
      final questions = await StudyData.instance.questionsByDifficulty(
        widget.subject,
        easyFirst: true,
      );
      if (!mounted) return;
      if (questions.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('연결된 기초 문제가 없습니다.')));
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QuizPlayScreen(
            title: '${widget.subject} 기초 확인 10문제',
            questions: questions.take(10).toList(),
            examMode: false,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _startingQuiz = false);
    }
  }

  /// 초경량 마크다운 렌더러 (외부 패키지 불필요)
  List<Widget> _renderMarkdown(BuildContext context, String md) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final widgets = <Widget>[];
    final lines = md.split('\n');
    var inCode = false;
    final codeBuf = StringBuffer();
    List<String>? tableBuf;

    void flushTable() {
      if (tableBuf == null || tableBuf!.isEmpty) return;
      final rows = tableBuf!
          .where((l) => !RegExp(r'^\s*\|[\s\-:|]+\|\s*$').hasMatch(l))
          .map(
            (l) => l
                .trim()
                .replaceAll(RegExp(r'^\||\|$'), '')
                .split('|')
                .map((c) => c.trim().replaceAll('**', ''))
                .toList(),
          )
          .toList();
      if (rows.isEmpty) {
        tableBuf = null;
        return;
      }
      final colCount = rows
          .map((r) => r.length)
          .reduce((a, b) => a > b ? a : b);
      widgets.add(
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              border: TableBorder.all(color: scheme.outlineVariant, width: 0.7),
              children: [
                for (var r = 0; r < rows.length; r++)
                  TableRow(
                    decoration: BoxDecoration(
                      color: r == 0 ? scheme.surfaceContainerHighest : null,
                    ),
                    children: [
                      for (var c = 0; c < colCount; c++)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          child: Text(
                            c < rows[r].length ? rows[r][c] : '',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: r == 0
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
      tableBuf = null;
    }

    for (final raw in lines) {
      final line = raw.trimRight();

      if (line.startsWith('```')) {
        if (inCode) {
          widgets.add(
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                codeBuf.toString().trimRight(),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          );
          codeBuf.clear();
        }
        inCode = !inCode;
        continue;
      }
      if (inCode) {
        codeBuf.writeln(raw);
        continue;
      }

      if (line.trimLeft().startsWith('|')) {
        tableBuf ??= [];
        tableBuf!.add(line);
        continue;
      } else {
        flushTable();
      }

      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 6));
      } else if (line.startsWith('# ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            child: Text(
              _strip(line.substring(2)),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      } else if (line.startsWith('## ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 4),
            child: Text(
              _strip(line.substring(3)),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.primary,
              ),
            ),
          ),
        );
      } else if (line.startsWith('### ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 3),
            child: Text(
              _strip(line.substring(4)),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      } else if (line.startsWith('> ')) {
        widgets.add(
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border(left: BorderSide(color: scheme.primary, width: 3)),
            ),
            child: Text(
              _strip(line.substring(2)),
              style: const TextStyle(height: 1.5, fontSize: 14),
            ),
          ),
        );
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(
                  child: Text(
                    _strip(line.substring(2)),
                    style: const TextStyle(height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (line == '---') {
        widgets.add(const Divider(height: 20));
      } else {
        widgets.add(Text(_strip(line), style: const TextStyle(height: 1.6)));
      }
    }
    flushTable();
    widgets.add(const SizedBox(height: 32));
    return widgets;
  }

  String _strip(String s) => s.replaceAll('**', '').replaceAll('`', '');
}
