import 'package:flutter/material.dart';
import '../services/pass_prediction.dart';
import '../theme/app_theme.dart';
import '../services/study_data.dart';
import '../screens/study/quiz_play_screen.dart';
import 'persistent_nav.dart';

/// 🎯 합격 예측 카드 — 홈 최상단 후킹.
/// "지금 시험 보면 몇 점 = 합격/불합격" + 과락 경보 + 오늘의 처방전(점수 상승 최대 토픽 3개).
/// 매일 열어보게 만드는 앱의 심장.
class PassPredictionCard extends StatefulWidget {
  const PassPredictionCard({super.key});

  @override
  State<PassPredictionCard> createState() => _PassPredictionCardState();
}

class _PassPredictionCardState extends State<PassPredictionCard> {
  PassPrediction? _pred;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await PassPredictionEngine.instance.predict();
    if (mounted) setState(() => _pred = p);
  }

  @override
  Widget build(BuildContext context) {
    final p = _pred;
    if (p == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (p.needsDiagnosis) return _diagnosisCard(context, p);
    return _predictionCard(context, p);
  }

  // ── 풀이 이력 부족 → 15문제 진단고사 유도 ─────────────────
  Widget _diagnosisCard(BuildContext context, PassPrediction p) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(AppTheme.rLg),
        boxShadow: AppTheme.glowShadow(AppTheme.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('🎯', style: TextStyle(fontSize: 24)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '지금 시험 보면 몇 점일까요?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '15문제 진단고사 5분이면 합격 예측 점수가 나옵니다.\n'
            '과락 위험 과목까지 바로 알려드려요. (풀이 ${p.totalAttempts}/${PassPrediction.minAttempts}문제)',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryDark,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              onPressed: () => _startDiagnosis(context),
              child: const Text(
                '무료 진단고사 시작 (5분)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startDiagnosis(BuildContext context) async {
    // 과목별 빈출 3문제 = 15문제 진단 세트
    final qs = <Question>[];
    for (final s in kSubjects) {
      final list = await StudyData.instance.questionsByFrequency(s);
      qs.addAll(list.take(3));
    }
    if (!context.mounted) return;
    await pushWithNav(
      context,
      QuizPlayScreen(
        title: '합격 예측 진단고사 (15문제)',
        questions: qs,
        examMode: false,
      ),
      currentSection: 2,
    );
    _load(); // 돌아오면 예측 갱신
  }

  // ── 예측 근거(방법론) 안내 시트 ───────────────────────
  void _showMethodology(BuildContext context, PassPrediction p) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.functions_rounded, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(
                    '합격 예측은 이렇게 계산됩니다',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _methodRow(
                ctx,
                '1',
                '토픽별 출제 비중',
                '기출문제 은행에서 과목별로 각 토픽이 얼마나 자주 출제됐는지 비중을 계산합니다.',
              ),
              _methodRow(
                ctx,
                '2',
                '나의 실제 정답률',
                '회원님이 푼 문제의 토픽별 정답률을 반영합니다. 풀이 수가 적은 토픽은 '
                    '사전 확률(35%) 쪽으로 보수적으로 보정합니다(베이지안 스무딩).',
              ),
              _methodRow(
                ctx,
                '3',
                '과목 점수 = Σ(출제비중 × 예상 정답률)',
                '토픽 비중과 정답률을 곱해 과목별 100점 만점 점수로 환산합니다.',
              ),
              _methodRow(
                ctx,
                '4',
                '합격 판정',
                '전 과목 평균 60점 이상 + 모든 과목 40점 이상(과락 없음)이면 합격권입니다.',
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '현재 풀이 ${p.totalAttempts}문제 기반 추정치입니다. '
                  '풀이가 쌓일수록 예측이 정확해지며, 실제 시험 결과와 다를 수 있는 '
                  '학습 참고용 지표입니다.',
                  style: Theme.of(
                    ctx,
                  ).textTheme.bodySmall?.copyWith(height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _methodRow(BuildContext ctx, String no, String title, String desc) {
    final cs = Theme.of(ctx).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: cs.primary.withValues(alpha: 0.12),
            child: Text(
              no,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: cs.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    height: 1.45,
                    color: cs.onSurface.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 본 예측 카드 ─────────────────────────────────────
  Widget _predictionCard(BuildContext context, PassPrediction p) {
    final pass = p.pass;
    final gwarakList = p.subjects.where((s) => s.gwarak).toList();
    final gradient = pass
        ? AppTheme.successGradient
        : (p.overall >= 50
              ? AppTheme.warningGradient
              : AppTheme.dangerGradient);

    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppTheme.rLg),
        boxShadow: AppTheme.glowShadow(gradient.colors.first),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '지금 시험 보면',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${p.overall.round()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 44,
                            height: 1.0,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6, left: 2),
                          child: Text(
                            '점',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  tooltip: '예측 점수 계산 근거',
                  onPressed: () => _showMethodology(context, p),
                  icon: const Icon(
                    Icons.info_outline_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    pass
                        ? '합격권 ✓'
                        : (gwarakList.isNotEmpty ? '과락 위험!' : '불합격권'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // 과목별 미니 바
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                for (final s in p.subjects) ...[
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${s.score.round()}',
                          style: TextStyle(
                            color: s.gwarak
                                ? Colors.yellowAccent
                                : Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: (s.score / 100).clamp(0.0, 1.0),
                            minHeight: 5,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.25,
                            ),
                            color: s.gwarak
                                ? Colors.yellowAccent
                                : Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _shortName(s.subject),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 9.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (s != p.subjects.last) const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          // 과락 경보
          if (gwarakList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '🚨 ${gwarakList.map((s) => _shortName(s.subject)).join(', ')} 40점 미만 — '
                  '평균이 넘어도 과락으로 전체 불합격입니다',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          // 오늘의 처방전
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(AppTheme.rLg),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('💊', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      '오늘의 합격 처방전',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '푼 문제 ${p.totalAttempts}개 기반',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (p.prescriptions.isEmpty)
                  const Text(
                    '모든 주요 토픽 정답률 75% 이상 — 실전 모의고사로 마무리하세요!',
                    style: TextStyle(fontSize: 12.5),
                  )
                else
                  for (final rx in p.prescriptions) _rxTile(context, rx),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _rxTile(BuildContext context, Prescription rx) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _startRxQuiz(context, rx),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '+${rx.expectedGain.toStringAsFixed(1)}점',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${rx.topic}  ·  ${_shortName(rx.subject)} · 기출 ${rx.topicQuestionCount}문항',
                style: const TextStyle(fontSize: 12.5, height: 1.3),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.play_circle_fill, size: 20, color: Colors.teal),
          ],
        ),
      ),
    );
  }

  Future<void> _startRxQuiz(BuildContext context, Prescription rx) async {
    final qs = await StudyData.instance.questionsByTopic(rx.topic);
    if (!context.mounted) return;
    await pushWithNav(
      context,
      QuizPlayScreen(
        title: '처방전: ${rx.topic}',
        questions: qs.take(10).toList(),
        examMode: false,
      ),
      currentSection: 2,
    );
    _load();
  }

  String _shortName(String s) {
    switch (s) {
      case '회로이론 및 제어공학':
        return '회로·제어';
      case '전기설비기술기준':
        return '설비기준';
      default:
        return s;
    }
  }
}
