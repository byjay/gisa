import 'study_data.dart';
import 'progress_service.dart';
import 'score_history.dart';

/// 🎯 합격 예측 엔진 — 유료 결제를 부르는 핵심 후킹
/// "지금 시험 보면 몇 점인가"를 기출 빈출 가중치 + 실제 풀이 정답률로 계산.
/// - 과목별 예측 점수 (토픽 출제 비중 가중 평균)
/// - 과락(40점 미만) 경보
/// - 오늘의 처방전: 예측 점수를 가장 크게 올리는 약점 토픽 3개 + 기대 상승폭
class SubjectPrediction {
  final String subject;
  final double score; // 0~100 예측 점수
  final int attempts; // 이 과목에서 푼 시도 수
  final bool gwarak; // 과락 위험 (40점 미만)
  SubjectPrediction({
    required this.subject,
    required this.score,
    required this.attempts,
  }) : gwarak = score < 40;
}

class Prescription {
  final String subject;
  final String topic;
  final double expectedGain; // 전체 평균 기준 기대 상승 점수
  final int topicQuestionCount; // 이 토픽의 기출 문항 수
  Prescription({
    required this.subject,
    required this.topic,
    required this.expectedGain,
    required this.topicQuestionCount,
  });
}

class PassPrediction {
  final double overall; // 전 과목 평균 예측
  final List<SubjectPrediction> subjects;
  final bool pass; // 평균 60 이상 + 전 과목 40 이상
  final int totalAttempts; // 전체 풀이 시도 수
  final List<Prescription> prescriptions;
  PassPrediction({
    required this.overall,
    required this.subjects,
    required this.totalAttempts,
    required this.prescriptions,
  }) : pass = overall >= 60 && subjects.every((s) => !s.gwarak);

  /// 신뢰 가능한 예측을 위한 최소 풀이 수 (미만이면 진단고사 유도)
  static const int minAttempts = 10;
  bool get needsDiagnosis => totalAttempts < minAttempts;
}

class PassPredictionEngine {
  PassPredictionEngine._();
  static final PassPredictionEngine instance = PassPredictionEngine._();

  /// 미응시 토픽의 사전 확률 — 4지선다 찍기 25% + 배경지식 보정
  static const double _prior = 0.35;

  Future<PassPrediction> predict() async {
    // 1) 기출 은행에서 과목→토픽별 출제 비중 계산
    final exams = await StudyData.instance.loadExams();
    final topicCount = <String, Map<String, int>>{}; // subject -> topic -> n
    final subjectTotal = <String, int>{};
    for (final e in exams) {
      for (final q in e.questions) {
        if (!kSubjects.contains(q.subject)) continue;
        final t = topicCount.putIfAbsent(q.subject, () => {});
        t[q.topic] = (t[q.topic] ?? 0) + 1;
        subjectTotal[q.subject] = (subjectTotal[q.subject] ?? 0) + 1;
      }
    }

    // 2) 실제 풀이 이력 (토픽별 correct/total)
    final stats = await ProgressService.instance.topicStats();

    double smoothedAcc(String subject, String topic) {
      final pair = stats[subject]?[topic];
      final c = pair?[0] ?? 0;
      final n = pair?[1] ?? 0;
      // 베이지안 스무딩: 시도가 적을수록 사전확률 쪽으로 수렴
      return (c + _prior * 4) / (n + 4);
    }

    // 3) 과목별 예측 점수 = Σ (토픽 출제비중 × 토픽 예상 정답률) × 100
    var totalAttempts = 0;
    final subjectPreds = <SubjectPrediction>[];
    for (final s in kSubjects) {
      final topics = topicCount[s] ?? {};
      final total = subjectTotal[s] ?? 0;
      double score;
      if (total == 0) {
        score = _prior * 100;
      } else {
        var acc = 0.0;
        topics.forEach((t, n) {
          acc += (n / total) * smoothedAcc(s, t);
        });
        score = acc * 100;
      }
      var attempts = 0;
      stats[s]?.forEach((_, pair) => attempts += pair[1]);
      totalAttempts += attempts;
      subjectPreds.add(
        SubjectPrediction(subject: s, score: score, attempts: attempts),
      );
    }
    final overall = subjectPreds.isEmpty
        ? 0.0
        : subjectPreds.map((s) => s.score).reduce((a, b) => a + b) /
              subjectPreds.length;

    // 4) 처방전 — "이 토픽을 75% 정답률로 끌어올리면 평균이 몇 점 오르는가"
    final rx = <Prescription>[];
    for (final s in kSubjects) {
      final topics = topicCount[s] ?? {};
      final total = subjectTotal[s] ?? 0;
      if (total == 0) continue;
      topics.forEach((t, n) {
        if (t == '기타' || n < 8) return; // 출제 비중 낮은 토픽 제외
        final acc = smoothedAcc(s, t);
        final target = 0.75;
        if (acc >= target) return;
        // 과목 점수 상승 = 비중 × (목표-현재) × 100, 평균 상승 = /5과목
        final gain = (n / total) * (target - acc) * 100 / kSubjects.length;
        rx.add(
          Prescription(
            subject: s,
            topic: t,
            expectedGain: gain,
            topicQuestionCount: n,
          ),
        );
      });
    }
    rx.sort((a, b) => b.expectedGain.compareTo(a.expectedGain));

    // 5) 오늘자 점수 스냅샷 기록 (트렌드 그래프용) — 시도 이력이 있을 때만
    if (totalAttempts > 0) {
      try {
        await ScoreHistory.instance.record(overall, totalAttempts);
      } catch (_) {}
    }

    return PassPrediction(
      overall: overall,
      subjects: subjectPreds,
      totalAttempts: totalAttempts,
      prescriptions: rx.take(3).toList(),
    );
  }
}
