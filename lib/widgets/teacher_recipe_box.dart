import 'package:flutter/material.dart';
import '../services/study_data.dart';

/// 🧑‍🏫 만능 선생님 풀이 레시피 박스
/// 모든 페이지(기출풀이·강의·슬라이드)에서 재사용:
/// ① 문제 유형 판별 체크 → ② 풀이 순서(단계별) → ③ 공식 + 적용 방법 → ④ 암기법(이론과 공존)
class TeacherRecipeBox extends StatelessWidget {
  final String topic;
  final String subject;
  final bool initiallyExpanded;
  final bool showMnemonics;

  const TeacherRecipeBox({
    super.key,
    required this.topic,
    required this.subject,
    this.initiallyExpanded = true,
    this.showMnemonics = true,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_RecipeBundle>(
      future: _load(),
      builder: (context, snap) {
        final data = snap.data;
        if (data == null || (data.recipe == null && data.mnemonics.isEmpty)) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (data.recipe != null) _recipeCard(context, data.recipe!),
            if (showMnemonics && data.mnemonics.isNotEmpty)
              _mnemonicCard(context, data.mnemonics),
          ],
        );
      },
    );
  }

  Future<_RecipeBundle> _load() async {
    final sd = StudyData.instance;
    await sd.loadRecipes();
    final recipe = sd.recipeForTopic(topic);
    List<Mnemonic> mnems = const [];
    if (showMnemonics) {
      final all = await sd.loadMnemonics();
      mnems = all
          .where((m) =>
              m.subject == subject ||
              m.subject == '공통' ||
              m.title.contains(topic) ||
              m.body.contains(topic))
          .toList();
      // 토픽 직접 언급 암기법 우선, 최대 3개만 (과다 노출 방지)
      mnems.sort((a, b) {
        final at = a.title.contains(topic) || a.body.contains(topic) ? 0 : 1;
        final bt = b.title.contains(topic) || b.body.contains(topic) ? 0 : 1;
        return at.compareTo(bt);
      });
      if (mnems.length > 3) mnems = mnems.sublist(0, 3);
    }
    return _RecipeBundle(recipe, mnems);
  }

  // ── ① 풀이 레시피 카드 ────────────────────────────────
  Widget _recipeCard(BuildContext context, SolutionRecipe r) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
        color: scheme.surface,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: const Text('🧑‍🏫', style: TextStyle(fontSize: 22)),
          title: Text('풀이 레시피 — $topic',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: scheme.primary)),
          subtitle: const Text('공식이 어떻게 적용되는지 + 풀이 순서',
              style: TextStyle(fontSize: 11)),
          children: [
            // ✓ 유형 판별 체크
            if (r.check.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.teal.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.fact_check,
                        size: 16, color: Colors.teal),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('먼저 확인: ${r.check}',
                          style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.45,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            // 풀이 순서 (번호 스텝)
            if (r.steps.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text('풀이 순서',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: scheme.primary)),
              ),
              const SizedBox(height: 6),
              for (var i = 0; i < r.steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Text('${i + 1}',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: scheme.onPrimary)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(r.steps[i],
                            style: const TextStyle(
                                fontSize: 12.5, height: 1.45)),
                      ),
                    ],
                  ),
                ),
            ],
            // 공식 + 적용법
            if (r.formulas.isNotEmpty) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('공식 & 적용 방법',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: scheme.primary)),
              ),
              const SizedBox(height: 6),
              for (final f in r.formulas)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.expr,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              height: 1.4)),
                      if (f.how.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('적용: ${f.how}',
                            style: TextStyle(
                                fontSize: 12,
                                height: 1.45,
                                color: scheme.onSurfaceVariant)),
                      ],
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  // ── ② 암기법 카드 (이론과 공존) ────────────────────────
  Widget _mnemonicCard(BuildContext context, List<Mnemonic> mnems) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
        color: Colors.amber.withValues(alpha: 0.06),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: const Text('🔑', style: TextStyle(fontSize: 20)),
          title: const Text('함께 외우기 — 관련 암기법',
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange)),
          subtitle: Text('${mnems.length}개 · 이론 이해 + 암기 동시 공략',
              style: const TextStyle(fontSize: 11)),
          children: [
            for (final m in mnems)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m.title,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(m.body,
                        style: const TextStyle(fontSize: 12.5, height: 1.5)),
                    if (m.tip.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('💡 ${m.tip}',
                          style: TextStyle(
                              fontSize: 11.5,
                              height: 1.4,
                              color: Colors.orange.shade800)),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RecipeBundle {
  final SolutionRecipe? recipe;
  final List<Mnemonic> mnemonics;
  _RecipeBundle(this.recipe, this.mnemonics);
}
