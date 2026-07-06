import 'package:flutter/material.dart';
import '../../services/study_data.dart';

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

  @override
  void initState() {
    super.initState();
    StudyData.instance.loadMnemonics().then((v) {
      if (mounted) setState(() => _all = v);
    });
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
      body: all == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
