import 'package:flutter/material.dart';
import '../../services/study_data.dart';
import '../../widgets/tutor_avatar.dart';
import 'lesson_screen.dart';

/// 실기(필답형) 대비 화면 — 카테고리별 핵심 문답 카드 + 필기 이론 연동
class SilgiScreen extends StatefulWidget {
  const SilgiScreen({super.key});

  @override
  State<SilgiScreen> createState() => _SilgiScreenState();
}

class _SilgiScreenState extends State<SilgiScreen> {
  SilgiData? _data;
  String _category = '전체';

  @override
  void initState() {
    super.initState();
    StudyData.instance.loadSilgi().then((v) {
      if (mounted) setState(() => _data = v);
    });
  }

  static const Map<String, IconData> _catIcons = {
    '수변전설비': Icons.electrical_services_rounded,
    '보호계전': Icons.shield_rounded,
    '전선로': Icons.cable_rounded,
    '시퀀스·PLC': Icons.memory_rounded,
    '조명·동력': Icons.light_rounded,
    '접지·KEC': Icons.public_rounded,
    '측정·시험': Icons.speed_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final cs = Theme.of(context).colorScheme;
    if (data == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('실기 대비')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final categories = <String>['전체'];
    for (final i in data.items) {
      if (!categories.contains(i.category)) categories.add(i.category);
    }
    final items = _category == '전체'
        ? data.items
        : data.items.where((i) => i.category == _category).toList();

    return Scaffold(
      appBar: AppBar(title: Text(data.title.isNotEmpty ? data.title : '실기 대비')),
      body: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width > 900
              ? (MediaQuery.of(context).size.width - 800) / 2
              : 16,
          vertical: 16,
        ),
        children: [
          TutorBanner(
            mood: TutorMood.teaching,
            message: data.overview.isNotEmpty
                ? data.overview
                : '필답형 16~18문항 150분, 60점 합격 (과락 없음). 단답형이 70~85%라서 문답 암기가 답입니다!',
          ),
          const SizedBox(height: 8),
          if (data.strategy.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('실기 합격 전략',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: cs.primary)),
              children: data.strategy
                  .map((s) => Padding(
                        padding:
                            const EdgeInsets.only(left: 4, right: 4, bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('🎯 ', style: TextStyle(fontSize: 13)),
                            Expanded(
                                child: Text(s,
                                    style: const TextStyle(
                                        fontSize: 13, height: 1.4))),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          const SizedBox(height: 8),
          // 카테고리 필터
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final c = categories[i];
                final sel = c == _category;
                return ChoiceChip(
                  label: Text(c, style: const TextStyle(fontSize: 12.5)),
                  selected: sel,
                  onSelected: (_) => setState(() => _category = c),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          ...items.map((it) => _silgiCard(context, it)),
        ],
      ),
    );
  }

  Widget _silgiCard(BuildContext context, SilgiItem it) {
    final cs = Theme.of(context).colorScheme;
    final stars = '★' * it.importance + '☆' * (5 - it.importance);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        leading: Icon(_catIcons[it.category] ?? Icons.bolt_rounded,
            color: cs.primary),
        title: Text(it.title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Row(
          children: [
            Text(it.category,
                style: TextStyle(fontSize: 11.5, color: cs.primary)),
            const SizedBox(width: 8),
            Text(stars,
                style: const TextStyle(fontSize: 11, color: Colors.amber)),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _labelBox(context, 'Q. 문제', it.question, cs.primary),
          const SizedBox(height: 8),
          _labelBox(context, 'A. 모범답안', it.answer, Colors.teal),
          if (it.memo.isNotEmpty) ...[
            const SizedBox(height: 8),
            _labelBox(context, '💡 암기 포인트', it.memo, Colors.orange.shade800),
          ],
          const SizedBox(height: 10),
          if (it.linkSubject.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.link_rounded, size: 16),
                label: Text('필기 이론 연동: ${it.linkSubject}',
                    style: const TextStyle(fontSize: 12)),
                onPressed: () => _openLinkedLesson(it),
              ),
            ),
        ],
      ),
    );
  }

  Widget _labelBox(
      BuildContext context, String label, String body, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 12, color: color)),
          const SizedBox(height: 6),
          SelectableText(body,
              style: const TextStyle(fontSize: 13.5, height: 1.55)),
        ],
      ),
    );
  }

  Future<void> _openLinkedLesson(SilgiItem it) async {
    final lessons = await StudyData.instance.lessonsBySubject(it.linkSubject);
    if (!mounted) return;
    if (lessons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${it.linkSubject} 강의를 찾을 수 없습니다')),
      );
      return;
    }
    // 제목/메모 키워드로 가장 관련있는 강의 찾기
    Lesson best = lessons.first;
    var bestScore = -1;
    final kw = (it.title + it.memo)
        .split(RegExp(r'[·\s,()/]'))
        .where((s) => s.length >= 2)
        .toList();
    for (final l in lessons) {
      var s = 0;
      for (final k in kw) {
        if (l.topic.contains(k)) s += 3;
        if (l.intro.contains(k)) s += 1;
      }
      if (s > bestScore) {
        bestScore = s;
        best = l;
      }
    }
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LessonViewerScreen(lesson: best)),
    );
  }
}
