import 'study_data.dart';

/// Validates server grading round-trips and derives the CBT's subject scores.
class CbtGradeSummary {
  CbtGradeSummary._({
    required this.resultsByQid,
    required this.subjectScores,
    required this.correct,
    required this.total,
  });

  final Map<String, Map<String, dynamic>> resultsByQid;
  final Map<String, double> subjectScores;
  final int correct;
  final int total;

  double get average => subjectScores.isEmpty
      ? 0
      : subjectScores.values.reduce((left, right) => left + right) /
            subjectScores.length;

  List<String> get failedSubjects => subjectScores.entries
      .where((entry) => entry.value < 40)
      .map((entry) => entry.key)
      .toList(growable: false);

  Map<String, dynamic>? resultFor(Question question) {
    final qid = question.remoteQid;
    return qid == null ? null : resultsByQid[qid];
  }

  factory CbtGradeSummary.fromResponse({
    required List<Question> questions,
    required Map<int, int> picked,
    required Map<String, dynamic> response,
  }) {
    if (questions.isEmpty) {
      throw const FormatException('채점할 문항이 없습니다.');
    }

    final questionByQid = <String, Question>{};
    for (final question in questions) {
      final qid = question.remoteQid;
      if (qid == null || qid.isEmpty || questionByQid.containsKey(qid)) {
        throw const FormatException('CBT 문항 ID가 없거나 중복되었습니다.');
      }
      questionByQid[qid] = question;
    }

    final rawResults = response['results'];
    if (rawResults is! List || rawResults.length != questions.length) {
      throw const FormatException('서버 채점 결과가 일부 누락되었습니다.');
    }

    final resultsByQid = <String, Map<String, dynamic>>{};
    for (final raw in rawResults) {
      if (raw is! Map) {
        throw const FormatException('서버 채점 결과 형식이 올바르지 않습니다.');
      }
      final result = Map<String, dynamic>.from(raw);
      final qid = result['qid'];
      final question = qid is String ? questionByQid[qid] : null;
      if (question == null || resultsByQid.containsKey(qid)) {
        throw const FormatException('서버 채점 문항이 요청과 일치하지 않습니다.');
      }

      final answer = result['answer'];
      final returnedPick = result['picked'];
      final isCorrect = result['correct'];
      final expectedPick = picked[questions.indexOf(question)] ?? 0;
      if (answer is! num ||
          answer != answer.toInt() ||
          answer.toInt() < 1 ||
          answer.toInt() > question.options.length ||
          returnedPick is! num ||
          returnedPick != expectedPick ||
          isCorrect is! bool ||
          isCorrect != (expectedPick > 0 && answer.toInt() == expectedPick)) {
        throw const FormatException('서버 채점 결과가 답안과 일치하지 않습니다.');
      }
      result['answer'] = answer.toInt();
      resultsByQid[qid] = Map<String, dynamic>.unmodifiable(result);
    }

    final reportedTotal = response['total'];
    final reportedCorrect = response['correct'];
    final correct = resultsByQid.values
        .where((result) => result['correct'] == true)
        .length;
    if (resultsByQid.length != questions.length ||
        reportedTotal is! num ||
        reportedTotal != questions.length ||
        reportedCorrect is! num ||
        reportedCorrect != correct) {
      throw const FormatException('서버 채점 합계가 문항별 결과와 다릅니다.');
    }

    final subjectTotals = <String, int>{};
    final subjectCorrect = <String, int>{};
    for (final question in questions) {
      final qid = question.remoteQid!;
      subjectTotals.update(
        question.subject,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      if (resultsByQid[qid]!['correct'] == true) {
        subjectCorrect.update(
          question.subject,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }
    }

    final subjectScores = <String, double>{
      for (final entry in subjectTotals.entries)
        entry.key: (subjectCorrect[entry.key] ?? 0) * 100 / entry.value,
    };

    return CbtGradeSummary._(
      resultsByQid: Map<String, Map<String, dynamic>>.unmodifiable(
        resultsByQid,
      ),
      subjectScores: Map<String, double>.unmodifiable(subjectScores),
      correct: correct,
      total: questions.length,
    );
  }
}
