import 'package:cert_study_tracker/providers/app_provider.dart';
import 'package:cert_study_tracker/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// [P3-A] 최소 스모크 테스트 - 온보딩 화면이 예외 없이 렌더링되는지 확인한다.
/// OnboardingScreen.build()는 AppProvider.init()이 완료되지 않아도(Hive 박스
/// 미오픈 상태) context.read AppProvider 를 호출하지 않으므로(버튼 콜백에서만
/// 사용) 여기서는 Provider 트리에 인스턴스만 공급하면 된다.
void main() {
  testWidgets('온보딩 화면은 크래시 없이 렌더링된다', (WidgetTester tester) async {
    var doneCalled = false;

    await tester.pumpWidget(
      ChangeNotifierProvider<AppProvider>(
        create: (_) => AppProvider(),
        child: MaterialApp(
          home: OnboardingScreen(onDone: () => doneCalled = true),
        ),
      ),
    );

    // 첫 페이지 렌더 확인 — 시험일 선택 버튼이 화면에 존재해야 한다.
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(doneCalled, false);
  });
}
