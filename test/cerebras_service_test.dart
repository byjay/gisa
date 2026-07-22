import 'package:cert_study_tracker/services/cerebras_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// CerebrasService는 개발 빌드 옵션으로만 키를 받는다.
/// - 키는 소스·저장소에 기록하지 않는다.
/// - ENABLE_DEV_AI와 CEREBRAS_API_KEY가 모두 있어야 AI가 활성화된다.
/// - setApiKey는 호환용 스텁이며 키를 저장하지 않는다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('개발 모드 라벨이 노출된다', () {
    expect(CerebrasService.testPeriodEndLabel, '개발 모드');
  });

  test('기본 빌드에서는 AI 키가 제공되지 않는다', () async {
    SharedPreferences.setMockInitialValues({});
    expect(CerebrasService.isTestPeriod, isFalse);
    expect(await CerebrasService.instance.hasKey(), isFalse);
    expect(await CerebrasService.instance.aiAvailable, isFalse);
    expect(await CerebrasService.instance.getApiKey(), isEmpty);
  });

  test('setApiKey는 호환용 스텁이므로 사용 가능 상태를 바꾸지 않는다', () async {
    SharedPreferences.setMockInitialValues({});
    final before = await CerebrasService.instance.hasKey();
    await CerebrasService.instance.setApiKey('user-owned-test-key');
    // 저장은 무시되며 빌드 옵션으로 주입한 값만 사용한다.
    expect(await CerebrasService.instance.hasKey(), before);
  });
}
