import 'score_history.dart';

/// 🗓 D-Day 합격 역산 플래너 — "며칠 남았고, 하루에 몇 문제 풀어야 60점에 닿는가"를
/// 구체적인 숫자로 계산. 감이 아니라 계획을 파는 화면의 핵심 로직.
class DDayPlan {
  final int dDay;
  final double currentScore;
  final double targetScore;
  final double pointsNeeded; // 목표까지 남은 점수
  final double gainPerQuestion; // 문제 1개당 예상 점수 상승 (실측 or 기본값)
  final int questionsNeeded; // 목표 도달까지 필요한 총 문제 수
  final int perDay; // 남은 일수로 나눈 하루 권장 문제 수
  final bool onTrack; // 이미 목표 이상인가
  final bool feasible; // D-Day 안에 현실적으로 도달 가능한가 (하루 60문제 이하)

  DDayPlan({
    required this.dDay,
    required this.currentScore,
    required this.targetScore,
    required this.gainPerQuestion,
  })  : pointsNeeded =
            (targetScore - currentScore) < 0 ? 0 : (targetScore - currentScore),
        questionsNeeded = (targetScore - currentScore) <= 0
            ? 0
            : ((targetScore - currentScore) / gainPerQuestion).ceil(),
        onTrack = currentScore >= targetScore,
        perDay = dDay <= 0
            ? 0
            : (((targetScore - currentScore) <= 0
                    ? 0
                    : ((targetScore - currentScore) / gainPerQuestion))
                / dDay)
                .ceil(),
        feasible = dDay <= 0
            ? false
            : (((targetScore - currentScore) <= 0
                        ? 0
                        : ((targetScore - currentScore) / gainPerQuestion)) /
                    dDay) <=
                60;
}

class DDayPlannerEngine {
  DDayPlannerEngine._();
  static final DDayPlannerEngine instance = DDayPlannerEngine._();

  Future<DDayPlan> compute({
    required int dDay,
    required double currentScore,
    double targetScore = 60,
  }) async {
    final gain = await ScoreHistory.instance.gainPerQuestion();
    return DDayPlan(
      dDay: dDay,
      currentScore: currentScore,
      targetScore: targetScore,
      gainPerQuestion: gain,
    );
  }
}
