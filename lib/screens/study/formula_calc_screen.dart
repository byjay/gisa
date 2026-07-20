import 'package:flutter/material.dart';
import '../../services/formula_calculators.dart';
import '../../widgets/persistent_nav.dart';
import '../../widgets/tutor_coach.dart';
import '../../widgets/help_dot.dart';

/// 공식 계산기 목록 (전기 또는 소방)
class FormulaCalcListScreen extends StatelessWidget {
  final String title;
  final List<FormulaCalc> calcs;
  final String bannerMsg;
  const FormulaCalcListScreen({
    super.key,
    required this.title,
    required this.calcs,
    required this.bannerMsg,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // 카테고리별 그룹핑
    final byCat = <String, List<FormulaCalc>>{};
    for (final c in calcs) {
      byCat.putIfAbsent(c.category, () => []).add(c);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: HelpDot(
              size: 22,
              title: '공식 계산기 안내',
              body: '값만 입력하면 시험에 자주 나오는 계산 문제를 자동으로 풀어주는 기능이에요.\n\n'
                  '📂 카테고리별 정리 — 관련된 공식끼리 묶어서 필요한 계산기를 빠르게 찾을 수 있어요.\n\n'
                  '🧮 값을 넣으면 계산 과정과 정답이 함께 나와서, 공식을 눈으로 확인하면서 원리도 이해할 수 있어요.\n\n'
                  '💡 실제 시험에서 계산기가 없을 때를 대비해, 계산 과정을 손으로도 한 번씩 따라 써보세요!',
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width > 800
              ? (MediaQuery.of(context).size.width - 680) / 2
              : 14,
          vertical: 14,
        ),
        children: [
          DynamicTutorBanner(
            situation: CoachSituation.formula,
            overrideMessage: bannerMsg,
          ),
          const SizedBox(height: 14),
          for (final entry in byCat.entries) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
              child: Text(
                entry.key,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: cs.primary,
                ),
              ),
            ),
            ...entry.value.map((c) => _calcTile(context, c)),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _calcTile(BuildContext context, FormulaCalc c) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.calculate_rounded, color: cs.primary),
        title: Text(
          c.title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          c.formula,
          style: TextStyle(
            fontSize: 11.5,
            color: cs.onSurface.withValues(alpha: 0.6),
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => pushWithNav(
          context,
          FormulaCalcDetailScreen(calc: c),
          currentSection: 1,
        ),
      ),
    );
  }
}

/// 공식 계산기 상세 — 입력 필드 + 계산 결과
class FormulaCalcDetailScreen extends StatefulWidget {
  final FormulaCalc calc;
  const FormulaCalcDetailScreen({super.key, required this.calc});

  @override
  State<FormulaCalcDetailScreen> createState() =>
      _FormulaCalcDetailScreenState();
}

class _FormulaCalcDetailScreenState extends State<FormulaCalcDetailScreen> {
  late final Map<String, TextEditingController> _ctrls;
  List<CalcResult> _results = [];

  @override
  void initState() {
    super.initState();
    _ctrls = {
      for (final f in widget.calc.fields)
        f.key: TextEditingController(
          text: f.defaultValue == 0 ? '' : _num(f.defaultValue),
        ),
    };
    _recompute();
  }

  String _num(double v) {
    var s = v.toString();
    if (s.endsWith('.0')) s = s.substring(0, s.length - 2);
    return s;
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _recompute() {
    final m = <String, double>{};
    for (final f in widget.calc.fields) {
      m[f.key] = double.tryParse(_ctrls[f.key]!.text.trim()) ?? 0;
    }
    setState(() => _results = widget.calc.compute(m));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final calc = widget.calc;
    return Scaffold(
      appBar: AppBar(
        title: Text(calc.title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: HelpDot(
              size: 22,
              title: '${calc.title} 계산기 안내',
              body: '이 공식에 필요한 값을 입력하면 자동으로 계산 과정과 정답을 보여줘요.\n\n'
                  '✏️ 각 입력칸에 조건에 맞는 숫자를 넣으면 실시간으로 결과가 계산돼요.\n\n'
                  '📐 계산 과정도 함께 표시되니, 눈으로 원리를 확인하며 공식을 외워보세요.\n\n'
                  '💡 시험장에서는 계산기가 없을 수 있으니, 손으로 직접 풀어보는 연습도 함께 하면 좋아요!',
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width > 800
              ? (MediaQuery.of(context).size.width - 680) / 2
              : 14,
          vertical: 14,
        ),
        children: [
          // 수식 + 설명
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  calc.formula,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  calc.desc,
                  style: const TextStyle(fontSize: 12.5, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '입력값',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 8),
          ...calc.fields.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: _ctrls[f.key],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                onChanged: (_) => _recompute(),
                decoration: InputDecoration(
                  labelText: f.label,
                  suffixText: f.unit.isNotEmpty ? f.unit : null,
                  filled: true,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Results
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFF445544),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              '계산 결과',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (_results.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '값을 입력하면 결과가 표시됩니다.',
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6)),
              ),
            )
          else
            ..._results.map(
              (r) => Container(
                margin: const EdgeInsets.only(bottom: 5),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.label,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      r.value,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: cs.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      r.unit,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
