import 'study_data.dart';

/// [P1-B/T10] 채점 결과 — UI/저장/연출과 분리된 순수 데이터.
///
/// `_finish()` 안에 뒤섞여 있던 채점 로직(과목별 집계, 오답 목록 생성)을
/// 이 순수 함수로 추출했다. 부작용(await, context, Hive 쓰기)이 전혀 없어
/// 위젯 없이 단위 테스트가 가능하다.
class QuizGradeResult {
  final int total;
  final int correct;
  final int percent; // 0~100, total==0이면 0
  final Map<String, int> subjectTotal;
  final Map<String, int> subjectCorrect;
  final List<Question> wrongQuestions;

  const QuizGradeResult({
    required this.total,
    required this.correct,
    required this.percent,
    required this.subjectTotal,
    required this.subjectCorrect,
    required this.wrongQuestions,
  });

  /// 오답노트 자동등록에 쓰는 요약 문자열 목록.
  List<String> wrongSummaries() => wrongQuestions
      .map(
        (q) =>
            '[${q.subject}] ${q.examLabel} ${q.no}번: '
            '${q.question.length > 60 ? q.question.substring(0, 60) : q.question}',
      )
      .toList();
}

class QuizGrader {
  QuizGrader._();

  /// [i] = 문항 인덱스, [picked] 값 = 선택한 보기(1-based). 선택하지 않은
  /// 문항은 picked에 키가 없으며 오답으로 처리한다(실전 미답 = 오답과 동일 취급,
  /// 기존 `_finish()` 동작과 동일하게 유지).
  static QuizGradeResult grade(
    List<Question> questions,
    Map<int, int> picked,
  ) {
    var correct = 0;
    final subjectTotal = <String, int>{};
    final subjectCorrect = <String, int>{};
    final wrongList = <Question>[];
    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      subjectTotal[q.subject] = (subjectTotal[q.subject] ?? 0) + 1;
      if (picked[i] == q.answer) {
        correct++;
        subjectCorrect[q.subject] = (subjectCorrect[q.subject] ?? 0) + 1;
      } else {
        wrongList.add(q);
      }
    }
    final total = questions.length;
    final pct = total == 0 ? 0 : (correct * 100 / total).round();
    return QuizGradeResult(
      total: total,
      correct: correct,
      percent: pct,
      subjectTotal: subjectTotal,
      subjectCorrect: subjectCorrect,
      wrongQuestions: wrongList,
    );
  }
}
