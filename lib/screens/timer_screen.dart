import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  String? _selectedExamId;

  String _fmt(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final running = app.timerRunning;

    return Scaffold(
      appBar: AppBar(title: const Text('학습 타이머')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            children: [
              // ── 시험 선택 카드 ──
              PremiumCard(
                padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                child: Row(
                  children: [
                    const IconBadge(
                        icon: Icons.flag_rounded,
                        color: AppTheme.primary,
                        size: 36,
                        iconSize: 18),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedExamId,
                          isExpanded: true,
                          hint: const Text('학습할 시험 선택 (선택사항)',
                              style: TextStyle(fontSize: 13.5)),
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: dark ? Colors.white : AppTheme.textStrong,
                          ),
                          items: [
                            const DropdownMenuItem<String>(
                                value: null, child: Text('일반 학습')),
                            ...app.exams.map((e) => DropdownMenuItem(
                                  value: e.id,
                                  child: Text(e.name,
                                      overflow: TextOverflow.ellipsis),
                                )),
                          ],
                          onChanged: running
                              ? null
                              : (v) => setState(() => _selectedExamId = v),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // ── 타이머 원형 디스플레이 ──
              Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: running ? AppTheme.heroGradient : null,
                  color: running
                      ? null
                      : (dark ? AppTheme.cardDark : Colors.white),
                  border: running
                      ? null
                      : Border.all(
                          color: dark
                              ? Colors.white.withValues(alpha: 0.08)
                              : const Color(0xFFE8EAF2),
                          width: 2),
                  boxShadow: running
                      ? AppTheme.glowShadow(AppTheme.primary)
                      : AppTheme.softShadow(context),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        running
                            ? Icons.local_fire_department_rounded
                            : Icons.timer_outlined,
                        size: 30,
                        color: running
                            ? Colors.white.withValues(alpha: 0.9)
                            : (dark ? Colors.white38 : AppTheme.textMuted),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _fmt(app.elapsedSeconds),
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: running
                              ? Colors.white
                              : (dark ? Colors.white : AppTheme.textStrong),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: running
                              ? Colors.white.withValues(alpha: 0.18)
                              : (dark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : const Color(0xFFF0F1F7)),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          running ? '집중 중...' : '준비됨',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: running
                                ? Colors.white
                                : (dark
                                    ? Colors.white54
                                    : AppTheme.textMuted),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // ── 컨트롤 버튼 ──
              if (!running)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => app.startTimer(_selectedExamId),
                    icon: const Icon(Icons.play_arrow_rounded, size: 24),
                    label: const Text('학습 시작'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: FilledButton.icon(
                        onPressed: () async {
                          final sec = await app.stopTimer();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      '${(sec / 60).ceil()}분 학습 기록이 저장되었습니다!')),
                            );
                          }
                        },
                        icon: const Icon(Icons.stop_rounded),
                        label: const Text('종료 & 저장'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.danger,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: OutlinedButton(
                        onPressed: app.cancelTimer,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.rSm + 2),
                          ),
                        ),
                        child: const Text('취소'),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 24),

              // ── 오늘 요약 3종 ──
              PremiumCard(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    _stat(context, Icons.today_rounded, '오늘',
                        '${app.todayMinutes}분', AppTheme.primary),
                    _divider(dark),
                    _stat(context, Icons.date_range_rounded, '이번 주',
                        '${app.weekMinutes}분', AppTheme.electric),
                    _divider(dark),
                    _stat(context, Icons.local_fire_department_rounded, '연속',
                        '${app.streak}일', const Color(0xFFF97316)),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── 집중 팁 ──
              PremiumCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Text('💡', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '뽀모도로: 25분 집중 + 5분 휴식을 반복하면 장시간 학습도 지치지 않아요.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.5,
                          color: dark ? Colors.white60 : AppTheme.textBody,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider(bool dark) => Container(
        width: 1,
        height: 40,
        color: dark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFEEF0F7),
      );

  Widget _stat(BuildContext context, IconData icon, String label,
      String value, Color color) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: dark ? Colors.white54 : AppTheme.textMuted)),
        ],
      ),
    );
  }
}
