import 'package:flutter/material.dart';
import '../../services/study_data.dart';
import '../../services/flashcard_srs.dart';
import 'flashcard_screen.dart';
import '../../widgets/persistent_nav.dart';

/// 암기법 사전: 과목별 필터 + 검색
class MnemonicsScreen extends StatefulWidget {
  const MnemonicsScreen({super.key});

  @override
  State<MnemonicsScreen> createState() => _MnemonicsScreenState();
}

class _MnemonicsScreenState extends State<MnemonicsScreen> {
  List<Mnemonic>? _all;
  String _filter = '전체';
  String _search = '';
  int _dueCount = 0;

  @override
  void initState() {
    super.initState();
    _loadDue();
    StudyData.instance.loadMnemonics().then((v) {
      if (mounted) setState(() => _all = v);
    });
  }

  Future<void> _loadDue() async {
    final due = await FlashcardSrs.instance.dueKeys();
    if (mounted) setState(() => _dueCount = due.length);
  }

  Future<void> _openFlashcards() async {
    await pushWithNav(context, FlashcardScreen(
        subjectFilter: _filter == '전체' ? null : _filter,
      ), currentSection: 1);
    _loadDue();
  }

  @override
  Widget build(BuildContext context) {
    final all = _all;
    final filters = ['전체', ...kSubjects, '공통'];
    final list = all == null
        ? <Mnemonic>[]
        : all.where((m) {
            final okSubject = _filter == '전체' || m.subject == _filter;
            final okSearch = _search.isEmpty ||
                m.title.contains(_search) ||
                m.body.contains(_search);
            return okSubject && okSearch;
          }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('암기법 사전 (시간절약 지름길)')),
      floatingActionButton: all == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _openFlashcards,
              icon: const Text('🃏', style: TextStyle(fontSize: 18)),
              label: Text(_dueCount > 0 ? '플래시카드 ($_dueCount)' : '플래시카드로 외우기'),
            ),
      body: all == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Material(
                    color: Colors.deepPurple.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _openFlashcards,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.deepPurple.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Text('🃏',
                                  style: TextStyle(fontSize: 20)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _dueCount > 0
                                        ? '플래시카드 암기 모드 · 오늘 $_dueCount개 복습'
                                        : '플래시카드 암기 모드로 쏙쏙 외우기',
                                    style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.deepPurple),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    '탭해서 뒤집기 → 안다/모른다 → 자동 복습 스케줄링',
                                    style: TextStyle(
                                        fontSize: 11.5, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.play_circle_fill,
                                color: Colors.deepPurple, size: 30),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: '키워드 검색 (예: 피뢰기, 접지, 결선)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      for (final f in filters)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(f, style: const TextStyle(fontSize: 12)),
                            selected: _filter == f,
                            onSelected: (_) => setState(() => _filter = f),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: list.isEmpty
                      ? const Center(child: Text('검색 결과가 없습니다.'))
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: list.length,
                          itemBuilder: (_, i) {
                            final m = list[i];
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(m.title,
                                              style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.bold)),
                                        ),
                                        Chip(
                                          label: Text(m.subject,
                                              style: const TextStyle(
                                                  fontSize: 10)),
                                          visualDensity:
                                              VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(m.body,
                                        style:
                                            const TextStyle(height: 1.55)),
                                    if (m.tip.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primaryContainer
                                              .withValues(alpha: 0.5),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text('💡 ${m.tip}',
                                            style: const TextStyle(
                                                fontSize: 12.5,
                                                height: 1.4)),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
