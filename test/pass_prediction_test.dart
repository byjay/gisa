import 'package:flutter_test/flutter_test.dart';
import 'package:cert_study_tracker/services/pass_prediction.dart';

void main() {
  group('PassPrediction 합격 판정 모델', () {
    SubjectPrediction sp(String s, double score, {int attempts = 10}) =>
        SubjectPrediction(subject: s, score: score, attempts: attempts);

    test('평균 60점 이상 + 전 과목 40점 이상이면 합격이다', () {
      final p = PassPrediction(
        overall: 65,
        subjects: [sp('A', 70), sp('B', 60), sp('C', 65)],
        totalAttempts: 30,
        prescriptions: const [],
      );
      expect(p.pass, isTrue);
    });

    test('평균이 60점이어도 한 과목이 40점 미만(과락)이면 불합격이다', () {
      final p = PassPrediction(
        overall: 62,
        subjects: [sp('A', 90), sp('B', 39), sp('C', 57)],
        totalAttempts: 30,
        prescriptions: const [],
      );
      expect(p.subjects[1].gwarak, isTrue);
      expect(p.pass, isFalse);
    });

    test('평균이 60점 미만이면 과락이 없어도 불합격이다', () {
      final p = PassPrediction(
        overall: 55,
        subjects: [sp('A', 55), sp('B', 55), sp('C', 55)],
        totalAttempts: 30,
        prescriptions: const [],
      );
      expect(p.subjects.any((s) => s.gwarak), isFalse);
      expect(p.pass, isFalse);
    });

    test('경계값: 정확히 40점은 과락이 아니다', () {
      expect(sp('A', 40).gwarak, isFalse);
      expect(sp('A', 39.99).gwarak, isTrue);
    });

    test('풀이 수가 최소 기준 미만이면 진단고사를 유도한다', () {
      final p = PassPrediction(
        overall: 35,
        subjects: [sp('A', 35, attempts: 2)],
        totalAttempts: 2,
        prescriptions: const [],
      );
      expect(p.needsDiagnosis, isTrue);

      final p2 = PassPrediction(
        overall: 35,
        subjects: [sp('A', 35)],
        totalAttempts: PassPrediction.minAttempts,
        prescriptions: const [],
      );
      expect(p2.needsDiagnosis, isFalse);
    });

    test('처방전은 기대 상승폭 정보를 보존한다', () {
      final rx = Prescription(
        subject: '회로이론',
        topic: '교류회로',
        expectedGain: 3.2,
        topicQuestionCount: 24,
      );
      expect(rx.expectedGain, closeTo(3.2, 0.001));
      expect(rx.topicQuestionCount, 24);
    });
  });
}
