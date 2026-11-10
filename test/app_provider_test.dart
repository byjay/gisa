import 'dart:io';

import 'package:cert_study_tracker/models/models.dart';
import 'package:cert_study_tracker/providers/app_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// AppProvider 회귀 테스트.
///
/// [AppProvider.init]은 내부에서 Hive.initFlutter()를 호출하고, 이는
/// path_provider 플러그인의 MethodChannel('plugins.flutter.io/path_provider')을
/// 통해 getApplicationDocumentsDirectory()를 조회한다. flutter test(VM) 환경에는
/// 네이티브 플랫폼 구현이 없으므로, 이 채널에 임시 디렉터리를 반환하는 목(mock)
/// 핸들러를 등록해 실제 AppProvider().init()을 수정 없이 그대로 구동한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('voltssam_provider_test_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (MethodCall call) async {
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
    // 각 테스트가 격리된 Hive 상태에서 시작하도록 박스를 모두 닫고 삭제한다.
    // (backup_service_test.dart와 동일한 패턴)
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<AppProvider> buildProvider() async {
    final provider = AppProvider();
    await provider.init();
    return provider;
  }

  group('T3 — setSelectedTutor 화이트리스트 (B2 회귀)', () {
    test('kTutorPersonas에 없는 id는 무시된다', () async {
      final provider = await buildProvider();
      await provider.setSelectedTutor('soyeon');
      expect(provider.selectedTutorId, 'soyeon');

      await provider.setSelectedTutor('not_a_real_tutor');
      expect(provider.selectedTutorId, 'soyeon'); // 변경되지 않아야 함
    });

    test("기본 튜터 'volt'로 되돌아올 수 있다 (과거 버그: 하드코딩 셋에 volt 누락)", () async {
      final provider = await buildProvider();
      expect(provider.selectedTutorId, 'volt');

      await provider.setSelectedTutor('harin');
      expect(provider.selectedTutorId, 'harin');

      await provider.setSelectedTutor('volt');
      expect(provider.selectedTutorId, 'volt');
    });
  });

  group('T4 — 타이머 벽시계 계산 (B1 회귀)', () {
    test('틱이 지연되어도 경과 시간은 벽시계 차이로 정확히 계산된다', () async {
      final provider = await buildProvider();
      var now = DateTime(2025, 1, 1, 10, 0, 0);
      provider.debugNow = () => now;

      provider.startTimer(null);
      expect(provider.elapsedSeconds, 0);

      // 틱이 한 번도 안 와도(타이머 지연 시뮬레이션) 5분이 지났다면
      // stopTimer 시점에 벽시계 기준으로 300초가 정확히 계산되어야 한다.
      now = now.add(const Duration(minutes: 5));
      final elapsed = await provider.stopTimer();
      expect(elapsed, 300);
    });

    test('stopTimer는 세션을 분 단위로 올림 저장한다', () async {
      final provider = await buildProvider();
      var now = DateTime(2025, 1, 1, 10, 0, 0);
      provider.debugNow = () => now;

      provider.startTimer('examA');
      now = now.add(const Duration(seconds: 61)); // 1분 1초 → 2분 올림
      await provider.stopTimer();

      expect(provider.totalMinutes, 2);
    });
  });

  group('T1 — streak (연속 학습일)', () {
    test('오늘 학습이 없으면 streak은 0이다', () async {
      final provider = await buildProvider();
      expect(provider.streak, 0);
    });

    test('오늘 학습을 기록하면 streak은 1이다', () async {
      final provider = await buildProvider();
      await provider.addSession(
        StudySession(id: 't1', examId: '', date: DateTime.now(), minutes: 10),
      );
      expect(provider.streak, 1);
    });

    test('연속 3일 학습 시 streak은 3이다', () async {
      final provider = await buildProvider();
      final today = DateTime.now();
      for (var i = 0; i < 3; i++) {
        await provider.addSession(
          StudySession(
            id: 't_streak_$i',
            examId: '',
            date: today.subtract(Duration(days: i)),
            minutes: 15,
          ),
        );
      }
      expect(provider.streak, 3);
    });
  });

  group('T2 — XP / 레벨', () {
    test('학습 1분 = 2XP', () async {
      final provider = await buildProvider();
      await provider.addSession(
        StudySession(id: 'xp1', examId: '', date: DateTime.now(), minutes: 10),
      );
      expect(provider.xp, 20);
    });

    test('정답 1개 = 5XP (퀴즈 결과 반영)', () async {
      final provider = await buildProvider();
      await provider.addQuizResult(title: '테스트', total: 10, correct: 4);
      expect(provider.xp, 20); // 4 * 5
    });

    test('레벨 1은 기본값이며 XP 0이어도 레벨 1이다', () async {
      final provider = await buildProvider();
      expect(provider.level, 1);
      expect(provider.xp, 0);
    });

    test('레벨업에 필요한 XP 경계값: xpForLevel(2) 도달 시 레벨 2', () async {
      final provider = await buildProvider();
      final needed = provider.xpForLevel(2); // (2-1)^2 * 120 = 120
      expect(needed, 120);
      // 120XP를 만들기 위해 학습 60분 기록 (60*2=120)
      await provider.addSession(
        StudySession(id: 'lvl', examId: '', date: DateTime.now(), minutes: 60),
      );
      expect(provider.xp, 120);
      expect(provider.level, 2);
    });
  });

  group('T9 — 마법 방패 지급/소모 규칙 (B5 회귀)', () {
    test('오늘 3대 미션을 모두 채우지 못하면 방패를 지급하지 않는다', () async {
      final provider = await buildProvider();
      final earned = await provider.maybeEarnShield();
      expect(earned, false);
      expect(provider.shieldCount, 0);
    });

    test('3대 미션을 모두 채우면 방패 1개를 지급한다(하루 1회)', () async {
      final provider = await buildProvider();
      await provider.addSession(
        StudySession(id: 'm1', examId: '', date: DateTime.now(), minutes: 30),
      );
      await provider.addQuizResult(title: '테스트', total: 10, correct: 5);

      expect(provider.todayMissionsAllDone, true);

      final earned = await provider.maybeEarnShield();
      expect(earned, true);
      expect(provider.shieldCount, 1);

      // 같은 날 두 번째 호출은 지급되지 않아야 한다.
      final earnedAgain = await provider.maybeEarnShield();
      expect(earnedAgain, false);
      expect(provider.shieldCount, 1);
    });

    test('방패는 최대 maxShields(2)개까지만 보유할 수 있다', () async {
      final provider = await buildProvider();
      await provider.addSession(
        StudySession(id: 'm2', examId: '', date: DateTime.now(), minutes: 30),
      );
      await provider.addQuizResult(title: '테스트', total: 10, correct: 5);
      await provider.maybeEarnShield(); // 1개

      // shieldCount를 강제로 2로 올려 상한 도달 상태를 재현한다.
      provider.shieldCount = AppProvider.maxShields;
      final earned = await provider.maybeEarnShield();
      expect(earned, false);
      expect(provider.shieldCount, AppProvider.maxShields);
    });
  });
}
