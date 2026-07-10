import 'package:flutter/material.dart';
import '../services/pass_prediction.dart';
import '../theme/app_theme.dart';
import '../services/study_data.dart';
import '../screens/study/quiz_play_screen.dart';

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
                child: Text('지금 시험 보면 몇 점일까요?',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '15문제 진단고사 5분이면 합격 예측 점수가 나옵니다.\n'
            '과락 위험 과목까지 바로 알려드려요. (풀이 ${p.totalAttempts}/${PassPrediction.minAttempts}문제)',
            style: const TextStyle(
                color: Colors.white70, fontSize: 12.5, height: 1.5),
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
              child: const Text('무료 진단고사 시작 (5분)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
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
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => QuizPlayScreen(
            title: '합격 예측 진단고사 (15문제)',
            questions: qs,
            examMode: false)));
    _load(); // 돌아오면 예측 갱신
  }

  // ── 본 예측 카드 ─────────────────────────────────────
  Widget _predictionCard(BuildContext context, PassPrediction p) {
    final pass = p.pass;
    final gwarakList = p.subjects.where((s) => s.gwarak).toList();
    final gradient = pass
        ? AppTheme.successGradient
        : (p.overall >= 50 ? AppTheme.warningGradient : AppTheme.dangerGradient);

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
                    const Text('지금 시험 보면',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${p.overall.round()}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 44,
                                height: 1.0,
                                fontWeight: FontWeight.w900)),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 6, left: 2),
                          child: Text('점',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 16)),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    pass ? '합격권 ✓' : (gwarakList.isNotEmpty ? '과락 위험!' : '불합격권'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800),
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
                        Text('${s.score.round()}',
                            style: TextStyle(
                                color: s.gwarak
                                    ? Colors.yellowAccent
                                    : Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 3),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: (s.score / 100).clamp(0.0, 1.0),
                            minHeight: 5,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.25),
                            color: s.gwarak
                                ? Colors.yellowAccent
                                : Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(_shortName(s.subject),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 9.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
                      height: 1.4),
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
                  bottom: Radius.circular(AppTheme.rLg)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('💊', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text('오늘의 합격 처방전',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.primary)),
                    const Spacer(),
                    Text('푼 문제 ${p.totalAttempts}개 기반',
                        style: TextStyle(
                            fontSize: 10.5,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: 8),
                if (p.prescriptions.isEmpty)
                  const Text('모든 주요 토픽 정답률 75% 이상 — 실전 모의고사로 마무리하세요!',
                      style: TextStyle(fontSize: 12.5))
                else
                  for (final rx in p.prescriptions)
                    _rxTile(context, rx),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('+${rx.expectedGain.toStringAsFixed(1)}점',
                  style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2E7D32))),
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
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => QuizPlayScreen(
            title: '처방전: ${rx.topic}',
            questions: qs.take(10).toList(),
            examMode: false)));
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

