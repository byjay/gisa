import 'dart:async';
import 'dart:convert';

import 'package:cert_study_tracker/services/progress_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response snapshotResponse(Map<String, dynamic> snapshot) => http.Response(
  jsonEncode({'snapshot': snapshot, 'updatedAt': 100}),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'uses the user session token and sends the current account snapshot',
    () async {
      final requests = <http.Request>[];
      final applied = <Map<String, dynamic>>[];
      final local = <String, dynamic>{
        'items': {
          'q-local': {'wrong': 1},
        },
      };
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') return snapshotResponse({'items': {}});
        return snapshotResponse(
          jsonDecode(request.body) as Map<String, dynamic>,
        );
      });
      final service = ProgressSyncService.forTesting(
        client: client,
        tokenProvider: () => 'user-session-a',
        ownerProvider: () => 'account-a',
        snapshotReader: () async => local,
        snapshotMerger: (snapshot) async => applied.add(snapshot),
        apiBaseUrl: () => 'https://api.example.test/',
      );

      expect(service.isEnabled, isTrue);
      expect(await service.syncNow(), isTrue);
      expect(requests.map((request) => request.method), ['GET', 'POST']);
      expect(
        requests.every(
          (request) =>
              request.headers['Authorization'] == 'Bearer user-session-a',
        ),
        isTrue,
      );
      expect(
        requests.last.url.toString(),
        'https://api.example.test/v1/progress',
      );
      expect(jsonDecode(requests.last.body), local);
      expect(applied, hasLength(2));
    },
  );

  test(
    'discards a delayed response from an account that is no longer active',
    () async {
      var owner = 'account-a';
      var token = 'session-a';
      final firstRequestStarted = Completer<void>();
      final releaseFirstResponse = Completer<http.Response>();
      final applied = <Map<String, dynamic>>[];
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' &&
            request.headers['Authorization'] == 'Bearer session-a') {
          if (!firstRequestStarted.isCompleted) firstRequestStarted.complete();
          return releaseFirstResponse.future;
        }
        if (request.headers['Authorization'] != 'Bearer session-b') {
          return http.Response('unexpected token', 401);
        }
        if (request.method == 'GET') {
          return snapshotResponse({
            'items': {
              'account-b-remote': {'wrong': 1, 'updatedAt': 2},
            },
          });
        }
        return snapshotResponse(
          jsonDecode(request.body) as Map<String, dynamic>,
        );
      });
      final service = ProgressSyncService.forTesting(
        client: client,
        tokenProvider: () => token,
        ownerProvider: () => owner,
        snapshotReader: () async => {
          'items': {
            '$owner-local': {'wrong': 1, 'updatedAt': 3},
          },
        },
        snapshotMerger: (snapshot) async => applied.add(snapshot),
        apiBaseUrl: () => 'https://api.example.test',
      );

      final syncing = service.syncNow();
      await firstRequestStarted.future;
      owner = 'account-b';
      token = 'session-b';
      service.activateUser();
      releaseFirstResponse.complete(
        snapshotResponse({
          'items': {
            'account-a-private': {'wrong': 1, 'updatedAt': 10},
          },
        }),
      );

      expect(await syncing, isTrue);
      expect(requests.map((request) => request.headers['Authorization']), [
        'Bearer session-a',
        'Bearer session-b',
        'Bearer session-b',
      ]);
      expect(applied, hasLength(2));
      expect(
        applied.every(
          (snapshot) => !snapshot.toString().contains('account-a-private'),
        ),
        isTrue,
      );
      expect(applied.first['items'], contains('account-b-remote'));
    },
  );

  test('local writes during a push trigger a second snapshot pass', () async {
    final firstPostStarted = Completer<void>();
    final releaseFirstPost = Completer<http.Response>();
    final requests = <http.Request>[];
    var postCount = 0;
    var local = <String, dynamic>{
      'items': {
        'q1': {'wrong': 1, 'updatedAt': 1},
      },
    };
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET') return snapshotResponse({'items': {}});
      postCount++;
      if (postCount == 1) {
        firstPostStarted.complete();
        return releaseFirstPost.future;
      }
      return snapshotResponse(jsonDecode(request.body) as Map<String, dynamic>);
    });
    final service = ProgressSyncService.forTesting(
      client: client,
      tokenProvider: () => 'session-a',
      ownerProvider: () => 'account-a',
      snapshotReader: () async => local,
      snapshotMerger: (_) async {},
      apiBaseUrl: () => 'https://api.example.test',
    );

    final firstSync = service.syncNow();
    await firstPostStarted.future;
    local = {
      'items': {
        'q1': {'wrong': 1, 'updatedAt': 1},
        'q2': {'correct': 1, 'updatedAt': 2},
      },
    };
    expect(await service.syncNow(), isFalse);
    releaseFirstPost.complete(
      snapshotResponse(jsonDecode(requests.last.body) as Map<String, dynamic>),
    );

    expect(await firstSync, isTrue);
    final postBodies = requests
        .where((request) => request.method == 'POST')
        .map((request) => jsonDecode(request.body) as Map<String, dynamic>)
        .toList();
    expect(postBodies, hasLength(2));
    expect(postBodies.last['items'], contains('q2'));
  });
}
