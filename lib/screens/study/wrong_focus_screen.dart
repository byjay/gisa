import 'package:flutter/material.dart';
import '../../services/progress_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/tutor_coach.dart';
import '../../widgets/help_dot.dart';
import '../../widgets/persistent_nav.dart';
import 'quiz_play_screen.dart';

/// 🎯 집중 오답노트 — "왜 틀리는지"에 집중한 복습 도구.
/// - 자주 틀리는 문제 랭킹(틀린 횟수순)
/// - 오답 원인별 집계 → 원인별 집중 풀기
/// - 마지막 오답 상태 문제 한 번에 다시 풀기
class WrongFocusScreen extends StatefulWidget {
  const WrongFocusScreen({super.key});

  @override
  State<WrongFocusScreen> createState() => _WrongFocusScreenState();
}

class _WrongFocusScreenState extends State<WrongFocusScreen> {
  bool _loading = true;
  Map<String, int> _reasonStats = {};
  List<
    ({
      String qid,
      int wrong,
      int correct,
      String subject,
      String topic,
      String? lastReason,
    })
  >
  _frequent = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final reasons = await ProgressService.instance.wrongReasonStats();
      final freq = await ProgressService.instance.frequentlyWrong(
        limit: 50,
        onlyUnmastered: false,
      );
      if (!mounted) return;
      setState(() {
        _reasonStats = reasons;
        _frequent = freq;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totalWrong = _frequent.fold<int>(0, (s, r) => s + r.wrong);
    final topReason = _reasonStats.entries.isEmpty
        ? null
        : (_reasonStats.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('집중 오답노트'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: HelpDot(
              size: 22,
              title: '집중 오답노트 안내',
              body:
                  '틀린 문제를 모아서 "왜 틀렸는지"까지 분석해주는 복습 도구예요.\n\n'
                  '📊 자주 틀리는 문제 랭킹 — 틀린 횟수가 많은 문제부터 순서대로 보여줘요.\n\n'
                  '🔍 오답 원인별 집계 — 실수인지, 개념을 몰라서인지, 헷갈려서인지 원인을 분류해줘요.\n\n'
                  '🎯 원인별 집중 풀기 — 같은 원인으로 틀린 문제들만 모아 다시 풀어볼 수 있어요.\n\n'
                  '💡 같은 실수를 반복하지 않으려면 이 화면을 꾸준히 확인하는 게 최고예요!',
            ),
          ),
          IconButton(
            tooltip: '새로고침',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.of(context).size.width > 800
                      ? (MediaQuery.of(context).size.width - 680) / 2
                      : 14,
                  vertical: 14,
                ),
                children: [
                  DynamicTutorBanner(
                    situation: _frequent.isEmpty
                        ? CoachSituation.encourage
                        : CoachSituation.quizWrongRepeat,
                    overrideMessage: _frequent.isEmpty
                        ? null
                        : '틀린 문제 ${_frequent.length}개(총 $totalWrong회 오답)를 모았어요. '
                              '${topReason != null ? '특히 「${topReason.key}」 실수가 가장 많아요. ' : ''}'
                              '같은 실수를 반복하지 않도록 원인부터 잡아봐요! 💪',
                  ),
                  const SizedBox(height: 16),

                  // 한 번에 다시 풀기
                  if (_frequent.isNotEmpty)
                    _actionCard(
                      cs,
                      icon: Icons.replay_rounded,
                      color: AppTheme.danger,
                      title: '틀린 문제 한 번에 다시 풀기',
                      subtitle: '자주 틀린 순서로 최대 20문제',
                      onTap: () => _solveQids(
                        _frequent.map((e) => e.qid).take(20).toSet(),
                        '집중 오답 복습',
                      ),
                    ),
                  const SizedBox(height: 18),

                  // ===== 오답 원인별 집계 =====
                  if (_reasonStats.isNotEmpty) ...[
                    _sectionTitle(cs, Icons.psychology_alt_rounded, '오답 원인 분석'),
                    const SizedBox(height: 10),
                    ..._reasonRows(cs),
                    const SizedBox(height: 20),
                  ],

                  // ===== 자주 틀리는 문제 랭킹 =====
                  _sectionTitle(cs, Icons.leaderboard_rounded, '자주 틀리는 문제 TOP'),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 10),
                    child: Text(
                      '틀린 횟수가 많은 문제부터 표시됩니다.',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  if (_frequent.isEmpty)
                    _empty(cs)
                  else
                    ..._frequent
                        .take(30)
                        .toList()
                        .asMap()
                        .entries
                        .map((e) => _wrongRow(cs, e.key + 1, e.value)),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(ColorScheme cs, IconData icon, String t) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Row(
      children: [
        Icon(icon, color: cs.primary, size: 20),
        const SizedBox(width: 6),
        Text(
          t,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: cs.primary,
          ),
        ),
      ],
    ),
  );

  List<Widget> _reasonRows(ColorScheme cs) {
    final entries = _reasonStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final max = entries.first.value;
    return entries.map((e) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    e.key,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${e.value}회',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.danger,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _solveReason(e.key),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('집중 풀기'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: max == 0 ? 0 : e.value / max,
                minHeight: 7,
                backgroundColor: AppTheme.danger.withValues(alpha: 0.12),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.danger,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _wrongRow(
    ColorScheme cs,
    int rank,
    ({
      String qid,
      int wrong,
      int correct,
      String subject,
      String topic,
      String? lastReason,
    })
    r,
  ) {
    // qid = trackId|examLabel|subject|no  → 마지막 조각이 번호
    final parts = r.qid.split('|');
    final label = parts.length >= 2 ? parts[1] : '';
    final no = parts.isNotEmpty ? parts.last : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: rank <= 3
                ? AppTheme.danger.withValues(alpha: 0.15)
                : cs.surfaceContainerHighest,
            child: Text(
              '$rank',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: rank <= 3 ? AppTheme.danger : cs.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${r.subject.isEmpty ? '문제' : r.subject} · ${r.topic}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  children: [
                    _miniTag(
                      '${label.isEmpty ? '' : '$label '}$no번',
                      cs.onSurface.withValues(alpha: 0.55),
                    ),
                    _miniTag('틀림 ${r.wrong}회', AppTheme.danger),
                    if (r.correct > 0)
                      _miniTag('맞힘 ${r.correct}회', AppTheme.success),
                    if (r.lastReason != null)
                      _miniTag(r.lastReason!, AppTheme.accent),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.replay_rounded, size: 20),
            tooltip: '이 문제 다시 풀기',
            onPressed: () => _solveQids({r.qid}, '오답 다시 풀기'),
          ),
        ],
      ),
    );
  }

  Widget _miniTag(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    ),
  );

