import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cert_study_tracker/screens/help_faq_screen.dart';

void main() {
  group('HelpFaqScreen 위젯', () {
    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: HelpFaqScreen()));
      await tester.pumpAndSettle();
    }

    testWidgets('FAQ 화면이 렌더링되고 주요 섹션이 표시된다', (tester) async {
      await pump(tester);
      expect(find.text('도움말 · FAQ'), findsOneWidget);
      expect(find.text('시작하기'), findsOneWidget);
      expect(find.text('문제 풀이 · 시험'), findsOneWidget);
    });

    testWidgets('질문을 탭하면 답변이 펼쳐진다', (tester) async {
      await pump(tester);
      const q = 'Gisaclub은 어떤 앱인가요?';
      expect(find.text(q), findsOneWidget);
      // 펼치기 전에는 답변 본문이 보이지 않는다
      expect(find.textContaining('올인원 학습 앱'), findsNothing);
      await tester.tap(find.text(q));
      await tester.pumpAndSettle();
      expect(find.textContaining('올인원 학습 앱'), findsOneWidget);
    });

    testWidgets('데이터/백업 섹션까지 스크롤 가능하다', (tester) async {
      await pump(tester);
      await tester.dragUntilVisible(
        find.text('데이터 · 백업'),
        find.byType(ListView),
        const Offset(0, -300),
      );
      expect(find.text('데이터 · 백업'), findsOneWidget);
    });
  });
}
