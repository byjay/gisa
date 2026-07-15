import 'package:cert_study_tracker/services/quiz_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QuizPolicy 정답 공개', () {
    test('연습 모드는 제출 전에도 공개할 수 있다', () {
      expect(
        QuizPolicy.canRevealAnswer(examMode: false, submitted: false),
        isTrue,
      );
    });

    test('실전 모드는 제출 전에 공개할 수 없다', () {
      expect(
        QuizPolicy.canRevealAnswer(examMode: true, submitted: false),
        isFalse,
      );
    });

    test('실전 모드는 제출 후 공개할 수 있다', () {
      expect(
        QuizPolicy.canRevealAnswer(examMode: true, submitted: true),
        isTrue,
      );
    });
  });

  group('QuizPolicy 미답 계산', () {
    test('미답 수를 계산한다', () {
      expect(QuizPolicy.unansweredCount(total: 100, answered: 87), 13);
    });

    test('답변 수가 전체보다 커도 음수가 되지 않는다', () {
      expect(QuizPolicy.unansweredCount(total: 10, answered: 11), 0);
    });
  });

  group('QuizPolicy 합격 판정', () {
    test('평균 60점 이상이고 과락이 없으면 합격한다', () {
      expect(
        QuizPolicy.isPassed(
          correct: 60,
          total: 100,
          subjectTotal: const {'A': 20, 'B': 20, 'C': 20, 'D': 20, 'E': 20},
          subjectCorrect: const {'A': 12, 'B': 12, 'C': 12, 'D': 12, 'E': 12},
        ),
        isTrue,
      );
    });

    test('평균이 60점이어도 한 과목이 40점 미만이면 불합격한다', () {
      expect(
        QuizPolicy.isPassed(
          correct: 60,
          total: 100,
          subjectTotal: const {'A': 20, 'B': 20, 'C': 20, 'D': 20, 'E': 20},
          subjectCorrect: const {'A': 7, 'B': 13, 'C': 13, 'D': 13, 'E': 14},
        ),
        isFalse,
      );
    });

    test('전체 문항이 0이면 안전하게 불합격 처리한다', () {
      expect(
        QuizPolicy.isPassed(
          correct: 0,
          total: 0,
          subjectTotal: const {},
          subjectCorrect: const {},
        ),
        isFalse,
      );
    });
  });
}
