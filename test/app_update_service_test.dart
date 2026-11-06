import 'dart:async';

import 'package:cert_study_tracker/services/app_update_service.dart';
import 'package:cert_study_tracker/services/service_control_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'does not fetch or launch updates while service state is unconfirmed',
    () async {
      final service = ServiceControlService(autoPoll: false);
      final update = AppUpdateService(
        serviceControl: service,
        client: MockClient(
          (_) async =>
              http.Response('{"latest_version":"9.0.0","latest_build":9}', 200),
        ),
      );
      addTearDown(service.dispose);
      addTearDown(update.dispose);

      await update.checkForUpdate();

      expect(update.checked, isFalse);
      expect(update.updateAvailable, isFalse);
      expect(await update.performUpdate(), isFalse);
    },
  );

  test('discards an update manifest that returns after service shutdown', () async {
    final status = http.Response(
      '{"enabled":true,"message":"","updatedAt":"2026-10-28T00:00:00Z","revision":1}',
      200,
    );
    final service = ServiceControlService(
      client: MockClient((_) async => status),
      apiBaseUrl: 'https://api.example.test',
      autoPoll: false,
    );
    await service.refresh();
    final response = Completer<http.Response>();
    final update = AppUpdateService(
      serviceControl: service,
      client: MockClient((_) => response.future),
    );
    addTearDown(service.dispose);
    addTearDown(update.dispose);

    final pending = update.checkForUpdate();
    service.reportDisabled('점검 중');
    response.complete(
      http.Response(
        '{"latest_version":"9.0.0","latest_build":9,"apk_url":"https://example.test/app.apk"}',
        200,
      ),
    );
    await pending;

    expect(update.checked, isFalse);
    expect(update.updateAvailable, isFalse);
    expect(await update.performUpdate(), isFalse);
  });
}
