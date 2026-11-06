import 'package:cert_study_tracker/services/cbt_grade_summary.dart';
import 'package:cert_study_tracker/services/study_data.dart';
import 'package:flutter_test/flutter_test.dart';

Question _question({required String qid, required String subject}) => Question(
  no: 1,
  subject: subject,
  topic: '기초',
  question: '테스트 문항',
  options: const ['1', '2', '3', '4'],
  answer: 0,
  hasImage: false,
  remoteQid: qid,
);

void main() {
  group('CbtGradeSummary', () {
    test('uses server grades to calculate subject and overall scores', () {
      final questions = [
        _question(qid: 'q1', subject: '전기설비'),
        _question(qid: 'q2', subject: '전기설비'),
        _question(qid: 'q3', subject: '전력공학'),
      ];

      final summary = CbtGradeSummary.fromResponse(
        questions: questions,
        picked: const {0: 2, 1: 1, 2: 0},
        response: {
          'total': 3,
          'correct': 1,
          'results': [
            {'qid': 'q1', 'picked': 2, 'answer': 2, 'correct': true},
            {'qid': 'q2', 'picked': 1, 'answer': 3, 'correct': false},
            {
              'qid': 'q3',
              'picked': 0,
              'answer': 4,
              'correct': false,
              'explanation': '미응답 문항은 오답 처리됩니다.',
            },
          ],
        },
      );

      expect(summary.correct, 1);
      expect(summary.total, 3);
      expect(summary.subjectScores['전기설비'], 50);
      expect(summary.subjectScores['전력공학'], 0);
      expect(summary.average, 25);
      expect(summary.failedSubjects, ['전력공학']);
      expect(summary.resultFor(questions[2])?['explanation'], contains('미응답'));
    });

    test('rejects a server response that omits a requested question', () {
      final questions = [_question(qid: 'q1', subject: '전기설비')];

      expect(
        () => CbtGradeSummary.fromResponse(
          questions: questions,
          picked: const {0: 1},
          response: const {'total': 0, 'correct': 0, 'results': []},
        ),
        throwsFormatException,
      );
    });

    test('rejects inconsistent correctness from the server', () {
      final questions = [_question(qid: 'q1', subject: '전기설비')];

      expect(
        () => CbtGradeSummary.fromResponse(
          questions: questions,
          picked: const {0: 2},
          response: const {
            'total': 1,
            'correct': 1,
            'results': [
              {'qid': 'q1', 'picked': 2, 'answer': 2, 'correct': false},
            ],
          },
        ),
        throwsFormatException,
      );
    });
  });
}
