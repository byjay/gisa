import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'admin_service.dart';
import 'app_config.dart';

enum ServiceAvailability { checking, enabled, disabled, unavailable }

class ServiceControlState {
  const ServiceControlState({
    required this.enabled,
    required this.message,
    required this.updatedAt,
    required this.revision,
  });

  final bool enabled;
  final String message;
  final String updatedAt;
  final int revision;

  factory ServiceControlState.fromJson(Map<String, dynamic> json) {
    if (json['enabled'] is! bool ||
        json['message'] is! String ||
        json['updatedAt'] is! String ||
        DateTime.tryParse(json['updatedAt'] as String) == null ||
        json['revision'] is! int) {
      throw const FormatException('서비스 상태 응답 형식이 올바르지 않습니다.');
    }
    return ServiceControlState(
      enabled: json['enabled'] as bool,
      message: (json['message'] as String).trim(),
      updatedAt: json['updatedAt'] as String,
      revision: json['revision'] as int,
    );
  }
}

class ServiceControlService extends ChangeNotifier {
  ServiceControlService({
    http.Client? client,
    DateTime Function()? now,
    String? apiBaseUrl,
    bool autoPoll = true,
  }) : _client = client ?? http.Client(),
       _now = now ?? DateTime.now,
       _apiBaseUrl = apiBaseUrl ?? AppConfig.apiBaseUrl,
       _autoPoll = autoPoll;

  static final ServiceControlService instance = ServiceControlService();

  static const pollInterval = Duration(seconds: 15);
  static const stateLifetime = Duration(seconds: 45);

  final http.Client _client;
  final DateTime Function() _now;
  final String _apiBaseUrl;
  final bool _autoPoll;
  Timer? _timer;
  ServiceAvailability _availability = ServiceAvailability.checking;
  DateTime? _lastConfirmedAt;
  String _message = '';
  int _generation = 0;
  int _refreshSequence = 0;
  int _revision = -1;
  bool _initialized = false;
  VoidCallback? _onDisabled;

  ServiceAvailability get availability => _availability;
  String get message => _message;
  int get generation => _generation;
  bool get isEnabled => _availability == ServiceAvailability.enabled;
  bool get isAdminOverrideAvailable =>
      AdminService.instance.serverToken?.isNotEmpty ?? false;

  void setDisabledHandler(VoidCallback handler) => _onDisabled = handler;

  Future<void> initialize() async {
    if (!_initialized) {
      _initialized = true;
      if (_autoPoll) {
        _timer = Timer.periodic(pollInterval, (_) => unawaited(refresh()));
      }
    }
    await refresh();
  }

  Future<void> refresh() async {
    final requestSequence = ++_refreshSequence;
    try {
      final response = await _client
          .get(Uri.parse('$_apiBaseUrl/v1/app/service-status'))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) throw const FormatException();
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is! Map<String, dynamic>) throw const FormatException();
      if (requestSequence != _refreshSequence) return;
      _apply(ServiceControlState.fromJson(body));
    } catch (_) {
      if (requestSequence != _refreshSequence) return;
      _expireIfNeeded();
    }
  }

  void reportDisabled(String message) {
    _refreshSequence++;
    final previousAvailability = _availability;
    final previousMessage = _message;
    _message = message.trim();
    _lastConfirmedAt = _now();
    _setAvailability(ServiceAvailability.disabled);
    if (previousAvailability == ServiceAvailability.disabled &&
        previousMessage != _message) {
      notifyListeners();
    }
  }

  Future<ServiceControlState> fetchAdminStatus() async {
    final response = await _adminRequest('GET');
    if (response.statusCode != 200) {
      throw ServiceControlException.fromResponse(response);
    }
    final state = _decodeState(response);
    _apply(state);
    return state;
  }

  Future<ServiceControlState> setEnabled({
    required bool enabled,
    String message = '',
  }) async {
    final response = await _adminRequest(
      'PUT',
      body: jsonEncode({'enabled': enabled, 'message': message}),
    );
    if (response.statusCode != 200) {
      throw ServiceControlException.fromResponse(response);
    }
    final state = _decodeState(response);
    _apply(state);
    return state;
  }

  Future<http.Response> _adminRequest(String method, {String? body}) {
    final token = AdminService.instance.serverToken;
    if (token == null || token.isEmpty || _apiBaseUrl.isEmpty) {
      throw const ServiceControlException(
        401,
        'admin_token_required',
        '운영자 토큰을 먼저 등록해 주세요.',
      );
    }
    final uri = Uri.parse('$_apiBaseUrl/v1/admin/service-control');
    final headers = {
      'Authorization': 'Bearer $token',
      if (body != null) 'Content-Type': 'application/json',
    };
    return method == 'GET'
        ? _client
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 12))
        : _client
              .put(uri, headers: headers, body: body)
              .timeout(const Duration(seconds: 12));
  }

  ServiceControlState _decodeState(http.Response response) {
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! Map<String, dynamic>) throw const FormatException();
    return ServiceControlState.fromJson(body);
  }

  void _apply(ServiceControlState state) {
    if (state.revision < _revision) return;
    _refreshSequence++;
    _revision = state.revision;
    final previousAvailability = _availability;
    final previousMessage = _message;
    _message = state.message;
    _lastConfirmedAt = _now();
    _setAvailability(
      state.enabled
          ? ServiceAvailability.enabled
          : ServiceAvailability.disabled,
    );
    if (previousAvailability ==
            (state.enabled
                ? ServiceAvailability.enabled
                : ServiceAvailability.disabled) &&
        previousMessage != _message) {
      notifyListeners();
    }
  }

  void _expireIfNeeded() {
    final confirmed = _lastConfirmedAt;
    if (confirmed == null || _now().difference(confirmed) >= stateLifetime) {
      _message = '서비스 상태를 확인할 수 없습니다. 네트워크 연결을 확인해 주세요.';
      _setAvailability(ServiceAvailability.unavailable);
    }
  }

  void _setAvailability(ServiceAvailability value) {
    if (_availability == value) return;
    _availability = value;
    _generation++;
    if (value == ServiceAvailability.disabled ||
        value == ServiceAvailability.unavailable) {
      _onDisabled?.call();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (!identical(this, instance)) _client.close();
    super.dispose();
  }
}

class ServiceControlException implements Exception {
  const ServiceControlException(this.statusCode, this.code, this.message);

  final int statusCode;
  final String code;
  final String message;

  factory ServiceControlException.fromResponse(http.Response response) {
    try {
      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return ServiceControlException(
        response.statusCode,
        body['error'] as String? ?? 'error',
        body['message'] as String? ?? '요청을 처리할 수 없습니다.',
      );
    } catch (_) {
      return ServiceControlException(
        response.statusCode,
        'error',
        '요청을 처리할 수 없습니다. (${response.statusCode})',
      );
    }
  }

  @override
  String toString() => message;
}
