import 'package:flutter/material.dart';
import '../services/dday_planner.dart';
import '../theme/app_theme.dart';
import '../services/score_history.dart';
import '../services/pass_prediction.dart';
import '../widgets/score_sparkline.dart';

/// 🗓 D-Day 합격 역산 카드 + 📈 점수 추이 그래프.
/// "D-14, 하루 32문제면 60점 도달" — 계획을 파는 화면.
/// "지난 7일 57→68점" — 성장의 증거를 보여주는 화면.
class DDayPlanCard extends StatefulWidget {
  final int dDay;
  const DDayPlanCard({super.key, required this.dDay});

  @override
  State<DDayPlanCard> createState() => _DDayPlanCardState();
}

class _DDayPlanCardState extends State<DDayPlanCard> {
  DDayPlan? _plan;
  List<(DateTime, double, int)> _history = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant DDayPlanCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dDay != widget.dDay) {
      _load();
    }
  }

  Future<void> _load() async {
    final pred = await PassPredictionEngine.instance.predict();
    final p = await DDayPlannerEngine.instance.compute(
      dDay: widget.dDay,
      currentScore: pred.overall,
    );
    final h = await ScoreHistory.instance.recent(days: 14);
    if (mounted) {
      setState(() {
        _plan = p;
        _history = h;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final plan = _plan;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 점수 추이 그래프 ────────────────────────────
        PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const IconBadge(
                    icon: Icons.show_chart_rounded,
                    color: AppTheme.electric,
                    size: 34,
                    iconSize: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '내 성장 그래프',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '최근 14일',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  if (_history.length >= 2)
                    _trendBadge(_history.first.$2, _history.last.$2),
                ],
              ),
              const SizedBox(height: 10),
              ScoreSparkline(
                values: _history.map((e) => e.$2).toList(),
                color: scheme.primary,
              ),
              if (_history.length >= 2) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_history.first.$1.month}/${_history.first.$1.day}',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '오늘',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        // ── D-Day 역산 플랜 ────────────────────────────
        if (plan != null && widget.dDay > 0)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: plan.onTrack
                  ? Colors.green.withValues(alpha: 0.08)
                  : (plan.feasible
                        ? scheme.primaryContainer.withValues(alpha: 0.5)
                        : Colors.red.withValues(alpha: 0.08)),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    (plan.onTrack
                            ? Colors.green
                            : (plan.feasible ? scheme.primary : Colors.red))
                        .withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('🗓', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    const Text(
                      '합격 역산 플랜',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'D-${widget.dDay}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (plan.onTrack)
                  const Text(
                    '🎉 이미 목표 60점을 넘었습니다! 실전 모의고사로 감각을 유지하세요.',
                    style: TextStyle(fontSize: 13, height: 1.5),
                  )
                else
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.6,
                        color: scheme.onSurface,
                      ),
                      children: [
                        const TextSpan(text: '목표 60점까지 '),
                        TextSpan(
                          text: '${plan.pointsNeeded.toStringAsFixed(1)}점',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: scheme.primary,
                          ),
                        ),
                        const TextSpan(text: ' 남음 → 앞으로 '),
                        TextSpan(
                          text: '${plan.questionsNeeded}문제',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: scheme.primary,
                          ),
                        ),
                        const TextSpan(text: ' 더 풀면 도달 가능\n하루 '),
                        TextSpan(
                          text: '${plan.perDay}문제',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.deepOrange,
                          ),
                        ),
                        const TextSpan(text: '씩 풀면 D-Day 전에 합격권입니다'),
                      ],
                    ),
                  ),
                if (!plan.onTrack && !plan.feasible) ...[
                  const SizedBox(height: 8),
                  Text(
                    '⚠ 현재 페이스로는 하루 ${plan.perDay}문제가 필요해 다소 빡빡합니다. '
                    '지금부터 오늘의 처방전을 매일 실행하면 격차를 줄일 수 있어요.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red.shade800,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _trendBadge(double first, double last) {
    final diff = last - first;
    final up = diff > 0.5;
    final down = diff < -0.5;
    final color = up ? Colors.green : (down ? Colors.red : Colors.grey);
    final sign = diff > 0 ? '+' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up
                ? Icons.trending_up
                : (down ? Icons.trending_down : Icons.trending_flat),
            size: 13,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            '$sign${diff.toStringAsFixed(1)}점',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
