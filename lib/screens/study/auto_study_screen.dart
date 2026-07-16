import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../services/auto_study_service.dart';
import '../../theme/app_theme.dart';
import 'quiz_play_screen.dart';
import '../../widgets/persistent_nav.dart';

class AutoStudyScreen extends StatefulWidget {
  const AutoStudyScreen({super.key});

  @override
  State<AutoStudyScreen> createState() => _AutoStudyScreenState();
}

class _AutoStudyScreenState extends State<AutoStudyScreen> {
  AutoStudyPlan? _plan;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final app = context.read<AppProvider>();
    try {
      final plan = await AutoStudyService.instance.buildPlan(
        dailyGoalMinutes: app.dailyGoalMinutes,
        studiedMinutes: app.todayMinutes,
      );
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = '오늘의 학습 계획을 만들지 못했습니다. 잠시 후 다시 시도해주세요.';
        _loading = false;
      });
    }
  }

  Future<void> _startTask(AutoStudyTask task) async {
    final completed = await pushWithNav<bool>(context, QuizPlayScreen(
          title: '자동학습 · ${task.title}',
          questions: task.questions,
          examMode: false,
        ), currentSection: 1);
    if (completed == true) {
      await AutoStudyService.instance.markCompleted(task.id);
    }
    if (mounted) await _load();
  }

  Future<void> _reset() async {
    await AutoStudyService.instance.resetToday();
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('자동학습 코치'),
        actions: [
          IconButton(
            tooltip: '오늘 계획 다시 시작',
            onPressed: _reset,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _ErrorState(message: _error!, onRetry: _load)
            : RefreshIndicator(onRefresh: _load, child: _body(_plan!)),
      ),
    );
  }

  Widget _body(AutoStudyPlan plan) {
    final next = plan.nextTask;
    final completed = plan.completedCount;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 32),
      children: [
        _CoachHero(
          plan: plan,
          onStart: next == null ? null : () => _startTask(next),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Text(
              '오늘의 자동 커리큘럼',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const Spacer(),
            Text(
              '$completed/${plan.tasks.length} 완료',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '복습, 오답, 약점, 실전 순서로 자동 배치됩니다. 완료할 때마다 다음 계획이 다시 계산됩니다.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < plan.tasks.length; i++)
          _TaskCard(
            index: i,
            task: plan.tasks[i],
            completed: plan.completedTaskIds.contains(plan.tasks[i].id),
            current: next?.id == plan.tasks[i].id,
            onTap: () => _startTask(plan.tasks[i]),
          ),
        const SizedBox(height: 8),
        _AutomationNote(plan: plan),
      ],
    );
  }
}

class AutoStudyPreviewCard extends StatefulWidget {
  final VoidCallback onOpen;

  const AutoStudyPreviewCard({super.key, required this.onOpen});

  @override
  State<AutoStudyPreviewCard> createState() => _AutoStudyPreviewCardState();
}

class _AutoStudyPreviewCardState extends State<AutoStudyPreviewCard> {
  Future<AutoStudyPlan>? _future;
  int? _goal;
  int? _today;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    if (_future == null ||
        _goal != app.dailyGoalMinutes ||
        _today != app.todayMinutes) {
      _goal = app.dailyGoalMinutes;
      _today = app.todayMinutes;
      _future = AutoStudyService.instance.buildPlan(
        dailyGoalMinutes: app.dailyGoalMinutes,
        studiedMinutes: app.todayMinutes,
      );
    }
    return FutureBuilder<AutoStudyPlan>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const PremiumCard(
            child: SizedBox(
              height: 108,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        final plan = snapshot.data!;
        final next = plan.nextTask;
        final scheme = Theme.of(context).colorScheme;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                scheme.primary,
                Color.lerp(scheme.primary, const Color(0xFF7C3AED), 0.65)!,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.rLg),
            boxShadow: AppTheme.glowShadow(scheme.primary),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.rLg),
            child: InkWell(
              onTap: widget.onOpen,
              borderRadius: BorderRadius.circular(AppTheme.rLg),
              child: Padding(
                padding: const EdgeInsets.all(17),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '오늘 공부는 앱이 설계했어요',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '기억 상태와 약점을 분석한 자동 커리큘럼',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              next == null
                                  ? '오늘의 자동학습을 모두 완료했습니다'
                                  : '다음: ${next.title}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            '${plan.totalQuestions}문항 · 약 ${plan.plannedMinutes}분',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: plan.progress,
                        minHeight: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.16),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CoachHero extends StatelessWidget {
  final AutoStudyPlan plan;
  final VoidCallback? onStart;

  const _CoachHero({required this.plan, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final next = plan.nextTask;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primary, const Color(0xFF7C3AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.glowShadow(scheme.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.psychology_alt_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${plan.trackName} 맞춤 루틴',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const Text(
                      '생각하지 말고, 다음 학습만 시작하세요',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        height: 1.3,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _HeroMetric(value: '${plan.totalQuestions}', label: '맞춤 문항'),
              _HeroMetric(value: '${plan.plannedMinutes}분', label: '예상 시간'),
              _HeroMetric(
                value: '${plan.completedCount}/${plan.tasks.length}',
                label: '완료 루틴',
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: scheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: onStart,
              icon: Icon(
                next == null
                    ? Icons.check_circle_rounded
                    : Icons.play_arrow_rounded,
              ),
              label: Text(
                next == null ? '오늘 자동학습 완료' : '${next.title} 시작',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String value;
  final String label;

  const _HeroMetric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final int index;
  final AutoStudyTask task;
  final bool completed;
  final bool current;
  final VoidCallback onTap;

  const _TaskCard({
    required this.index,
    required this.task,
    required this.completed,
    required this.current,
    required this.onTap,
  });

  Color _color() => switch (task.kind) {
    AutoStudyTaskKind.dueReview => const Color(0xFF7C3AED),
    AutoStudyTaskKind.wrongRecovery => const Color(0xFFEF4444),
    AutoStudyTaskKind.adaptivePractice => const Color(0xFF0891B2),
    AutoStudyTaskKind.miniMock => const Color(0xFF059669),
  };

  IconData _icon() => switch (task.kind) {
    AutoStudyTaskKind.dueReview => Icons.event_repeat_rounded,
    AutoStudyTaskKind.wrongRecovery => Icons.healing_rounded,
    AutoStudyTaskKind.adaptivePractice => Icons.auto_graph_rounded,
    AutoStudyTaskKind.miniMock => Icons.timer_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final color = _color();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: current
            ? color.withValues(alpha: 0.09)
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: current
                    ? color.withValues(alpha: 0.5)
                    : scheme.outlineVariant.withValues(alpha: 0.45),
                width: current ? 1.4 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: completed
                        ? AppTheme.success.withValues(alpha: 0.12)
                        : color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    completed ? Icons.check_rounded : _icon(),
                    color: completed ? AppTheme.success : color,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${index + 1}. ${task.title}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (current) ...[
                            const SizedBox(width: 6),
                            _SmallBadge(text: 'NEXT', color: color),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        task.reason,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.4,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '${task.subject} · ${task.questions.length}문항 · 약 ${task.estimatedMinutes}분',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _SmallBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AutomationNote extends StatelessWidget {
  final AutoStudyPlan plan;

  const _AutomationNote({required this.plan});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.tune_rounded, color: scheme.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '자동 설계 기준: 오늘 목표 ${plan.targetMinutes}분, 완료한 학습 ${plan.studiedMinutes}분, 복습 예정일, 최근 오답, 토픽별 정답률, 기출 빈도. 학습 결과는 다음 큐에 자동 반영됩니다.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.5,
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }
}
