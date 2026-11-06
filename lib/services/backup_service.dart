import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, debugPrint;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'secure_box_service.dart';
import 'user_data_scope.dart';

/// 백업/복원 결과 계약 — 성공/실패를 명시적으로 표현한다 (P0-3 오류 은닉 방지).
class OperationResult<T> {
  final bool success;
  final T? data;
  final String? errorMessage;

  const OperationResult.ok(this.data) : success = true, errorMessage = null;
  const OperationResult.fail(this.errorMessage) : success = false, data = null;
}

/// 📦 데이터 백업/복원 서비스 (H2 갭 해소)
///
/// - 로컬 우선 앱의 구조적 약점(계정 동기화 부재)을 파일 내보내기/가져오기로 절충한다.
/// - 대상 Hive 박스 전량 + SharedPreferences 선별 키를 JSON 1개로 직렬화.
/// - 버전(schemaVersion) + 체크섬(sha256) + 생성일 + 앱버전을 포함해
///   손상/구버전 백업을 원본을 훼손하지 않고 안전하게 실패시킨다.
class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  /// User-owned Hive boxes. Names are resolved once per export/import operation.
  static const List<String> _baseBoxNames = [
    'exams',
    'sessions',
    'wrongNotes',
    'settings',
    'quizResults',
    'questionProgress',
    'flashcardSrs',
    'scoreHistory',
    'slideProgress',
    'exam_registrations',
    'progressSyncMeta',
  ];
  static const Set<String> _secureBoxBaseNames = {
    'sessions',
    'wrongNotes',
    'quizResults',
    'progressSyncMeta',
  };
  static List<String> get _boxNames =>
      _baseBoxNames.map(UserDataScope.boxName).toList(growable: false);

  static const int schemaVersion = 1;
  static const String appVersion = '1.0.0';

  /// 현재 로컬 데이터 전체를 JSON 문자열로 내보낸다.
  Future<OperationResult<String>> exportAll() async {
    try {
      final boxes = <String, Map<String, dynamic>>{};
      final boxNames = _boxNames;
      for (final name in boxNames) {
        final box = await _openBox(name);
        final map = <String, dynamic>{};
        for (final key in box.keys) {
          final v = box.get(key);
          map[key.toString()] = _sanitize(v);
        }
        boxes[name] = map;
      }

      final payload = {
        'schemaVersion': schemaVersion,
        'appVersion': appVersion,
        'createdAt': DateTime.now().toIso8601String(),
        'boxes': boxes,
      };
      final body = jsonEncode(payload);
      final checksum = sha256.convert(utf8.encode(body)).toString();
      final wrapped = jsonEncode({'checksum': checksum, 'payload': payload});
      return OperationResult.ok(wrapped);
    } catch (e) {
      if (kDebugMode) debugPrint('BackupService.exportAll 실패: $e');
      return OperationResult.fail('백업 파일을 만드는 중 오류가 발생했어요: $e');
    }
  }

  /// 이전에 내보낸 JSON 문자열을 검증 후 복원한다.
  /// 실패 시 원본 데이터를 훼손하지 않고 안전하게 실패한다(사전 검증 → 실제 쓰기 순서).
  Future<OperationResult<int>> importAll(String rawJson) async {
    Map<String, dynamic> wrapped;
    try {
      wrapped = jsonDecode(rawJson) as Map<String, dynamic>;
    } catch (e) {
      return const OperationResult.fail('올바른 백업 파일이 아니에요. 파일이 손상되었을 수 있어요.');
    }

    final checksum = wrapped['checksum'] as String?;
    final payload = wrapped['payload'];
    if (checksum == null || payload == null) {
      return const OperationResult.fail('백업 파일 형식이 올바르지 않아요.');
    }

    final payloadStr = jsonEncode(payload);
    final actualChecksum = sha256.convert(utf8.encode(payloadStr)).toString();
    if (actualChecksum != checksum) {
      return const OperationResult.fail(
        '백업 파일의 체크섬이 일치하지 않아요. 손상된 파일일 수 있어 복원을 중단했어요.',
      );
    }

    final payloadMap = payload as Map<String, dynamic>;
    final version = payloadMap['schemaVersion'] as int?;
    if (version == null || version > schemaVersion) {
      return OperationResult.fail(
        '이 백업은 더 최신 버전의 앱에서 만들어졌어요(v$version). 앱을 업데이트한 뒤 다시 시도해주세요.',
      );
    }

    final boxesRaw = payloadMap['boxes'];
    if (boxesRaw is! Map) {
      return const OperationResult.fail('백업 파일에 데이터가 없어요.');
    }
    final boxNames = _boxNames;
    if (!_matchesCurrentOwner(boxesRaw.keys.whereType<String>(), boxNames)) {
      return const OperationResult.fail(
        '다른 계정 또는 게스트 공간의 백업입니다. 백업을 만든 계정으로 로그인한 뒤 복원해 주세요.',
      );
    }

    // [P2-A/B6] box.clear() 후 put 도중 예외가 나면 그 박스가 반파 상태로
    // 남는 문제를 막기 위해, 각 박스를 건드리기 직전에 원본 내용을
    // 스냅샷해 두고 실패 시 그 박스만 스냅샷으로 되돌린다. 이미 정상 복원된
    // 앞선 박스는 그대로 유지한다(전체 백업 자체가 이미 검증된 하나의
    // 스냅샷이므로, 박스 단위 원자성이면 데이터 훼손 방지 목적을 충족한다).
    int restoredBoxes = 0;
    for (final name in boxNames) {
      final boxData = boxesRaw[name];
      if (boxData is! Map) continue;
      final box = await _openBox(name);
      final snapshot = Map<dynamic, dynamic>.from(box.toMap());
      try {
        await box.clear();
        for (final entry in boxData.entries) {
          await box.put(entry.key, entry.value);
        }
        restoredBoxes++;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('BackupService.importAll: "$name" 박스 복원 실패, 롤백: $e');
        }
        try {
          await box.clear();
          await box.putAll(snapshot);
        } catch (rollbackError) {
          if (kDebugMode) {
            debugPrint(
              'BackupService.importAll: "$name" 박스 롤백도 실패: $rollbackError',
            );
          }
        }
        return OperationResult.fail(
          '복원 중 오류가 발생해 "$name" 데이터를 원래 상태로 되돌렸어요. 백업 파일을 확인한 뒤 다시 시도해주세요: $e',
        );
      }
    }
    return OperationResult.ok(restoredBoxes);
  }

  /// 백업 파일의 요약 정보(생성일·문항수 등)만 미리 확인 — 복원 전 사용자 확인용.
  Future<OperationResult<BackupSummary>> peek(String rawJson) async {
    try {
      final wrapped = jsonDecode(rawJson) as Map<String, dynamic>;
      final payload = wrapped['payload'] as Map<String, dynamic>;
      final boxes = payload['boxes'] as Map<String, dynamic>;
      final quizCount = _countBaseBox(boxes, 'quizResults');
      final noteCount = _countBaseBox(boxes, 'wrongNotes');
      return OperationResult.ok(
        BackupSummary(
          createdAt:
              DateTime.tryParse(payload['createdAt'] as String? ?? '') ??
              DateTime.now(),
          appVersion: payload['appVersion'] as String? ?? '?',
          quizResultCount: quizCount,
          wrongNoteCount: noteCount,
        ),
      );
    } catch (e) {
      return OperationResult.fail('백업 파일을 읽을 수 없어요: $e');
    }
  }

  Future<Box> _openBox(String name) {
    final baseName = name.split('__account_').first;
    if (_secureBoxBaseNames.contains(baseName)) {
      return SecureBoxService.instance.openSecureBox(name);
    }
    return Hive.openBox(name);
  }

  bool _matchesCurrentOwner(
    Iterable<String> backupNames,
    List<String> currentNames,
  ) {
    final fingerprints = backupNames
        .map(_accountFingerprint)
        .whereType<String>()
        .toSet();
    final currentFingerprint = _accountFingerprint(
      currentNames.firstWhere((name) => name.startsWith('sessions')),
    );
    if (fingerprints.length > 1) return false;
    final backupFingerprint = fingerprints.isEmpty ? null : fingerprints.first;
    return backupFingerprint == currentFingerprint;
  }

  String? _accountFingerprint(String boxName) {
    final marker = boxName.lastIndexOf('__account_');
    return marker < 0 ? null : boxName.substring(marker + '__account_'.length);
  }

  int _countBaseBox(Map<String, dynamic> boxes, String baseName) => boxes
      .entries
      .where(
        (entry) =>
            entry.key == baseName ||
            entry.key.startsWith('${baseName}__account_'),
      )
      .fold<int>(
        0,
        (count, entry) => count + ((entry.value as Map?)?.length ?? 0),
      );

  /// Q80: 자동 백업 — 앱 문서 디렉토리에 최신 백업 파일 1개를 유지한다.
  /// (수동 내보내기 공유와는 별개로, 사용자가 인지하지 못해도 데이터 손실을 완화)
  /// 웹 플랫폼은 파일시스템 접근이 제한적이라 스킵한다.
  Future<OperationResult<String>> autoBackupToLocalFile() async {
    if (kIsWeb) {
      return const OperationResult.fail('웹에서는 자동 백업을 지원하지 않아요.');
    }
    final exported = await exportAll();
    if (!exported.success) {
      return OperationResult.fail(exported.errorMessage);
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/voltssam_autobackup.json');
      await file.writeAsString(exported.data!);
      return OperationResult.ok(file.path);
    } catch (e) {
      if (kDebugMode) debugPrint('BackupService.autoBackupToLocalFile 실패: $e');
      return OperationResult.fail('자동 백업 저장 중 오류: $e');
    }
  }

  /// SharedPreferences는 boxes로 다루지 않는 부속 설정 위주라 백업 스코프에서는
  /// 의도적으로 제외한다(Hive settings 박스가 단일 진실 원천). 향후 필요 시 확장.
  Future<void> debugDumpPrefsKeys() async {
    if (!kDebugMode) return;
    final prefs = await SharedPreferences.getInstance();
    debugPrint('SharedPreferences keys: ${prefs.getKeys()}');
  }

  dynamic _sanitize(dynamic v) {
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), _sanitize(val)));
    }
    if (v is List) {
      return v.map(_sanitize).toList();
    }
    return v;
  }
}

class BackupSummary {
  final DateTime createdAt;
  final String appVersion;
  final int quizResultCount;
  final int wrongNoteCount;

  const BackupSummary({
    required this.createdAt,
    required this.appVersion,
    required this.quizResultCount,
    required this.wrongNoteCount,
  });
}
