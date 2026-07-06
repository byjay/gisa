import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final theme = Theme.of(context);
    final last7 = app.lastNDaysMinutes(7);
    final maxVal = last7.fold(0, (a, b) => a > b ? a : b);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('통계 & 목표')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Goal progress
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('학습 목표',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _showGoalDialog(context),
                        ),
                      ],
                    ),
                    _goalRow('오늘', app.todayMinutes, app.dailyGoalMinutes,
                        theme.colorScheme.primary),
                    const SizedBox(height: 12),
                    _goalRow('이번 주', app.weekMinutes, app.weeklyGoalMinutes,
                        Colors.teal),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Weekly bar chart
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('최근 7일 학습 시간',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 160,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(7, (i) {
                          final day =
                              now.subtract(Duration(days: 6 - i));
                          final val = last7[i];
                          final h = maxVal > 0 ? (val / maxVal) * 110 : 0.0;
                          final isToday = i == 6;
                          return Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(val > 0 ? '$val' : '',
                                    style: const TextStyle(fontSize: 10)),
                                const SizedBox(height: 4),
                                Container(
                                  height: h < 4 && val > 0 ? 4 : h,
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 6),
                                  decoration: BoxDecoration(
                                    color: isToday
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.primary
                                            .withValues(alpha: 0.4),
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(4)),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(DateFormat('E', 'ko').format(day),
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: isToday
                                            ? FontWeight.bold
                                            : FontWeight.normal)),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Summary stats
            Row(
              children: [
                Expanded(
                    child: _summaryCard('총 학습', _fmtMin(app.totalMinutes),
                        Icons.timer, Colors.indigo)),
                const SizedBox(width: 12),
                Expanded(
                    child: _summaryCard('연속 학습', '${app.streak}일',
                        Icons.local_fire_department, Colors.orange)),
              ],
            ),
            const SizedBox(height: 16),
            // Per-exam breakdown
            if (app.exams.isNotEmpty) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('시험별 학습 시간',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ...app.exams.map((e) {
                        final min = app.minutesForExam(e.id);
                        final total = app.totalMinutes;
                        final ratio = total > 0 ? min / total : 0.0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(e.name),
                                  Text(_fmtMin(min),
                                      style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 12)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: ratio,
                                  minHeight: 6,
                                  backgroundColor: Colors.grey.shade200,
                                  color: e.color,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmtMin(int m) => m >= 60 ? '${m ~/ 60}시간 ${m % 60}분' : '$m분';

  Widget _goalRow(String label, int current, int goal, Color color) {
    final ratio = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$label: $current / $goal분'),
            Text('${(ratio * 100).toInt()}%',
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            Text(label,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void _showGoalDialog(BuildContext context) {
    final app = context.read<AppProvider>();
    final dailyCtrl =
        TextEditingController(text: app.dailyGoalMinutes.toString());
    final weeklyCtrl =
        TextEditingController(text: app.weeklyGoalMinutes.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('목표 설정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: dailyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '일일 목표 (분)'),
            ),
            TextField(
              controller: weeklyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '주간 목표 (분)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
            onPressed: () {
              app.setGoals(
                daily: int.tryParse(dailyCtrl.text) ?? 120,
                weekly: int.tryParse(weeklyCtrl.text) ?? 600,
              );
              Navigator.pop(ctx);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}
