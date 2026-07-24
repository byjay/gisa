import 'package:cert_study_tracker/services/quiz_grader.dart';
import 'package:cert_study_tracker/services/study_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// [P1-B/T10] QuizGrader — quiz_play_screen._finish()에서 추출한 순수
/// 채점 함수의 회귀 테스트. 위젯 없이 채점 정확성만 검증한다.
void main() {
  Question q({
    required int no,
    required String subject,
    int answer = 1,
  }) => Question(
    no: no,
    subject: subject,
    topic: 't',
    question: '문제 $no',
    options: const ['1', '2', '3', '4'],
    answer: answer,
    hasImage: false,
  );

  group('QuizGrader.grade', () {
    test('빈 문항 목록이면 total=0, percent=0으로 안전하게 처리된다', () {
      final r = QuizGrader.grade(const [], const {});
      expect(r.total, 0);
      expect(r.correct, 0);
      expect(r.percent, 0);
      expect(r.subjectTotal, isEmpty);
      expect(r.wrongQuestions, isEmpty);
    });

    test('전부 정답이면 percent=100, 오답 없음', () {
      final questions = [
        q(no: 1, subject: '전기이론', answer: 2),
        q(no: 2, subject: '전기이론', answer: 3),
      ];
      final picked = {0: 2, 1: 3};
      final r = QuizGrader.grade(questions, picked);
      expect(r.correct, 2);
      expect(r.percent, 100);
      expect(r.wrongQuestions, isEmpty);
    });

    test('미답 문항(picked에 키 없음)은 오답으로 취급한다', () {
      final questions = [q(no: 1, subject: '전기이론', answer: 1)];
      final picked = <int, int>{}; // 아무것도 선택하지 않음
      final r = QuizGrader.grade(questions, picked);
      expect(r.correct, 0);
      expect(r.wrongQuestions.length, 1);
    });

    test('과목별 집계가 정확히 분리된다', () {
      final questions = [
        q(no: 1, subject: 'A', answer: 1),
        q(no: 2, subject: 'A', answer: 1),
        q(no: 3, subject: 'B', answer: 1),
      ];
      final picked = {0: 1, 1: 2, 2: 1}; // A과목 1문 오답, B과목 정답
      final r = QuizGrader.grade(questions, picked);
      expect(r.subjectTotal['A'], 2);
      expect(r.subjectCorrect['A'], 1);
      expect(r.subjectTotal['B'], 1);
      expect(r.subjectCorrect['B'], 1);
    });

    test('percent는 반올림 처리된다 (2/3 -> 67)', () {
      final questions = [
        q(no: 1, subject: 'A', answer: 1),
        q(no: 2, subject: 'A', answer: 1),
        q(no: 3, subject: 'A', answer: 1),
      ];
      final picked = {0: 1, 1: 1, 2: 2}; // 2/3 정답
      final r = QuizGrader.grade(questions, picked);
      expect(r.percent, 67);
    });

    test('wrongSummaries는 과목·회차·번호·60자 이내 요약을 포함한다', () {
      final longQuestion = 'ㄱ' * 100;
      final q1 = Question(
        no: 5,
        subject: '전기이론',
        topic: 't',
        question: longQuestion,
        options: const ['1', '2'],
        answer: 1,
        hasImage: false,
        examLabel: '2024-1회',
      );
      final r = QuizGrader.grade([q1], <int, int>{}); // 오답 처리
      final summaries = r.wrongSummaries();
      expect(summaries.length, 1);
      expect(summaries.first, contains('[전기이론]'));
      expect(summaries.first, contains('2024-1회'));
      expect(summaries.first, contains('5번'));
      // 60자 초과 문제는 잘려야 한다 (전체 100자가 그대로 포함되지 않음).
      expect(summaries.first.length, lessThan(longQuestion.length + 30));
    });
  });
}
