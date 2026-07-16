import 'pass_prediction.dart';
import 'dday_planner.dart';
import 'score_history.dart';
import 'qnet_schedule_service.dart';
import 'exam_registration.dart';

/// 🧠 시험 통합 분석 레이어
///
/// 사용자가 요청한 "학습정보·과거정보로 연동해서 분석"의 핵심.
/// 서로 흩어져 있던 세 가지를 하나로 묶는다:
///   1) 크롤링한 실제 시험일정([QnetExamRound]) → D-Day
///   2) 과거 학습데이터 기반 합격예측([PassPredictionEngine])
///   3) D-Day 역산 학습 플랜([DDayPlannerEngine])
///   4) 가답안 실채점([ExamRegistration]) → 예측 대비 실측 비교
///
/// 결과([ExamAnalysis])는 "이 회차에 응시하면 지금 실력으로 몇 점이고,
/// 합격까지 하루 몇 문제를 풀어야 하며, 가답안 실채점은 예측과 얼마나 맞았나"를
/// 한 화면에서 보여주기 위한 데이터다.
class ExamAnalysis {
  /// 대상 회차·단계
  final String roundLabel;
  final ExamPhase phase;

  /// D-Day (시험일까지 남은 일수). 시험일 미상이면 null.
  final int? dDay;
  final DateTime? examDate;

  /// 과거 학습데이터 기반 현재 실력 예측
  final PassPrediction prediction;

  /// D-Day 역산 학습 플랜 (남은 일수 있을 때만)
  final DDayPlan? plan;

  /// 가답안 실채점 결과(있으면)와 예측 대비 비교
  final double? actualScore; // 가답안 실채점 점수
  final double? predVsActualGap; // 실측 - 예측 (양수면 예측보다 잘봄)

  const ExamAnalysis({
    required this.roundLabel,
    required this.phase,
    required this.dDay,
    required this.examDate,
    required this.prediction,
    required this.plan,
    required this.actualScore,
    required this.predVsActualGap,
  });

  /// 한 줄 요약 코칭 문구 — 상황별로 분기.
  String get coaching {
    // 이미 가답안 실채점이 있으면 결과 중심 문구
    if (actualScore != null) {
      final gap = predVsActualGap ?? 0;
      if (actualScore! >= 60 && (prediction.subjects.every((s) => !s.gwarak))) {
        return '가답안 ${actualScore!.toStringAsFixed(0)}점 — 합격권이에요! '
            '${gap >= 0 ? '예측보다 +${gap.toStringAsFixed(0)}점 잘 봤어요.' : '예측보다 ${gap.toStringAsFixed(0)}점 낮았어요.'}';
      }
      return '가답안 ${actualScore!.toStringAsFixed(0)}점 — 아쉽지만 다음 회차를 노려봐요. '
          '약점 과목을 집중 보완하면 충분히 가능해요.';
    }
    // 아직 시험 전: 예측 + 플랜 중심 문구
    if (prediction.needsDiagnosis) {
      return '아직 풀이 데이터가 적어요. 진단 문제를 ${PassPrediction.minAttempts}개 이상 풀면 '
          '정확한 합격 예측이 시작돼요.';
    }
    final p = plan;
    if (p == null || dDay == null) {
      return '지금 실력 예측 ${prediction.overall.toStringAsFixed(0)}점. '
          '응시할 회차를 정하면 D-Day 학습 플랜을 계산해 드려요.';
    }
    if (p.onTrack) {
      return '예측 ${prediction.overall.toStringAsFixed(0)}점 — 이미 합격권! '
          '$dDay일 동안 감을 유지하며 오답만 정리하면 돼요.';
    }
    if (!p.feasible) {
      return 'D-$dDay 안에 목표까지 하루 ${p.perDay}문제는 빠듯해요. '
          '핵심 빈출 토픽부터 공략하는 전략이 필요해요.';
    }
    return '합격까지 하루 ${p.perDay}문제씩 $dDay일! '
        '가장 효율 높은 토픽부터 풀면 예측 점수가 빠르게 올라요.';
  }
}

class ExamAnalysisEngine {
  ExamAnalysisEngine._();
  static final ExamAnalysisEngine instance = ExamAnalysisEngine._();

  int? _dDay(DateTime? d) {
    if (d == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final t = DateTime(d.year, d.month, d.day);
    return t.difference(today).inDays;
  }

  /// 회차·단계에 대한 통합 분석 계산.
  ///
  /// [round] 크롤링한 회차 일정, [phase] 필기/실기,
  /// [registration] 응시 등록/가답안(있으면).
  Future<ExamAnalysis> analyze({
    required QnetExamRound round,
    required ExamPhase phase,
    ExamRegistration? registration,
    double targetScore = 60,
  }) async {
    // 1) 실제 시험일 → D-Day
    final examRange =
        phase == ExamPhase.written ? round.writtenExam : round.practicalExam;
    final examDate = examRange?.start;
    final dDay = _dDay(examDate);

    // 2) 과거 학습데이터 기반 현재 실력 예측
    final prediction = await PassPredictionEngine.instance.predict();

    // 3) D-Day 역산 플랜 (시험이 아직 안 지났을 때만 의미 있음)
    DDayPlan? plan;
    if (dDay != null && dDay >= 0) {
      plan = await DDayPlannerEngine.instance.compute(
        dDay: dDay,
        currentScore: prediction.overall,
        targetScore: targetScore,
      );
    }

    // 4) 가답안 실채점 vs 예측 비교
    double? actual;
    double? gap;
    if (registration?.score != null) {
      actual = registration!.score;
      gap = actual! - prediction.overall;
    }

    return ExamAnalysis(
      roundLabel: round.label,
      phase: phase,
      dDay: dDay,
      examDate: examDate,
      prediction: prediction,
      plan: plan,
      actualScore: actual,
      predVsActualGap: gap,
    );
  }

  /// 가답안 채점 결과를 과거 점수 이력([ScoreHistory])에 실측 스냅샷으로 반영.
  /// → 통계·추세 그래프가 "예측"뿐 아니라 "실제 시험 결과"까지 함께 담게 된다.
  Future<void> recordActualToHistory(ExamRegistration reg) async {
    final score = reg.score;
    if (score == null) return;
    try {
      await ScoreHistory.instance.record(score, reg.scoredTotal ?? 0);
    } catch (_) {}
  }
}
