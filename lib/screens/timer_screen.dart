import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';

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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('학습 타이머')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Exam selector
              DropdownButtonFormField<String>(
                initialValue: _selectedExamId,
                decoration: const InputDecoration(
                  labelText: '학습할 시험 선택 (선택사항)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String>(
                      value: null, child: Text('일반 학습')),
                  ...app.exams.map((e) => DropdownMenuItem(
                        value: e.id,
                        child: Text(e.name, overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: app.timerRunning
                    ? null
                    : (v) => setState(() => _selectedExamId = v),
              ),
              const SizedBox(height: 40),
              // Timer display
              Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  border: Border.all(
                    color: app.timerRunning
                        ? theme.colorScheme.primary
                        : Colors.grey.shade300,
                    width: 6,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _fmt(app.elapsedSeconds),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontFeatures: const [],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        app.timerRunning ? '집중 중...' : '준비됨',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!app.timerRunning)
                    FilledButton.icon(
                      onPressed: () => app.startTimer(_selectedExamId),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('시작'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                      ),
                    )
                  else ...[
                    FilledButton.icon(
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
                      icon: const Icon(Icons.stop),
                      label: const Text('종료 & 저장'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: app.cancelTimer,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                      ),
                      child: const Text('취소'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 32),
              // Today summary
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _stat('오늘', '${app.todayMinutes}분'),
                      _stat('이번 주', '${app.weekMinutes}분'),
                      _stat('연속', '${app.streak}일'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value) => Column(
        children: [
          Text(value,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
        ],
      );
}
