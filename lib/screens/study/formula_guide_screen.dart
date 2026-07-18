import 'package:flutter/material.dart';
import '../../services/study_data.dart';
import '../../widgets/tutor_avatar.dart';

/// 공식 마스터 화면 — 읽는법·기호뜻·비유이해·암기법·기출예제 + 초보자 기초사전
class FormulaGuideScreen extends StatefulWidget {
  const FormulaGuideScreen({super.key});

  @override
  State<FormulaGuideScreen> createState() => _FormulaGuideScreenState();
}

class _FormulaGuideScreenState extends State<FormulaGuideScreen>
    with SingleTickerProviderStateMixin {
  FormulaGuideData? _data;
  List<BasicTerm> _commonBasics = const [];
  List<String> _commonCats = const [];
  late final TabController _tab;
  String _subject = '전체';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    StudyData.instance.loadFormulaGuide().then((v) {
      if (mounted) setState(() => _data = v);
    });
    // 전 종목 공통 왕초보 기초사전(300+ 용어) 로드
    StudyData.instance.loadBasicsDict().then((v) {
      if (mounted) {
        setState(() {
          _commonBasics = v;
          _commonCats = StudyData.instance.basicsCategories;
        });
      }
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      appBar: AppBar(
        title: const Text('공식 마스터'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: '공식 이해·암기'),
            Tab(text: '왕초보 기초사전'),
          ],
        ),
      ),
      body: data == null
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tab,
              children: [_formulaTab(context, data), _basicsTab(context, data)],
            ),
    );
  }

  Widget _formulaTab(BuildContext context, FormulaGuideData data) {
    final subjects = <String>['전체', ...kSubjects];
    final items = _subject == '전체'
        ? data.formulas
        : data.formulas.where((f) => f.subject == _subject).toList();

    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width > 900
            ? (MediaQuery.of(context).size.width - 800) / 2
            : 16,
        vertical: 12,
      ),
      children: [
        TutorBanner(
          mood: TutorMood.teaching,
          message: data.intro.isNotEmpty
              ? data.intro
              : '공식은 이해하면 자동으로 외워져요! 읽는법, 기호뜻, 비유, 암기법, 예제 순서로 정복하세요.',
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: subjects.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (context, i) {
              final s = subjects[i];
              return ChoiceChip(
                label: Text(
                  s == '전체' ? s : s.substring(0, 4),
                  style: const TextStyle(fontSize: 12),
                ),
                selected: s == _subject,
                onSelected: (_) => setState(() => _subject = s),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        ...items.map((f) => _formulaCard(context, f)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _formulaCard(BuildContext context, FormulaGuide f) {
    final cs = Theme.of(context).colorScheme;
    final stars = '★' * f.importance;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        title: Text(
          f.name,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                f.expr,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${f.subject.length > 4 ? f.subject.substring(0, 4) : f.subject} · ${f.topic}  $stars',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _step(context, '1', '🗣 소리내어 읽기', f.read, Colors.blue),
          if (f.symbols.isNotEmpty) ...[
            const SizedBox(height: 8),
            _stepHeader(context, '2', '🔤 기호 하나씩 뜯어보기', Colors.indigo),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.indigo.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.indigo.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: f.symbols
                    .map(
                      (s) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 56,
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.indigo.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                s.sym,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.indigo,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                s.meaning,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          const SizedBox(height: 8),
          _step(context, '3', '💡 비유로 이해하기', f.understand, Colors.teal),
          const SizedBox(height: 8),
          _step(context, '4', '🧠 암기법', f.mnemonic, Colors.deepOrange),
          const SizedBox(height: 8),
          _step(context, '5', '✏️ 기출 포인트·예제', f.example, Colors.purple),
        ],
      ),
    );
  }

  Widget _stepHeader(
    BuildContext context,
    String num,
    String title,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            num,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _step(
    BuildContext context,
    String num,
    String title,
    String body,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(context, num, title, color),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: SelectableText(
            body,
            style: const TextStyle(fontSize: 13, height: 1.55),
          ),
        ),
      ],
    );
  }

  Widget _basicsTab(BuildContext context, FormulaGuideData data) {
    final cs = Theme.of(context).colorScheme;
    // 트랙별 basics + 전 종목 공통 사전(312개) 병합. term 기준 중복 제거.
    final seen = <String>{};
    final merged = <BasicTerm>[];
    for (final b in [...data.basics, ..._commonBasics]) {
      final key = b.term.trim();
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      merged.add(b);
    }
    final groups = <String, List<BasicTerm>>{};
    for (final b in merged) {
      groups.putIfAbsent(b.category, () => []).add(b);
    }
    // 카테고리 정렬: 공통 사전 순서 우선, 그 외는 뒤에
    final orderedCats = <String>[
      ..._commonCats.where(groups.containsKey),
      ...groups.keys.where((c) => !_commonCats.contains(c)),
    ];
    final orderedGroups = <String, List<BasicTerm>>{
      for (final c in orderedCats) c: groups[c]!,
    };

    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width > 900
            ? (MediaQuery.of(context).size.width - 800) / 2
            : 16,
        vertical: 12,
      ),
      children: [
        TutorBanner(
          mood: TutorMood.happy,
          message:
              '전기가 처음이라면 여기부터! 단위·기호·핵심개념 ${merged.length}개를 한 곳에 모았어요. V·A·Ω부터 ε·ω·θ 읽는 법까지 — 기초가 잡히면 공식이 무섭지 않아요.',
        ),
        const SizedBox(height: 10),
        ...orderedGroups.entries.expand(
          (e) => [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 6),
              child: Text(
                e.key,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: cs.primary,
                ),
              ),
            ),
            ...e.value.map(
              (b) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ExpansionTile(
                  title: Text(
                    b.term,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    b.easy,
                    style: const TextStyle(fontSize: 12.5, height: 1.4),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.secondaryContainer.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: SelectableText(
                        b.detail,
                        style: const TextStyle(fontSize: 13, height: 1.55),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
