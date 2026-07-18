import 'package:flutter/material.dart';
import '../../services/unit_converter.dart';
import '../../widgets/persistent_nav.dart';

/// 단위 환산 — 13개 카테고리 목록
class UnitConverterHomeScreen extends StatelessWidget {
  const UnitConverterHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cats = UnitConverter.categories;
    return Scaffold(
      appBar: AppBar(title: const Text('단위 환산')),
      body: ListView.separated(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width > 800
              ? (MediaQuery.of(context).size.width - 680) / 2
              : 14,
          vertical: 14,
        ),
        itemCount: cats.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final c = cats[i];
          return Material(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => pushWithNav(
                context,
                UnitConverterDetailScreen(category: c),
                currentSection: 1,
              ),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: cs.primaryContainer.withValues(alpha: 0.5),
                        border: Border.all(color: cs.primary, width: 1.5),
                      ),
                      child: Text(
                        c.iconText,
                        style: TextStyle(
                          fontSize: c.iconText.length > 2 ? 12 : 17,
                          fontWeight: FontWeight.w900,
                          color: cs.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        c.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: cs.onSurface.withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 단위 환산 상세 — 입력값 + from/to 드롭다운 + Results 표
class UnitConverterDetailScreen extends StatefulWidget {
  final ConvCategory category;
  const UnitConverterDetailScreen({super.key, required this.category});

  @override
  State<UnitConverterDetailScreen> createState() =>
      _UnitConverterDetailScreenState();
}

class _UnitConverterDetailScreenState extends State<UnitConverterDetailScreen> {
  late int _from;
  late int _to;
  final _ctrl = TextEditingController(text: '1');
  double _value = 1;

  @override
  void initState() {
    super.initState();
    _from = widget.category.defaultFrom;
    _to = widget.category.defaultTo.clamp(0, widget.category.units.length - 1);
    _ctrl.addListener(() {
      final v = double.tryParse(_ctrl.text.trim());
      if (v != null) setState(() => _value = v);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double _convert(int fromIdx, int toIdx) {
    if (widget.category.id == 'fuel') {
      return UnitConverter.convertFuel(fromIdx, toIdx, _value);
    }
    return UnitConverter.convert(widget.category, fromIdx, toIdx, _value);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cat = widget.category;
    final targetVal = _convert(_from, _to);
    return Scaffold(
      appBar: AppBar(title: Text(cat.title)),
      body: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width > 800
              ? (MediaQuery.of(context).size.width - 680) / 2
              : 14,
          vertical: 14,
        ),
        children: [
          // 입력값 + from 단위
          _inputRow(
            context,
            label: cat.id == 'temperature'
                ? '온도'
                : cat.id == 'area'
                ? '면적'
                : '입력값',
            controller: _ctrl,
            unitIndex: _from,
            onUnitChange: (v) => setState(() => _from = v),
          ),
          const SizedBox(height: 10),
          // 결과값 + to 단위 (읽기전용)
          _resultRow(
            context,
            label: '원하는',
            value: UnitConverter.fmt(targetVal),
            unitIndex: _to,
            onUnitChange: (v) => setState(() => _to = v),
          ),
          const SizedBox(height: 18),
          // Results 헤더
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFF445544),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Results :',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 4),
          ...List.generate(cat.units.length, (i) {
            final u = cat.units[i];
            final v = _convert(_from, i);
            final highlight = i == _to;
            return Container(
              margin: const EdgeInsets.only(bottom: 3),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: highlight
                    ? cs.primary.withValues(alpha: 0.12)
                    : (i.isEven
                          ? cs.surfaceContainerHighest.withValues(alpha: 0.4)
                          : Colors.transparent),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      UnitConverter.fmt(v),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 96,
                    child: Text(
                      '${u.symbol}  ',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (cat.id == 'fuel') ...[
            const SizedBox(height: 10),
            Text(
              '※ L/100km는 역수 관계로 환산됩니다.',
              style: TextStyle(
                fontSize: 11.5,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _inputRow(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    required int unitIndex,
    required ValueChanged<int> onUnitChange,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: cs.primary)),
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                  ),
                ),
              ],
            ),
          ),
          _unitDropdown(context, unitIndex, onUnitChange),
        ],
      ),
    );
  }

  Widget _resultRow(
    BuildContext context, {
    required String label,
    required String value,
    required int unitIndex,
    required ValueChanged<int> onUnitChange,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: cs.primary)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _unitDropdown(context, unitIndex, onUnitChange),
        ],
      ),
    );
  }

  Widget _unitDropdown(
    BuildContext context,
    int index,
    ValueChanged<int> onChange,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: index,
          isDense: true,
          borderRadius: BorderRadius.circular(10),
          items: List.generate(widget.category.units.length, (i) {
            final u = widget.category.units[i];
            return DropdownMenuItem(
              value: i,
              child: Text(
                u.symbol,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }),
          onChanged: (v) {
            if (v != null) onChange(v);
          },
        ),
      ),
    );
  }
}
