import 'package:cert_study_tracker/screens/service_maintenance_screen.dart';
import 'package:cert_study_tracker/services/service_control_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets(
    'disabled gate replaces every navigator route with maintenance UI',
    (tester) async {
      final service = ServiceControlService(
        client: MockClient(
          (_) async => http.Response(
            '{"enabled":true,"message":"","updatedAt":"2026-10-28T00:00:00Z","revision":1}',
            200,
          ),
        ),
        apiBaseUrl: 'https://api.example.test',
        autoPoll: false,
      );
      await service.refresh();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => ServiceMaintenanceGate(
            service: service,
            child: child ?? const SizedBox.shrink(),
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => const Scaffold(body: Text('다른 사용자 기능')),
                  ),
                ),
                child: const Text('사용자 기능'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('사용자 기능'));
      await tester.pumpAndSettle();
      expect(find.text('다른 사용자 기능'), findsOneWidget);

      service.reportDisabled('점검 중');
      await tester.pumpAndSettle();

      expect(find.text('점검 중'), findsOneWidget);
      expect(find.text('사용자 기능'), findsNothing);
      expect(find.text('다른 사용자 기능'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      service.dispose();
    },
  );
}
