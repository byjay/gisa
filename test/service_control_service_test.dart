import 'dart:async';

import 'package:cert_study_tracker/services/service_control_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'starts fail-closed and becomes enabled after a valid status response',
    () async {
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
      addTearDown(service.dispose);

      expect(service.isEnabled, isFalse);
      await service.refresh();

      expect(service.availability, ServiceAvailability.enabled);
      expect(service.isEnabled, isTrue);
    },
  );

  test('expires confirmed state after 45 seconds when refresh fails', () async {
    var now = DateTime.utc(2026, 10, 28);
    var succeeds = true;
    final service = ServiceControlService(
      client: MockClient(
        (_) async => succeeds
            ? http.Response(
                '{"enabled":true,"message":"","updatedAt":"2026-10-28T00:00:00Z","revision":1}',
                200,
              )
            : http.Response('offline', 503),
      ),
      apiBaseUrl: 'https://api.example.test',
      now: () => now,
      autoPoll: false,
    );
    addTearDown(service.dispose);

    await service.refresh();
    now = now.add(const Duration(seconds: 46));
    succeeds = false;
    await service.refresh();

    expect(service.availability, ServiceAvailability.unavailable);
    expect(service.isEnabled, isFalse);
  });

  test('a disabled response and local 503 report disable immediately', () async {
    final service = ServiceControlService(
      client: MockClient(
        (_) async => http.Response(
          '{"enabled":false,"message":"점검","updatedAt":"2026-10-28T00:00:00Z","revision":2}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
      apiBaseUrl: 'https://api.example.test',
      autoPoll: false,
    );
    addTearDown(service.dispose);

    await service.refresh();
    expect(service.availability, ServiceAvailability.disabled);
    service.reportDisabled('점검');
    expect(service.isEnabled, isFalse);
    expect(service.message, '점검');
  });

  test('an in-flight enabled status cannot undo a newer 503 lock', () async {
    final response = Completer<http.Response>();
    final service = ServiceControlService(
      client: MockClient((_) => response.future),
      apiBaseUrl: 'https://api.example.test',
      autoPoll: false,
    );
    addTearDown(service.dispose);

    final pending = service.refresh();
    service.reportDisabled('점검 중');
    response.complete(
      http.Response(
        '{"enabled":true,"message":"","updatedAt":"2026-10-28T00:00:00Z","revision":1}',
        200,
      ),
    );
    await pending;

    expect(service.availability, ServiceAvailability.disabled);
    expect(service.message, '점검 중');
  });
}
