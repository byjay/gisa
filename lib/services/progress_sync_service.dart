import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'app_config.dart';
import 'auth_service.dart';
import 'progress_snapshot_store.dart';

/// Syncs a user's local learning record with that user's authenticated Worker row.
class ProgressSyncService {
  ProgressSyncService._()
    : _client = http.Client(),
      _tokenProvider = (() => AuthService.instance.sessionToken),
      _ownerProvider = (() => AuthService.instance.dataOwnerId),
      _snapshotReader = ProgressSnapshotStore.read,
      _snapshotMerger = ProgressSnapshotStore.mergeRemote,
      _apiBaseUrl = (() => AppConfig.apiBaseUrl);

  @visibleForTesting
  ProgressSyncService.forTesting({
    required http.Client client,
    required String? Function() tokenProvider,
    required String? Function() ownerProvider,
    required Future<Map<String, dynamic>> Function() snapshotReader,
    required Future<void> Function(Map<String, dynamic>) snapshotMerger,
    required String Function() apiBaseUrl,
  }) : _client = client,
       _tokenProvider = tokenProvider,
       _ownerProvider = ownerProvider,
       _snapshotReader = snapshotReader,
       _snapshotMerger = snapshotMerger,
       _apiBaseUrl = apiBaseUrl;

  static final ProgressSyncService instance = ProgressSyncService._();

  final http.Client _client;
  final String? Function() _tokenProvider;
  final String? Function() _ownerProvider;
  final Future<Map<String, dynamic>> Function() _snapshotReader;
  final Future<void> Function(Map<String, dynamic>) _snapshotMerger;
  final String Function() _apiBaseUrl;

  Timer? _timer;
  bool _syncing = false;
  bool _rerunRequested = false;
  int _generation = 0;
  VoidCallback? onSnapshotApplied;

  bool get isEnabled =>
      _apiBaseUrl().isNotEmpty &&
      (_tokenProvider()?.isNotEmpty ?? false) &&
      (_ownerProvider()?.isNotEmpty ?? false);

  /// Debounces rapid local writes while preserving a second pass if one arrives
  /// during a network round trip.
  void scheduleSync() {
    if (!isEnabled) return;
    if (_syncing) {
      _rerunRequested = true;
      return;
    }
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 700), () {
      unawaited(syncNow());
    });
  }

  /// Invalidates any response started under the previous account/session.
  void activateUser() {
    _generation++;
    _timer?.cancel();
    _timer = null;
    _rerunRequested = true;
    scheduleSync();
  }

  @visibleForTesting
  void resetForTesting() {
    _timer?.cancel();
    _timer = null;
    _generation++;
    _syncing = false;
    _rerunRequested = false;
  }

  Future<bool> syncNow() async {
    if (!isEnabled) return false;
    if (_syncing) {
      _rerunRequested = true;
      return false;
    }

    _syncing = true;
    var success = true;
    try {
      do {
        _rerunRequested = false;
        final generation = _generation;
        final ownerId = _ownerProvider();
        final token = _tokenProvider();
        final baseUrl = _apiBaseUrl().replaceFirst(RegExp(r'/+$'), '');
        if (ownerId == null ||
            token == null ||
            token.isEmpty ||
            baseUrl.isEmpty) {
          return false;
        }

        try {
          final getResponse = await _client
              .get(
                Uri.parse('$baseUrl/v1/progress'),
                headers: {'Authorization': 'Bearer $token'},
              )
              .timeout(const Duration(seconds: 12));
          if (!_isCurrent(generation, ownerId, token)) continue;
          if (getResponse.statusCode != 200) return false;

          final pulled = _decodeSnapshot(getResponse.body);
          if (pulled == null) return false;
          await _snapshotMerger(pulled);
          if (!_isCurrent(generation, ownerId, token)) continue;
          onSnapshotApplied?.call();

          final local = await _snapshotReader();
          if (!_isCurrent(generation, ownerId, token)) continue;
          final postResponse = await _client
              .post(
                Uri.parse('$baseUrl/v1/progress'),
                headers: {
                  'Authorization': 'Bearer $token',
                  'Content-Type': 'application/json',
                },
                body: jsonEncode(local),
              )
              .timeout(const Duration(seconds: 12));
          if (!_isCurrent(generation, ownerId, token)) continue;
          if (postResponse.statusCode != 200) return false;

          final pushed = _decodeSnapshot(postResponse.body);
          if (pushed == null) return false;
          await _snapshotMerger(pushed);
          if (!_isCurrent(generation, ownerId, token)) continue;
          onSnapshotApplied?.call();
        } catch (error) {
          if (kDebugMode) {
            debugPrint('progress sync failed; local records kept: $error');
          }
          success = false;
          break;
        }
      } while (_rerunRequested);
    } finally {
      _syncing = false;
      if (_rerunRequested && isEnabled) scheduleSync();
    }
    return success;
  }

  Map<String, dynamic>? _decodeSnapshot(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map || decoded['snapshot'] is! Map) return null;
      return Map<String, dynamic>.from(decoded['snapshot'] as Map);
    } on FormatException {
      return null;
    }
  }

  bool _isCurrent(int generation, String ownerId, String token) =>
      generation == _generation &&
      ownerId == _ownerProvider() &&
      token == _tokenProvider();
}