  Widget _actionCard(
    ColorScheme cs, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: cs.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty(ColorScheme cs) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        Icon(
          Icons.emoji_events_rounded,
          size: 40,
          color: cs.onSurface.withValues(alpha: 0.3),
        ),
        const SizedBox(height: 10),
        Text(
          '아직 틀린 문제가 없어요!',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: cs.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '문제를 풀다 틀리면 이곳에 자동으로 쌓이고\n원인별로 집중 복습할 수 있어요.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.5,
            color: cs.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    ),
  );

  Future<void> _solveReason(String reason) async {
    final qids = await ProgressService.instance.qidsByReason(reason);
    if (!mounted) return;
    await _solveQids(qids, '「$reason」 원인 집중');
  }

  Future<void> _solveQids(Set<String> qids, String title) async {
    final messenger = ScaffoldMessenger.of(context);
    if (qids.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('풀 문제가 없습니다.')));
      return;
    }
    try {
      final questions = await ProgressService.instance.resolveQuestions(qids);
      if (!mounted) return;
      if (questions.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('문제를 복원하지 못했습니다.')),
        );
        return;
      }
      questions.shuffle();
      pushWithNav(
        context,
        QuizPlayScreen(
          title: title,
          questions: questions.take(20).toList(),
          examMode: false,
        ),
        currentSection: 1,
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('문제를 불러오지 못했습니다. 다시 시도해주세요.')),
      );
    }
  }
}
