import 'dart:async';

import 'package:cert_study_tracker/services/remote_content_api.dart';
import 'package:cert_study_tracker/services/exam_track.dart';
import 'package:cert_study_tracker/services/study_data.dart';
import 'package:cert_study_tracker/services/service_control_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'discards a delayed study response after the login session changes',
    () async {
      final api = RemoteContentApi.instance;
      final response = Completer<http.Response>();
      api.authToken = 'session-a-test-token';
      addTearDown(() => api.authToken = null);

      final pending = http.runWithClient(
        () => api.getStudyFile(
          group: 'track',
          track: 'electrician',
          filename: 'study_plan.json',
        ),
        () => MockClient((_) => response.future),
      );

      api.authToken = null;
      response.complete(http.Response('{"mustNotBeCached":true}', 200));

      await expectLater(
        pending,
        throwsA(
          isA<RemoteContentException>().having(
            (error) => error.code,
            'error code',
            'session_changed',
          ),
        ),
      );
    },
  );

  test(
    'a cache invalidation prevents an older study response from repopulating memory',
    () async {
      final api = RemoteContentApi.instance;
      final studyData = StudyData.instance;
      final response = Completer<http.Response>();
      var calls = 0;
      addTearDown(() {
        api.authToken = null;
        studyData.clearSessionCache();
      });
      const subject = '전기자기학';
      setExamTrackCatalog([
        ExamTrack.fromJson({
          'id': 'electrician',
          'name': '전기기사',
          'shortName': '전기기사',
          'tagline': '검증용 종목',
          'emoji': '⚡',
          'subjects': [subject],
          'theoryFiles': {subject: 'theory/electrician/01.md'},
          'questionCount': 0,
          'topicCount': 0,
          'repeatCount': 0,
          'bankLabel': '검증용',
          'paperSize': 0,
        }),
      ]);
      studyData.setTrack(trackById('electrician'));
      api.authToken = 'session-a-test-token';

      final pending = http.runWithClient(
        () => studyData.loadTheory(subject),
        () => MockClient((_) {
          calls++;
          if (calls == 1) return response.future;
          return Future.value(http.Response('fresh-session-theory', 200));
        }),
      );

      studyData.clearSessionCache();
      response.complete(http.Response('stale-session-theory', 200));
      expect(await pending, '# 자료를 불러올 수 없습니다');
      expect(
        await http.runWithClient(
          () => studyData.loadTheory(subject),
          () => MockClient((_) async {
            calls++;
            return http.Response('fresh-session-theory', 200);
          }),
        ),
        'fresh-session-theory',
        reason: 'the stale response must not be cached',
      );
      expect(
        calls,
        2,
        reason: 'the next session must fetch instead of using stale cache',
      );
    },
  );

  test(
    'a service_disabled response immediately locks service control',
    () async {
      final api = RemoteContentApi.instance;
      final service = ServiceControlService.instance;
      api.authToken = 'session-a-test-token';
      addTearDown(() => api.authToken = null);

      await http.runWithClient(
        () => expectLater(
          api.getStudyFile(
            group: 'track',
            track: 'electrician',
            filename: 'study_plan.json',
          ),
          throwsA(
            isA<RemoteContentException>().having(
              (error) => error.code,
              'error code',
              'service_disabled',
            ),
          ),
        ),
        () => MockClient(
          (_) async => http.Response(
            '{"error":"service_disabled","message":"점검 중"}',
            503,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      expect(service.availability, ServiceAvailability.disabled);
      expect(service.message, '점검 중');
    },
  );
}
