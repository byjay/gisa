import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../widgets/pass_prediction_card.dart';
import '../widgets/dday_plan_card.dart';

class HomeScreen extends StatelessWidget {
  final void Function(int) onNavigate;
  const HomeScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final theme = Theme.of(context);
    final upcoming = app.exams.where((e) => e.dDay >= 0).toList();
    final nearest = upcoming.isNotEmpty ? upcoming.first : null;
    final dailyRatio = app.dailyGoalMinutes > 0
        ? (app.todayMinutes / app.dailyGoalMinutes).clamp(0.0, 1.0)
        : 0.0;
    final pendingNotes = app.notes.where((n) => !n.mastered).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('자격증 스터디 트래커'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: app.darkMode ? '라이트 모드' : '다크 모드 (야간 학습)',
            icon: Icon(
                app.darkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            onPressed: () => context.read<AppProvider>().toggleDarkMode(),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(DateFormat('yyyy년 M월 d일 (E)', 'ko').format(DateTime.now()),
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            // 🎯 합격 예측 — 앱의 심장 (매일 열어보게 만드는 후킹)
            const PassPredictionCard(),
            const SizedBox(height: 12),
            // 📈 성장 그랤프 + 🗓 D-Day 역산 플랜 (돈 낼 만한 이유: 계획과 증거)
            DDayPlanCard(dDay: nearest?.dDay ?? 0),
            const SizedBox(height: 16),
            // D-Day hero card
            GestureDetector(
              onTap: () => onNavigate(2),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: nearest != null
                        ? [nearest.color, nearest.color.withValues(alpha: 0.7)]
                        : [
                            theme.colorScheme.primary,
                            theme.colorScheme.primary.withValues(alpha: 0.7)
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: nearest != null
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(nearest.name,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text(
                                    DateFormat('yyyy.MM.dd')
                                        .format(nearest.examDate),
                                    style: const TextStyle(
                                        color: Colors.white70)),
                              ],
                            ),
                          ),
                          Text(
                            nearest.dDay == 0 ? 'D-Day' : 'D-${nearest.dDay}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      )
                    : const Row(
                        children: [
                          Icon(Icons.add_circle_outline, color: Colors.white),
                          SizedBox(width: 12),
                          Text('시험을 등록하고 D-Day를 관리하세요!',
                              style: TextStyle(color: Colors.white)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            // 전기기사 문제은행 바로가기 (학습 탭)
            Card(
              color: theme.colorScheme.primaryContainer,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onNavigate(1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.school,
                          size: 36, color: theme.colorScheme.primary),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('전기기사 문제은행',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)),
                            SizedBox(height: 4),
                            Text(
                              '기출 2,897문항 · 1:1 강의 46토픽 · 반복기출 암기 347제\n'
                              '이론-문제-암기법 완전 연동 학습',
                              style: TextStyle(fontSize: 12, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Today goal progress
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('오늘의 학습 목표',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                            '${app.todayMinutes} / ${app.dailyGoalMinutes}분',
                            style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: dailyRatio,
                        minHeight: 10,
                        backgroundColor: Colors.grey.shade200,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dailyRatio >= 1.0
                          ? '오늘 목표 달성! 🎉'
                          : '목표까지 ${app.dailyGoalMinutes - app.todayMinutes}분 남았어요',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Quick stats
            Row(
              children: [
                Expanded(
                    child: _quickStat(context, Icons.local_fire_department,
                        '${app.streak}일', '연속 학습', Colors.orange, () => onNavigate(4))),
                const SizedBox(width: 10),
                Expanded(
                    child: _quickStat(context, Icons.timer, '${app.weekMinutes}분',
                        '이번 주', Colors.teal, () => onNavigate(4))),
                const SizedBox(width: 10),
                Expanded(
                    child: _quickStat(context, Icons.quiz, '$pendingNotes개',
                        '복습할 오답', Colors.redAccent, () => onNavigate(5))),
              ],
            ),
            const SizedBox(height: 16),
            // Quick actions
            const Text('빠른 실행',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _actionButton(context, Icons.play_circle_fill,
                      '타이머 시작', theme.colorScheme.primary, () => onNavigate(3)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _actionButton(context, Icons.school, '오늘의 학습',
                      Colors.teal, () => onNavigate(1)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Upcoming exams list
            if (upcoming.length > 1) ...[
              const Text('다가오는 시험',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              ...upcoming.skip(1).take(3).map((e) => Card(
                    child: ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: e.color.withValues(alpha: 0.15),
                        child: Text(e.name[0],
                            style: TextStyle(color: e.color, fontSize: 14)),
                      ),
                      title: Text(e.name),
                      trailing: Text('D-${e.dDay}',
                          style: TextStyle(
                              color: e.color, fontWeight: FontWeight.bold)),
                      onTap: () => onNavigate(2),
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  Widget _quickStat(BuildContext context, IconData icon, String value,
      String label, Color color, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              Text(label,
                  style:
                      TextStyle(fontSize: 11, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionButton(BuildContext context, IconData icon, String label,
      Color color, VoidCallback onTap) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(label,
                  style:
                      TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
