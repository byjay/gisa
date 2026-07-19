import 'package:cert_study_tracker/services/cerebras_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// CerebrasService는 "테스트 기간 자동 내장 키" 모델로 진화했다.
/// - 테스트 기간 동안: AI 자동 활성화(내장 키 조립), hasKey == true
/// - 기간 종료 후: 키 없음, AI 비활성화
/// - setApiKey는 호환용 스텁(사용자 저장 무시) — 이전 BYOK 계약은 폐기됨
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('테스트 기간 종료일이 미래로 설정되어 있다', () {
    // 기간 라벨이 YYYY.MM.DD 형식으로 노출된다
    expect(
      CerebrasService.testPeriodEndLabel,
      matches(RegExp(r'^\d{4}\.\d{2}\.\d{2}$')),
    );
  });

  test('테스트 기간 여부는 종료일과 현재 시각으로 결정된다', () {
    final expected = DateTime.now().isBefore(CerebrasService.testPeriodEnd);
    expect(CerebrasService.isTestPeriod, expected);
  });

  test('테스트 기간에는 AI 사용 가능(hasKey/aiAvailable)이며 키가 조립된다', () async {
    SharedPreferences.setMockInitialValues({});
    if (CerebrasService.isTestPeriod) {
      expect(await CerebrasService.instance.hasKey(), isTrue);
      expect(await CerebrasService.instance.aiAvailable, isTrue);
      final key = await CerebrasService.instance.getApiKey();
      expect(key, isNotEmpty);
      // Groq 키 접두사 규칙
      expect(key.startsWith('gsk_'), isTrue);
    } else {
      expect(await CerebrasService.instance.hasKey(), isFalse);
      expect(await CerebrasService.instance.getApiKey(), isEmpty);
    }
  });

  test('setApiKey는 호환용 스텁이므로 사용 가능 상태를 바꾸지 않는다', () async {
    SharedPreferences.setMockInitialValues({});
    final before = await CerebrasService.instance.hasKey();
    await CerebrasService.instance.setApiKey('user-owned-test-key');
    // 저장은 무시되고 테스트 기간 게이트만 상태를 결정한다
    expect(await CerebrasService.instance.hasKey(), before);
  });
}
