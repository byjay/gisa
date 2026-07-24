import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Q40 로컬 크래시/에러 리포팅.
///
/// Firebase Crashlytics/Sentry 같은 외부 SaaS 대신, 개인정보 유출 없이
/// 기기 내부에만 최근 오류를 기록한다(로컬 우선 앱 원칙 준수).
///
/// - `FlutterError.onError` 및 `PlatformDispatcher.onError`에서 호출.
/// - 최근 [_maxRecords]건만 링버퍼로 유지(shared_preferences JSON).
/// - 설정 화면에서 조회/복사/삭제 가능(사용자가 스스로 개발자에게 전달).
class CrashLogger {
  CrashLogger._();
  static final CrashLogger instance = CrashLogger._();

  static const _pref = 'crash_logs_v1';
  static const _maxRecords = 30;

  final List<CrashRecord> _cache = [];
  bool _loaded = false;

  /// 앱 시작 시 1회 호출: 글로벌 에러 훅을 등록한다.
  Future<void> init() async {
    await _load();
    final prevFlutterOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      prevFlutterOnError?.call(details);
      unawaited(
        record(
          details.exceptionAsString(),
          stack: details.stack?.toString(),
          context: details.context?.toString(),
        ),
      );
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(record(error.toString(), stack: stack.toString()));
      return true; // 앱이 죽지 않도록 처리 완료로 표시
    };
  }

  Future<void> _load() async {
    if (_loaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pref);
      if (raw != null) {
        final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        _cache
          ..clear()
          ..addAll(list.map(CrashRecord.fromMap));
      }
    } catch (_) {
      // 로그 로드 실패는 무시(로그 자체가 앱을 방해하면 안 됨).
    }
    _loaded = true;
  }

  Future<void> record(String message, {String? stack, String? context}) async {
    try {
      await _load();
      _cache.insert(
        0,
        CrashRecord(
          time: DateTime.now(),
          message: message,
          stack: stack,
          context: context,
        ),
      );
      while (_cache.length > _maxRecords) {
        _cache.removeLast();
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _pref,
        jsonEncode(_cache.map((e) => e.toMap()).toList()),
      );
    } catch (_) {
      // 저장 실패 무시
    }
    if (kDebugMode) debugPrint('CrashLogger: $message');
  }

  Future<List<CrashRecord>> getAll() async {
    await _load();
    return List.unmodifiable(_cache);
  }

  Future<void> clear() async {
    _cache.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_pref);
    } catch (_) {}
  }

  /// 개발자 전달용 텍스트 덤프.
  Future<String> exportText() async {
    final all = await getAll();
    if (all.isEmpty) return '기록된 오류가 없습니다.';
    final buf = StringBuffer('Gisaclub 오류 로그 (${all.length}건)\n');
    for (final r in all) {
      buf.writeln('─────────────────────────');
      buf.writeln('[${r.time.toIso8601String()}]');
      buf.writeln(r.message);
      if (r.context != null) buf.writeln('context: ${r.context}');
      if (r.stack != null) buf.writeln(r.stack);
    }
    return buf.toString();
  }
}

class CrashRecord {
  final DateTime time;
  final String message;
  final String? stack;
  final String? context;

  CrashRecord({
    required this.time,
    required this.message,
    this.stack,
    this.context,
  });

  Map<String, dynamic> toMap() => {
    'time': time.toIso8601String(),
    'message': message,
    'stack': stack,
    'context': context,
  };

  factory CrashRecord.fromMap(Map<String, dynamic> m) => CrashRecord(
    time: DateTime.tryParse(m['time'] as String? ?? '') ?? DateTime.now(),
    message: m['message'] as String? ?? '',
    stack: m['stack'] as String?,
    context: m['context'] as String?,
  );
}
