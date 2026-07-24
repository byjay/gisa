import 'package:cert_study_tracker/services/cerebras_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// CerebrasService BYOK(Bring Your Own Key) 스펙 회귀 테스트.
/// - 상용화: 사용자가 본인 Cerebras 무료 키를 설정에서 입력·저장하면
///   릴리스 빌드에서도 AI 튜터가 동작한다.
/// - 개발자 키를 앱에 심지 않으므로 키 유출/비용 문제가 없다.
/// - setApiKey는 로컬(SharedPreferences)에 실제로 저장한다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AI 튜터 설정은 항상 노출된다(BYOK)', () {
    expect(CerebrasService.isTestPeriod, isTrue);
    expect(CerebrasService.testPeriodEndLabel, '무료');
  });

  test('사용자 키가 없으면 AI 키가 비어 있다(기본 빌드)', () async {
    SharedPreferences.setMockInitialValues({});
    // 캐시 초기화를 위해 빈 저장으로 상태 리셋
    await CerebrasService.instance.setApiKey('');
    expect(await CerebrasService.instance.hasUserKey(), isFalse);
    // 개발 키가 주입되지 않은 테스트 빌드에서는 최종 키도 비어 있음
    expect(await CerebrasService.instance.getApiKey(), isEmpty);
  });

  test('setApiKey로 사용자 키를 저장하면 hasUserKey가 true가 된다', () async {
    SharedPreferences.setMockInitialValues({});
    await CerebrasService.instance.setApiKey('user-owned-test-key');
    expect(await CerebrasService.instance.hasUserKey(), isTrue);
    expect(await CerebrasService.instance.getApiKey(), 'user-owned-test-key');
    expect(await CerebrasService.instance.hasKey(), isTrue);
  });

  test('setApiKey에 빈 문자열을 주면 저장된 키가 삭제된다', () async {
    SharedPreferences.setMockInitialValues({});
    await CerebrasService.instance.setApiKey('temp-key');
    expect(await CerebrasService.instance.hasUserKey(), isTrue);
    await CerebrasService.instance.setApiKey('');
    expect(await CerebrasService.instance.hasUserKey(), isFalse);
  });
}
