import 'package:flutter/material.dart';

/// 🎨 상업화 수준 프리미엄 디자인 시스템
/// - 브랜드 컬러: 딥 인디고 + 일렉트릭 바이올렛 (전기기사 아이덴티티)
/// - 세련된 그라디언트, 부드러운 그림자, 일관된 라운딩
class AppTheme {
  AppTheme._();

  // ── Brand Colors ────────────────────────────────
  static const Color primary = Color(0xFF4F46E5); // Indigo 600
  static const Color primaryDark = Color(0xFF3730A3); // Indigo 800
  static const Color accent = Color(0xFF7C3AED); // Violet 600
  static const Color electric = Color(0xFF06B6D4); // Cyan 500 (전기 포인트)

  static const Color success = Color(0xFF059669); // Emerald 600
  static const Color warning = Color(0xFFD97706); // Amber 600
  static const Color danger = Color(0xFFDC2626); // Red 600

  // ── Surfaces ────────────────────────────────────
  static const Color bgLight = Color(0xFFF6F7FB);
  static const Color cardLight = Colors.white;
  static const Color bgDark = Color(0xFF0F1117);
  static const Color cardDark = Color(0xFF1A1D27);

  // ── Text ────────────────────────────────────────
  static const Color textStrong = Color(0xFF111827);
  static const Color textBody = Color(0xFF374151);
  static const Color textMuted = Color(0xFF6B7280);

