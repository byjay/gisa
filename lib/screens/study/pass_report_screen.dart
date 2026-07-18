import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import '../../services/study_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/tutor_avatar.dart';
import '../../widgets/persistent_nav.dart';
import 'quiz_play_screen.dart';

/// 🏆 합격 분석 리포트 — 회독(N회독) 트래커 + 과목별 약점 진단.
/// 경쟁 앱 대비 차별화: 취약 과목을 자동으로 짚어주고 바로 풀이로 연결.
class PassReportScreen extends StatefulWidget {
  const PassReportScreen({super.key});

  @override
  State<PassReportScreen> createState() => _PassReportScreenState();
}

class _PassReportScreenState extends State<PassReportScreen> {
  int _bankSize = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final n = await StudyData.instance.bankQuestionCount();
      if (!mounted) return;
      setState(() {
        _bankSize = n;
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
    final app = context.watch<AppProvider>();
    final analysis = app.subjectAnalysis();
    final rounds = _bankSize > 0 ? app.reviewRounds(_bankSize) : 0;
    final roundProgress = _bankSize > 0
        ? app.reviewRoundProgress(_bankSize)
        : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('합격 분석 리포트')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width > 800
                    ? (MediaQuery.of(context).size.width - 680) / 2
                    : 14,
                vertical: 14,
              ),
              children: [
                TutorBanner(
                  mood: analysis.isEmpty
                      ? TutorMood.cheer
                      : (analysis.first['accuracy'] as int) < 60
                      ? TutorMood.thinking
                      : TutorMood.happy,
                  message: _headline(app, analysis, rounds),
                ),
                const SizedBox(height: 16),

                // ===== 회독 트래커 =====
                _roundTracker(cs, app, rounds, roundProgress),
                const SizedBox(height: 18),

                // ===== 핵심 지표 =====
                Row(
                  children: [
                    _statTile(
                      cs,
                      '누적 풀이',
                      '${app.lifetimeSolved}',
                      '문항',
                      Icons.assignment_turned_in_rounded,
                      AppTheme.primary,
                    ),
                    const SizedBox(width: 10),
                    _statTile(
                      cs,
                      '평균 정답률',
                      '${app.overallAccuracy}',
                      '%',
                      Icons.percent_rounded,
                      app.overallAccuracy >= 60
                          ? AppTheme.success
                          : AppTheme.warning,
                    ),
                    const SizedBox(width: 10),
                    _statTile(
                      cs,
                      '완료 세트',
                      '${app.completedQuizSessions}',
                      '회',
                      Icons.check_circle_rounded,
                      AppTheme.accent,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ===== 과목별 약점 진단 =====
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 10),
                  child: Row(
                    children: [
                      Icon(Icons.radar_rounded, color: cs.primary, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        '과목별 약점 진단',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (analysis.isEmpty)
                  _emptyDiagnosis(cs)
                else ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 10),
                    child: Text(
                      '정답률이 낮은 과목부터 표시됩니다. 약한 과목을 집중 공략하세요!',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  ...analysis.asMap().entries.map(
                    (e) => _subjectBar(context, cs, e.value, e.key == 0),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  String _headline(
    AppProvider app,
    List<Map<String, dynamic>> analysis,
    int rounds,
  ) {
    if (app.lifetimeSolved == 0) {
      return '문제를 풀면 합격까지 남은 약점을 자동으로 진단해드려요. '
          '지금 CBT 한 세트만 풀어볼까요? 🚀';
    }
    if (analysis.isNotEmpty) {
      final weak = analysis.first;
      final acc = weak['accuracy'] as int;
      if (acc < 60) {
        return '지금 가장 약한 과목은 「${weak['subject']}」($acc%)! '
            '합격 기준(과목 40점·평균 60점)을 위해 여기부터 잡아요. 💪';
      }
    }
    return '지금까지 $rounds회독 완주! 평균 정답률 ${app.overallAccuracy}%로 '
        '합격권을 유지하고 있어요. 이대로 쭉 가요! 🔥';
  }

  Widget _roundTracker(
    ColorScheme cs,
    AppProvider app,
    int rounds,
    double progress,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.replay_circle_filled_rounded,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                '기출 회독 트래커',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$rounds회독',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _bankSize == 0
                ? '문제은행을 불러오는 중...'
                : '다음 회독까지 ${(progress * 100).round()}% · '
                      '누적 ${app.lifetimeSolved}문항 / 은행 $_bankSize문항',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '합격자들이 강조하는 1순위 전략은 기출 반복 풀이예요.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile(
    ColorScheme cs,
    String label,
    String value,
    String unit,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                text: value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: cs.onSurface,
                ),
                children: [
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _subjectBar(
    BuildContext context,
    ColorScheme cs,
    Map<String, dynamic> s,
    bool isWeakest,
  ) {
    final acc = s['accuracy'] as int;
    final color = acc >= 70
        ? AppTheme.success
        : acc >= 50
        ? AppTheme.warning
        : AppTheme.danger;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isWeakest ? color : cs.outlineVariant,
          width: isWeakest ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isWeakest)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '최우선',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ),
              Expanded(
                child: Text(
                  s['subject'] as String,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$acc%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: acc / 100,
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '${s['correct']}/${s['total']} 정답',
                style: TextStyle(
                  fontSize: 11.5,
                  color: cs.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () =>
                    _practiceSubject(context, s['subject'] as String),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('이 과목 집중 풀기'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 0,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyDiagnosis(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(
            Icons.insights_rounded,
            size: 40,
            color: cs.onSurface.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 10),
          Text(
            '아직 진단할 데이터가 없어요.',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'CBT 모의고사를 한 세트 풀면\n과목별 강·약점이 자동으로 분석됩니다.',
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
  }

  Future<void> _practiceSubject(BuildContext context, String subject) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final qs = await StudyData.instance.questionsBySubject(subject);
      if (!context.mounted) return;
      if (qs.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('해당 과목 문제를 찾지 못했습니다.')),
        );
        return;
      }
      qs.shuffle();
      final pick = qs.take(20).toList();
      pushWithNav(
        context,
        QuizPlayScreen(
          title: '$subject 집중 풀기',
          questions: pick,
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
