import 'package:flutter_test/flutter_test.dart';
import 'package:cert_study_tracker/services/auto_study_service.dart';

void main() {
  group('AutoStudyService 학습량 계산', () {
    test('남은 목표 시간을 문항 예산으로 변환한다', () {
      expect(
        AutoStudyService.questionBudget(
          dailyGoalMinutes: 60,
          studiedMinutes: 20,
        ),
        20,
      );
    });

    test('목표를 달성했어도 최소 복습량을 유지한다', () {
      expect(
        AutoStudyService.questionBudget(
          dailyGoalMinutes: 30,
          studiedMinutes: 40,
        ),
        10,
      );
    });

    test('과도한 일일 목표는 최대 문항 수로 제한한다', () {
      expect(
        AutoStudyService.questionBudget(
          dailyGoalMinutes: 300,
          studiedMinutes: 0,
        ),
        40,
      );
    });
  });

  group('AutoStudyService 우선순위', () {
    test('복습과 오답을 새로운 문제보다 먼저 배치한다', () {
      expect(
        AutoStudyService.priorityOrder(
          dueCount: 3,
          wrongCount: 2,
          includeMock: true,
        ),
        [
          AutoStudyTaskKind.dueReview,
          AutoStudyTaskKind.wrongRecovery,
          AutoStudyTaskKind.adaptivePractice,
          AutoStudyTaskKind.miniMock,
        ],
      );
    });

    test('기록이 없어도 맞춤 연습은 항상 제공한다', () {
      expect(
        AutoStudyService.priorityOrder(
          dueCount: 0,
          wrongCount: 0,
          includeMock: false,
        ),
        [AutoStudyTaskKind.adaptivePractice],
      );
    });
  });
}