  // ── Gradients ───────────────────────────────────
  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
    stops: [0.0, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient electricGradient = LinearGradient(
    colors: [Color(0xFF0891B2), Color(0xFF06B6D4)],
    stops: [0.0, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF047857), Color(0xFF10B981)],
    stops: [0.0, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient dangerGradient = LinearGradient(
    colors: [Color(0xFFB91C1C), Color(0xFFEF4444)],
    stops: [0.0, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [Color(0xFFB45309), Color(0xFFF59E0B)],
    stops: [0.0, 1.0],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// 🕐 시간대별 살아있는 헤더 그라데이션 — 앱이 하루의 리듬을 함께한다
  static LinearGradient timeGradient([DateTime? at]) {
    final h = (at ?? DateTime.now()).hour;
    if (h < 6) {
      // 새벽 — 깊은 남색+보라 (고요한 몰입)
      return const LinearGradient(
        colors: [Color(0xFF1E1B4B), Color(0xFF4C1D95)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (h < 12) {
      // 아침 — 인디고+스카이 (상쾌한 시작)
      return const LinearGradient(
        colors: [Color(0xFF4F46E5), Color(0xFF0EA5E9)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (h < 18) {
      // 오후 — 브랜드 인디고+바이올렛 (집중의 절정)
      return heroGradient;
    } else {
      // 밤 — 바이올렛+로즈 (하루 마무리)
      return const LinearGradient(
        colors: [Color(0xFF6D28D9), Color(0xFFBE185D)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
  }

  // ── Shadows ─────────────────────────────────────
  static List<BoxShadow> softShadow(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) return const [];
    return [
      BoxShadow(
        color: const Color(0xFF4F46E5).withValues(alpha: 0.06),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ];
  }

  static List<BoxShadow> glowShadow(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.35),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  // ── Radius ──────────────────────────────────────
  static const double rSm = 12;
  static const double rMd = 16;
  static const double rLg = 20;
  static const double rXl = 28;

  // ── 테마 팔레트 (10종) ────────────────────────────
  // 사용자가 설정에서 선택. seed 색상으로 전체 톤을 결정하며
  // 브랜드 static const(primary/accent 등)는 포인트 컬러로 유지한다.
  static const List<ThemePalette> palettes = [
    ThemePalette(
      id: 'indigo',
      name: '일렉트릭 인디고',
      emoji: '⚡',
      seed: Color(0xFF4F46E5),
      accent: Color(0xFF7C3AED),
    ),
    ThemePalette(
      id: 'emerald',
      name: '포레스트 에메랄드',
      emoji: '🌿',
      seed: Color(0xFF059669),
      accent: Color(0xFF0D9488),
    ),
    ThemePalette(
      id: 'rose',
      name: '선셋 로즈',
      emoji: '🌸',
      seed: Color(0xFFE11D48),
      accent: Color(0xFFF43F5E),
    ),
    ThemePalette(
      id: 'amber',
      name: '골든 앰버',
      emoji: '🔥',
      seed: Color(0xFFD97706),
      accent: Color(0xFFEA580C),
    ),
    ThemePalette(
      id: 'ocean',
      name: '딥 오션',
      emoji: '🌊',
      seed: Color(0xFF0284C7),
      accent: Color(0xFF06B6D4),
    ),
    ThemePalette(
      id: 'purple',
      name: '로얄 퍼플',
      emoji: '💜',
      seed: Color(0xFF7C3AED),
      accent: Color(0xFFA855F7),
    ),
    ThemePalette(
      id: 'pink',
      name: '베리 핑크',
      emoji: '🍓',
      seed: Color(0xFFDB2777),
      accent: Color(0xFFEC4899),
    ),
    ThemePalette(
      id: 'lime',
      name: '프레쉬 라임',
      emoji: '🍏',
      seed: Color(0xFF65A30D),
      accent: Color(0xFF84CC16),
    ),
    ThemePalette(
      id: 'graphite',
      name: '시크 그래파이트',
      emoji: '🪨',
      seed: Color(0xFF475569),
      accent: Color(0xFF64748B),
    ),
    ThemePalette(
      id: 'teal',
      name: '민트 틸',
      emoji: '🧊',
      seed: Color(0xFF0D9488),
      accent: Color(0xFF14B8A6),
    ),
  ];

  static ThemePalette paletteById(String? id) =>
      palettes.firstWhere((p) => p.id == id, orElse: () => palettes.first);

  // ── ThemeData ───────────────────────────────────
  static ThemeData light([ThemePalette? palette]) {
    final p = palette ?? palettes.first;
    final scheme = ColorScheme.fromSeed(
      seedColor: p.seed,
    ).copyWith(primary: p.seed, secondary: p.accent, surface: cardLight);
    // 팔레트 씨앗이 배경에 은은하게 배어나오도록 — 테마 교체 체감 극대화
    final tintedBg = Color.alphaBlend(p.seed.withValues(alpha: 0.035), bgLight);
    return _base(
      scheme,
      Brightness.light,
      p,
    ).copyWith(scaffoldBackgroundColor: tintedBg);
  }

  static ThemeData dark([ThemePalette? palette]) {
    final p = palette ?? palettes.first;
    final scheme = ColorScheme.fromSeed(
      seedColor: p.seed,
      brightness: Brightness.dark,
    ).copyWith(surface: cardDark);
    final tintedBg = Color.alphaBlend(p.seed.withValues(alpha: 0.05), bgDark);
    return _base(
      scheme,
      Brightness.dark,
      p,
    ).copyWith(scaffoldBackgroundColor: tintedBg);
  }

  static ThemeData _base(
    ColorScheme scheme,
    Brightness brightness,
    ThemePalette p,
  ) {
    final dark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
      fontFamily: 'Pretendard',
      fontFamilyFallback: const ['Noto Sans KR', 'Apple SD Gothic Neo'],
      splashFactory: InkSparkle.splashFactory,
      cardTheme: CardThemeData(
        elevation: 0,
        color: dark
            ? Color.alphaBlend(p.seed.withValues(alpha: 0.04), cardDark)
            : cardLight,
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(vertical: 5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(rMd),
          side: BorderSide(
            color: dark
                ? p.seed.withValues(alpha: 0.14)
                : Color.alphaBlend(
                    p.seed.withValues(alpha: 0.10),
                    const Color(0xFFE8EAF2),
                  ),
          ),
        ),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          color: dark ? Colors.white : textStrong,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark
            ? Colors.white.withValues(alpha: 0.04)
            : p.seed.withValues(alpha: 0.03),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: dark
                ? Colors.white.withValues(alpha: 0.12)
                : p.seed.withValues(alpha: 0.18),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.seed, width: 1.6),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.seed.withValues(alpha: 0.2)),
        ),
      ),
      dialogTheme: DialogThemeData(
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titleTextStyle: TextStyle(
          fontSize: 17.5,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
          color: dark ? Colors.white : textStrong,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.seed,
        linearTrackColor: p.seed.withValues(alpha: 0.12),
        circularTrackColor: p.seed.withValues(alpha: 0.12),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: p.seed,
        foregroundColor: Colors.white,
      ),
      // 모든 기본 아이콘에 동일한 굵기·색·터치 밀도를 적용한다.
      // 개별 화면에서 색을 지정한 아이콘은 그 의도를 보존한다.
      iconTheme: IconThemeData(
        color: dark ? Colors.white70 : const Color(0xFF4B5568),
        size: 22,
        opticalSize: 24,
        weight: 520,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.all(10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          foregroundColor: dark ? Colors.white70 : const Color(0xFF4B5568),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: dark ? Colors.white70 : const Color(0xFF4B5568),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(rSm)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        elevation: 0,
        backgroundColor: dark ? cardDark : Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        indicatorColor: scheme.primary.withValues(alpha: dark ? 0.28 : 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 10.5,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected
                ? scheme.primary
                : (dark ? Colors.white54 : textMuted),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: selected ? 25 : 23,
            opticalSize: 24,
            weight: selected ? 650 : 480,
            color: selected
                ? scheme.primary
                : (dark ? Colors.white54 : textMuted),
          );
        }),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: dark ? Colors.white54 : textMuted,
        indicatorColor: scheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: dark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFE8EAF2),
        overlayColor: WidgetStatePropertyAll(
          scheme.primary.withValues(alpha: 0.06),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(rSm + 2),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: dark
                ? Colors.white.withValues(alpha: 0.1)
                : const Color(0xFFE8EAF2),
          ),
        ),
        backgroundColor: dark ? cardDark : Colors.white,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
      dividerTheme: DividerThemeData(
        color: dark
            ? Colors.white.withValues(alpha: 0.07)
            : const Color(0xFFEDEFF5),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(rSm)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(rXl)),
        ),
      ),
    );
  }
}

/// ── 재사용 프리미엄 위젯들 ──────────────────────────

/// 섹션 헤더 (타이틀 + 서브타이틀 + 액션)
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? emoji;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (emoji != null) ...[
                      Text(emoji!, style: const TextStyle(fontSize: 17)),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: dark ? Colors.white : AppTheme.textStrong,
                        ),
                      ),
                    ),
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: dark ? Colors.white54 : AppTheme.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 프리미엄 카드 컨테이너 (부드러운 그림자 + 보더)
class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final Color? color;
  final double radius;

  const PremiumCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.gradient,
    this.color,
    this.radius = AppTheme.rMd,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final body = Container(
      decoration: BoxDecoration(
        gradient: gradient,
        color: gradient == null
            ? (color ?? (dark ? AppTheme.cardDark : Colors.white))
            : null,
        borderRadius: BorderRadius.circular(radius),
        border: gradient == null
            ? Border.all(
                color: dark
                    ? Colors.white.withValues(alpha: 0.06)
                    : const Color(0xFFE8EAF2),
              )
            : null,
        boxShadow: gradient != null
            ? AppTheme.glowShadow((gradient as LinearGradient).colors.first)
            : AppTheme.softShadow(context),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    return body;
  }
}

/// 아이콘 뱃지 (컬러 배경의 둥근 아이콘)
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;

  const IconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 42,
    this.iconSize = 22,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.32);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.24),
            color.withValues(alpha: 0.07),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: radius,
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: size * 0.13,
            left: size * 0.16,
            child: Container(
              width: size * 0.3,
              height: size * 0.12,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(size),
              ),
            ),
          ),
          Icon(
            icon,
            color: color,
            size: iconSize,
            opticalSize: iconSize,
            weight: 600,
          ),
        ],
      ),
    );
  }
}

/// 작은 라벨 필 (뱃지)
class PillBadge extends StatelessWidget {
  final String text;
  final Color color;
  final bool filled;

  const PillBadge({
    super.key,
    required this.text,
    required this.color,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: filled ? Colors.white : color,
        ),
      ),
    );
  }
}

/// 테마 팔레트 정의 (10종)
class ThemePalette {
  final String id;
  final String name;
  final String emoji;
  final Color seed;
  final Color accent;
  const ThemePalette({
    required this.id,
    required this.name,
    required this.emoji,
    required this.seed,
    required this.accent,
  });
}
