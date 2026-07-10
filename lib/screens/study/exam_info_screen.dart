import 'package:flutter/material.dart';
import '../../services/study_data.dart';
import '../../widgets/tutor_avatar.dart';

/// 2026 시험 정보 센터: 일정·D-Day, 출제기준 개정, 합격률 통계,
/// 과목별 전략, 점수 시나리오, CBT 실전 팁
class ExamInfoScreen extends StatefulWidget {
  const ExamInfoScreen({super.key});

  @override
  State<ExamInfoScreen> createState() => _ExamInfoScreenState();
}

class _ExamInfoScreenState extends State<ExamInfoScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _info;
  bool _loading = true;
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
    _load();
  }

  Future<void> _load() async {
    final info = await StudyData.instance.loadExamInfo();
    if (!mounted) return;
    setState(() {
      _info = info;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('2026 시험 정보 센터'),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabs: const [
            Tab(text: '시험일정'),
            Tab(text: '출제기준 개정'),
            Tab(text: 'KEC 2026 개정'),
            Tab(text: '과목별 전략'),
            Tab(text: 'CBT 실전'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _info == null
              ? const Center(child: Text('시험 정보를 불러오지 못했습니다.'))
              : TabBarView(
                  controller: _tab,
                  children: [
                    _scheduleTab(),
                    _criteriaTab(),
                    _kecTab(),
                    _strategyTab(),
                    _cbtTab(),
                  ],
                ),
    );
  }

  // ── Tab 1: 시험일정 ──────────────────────────────────────────
  Widget _scheduleTab() {
    final schedule = (_info!['schedule'] as List).cast<Map<String, dynamic>>();
    final notes = (_info!['scheduleNotes'] as List).cast<String>();
    final target = schedule.firstWhere((s) => s['status'] == 'target',
        orElse: () => schedule.last);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _dDayCard(target),
        const SizedBox(height: 16),
        ...schedule.map(_roundCard),
        const SizedBox(height: 8),
        _noteCard('일정 유의사항', notes, Icons.info_outline, Colors.blueGrey),
        const SizedBox(height: 8),
        Text(
          '출처: ${(_info!['sources'] as List).join(' · ')}',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _dDayCard(Map<String, dynamic> target) {
    final filingIso = target['filingStartIso'] as String?;
    final examIso = target['examStartIso'] as String?;
    final now = DateTime.now();
    int? dFiling, dExam;
    if (filingIso != null) {
      dFiling = DateTime.parse(filingIso).difference(now).inDays;
    }
    if (examIso != null) {
      dExam = DateTime.parse(examIso).difference(now).inDays;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade700, Colors.indigo.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const TutorAvatar(mood: TutorMood.cheer, size: 64),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${target['round']}회차가 올해 마지막 기회!',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const SizedBox(height: 6),
                if (dFiling != null)
                  Text(
                    dFiling >= 0
                        ? '원서접수 시작까지 D-$dFiling'
                        : '원서접수 시작됨 (${target['writtenFiling']})',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                if (dExam != null && dExam >= 0)
                  Text('필기시험 시작까지 D-$dExam',
                      style: TextStyle(
                          color: Colors.amber.shade200,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                const SizedBox(height: 4),
                const Text('접수 첫날 10시에 바로 접수하세요. 인기 시험장은 금방 마감됩니다.',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roundCard(Map<String, dynamic> r) {
    final isTarget = r['status'] == 'target';
    final done = r['status'] == 'done';
    final color = isTarget
        ? Colors.indigo
        : done
            ? Colors.grey
            : Colors.teal;

    Widget row(String label, String? value, {bool bold = false}) {
      if (value == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 92,
                child: Text(label,
                    style: TextStyle(
                        fontSize: 12.5, color: Colors.grey.shade600))),
            Expanded(
              child: Text(value,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                      color: done ? Colors.grey : Colors.black87)),
            ),
          ],
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isTarget
            ? BorderSide(color: color, width: 2)
            : BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${r['round']}회차',
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ),
                const SizedBox(width: 8),
                if (isTarget)
                  const Text('지금 목표로 삼을 회차',
                      style: TextStyle(
                          color: Colors.indigo,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5)),
                if (done)
                  Text('접수 종료',
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 12.5)),
              ],
            ),
            const SizedBox(height: 8),
            row('필기 원서접수', r['writtenFiling'] as String?, bold: isTarget),
            row('', r['writtenFilingExtra'] as String?),
            row('필기 시험', r['writtenExam'] as String?, bold: isTarget),
            row('필기 합격발표', r['writtenResult'] as String?),
            row('실기 원서접수', r['practicalFiling'] as String?),
            row('실기 시험', r['practicalExam'] as String?),
            row('최종 합격발표', r['finalResult'] as String?),
          ],
        ),
      ),
    );
  }

  // ── Tab 2: 출제기준 개정 ─────────────────────────────────────
  Widget _criteriaTab() {
    final c = _info!['criteria2026'] as Map<String, dynamic>;
    final items = (c['items'] as List).cast<Map<String, dynamic>>();
    final passRates = (_info!['passRates'] as List).cast<Map<String, dynamic>>();
    final insights = (_info!['passRateInsights'] as List).cast<String>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.deepOrange.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.deepOrange.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.campaign, color: Colors.deepOrange.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(c['title'] as String,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.deepOrange.shade800)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(c['summary'] as String,
                  style: const TextStyle(fontSize: 13.5, height: 1.5)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...items.map((it) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ExpansionTile(
                leading: const Icon(Icons.rule, color: Colors.deepOrange),
                title: Text(it['title'] as String,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                children: [
                  Text(it['detail'] as String,
                      style: const TextStyle(fontSize: 13.5, height: 1.6)),
                ],
              ),
            )),
        const SizedBox(height: 16),
        const Text('연도별 합격률 (필기 / 실기)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: passRates.map((p) {
                final written = (p['written'] as num).toDouble();
                final practical = (p['practical'] as num).toDouble();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      SizedBox(
                          width: 44,
                          child: Text(p['year'] as String,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13))),
                      Expanded(child: _rateBar('필기', written, Colors.indigo)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _rateBar('실기', practical, Colors.teal)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _noteCard('통계가 말해주는 것', insights, Icons.insights, Colors.indigo),
        const SizedBox(height: 16),
        _passRates2025Card(),
        const SizedBox(height: 16),
        _latestTrendsCard(),
      ],
    );
  }

  Widget _passRates2025Card() {
    final p25 = _info!['passRates2025'] as Map<String, dynamic>;
    final rounds = (p25['rounds'] as List).cast<Map<String, dynamic>>();
    final insights = (p25['insights'] as List).cast<String>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('NEW',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700)),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(p25['title'] as String,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: rounds.map((r) {
                final rate = (r['rate'] as num).toDouble();
                final isPractical = (r['round'] as String).contains('실기');
                final applicants = r['applicants'] as int?;
                final passed = r['passed'] as int?;
                final danger = rate < 15;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 118,
                        child: Text(r['round'] as String,
                            style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600)),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: rate / 100,
                                minHeight: 8,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation(danger
                                    ? Colors.red
                                    : isPractical
                                        ? Colors.teal
                                        : Colors.indigo),
                              ),
                            ),
                            if (applicants != null && passed != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                    '응시 $applicants명 · 합격 $passed명',
                                    style: TextStyle(
                                        fontSize: 10.5,
                                        color: Colors.grey.shade600)),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 52,
                        child: Text(' $rate%',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: danger
                                    ? Colors.red.shade700
                                    : Colors.indigo)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _noteCard('2025 데이터가 주는 신호', insights, Icons.trending_up, Colors.red),
      ],
    );
  }

  Widget _latestTrendsCard() {
    final trends = _info!['latestTrends'] as Map<String, dynamic>;
    final items = (trends['items'] as List).cast<Map<String, dynamic>>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(trends['title'] as String,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        ...items.map((it) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ExpansionTile(
                leading:
                    const Icon(Icons.trending_up, color: Colors.purple),
                title: Text(it['title'] as String,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                children: [
                  Text(it['detail'] as String,
                      style: const TextStyle(fontSize: 13.5, height: 1.6)),
                ],
              ),
            )),
      ],
    );
  }

  // ── Tab 3: KEC 2026 개정 ─────────────────────────────────────
  Widget _kecTab() {
    final kec = _info!['kecChanges2026'] as Map<String, dynamic>;
    final areas = (kec['areas'] as List).cast<Map<String, dynamic>>();
    final mnemonics = (kec['mnemonics'] as List).cast<String>();
    final traps = (kec['trapPoints'] as List).cast<String>();
    final coverage = _info!['dataCoverage'] as Map<String, dynamic>;
    final howTo = (coverage['howToCover'] as List).cast<String>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red.shade700, Colors.deepOrange.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(kec['title'] as String,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(kec['warning'] as String,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13, height: 1.5)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        ...areas.map(_kecAreaCard),
        const SizedBox(height: 8),
        _noteCard('암기법 3종 세트', mnemonics, Icons.psychology, Colors.purple),
        const SizedBox(height: 10),
        _noteCard('시험장 함정 5포인트 (구규정 = 오답)', traps,
            Icons.dangerous, Colors.red),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blueGrey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.fact_check,
                      size: 18, color: Colors.blueGrey.shade700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(coverage['title'] as String,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: Colors.blueGrey.shade800)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(coverage['detail'] as String,
                  style: const TextStyle(fontSize: 12.5, height: 1.55)),
              const SizedBox(height: 8),
              ...howTo.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle,
                            size: 14, color: Colors.blueGrey.shade600),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(t,
                                style: const TextStyle(
                                    fontSize: 12.5, height: 1.5))),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _kecAreaCard(Map<String, dynamic> area) {
    final changes = (area['changes'] as List).cast<Map<String, dynamic>>();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(area['area'] as String,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.deepOrange.shade800)),
            const SizedBox(height: 10),
            ...changes.map((c) {
              final before = c['before'] as String;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c['item'] as String,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (before != '—') ...[
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(before,
                                  style: TextStyle(
                                      fontSize: 12,
                                      decoration:
                                          TextDecoration.lineThrough,
                                      color: Colors.grey.shade600)),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(Icons.arrow_forward,
                                size: 16, color: Colors.deepOrange),
                          ),
                        ],
                        Expanded(
                          flex: before == '—' ? 2 : 1,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: Colors.green.shade200),
                            ),
                            child: Text(c['after'] as String,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade800)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _rateBar(String label, double pct, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label $pct%',
            style: TextStyle(fontSize: 11, color: color)),
        const SizedBox(height: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct / 100,
            minHeight: 7,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }

  // ── Tab 3: 과목별 전략 ──────────────────────────────────────
  Widget _strategyTab() {
    final strategies =
        (_info!['subjectStrategies'] as List).cast<Map<String, dynamic>>();
    final scenarios =
        (_info!['scoreScenarios'] as List).cast<Map<String, dynamic>>();
    final order = _info!['studyOrder'] as Map<String, dynamic>;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const TutorBanner(
          mood: TutorMood.teaching,
          message: '전기기사는 절대평가! 100점이 아니라 "평균 60 + 과목당 40 이상"을 설계하는 시험이에요.',
        ),
        const SizedBox(height: 12),
        const Text('합격 점수 시나리오',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        ...scenarios.map(_scenarioCard),
        const SizedBox(height: 16),
        const Text('과목별 공략법',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        ...strategies.map(_strategyCard),
        const SizedBox(height: 16),
        const Text('추천 학습 순서',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        _orderCard('전공자 루트', (order['major'] as List).cast<String>(),
            Colors.indigo),
        const SizedBox(height: 8),
        _orderCard('비전공자 루트', (order['nonMajor'] as List).cast<String>(),
            Colors.teal),
      ],
    );
  }

  Widget _scenarioCard(Map<String, dynamic> s) {
    final scores = (s['scores'] as Map<String, dynamic>);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(s['name'] as String,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('평균 ${s['average']}점',
                      style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(s['desc'] as String,
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
            const SizedBox(height: 10),
            ...scores.entries.map((e) {
              final v = (e.value as num).toInt();
              final danger = v < 50;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.5),
                child: Row(
                  children: [
                    SizedBox(
                        width: 110,
                        child: Text(e.key,
                            style: const TextStyle(fontSize: 12.5))),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: v / 100,
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation(
                              danger ? Colors.orange : Colors.indigo),
                        ),
                      ),
                    ),
                    SizedBox(
                        width: 38,
                        child: Text(' $v점',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: danger
                                    ? Colors.orange.shade800
                                    : Colors.indigo))),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _strategyCard(Map<String, dynamic> st) {
    final tips = (st['tips'] as List).cast<String>();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(st['subject'] as String,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _miniChip(st['risk'] as String, Colors.red),
              _miniChip('목표 ${st['targetScore']}점', Colors.green),
            ],
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text('우선순위: ${st['priority']}',
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo)),
          ),
          const SizedBox(height: 8),
          ...tips.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ',
                        style: TextStyle(
                            color: Colors.indigo, fontWeight: FontWeight.bold)),
                    Expanded(
                        child: Text(t,
                            style: const TextStyle(
                                fontSize: 13, height: 1.5))),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _miniChip(String text, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, color: color.shade700, fontWeight: FontWeight.w600)),
    );
  }

  Widget _orderCard(String title, List<String> steps, MaterialColor color) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color.shade700)),
            const SizedBox(height: 8),
            ...steps.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 11,
                        backgroundColor: color.shade100,
                        child: Text('${e.key + 1}',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: color.shade800)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(e.value,
                              style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  // ── Tab 4: CBT 실전 ─────────────────────────────────────────
  Widget _cbtTab() {
    final tips = (_info!['cbtTips'] as List).cast<String>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const TutorBanner(
          mood: TutorMood.thinking,
          message: 'CBT는 문제은행에서 사람마다 다른 문제가 나와요. "기출 암기"가 아니라 "유형 대비"가 정답!',
        ),
        const SizedBox(height: 12),
        ...tips.asMap().entries.map((e) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.indigo.shade50,
                  child: Text('${e.key + 1}',
                      style: const TextStyle(
                          color: Colors.indigo, fontWeight: FontWeight.bold)),
                ),
                title: Text(e.value,
                    style: const TextStyle(fontSize: 13.5, height: 1.5)),
              ),
            )),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb, color: Colors.amber, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '이 앱의 "빈출 유형변형 분석" 메뉴에서 같은 유형이 몇 번, 어떻게 변형되어 나왔는지 확인하고, '
                  '"빈출순 풀기"로 출제 확률이 높은 문제부터 정복하세요.',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _noteCard(
      String title, List<String> items, IconData icon, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color.shade700),
              const SizedBox(width: 6),
              Text(title,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: color.shade800)),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ',
                        style: TextStyle(color: color.shade700)),
                    Expanded(
                        child: Text(t,
                            style:
                                const TextStyle(fontSize: 12.5, height: 1.5))),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
