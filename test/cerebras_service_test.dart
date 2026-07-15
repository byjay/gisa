import 'package:cert_study_tracker/services/cerebras_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AI 키가 없으면 사용 불가 상태다', () async {
    SharedPreferences.setMockInitialValues({});
    await CerebrasService.instance.setApiKey('');
    expect(await CerebrasService.instance.hasKey(), isFalse);
  });

  test('사용자 키를 저장하면 사용 가능 상태가 된다', () async {
    SharedPreferences.setMockInitialValues({});
    await CerebrasService.instance.setApiKey('user-owned-test-key');
    expect(await CerebrasService.instance.hasKey(), isTrue);
    expect(await CerebrasService.instance.getApiKey(), 'user-owned-test-key');
  });

  test('빈 키 저장은 기존 키를 제거한다', () async {
    SharedPreferences.setMockInitialValues({});
    await CerebrasService.instance.setApiKey('user-owned-test-key');
    await CerebrasService.instance.setApiKey('   ');
    expect(await CerebrasService.instance.hasKey(), isFalse);
  });
}
