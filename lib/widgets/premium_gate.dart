import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/entitlement_service.dart';
import '../screens/premium_screen.dart';

/// 💎 프리미엄 전환 후킹 UI 모음.
///
/// 무료 사용자가 잠긴 콘텐츠/기능에 닿을 때 "업그레이드" 유도를 일관된
/// 디자인으로 노출한다. 서버측 권한 검증(EntitlementService/ContentApi)과
/// 별개로, 이 위젯들은 UX 후킹 전용이다.

/// 프리미엄 페이월(구독 안내)로 이동.
Future<void> openPremiumPaywall(BuildContext context, {String? hook}) {
  return Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => PremiumScreen(hookMessage: hook)),
  );
}

/// 🔒 잠긴 콘텐츠 위에 덮는 블러/자물쇠 오버레이 카드.
/// 무료 사용자가 볼 수 없는 문항/기능 자리에 배치한다.
class LockedOverlay extends StatelessWidget {
  const LockedOverlay({
    super.key,
    required this.title,
    this.subtitle,
    this.hook,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final String? hook;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => openPremiumPaywall(context, hook: hook),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(compact ? 14 : 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF4F46E5).withValues(alpha: 0.10),
              const Color(0xFFF59E0B).withValues(alpha: 0.10),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: compact ? 38 : 46,
              height: compact ? 38 : 46,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.lock_rounded,
                color: Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: compact ? 13.5 : 15,
                      color: cs.onSurface,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: compact ? 11.5 : 12.5,
                        color: cs.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFF59E0B)),
          ],
        ),
      ),
    );
  }
}

/// 💎 프리미엄 유도 배너(상단/하단 삽입용, 얇은 형태).
class PremiumHookBanner extends StatelessWidget {
  const PremiumHookBanner({
    super.key,
    required this.message,
    this.cta = '프리미엄 보기',
    this.hook,
  });

  final String message;
  final String cta;
  final String? hook;

  @override
  Widget build(BuildContext context) {
    // 프리미엄 사용자에겐 배너를 숨긴다.
    final isPremium = context.select<EntitlementService, bool>(
      (e) => e.isPremium,
    );
    if (isPremium) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Text('💎', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF4F46E5),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
              ),
            ),
            onPressed: () => openPremiumPaywall(context, hook: hook),
            child: Text(cta),
          ),
        ],
      ),
    );
  }
}

/// 무료 사용자에게 "n번째부터 잠김" 안내를 주는 인라인 칩.
class FreeLimitChip extends StatelessWidget {
  const FreeLimitChip({super.key, required this.allowed, required this.total});
  final int allowed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final isPremium = context.select<EntitlementService, bool>(
      (e) => e.isPremium,
    );
    if (isPremium) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '무료 미리보기 $allowed/$total문항 · 나머지는 프리미엄',
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFFB45309),
        ),
      ),
    );
  }
}
