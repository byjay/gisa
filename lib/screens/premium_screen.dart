import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/entitlement_service.dart';

/// 💎 프리미엄 구독 안내(페이월) 화면.
///
/// 무료 vs 프리미엄 기능을 비교하고 구독을 유도한다. 실제 결제는 Google Play
/// 인앱 결제로 처리하며, 영수증은 서버(Cloudflare Worker)가 검증한 뒤 구독
/// 상태를 확정한다(이 화면은 결제 시작점 + 후킹 UX 담당).
class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key, this.hookMessage});

  /// 어떤 잠금에서 넘어왔는지 상단에 강조할 후킹 메시지.
  final String? hookMessage;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final ent = context.watch<EntitlementService>();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 200,
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                'Gisaclub 프리미엄',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                  ),
                ),
                child: const Center(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 40),
                    child: Text('💎', style: TextStyle(fontSize: 64)),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hookMessage != null) ...[
                    _hookCard(cs, hookMessage!),
                    const SizedBox(height: 18),
                  ],
                  Text(
                    '합격까지, 잠금 없이 전부',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '무료로도 시작할 수 있어요. 프리미엄이면 기출 전체와 AI 선생님을 '
                    '제한 없이 활용해 합격 확률을 끌어올립니다.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: cs.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _compareTable(context),
                  const SizedBox(height: 22),
                  _featureHighlights(cs),
                  const SizedBox(height: 24),
                  if (ent.isPremium)
                    _activeCard(cs, ent)
                  else
                    _subscribeButtons(context),
                  const SizedBox(height: 16),
                  Text(
                    '구독은 Google Play를 통해 결제되며 언제든 해지할 수 있어요. '
                    '결제 정보는 서버에서 안전하게 검증됩니다.',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.5,
                      color: cs.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hookCard(ColorScheme cs, String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_open_rounded, color: Color(0xFFB45309)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFFB45309),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compareTable(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final rows = <(String, String, String)>[
      ('기출문제 열람', '10%만', '100% 전체'),
      ('AI 선생님 질문', '하루 5회·짧은 답변', '무제한 · 심화 추론'),
      ('AI 오답 분석', '요약만', '문항별 상세 진단'),
      ('기출 빈도 분석', '기본 요약', '변형 패턴·재출제 추적'),
      ('속독 답외우기', '기본 모드', '강화 모드(스피드런)'),
      ('합격 예측', '제공', '정밀 예측 + 취약점 리포트'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              children: [
                const Expanded(flex: 4, child: SizedBox()),
                Expanded(
                  flex: 3,
                  child: Text(
                    '무료',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                const Expanded(
                  flex: 3,
                  child: Text(
                    '💎 프리미엄',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12.5,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...rows.map((r) => _compareRow(cs, r.$1, r.$2, r.$3)),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _compareRow(
    ColorScheme cs,
    String label,
    String free,
    String premium,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              free,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: cs.onSurface.withValues(alpha: 0.55),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              premium,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF4F46E5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureHighlights(ColorScheme cs) {
    final items = <(String, String, String)>[
      ('🚀', '기출 전체 해금', '과목·회차별 모든 기출문제와 해설을 제한 없이'),
      ('🤖', 'AI 선생님 무제한', '심화 추론으로 오답의 근본 원인까지 1:1 코칭'),
      ('📊', '변형 출제 추적', '같은 개념이 어떻게 바뀌어 재출제되는지 패턴 분석'),
      ('⚡', '속독 스피드런', '고빈출 문항 답 외우기를 초단위로 훈련'),
    ];
    return Column(
      children: items
          .map(
            (it) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(it.$1, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          it.$2,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          it.$3,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: cs.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _subscribeButtons(BuildContext context) {
    return Column(
      children: [
        _planButton(
          context,
          title: '연간 구독',
          price: '₩39,000 / 년',
          sub: '월 3,250원 · 2개월 무료 혜택',
          highlight: true,
        ),
        const SizedBox(height: 10),
        _planButton(
          context,
          title: '월간 구독',
          price: '₩4,900 / 월',
          sub: '언제든 해지 가능',
          highlight: false,
        ),
      ],
    );
  }

  Widget _planButton(
    BuildContext context, {
    required String title,
    required String price,
    required String sub,
    required bool highlight,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: highlight ? const Color(0xFF4F46E5) : cs.surface,
      borderRadius: BorderRadius.circular(16),
      elevation: highlight ? 4 : 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _startPurchase(context, title),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: highlight ? null : Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: highlight ? Colors.white : cs.onSurface,
                          ),
                        ),
                        if (highlight) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'BEST',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      sub,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: highlight
                            ? Colors.white.withValues(alpha: 0.85)
                            : cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                price,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: highlight ? Colors.white : const Color(0xFF4F46E5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _activeCard(ColorScheme cs, EntitlementService ent) {
    final exp = ent.expiry;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          const Icon(Icons.verified_rounded, color: Colors.teal, size: 40),
          const SizedBox(height: 8),
          const Text(
            '프리미엄 이용 중',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.teal,
            ),
          ),
          if (exp != null) ...[
            const SizedBox(height: 4),
            Text(
              '만료: ${exp.year}.${exp.month}.${exp.day}',
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _startPurchase(BuildContext context, String plan) {
    // 실제 결제는 Google Play Billing으로 연결 예정.
    // 서버(Cloudflare Worker)가 영수증을 검증해 구독을 확정한다.
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shopping_cart_rounded,
              size: 40,
              color: Color(0xFF4F46E5),
            ),
            const SizedBox(height: 12),
            Text(
              '$plan 결제',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              '결제 연동(Google Play 인앱 결제)은 스토어 등록 후 활성화됩니다. '
              '결제 완료 시 서버 검증을 거쳐 프리미엄이 자동 적용돼요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, height: 1.5),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('확인'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
