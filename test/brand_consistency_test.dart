import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 브랜드 일관성 회귀 방지 테스트 (Q84/Q98 재발 방지 가드)
/// 앱 라벨이 과거처럼 기본값("Cert Study Tracker" 등)으로 되돌아가는
/// 회귀 버그를 CI/로컬 테스트 단계에서 즉시 잡아낸다.
void main() {
  group('브랜드 일관성 가드', () {
    test('AndroidManifest의 android:label은 볼트쌤이다', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(
        manifest.contains('android:label="볼트쌤"'),
        isTrue,
        reason:
            'Android 앱 라벨이 브랜드명(볼트쌤)에서 이탈했습니다. '
            '회귀 버그 — AndroidManifest.xml을 확인하세요.',
      );
    });

    test('웹 manifest.json의 short_name은 볼트쌤이다', () {
      final manifest = File('web/manifest.json').readAsStringSync();
      expect(
        manifest.contains('볼트쌤'),
        isTrue,
        reason: '웹 매니페스트에서 브랜드명이 사라졌습니다.',
      );
    });

    test('웹 index.html 타이틀에 브랜드명이 포함된다', () {
      final html = File('web/index.html').readAsStringSync();
      expect(html.contains('볼트쌤'), isTrue, reason: '웹 타이틀에서 브랜드명이 사라졌습니다.');
    });
  });
}
