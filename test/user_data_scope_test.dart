import 'dart:io';

import 'package:cert_study_tracker/models/models.dart';
import 'package:cert_study_tracker/providers/app_provider.dart';
import 'package:cert_study_tracker/services/progress_service.dart';
import 'package:cert_study_tracker/services/progress_snapshot_store.dart';
import 'package:cert_study_tracker/services/flashcard_srs.dart';
import 'package:cert_study_tracker/services/score_history.dart';
import 'package:cert_study_tracker/services/exam_registration.dart';
import 'package:cert_study_tracker/services/secure_box_service.dart';
import 'package:cert_study_tracker/services/study_data.dart';
import 'package:cert_study_tracker/services/user_data_scope.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('gisaclub_user_scope_');
    Hive.init(tempDir.path);
    UserDataScope.activate(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory' ||
              call.method == 'getApplicationSupportDirectory') {
            return tempDir.path;
          }
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test(
    'guest retains legacy box names and accounts get private deterministic names',
    () {
      expect(UserDataScope.boxName('sessions'), 'sessions');
      final alice = UserDataScope.boxNameForOwner('sessions', 'account-alice');
      final bob = UserDataScope.boxNameForOwner('sessions', 'account-bob');

      expect(alice, isNot(bob));
      expect(alice, UserDataScope.boxNameForOwner('sessions', 'account-alice'));
      expect(alice, startsWith('sessions__account_'));
      expect(alice, isNot(contains('account-alice')));
    },
  );

  test(
    'question progress is isolated when switching between accounts',
    () async {
      final service = ProgressService.instance;
      final question = Question(
        no: 1,
        subject: '전기기사',
        topic: '회로이론',
        question: '테스트 문제',
        options: const ['1', '2', '3', '4'],
        answer: 1,
        hasImage: false,
        remoteQid: 'isolated-question',
      );

      await service.activateUser('account-alice');
      await service.record(question, false);
      expect(await service.wrongCountFor(question.qid), 1);

      await service.activateUser('account-bob');
      expect(await service.wrongCountFor(question.qid), 0);
      await service.record(question, true);

      await service.activateUser('account-alice');
      expect(await service.wrongCountFor(question.qid), 1);
      expect((await service.historyFor(question.qid))?.lastResult, 'x');
    },
  );

  test(
    'AppProvider switches sessions and quiz results without crossing accounts',
    () async {
      final provider = AppProvider();
      await provider.init(initializeHive: false);
      await provider.activateUser('account-alice');
      await provider.addSession(
        StudySession(
          id: 'alice-session',
          examId: '',
          date: DateTime(2026),
          minutes: 12,
        ),
      );
      await provider.addQuizResult(title: 'Alice quiz', total: 1, correct: 1);

      await provider.activateUser('account-bob');
      expect(provider.sessions, isEmpty);
      expect(provider.quizResults, isEmpty);
      await provider.addSession(
        StudySession(
          id: 'bob-session',
          examId: '',
          date: DateTime(2026),
          minutes: 7,
        ),
      );

      await provider.activateUser('account-alice');
      expect(provider.sessions.map((session) => session.id), ['alice-session']);
      expect(provider.quizResults.single['title'], 'Alice quiz');
    },
  );

  test(
    'remote snapshot merge preserves newer local rows and applies tombstones per account',
    () async {
      UserDataScope.activate('account-alice');
      final itemBox = await Hive.openBox(
        UserDataScope.boxName('questionProgress'),
      );
      await itemBox.put('q-local', {'wrong': 4, 'updatedAt': 100});
      final sessions = await SecureBoxService.instance.openSecureBox(
        UserDataScope.boxName('sessions'),
      );
      await sessions.put('session-keep', {
        'id': 'session-keep',
        'examId': '',
        'date': '2026-01-01',
        'minutes': 5,
        'updatedAt': 100,
      });
      await sessions.put('session-delete', {
        'id': 'session-delete',
        'examId': '',
        'date': '2026-01-01',
        'minutes': 9,
        'updatedAt': 100,
      });
      final quizzes = await SecureBoxService.instance.openSecureBox(
        UserDataScope.boxName('quizResults'),
      );
      await quizzes.put('quiz-delete', {
        'id': 'quiz-delete',
        'title': 'old',
        'total': 1,
        'correct': 1,
        'date': '2026-01-01',
        'updatedAt': 100,
      });

      await ProgressSnapshotStore.mergeRemote({
        'items': {
          'q-local': {'wrong': 1, 'updatedAt': 99},
          'q-remote': {'correct': 2, 'updatedAt': 101},
        },
        'sessions': [
          {
            'id': 'session-delete',
            'examId': '',
            'date': '2026-01-01',
            'minutes': 9,
            'updatedAt': 200,
          },
          {
            'id': 'session-remote',
            'examId': '',
            'date': '2026-01-02',
            'minutes': 3,
            'updatedAt': 101,
          },
        ],
        'quizResults': [
          {
            'id': 'quiz-delete',
            'title': 'stale',
            'total': 1,
            'correct': 1,
            'date': '2026-01-01',
            'updatedAt': 200,
          },
          {
            'id': 'quiz-remote',
            'title': 'new',
            'total': 2,
            'correct': 1,
            'date': '2026-01-02',
            'updatedAt': 101,
          },
        ],
        'deleted': {
          'sessions': ['session-delete'],
          'quizResults': ['quiz-delete'],
        },
      });

      final alice = await ProgressSnapshotStore.read();
      expect((alice['items'] as Map)['q-local']['wrong'], 4);
      expect((alice['items'] as Map), contains('q-remote'));
      expect((alice['sessions'] as List).map((row) => row['id']), [
        'session-keep',
        'session-remote',
      ]);
      expect((alice['quizResults'] as List).map((row) => row['id']), [
        'quiz-remote',
      ]);

      UserDataScope.activate('account-bob');
      final bob = await ProgressSnapshotStore.read();
      expect((bob['items'] as Map), isEmpty);
      expect(bob['sessions'], isEmpty);
      expect(bob['quizResults'], isEmpty);
      expect((bob['deleted'] as Map)['sessions'], isEmpty);
    },
  );

  test(
    'progress snapshot syncs safe feature state but never wrong-note text',
    () async {
      UserDataScope.activate('account-alice');
      final ownerBox = UserDataScope.boxName('sessions');
      final flashcards = await Hive.openBox(
        UserDataScope.boxName('flashcardSrs'),
      );
      await flashcards.put('card-q1', {
        'box': 2,
        'seen': 4,
        'known': 3,
        'nextDue': '2026-10-30T00:00:00.000Z',
        'updatedAt': 100,
      });
      final scores = await Hive.openBox(UserDataScope.boxName('scoreHistory'));
      await scores.put('2026-10-29', {
        'score': 70.1254,
        'attempts': 40,
        'ts': '2026-10-29T01:00:00.000Z',
        'updatedAt': 101,
      });
      final slides = await Hive.openBox(UserDataScope.boxName('slideProgress'));
      await slides.put('seen_1', 7);
      await slides.put('seen_summary_2', 3);
      await slides.put('lastDay', 2);
      await slides.put('level', 'fast');
      await slides.put('__meta_last_day_updated_at', 102);
      await slides.put('__meta_level_updated_at', 103);
      final registrations = await SecureBoxService.instance.openSecureBox(
        UserDataScope.boxName('exam_registrations'),
      );
      await registrations.put('reg-1', {
        'id': 'reg-1',
        'jmCd': '1234',
        'catalogId': 'electrician',
        'certName': '전기기사',
        'roundLabel': '2026년 1회',
        'phase': 'written',
        'status': 'taken',
        'scoredTotal': 100,
        'scoredCorrect': 71,
        'subjectFails': 0,
        'scoredAt': '2026-10-29T01:00:00.000Z',
        'updatedAt': 104,
      });
      final wrongNotes = await SecureBoxService.instance.openSecureBox(
        UserDataScope.boxName('wrongNotes'),
      );
      await wrongNotes.put('private-note', {
        'question': '비공개 문제 원문',
        'answer': '비공개 정답',
        'memo': '사용자 개인 메모',
      });

      final snapshot = await ProgressSnapshotStore.read();
      expect(snapshot['flashcards'], hasLength(1));
      expect((snapshot['flashcards'] as List).single['id'], 'card-q1');
      expect((snapshot['scores'] as List).single['scoreMilli'], 70125);
      expect(snapshot['slides'], {
        'seen_1': 7,
        'seen_summary_2': 3,
        'lastDay': 2,
        'lastDayUpdatedAt': 102,
        'level': 'fast',
        'levelUpdatedAt': 103,
      });
      expect((snapshot['registrations'] as List).single['certName'], '전기기사');
      expect(snapshot.toString(), isNot(contains('비공개 문제 원문')));
      expect(snapshot.toString(), isNot(contains('비공개 정답')));
      expect(snapshot.toString(), isNot(contains('사용자 개인 메모')));

      UserDataScope.activate('account-bob');
      final bob = await ProgressSnapshotStore.read();
      expect(bob['flashcards'], isEmpty);
      expect(bob['scores'], isEmpty);
      expect(bob['slides'], isEmpty);
      expect(bob['registrations'], isEmpty);
      expect(ownerBox, isNot(UserDataScope.boxName('sessions')));
    },
  );

  test(
    'SRS and millipoint score writes stay in the active account namespace',
    () async {
      UserDataScope.activate('account-alice');
      await FlashcardSrs.instance.activateUser();
      await ScoreHistory.instance.activateUser();
      await FlashcardSrs.instance.mark('card-q1', true);
      await ScoreHistory.instance.record(99.9996, 12);

      final alice = await ProgressSnapshotStore.read();
      expect((alice['flashcards'] as List).single['id'], 'card-q1');
      expect((alice['scores'] as List).single['scoreMilli'], 100000);
      expect((await ScoreHistory.instance.recent(days: 1)).single.$2, 100);

      UserDataScope.activate('account-bob');
      await FlashcardSrs.instance.activateUser();
      await ScoreHistory.instance.activateUser();
      final bob = await ProgressSnapshotStore.read();
      expect(bob['flashcards'], isEmpty);
      expect(bob['scores'], isEmpty);
      expect(await FlashcardSrs.instance.seenKeys(), isEmpty);
      expect(await ScoreHistory.instance.recent(days: 1), isEmpty);
    },
  );

  test(
    'equal-timestamp SRS conflicts converge independent of device order',
    () async {
      UserDataScope.activate('account-a');
      final accountA = await Hive.openBox(
        UserDataScope.boxName('flashcardSrs'),
      );
      await accountA.put('card-q1', {
        'box': 1,
        'seen': 2,
        'known': 1,
        'updatedAt': 50,
      });
      final scoreA = await Hive.openBox(UserDataScope.boxName('scoreHistory'));
      await scoreA.put('2026-10-29', {
        'scoreMilli': 60000,
        'attempts': 20,
        'updatedAt': 50,
      });
      final registrationA = await SecureBoxService.instance.openSecureBox(
        UserDataScope.boxName('exam_registrations'),
      );
      await registrationA.put('reg-1', {
        'id': 'reg-1',
        'jmCd': '1234',
        'catalogId': 'electrician',
        'certName': '전기기사',
        'roundLabel': '1회',
        'phase': 'written',
        'status': 'planned',
        'updatedAt': 50,
      });
      await ProgressSnapshotStore.mergeRemote({
        'flashcards': [
          {'id': 'card-q1', 'box': 3, 'seen': 4, 'known': 2, 'updatedAt': 50},
        ],
        'scores': [
          {
            'id': '2026-10-29',
            'scoreMilli': 70000,
            'attempts': 30,
            'updatedAt': 50,
          },
        ],
        'registrations': [
          {
            'id': 'reg-1',
            'jmCd': '1234',
            'catalogId': 'electrician',
            'certName': '전기기사',
            'roundLabel': '1회',
            'phase': 'written',
            'status': 'passed',
            'updatedAt': 50,
          },
        ],
      });
      final afterServerThenClient = await ProgressSnapshotStore.read();

      UserDataScope.activate('account-b');
      final accountB = await Hive.openBox(
        UserDataScope.boxName('flashcardSrs'),
      );
      await accountB.put('card-q1', {
        'box': 3,
        'seen': 4,
        'known': 2,
        'updatedAt': 50,
      });
      final scoreB = await Hive.openBox(UserDataScope.boxName('scoreHistory'));
      await scoreB.put('2026-10-29', {
        'scoreMilli': 70000,
        'attempts': 30,
        'updatedAt': 50,
      });
      final registrationB = await SecureBoxService.instance.openSecureBox(
        UserDataScope.boxName('exam_registrations'),
      );
      await registrationB.put('reg-1', {
        'id': 'reg-1',
        'jmCd': '1234',
        'catalogId': 'electrician',
        'certName': '전기기사',
        'roundLabel': '1회',
        'phase': 'written',
        'status': 'passed',
        'updatedAt': 50,
      });
      await ProgressSnapshotStore.mergeRemote({
        'flashcards': [
          {'id': 'card-q1', 'box': 1, 'seen': 2, 'known': 1, 'updatedAt': 50},
        ],
        'scores': [
          {
            'id': '2026-10-29',
            'scoreMilli': 60000,
            'attempts': 20,
            'updatedAt': 50,
          },
        ],
        'registrations': [
          {
            'id': 'reg-1',
            'jmCd': '1234',
            'catalogId': 'electrician',
            'certName': '전기기사',
            'roundLabel': '1회',
            'phase': 'written',
            'status': 'planned',
            'updatedAt': 50,
          },
        ],
      });
      final afterClientThenServer = await ProgressSnapshotStore.read();

      for (final collection in ['flashcards', 'scores', 'registrations']) {
        expect(
          afterServerThenClient[collection],
          afterClientThenServer[collection],
        );
      }
    },
  );

  test(
    'registration saves are timestamped and deletions create account-local tombstones',
    () async {
      UserDataScope.activate('account-alice');
      await ExamRegistrationStore.instance.init(ownerId: 'account-alice');
      final registration = ExamRegistration(
        id: '1234__2026_1__written',
        jmCd: '1234',
        catalogId: 'electrician',
        certName: '전기기사',
        roundLabel: '2026년 1회',
        phase: ExamPhase.written,
      );
      await ExamRegistrationStore.instance.save(registration);
      final saved = await ProgressSnapshotStore.read();
      expect(
        (saved['registrations'] as List).single['updatedAt'],
        greaterThan(0),
      );

      await ExamRegistrationStore.instance.delete(registration.id);
      final deleted = await ProgressSnapshotStore.read();
      expect(deleted['registrations'], isEmpty);
      expect(
        ((deleted['deleted'] as Map)['registrations'] as Map).keys,
        contains(registration.id),
      );

      UserDataScope.activate('account-bob');
      await ExamRegistrationStore.instance.init(ownerId: 'account-bob');
      final bob = await ProgressSnapshotStore.read();
      expect(bob['registrations'], isEmpty);
      expect((bob['deleted'] as Map)['registrations'], isEmpty);
    },
  );

  test(
    're-adding a deleted registration creates a newer sync version',
    () async {
      UserDataScope.activate('account-restore');
      await ExamRegistrationStore.instance.init(ownerId: 'account-restore');
      final registration = ExamRegistration(
        id: '1234__2026_1__written',
        jmCd: '1234',
        catalogId: 'electrician',
        certName: '전기기사',
        roundLabel: '2026년 1회',
        phase: ExamPhase.written,
      );

      await ExamRegistrationStore.instance.save(registration);
      await ExamRegistrationStore.instance.delete(registration.id);
      final deleted = await ProgressSnapshotStore.read();
      final tombstoneAt =
          ((deleted['deleted'] as Map)['registrations'] as Map)[registration.id]
              as int;

      await ExamRegistrationStore.instance.save(registration);
      final restored = await ProgressSnapshotStore.read();
      final restoredRecord = (restored['registrations'] as List).single;
      final restoredTombstones =
          (restored['deleted'] as Map)['registrations'] as Map;

      expect(restoredRecord['id'], registration.id);
      expect(restoredRecord['updatedAt'], greaterThan(tombstoneAt));
      expect(restoredTombstones.keys, contains(registration.id));

      await ProgressSnapshotStore.mergeRemote(restored);
      final settled = await ProgressSnapshotStore.read();
      expect((settled['registrations'] as List).single['id'], registration.id);
      expect((settled['deleted'] as Map)['registrations'], isEmpty);
    },
  );

  test(
    'safe progress merge keeps max slide counters and registration tombstones',
    () async {
      UserDataScope.activate('account-alice');
      final flashcards = await Hive.openBox(
        UserDataScope.boxName('flashcardSrs'),
      );
      await flashcards.put('card-q1', {
        'box': 1,
        'seen': 2,
        'known': 1,
        'updatedAt': 200,
      });
      final scores = await Hive.openBox(UserDataScope.boxName('scoreHistory'));
      await scores.put('2026-10-29', {
        'score': 60.0,
        'attempts': 20,
        'ts': '2026-10-29T01:00:00.000Z',
        'updatedAt': 200,
      });
      final slides = await Hive.openBox(UserDataScope.boxName('slideProgress'));
      await slides.put('seen_1', 8);
      await slides.put('seen_2', 1);
      await slides.put('lastDay', 1);
      await slides.put('level', 'standard');
      await slides.put('__meta_last_day_updated_at', 200);
      await slides.put('__meta_level_updated_at', 200);
      final registrations = await SecureBoxService.instance.openSecureBox(
        UserDataScope.boxName('exam_registrations'),
      );
      await registrations.put('deleted-reg', {
        'id': 'deleted-reg',
        'status': 'planned',
      });

      await ProgressSnapshotStore.mergeRemote({
        'flashcards': [
          {'id': 'card-q1', 'box': 4, 'seen': 6, 'known': 5, 'updatedAt': 199},
          {'id': 'card-q2', 'box': 0, 'seen': 1, 'known': 0, 'updatedAt': 201},
        ],
        'scores': [
          {
            'id': '2026-10-29',
            'scoreMilli': 80000,
            'attempts': 30,
            'updatedAt': 199,
          },
          {
            'id': '2026-10-28',
            'scoreMilli': 69999,
            'attempts': 18,
            'updatedAt': 201,
          },
        ],
        'slides': {
          'seen_1': 4,
          'seen_2': 5,
          'lastDay': 3,
          'lastDayUpdatedAt': 201,
          'level': 'fast',
          'levelUpdatedAt': 199,
        },
        'registrations': [
          {
            'id': 'deleted-reg',
            'jmCd': '1234',
            'catalogId': 'electrician',
            'certName': '전기기사',
            'roundLabel': '2026년 1회',
            'phase': 'written',
            'status': 'passed',
            'updatedAt': 999,
          },
          {
            'id': 'remote-reg',
            'jmCd': '1234',
            'catalogId': 'electrician',
            'certName': '전기기사',
            'roundLabel': '2026년 2회',
            'phase': 'practical',
            'status': 'planned',
            'updatedAt': 201,
          },
        ],
        'deleted': {
          'registrations': ['deleted-reg'],
        },
      });

      final merged = await ProgressSnapshotStore.read();
      final mergedCards = (merged['flashcards'] as List).cast<Map>();
      expect(
        mergedCards.singleWhere((row) => row['id'] == 'card-q1')['box'],
        1,
      );
      expect(mergedCards.any((row) => row['id'] == 'card-q2'), isTrue);
      final mergedScores = (merged['scores'] as List).cast<Map>();
      expect(
        mergedScores.singleWhere(
          (row) => row['id'] == '2026-10-29',
        )['scoreMilli'],
        60000,
      );
      expect(
        mergedScores.singleWhere(
          (row) => row['id'] == '2026-10-28',
        )['scoreMilli'],
        69999,
      );
      expect((merged['slides'] as Map)['seen_1'], 8);
      expect((merged['slides'] as Map)['seen_2'], 5);
      expect((merged['slides'] as Map)['lastDay'], 3);
      expect((merged['slides'] as Map)['level'], 'standard');
      expect((merged['registrations'] as List).map((row) => row['id']), [
        'remote-reg',
      ]);
      expect(
        ((merged['deleted'] as Map)['registrations'] as Map).keys,
        contains('deleted-reg'),
      );
    },
  );

  test(
    'a remote merge started for account A cannot switch boxes to account B mid-open',
    () async {
      UserDataScope.activate('account-alice');
      final merge = ProgressSnapshotStore.mergeRemote({
        'sessions': [
          {
            'id': 'alice-only',
            'examId': '',
            'date': '2026-01-01',
            'minutes': 1,
            'updatedAt': 1,
          },
        ],
      });
      UserDataScope.activate('account-bob');
      await merge;

      final bob = await ProgressSnapshotStore.read();
      expect(bob['sessions'], isEmpty);
      UserDataScope.activate('account-alice');
      final alice = await ProgressSnapshotStore.read();
      expect(alice['sessions'], isEmpty);
    },
  );

  test(
    'overlapping account activations leave all AppProvider boxes on the latest user',
    () async {
      final provider = AppProvider();
      await provider.init(initializeHive: false);

      final aliceActivation = provider.activateUser('account-alice');
      final bobActivation = provider.activateUser('account-bob');
      await Future.wait([aliceActivation, bobActivation]);
      expect(UserDataScope.ownerId, 'account-bob');

      await provider.addSession(
        StudySession(
          id: 'bob-only',
          examId: '',
          date: DateTime(2026),
          minutes: 2,
        ),
      );
      await provider.activateUser('account-alice');
      expect(provider.sessions, isEmpty);
      await provider.activateUser('account-bob');
      expect(provider.sessions.map((session) => session.id), ['bob-only']);
    },
  );
}
