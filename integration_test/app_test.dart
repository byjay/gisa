// Q37 통합 테스트 스위트 — 앱 부팅 및 핵심 화면 스모크 테스트.
//
// 실행: flutter test integration_test/app_test.dart
// (기기/에뮬레이터 또는 flutter drive 로 구동)
//
// 목적: 위젯 단위 테스트로는 잡히지 않는 "앱 전체 부팅 → 초기 렌더 →
// 주요 탭 진입"이 실기기에서 크래시 없이 동작하는지 회귀 검증.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:cert_study_tracker/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Gisaclub 앱 통합 테스트', () {
    testWidgets('앱이 크래시 없이 부팅되고 첫 화면이 렌더된다', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // MaterialApp 루트가 존재해야 한다.
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('하단 네비게이션이 있으면 각 탭으로 이동해도 크래시가 없다', (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 3));

      final navBar = find.byType(NavigationBar);
      if (navBar.evaluate().isEmpty) {
        // 온보딩/트랙 선택 등 게이트 화면이면 스킵(부팅 성공만으로 통과).
        return;
      }

      final destinations = find.descendant(
        of: navBar,
        matching: find.byType(NavigationDestination),
      );
      final count = destinations.evaluate().length;
      for (var i = 0; i < count; i++) {
        await tester.tap(destinations.at(i));
        await tester.pumpAndSettle(const Duration(milliseconds: 800));
        // 각 탭 전환 후에도 앱 루트가 유지되는지 확인.
        expect(find.byType(MaterialApp), findsOneWidget);
      }
    });
  });
}
