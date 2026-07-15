/// 문제풀이와 실전 시험에서 공유하는 결정적 정책.
class QuizPolicy {
  const QuizPolicy._();

  /// 실전 시험은 제출 전 정답과 해설을 절대 공개하지 않는다.
  static bool canRevealAnswer({
    required bool examMode,
    required bool submitted,
  }) => !examMode || submitted;

  static int unansweredCount({required int total, required int answered}) =>
      (total - answered).clamp(0, total);

  /// 국가기술자격 필기 합격: 평균 60점 이상이며 모든 과목 40점 이상.
  static bool isPassed({
    required int correct,
    required int total,
    required Map<String, int> subjectTotal,
    required Map<String, int> subjectCorrect,
  }) {
    if (total <= 0) return false;
    final overall = correct * 100 / total;
    if (overall < 60) return false;
    for (final entry in subjectTotal.entries) {
      if (entry.value <= 0) return false;
      final score = (subjectCorrect[entry.key] ?? 0) * 100 / entry.value;
      if (score < 40) return false;
    }
    return true;
  }
}
