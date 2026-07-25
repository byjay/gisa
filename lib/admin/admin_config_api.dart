import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../services/admin_service.dart';
import '../services/app_config.dart';
import '../services/remote_config_service.dart';

/// 🛠️ 관리자 콘솔 ↔ 서버 원격설정 API 클라이언트 (관리자 앱 전용).
///
/// - GET  `/v1/app/config`  : 현재 배포된 설정 조회(공개지만 관리자 콘솔도 사용).
/// - PUT  `/v1/app/config`  : 관리자 토큰(Bearer)으로 설정 배포. "배포" 버튼이 호출.
///
/// 서버가 version/updatedAt을 증가시켜 반환하므로, 학습앱은 다음 pull 때 변경을 감지한다.
class AdminConfigApi {
  AdminConfigApi._();
  static final AdminConfigApi instance = AdminConfigApi._();

  String get _base => AppConfig.apiBaseUrl;

  /// 현재 서버 설정을 불러온다. 실패 시 null.
  Future<RemoteAppConfig?> fetch() async {
    if (_base.isEmpty) return null;
    try {
      final res = await http
          .get(Uri.parse('$_base/v1/app/config'))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      return RemoteAppConfig.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('AdminConfigApi.fetch 실패: $e');
      return null;
    }
  }

  /// 관리자 설정을 서버에 배포(PUT). 성공 시 서버가 반환한 최신 설정.
  Future<AdminPublishResult> publish(RemoteAppConfig cfg) async {
    if (_base.isEmpty) {
      return const AdminPublishResult.failure('서버(API_BASE_URL)가 설정되지 않았습니다.');
    }
    final token = AdminService.instance.serverToken;
    if (token == null || token.isEmpty) {
      return const AdminPublishResult.failure('관리자 토큰이 없습니다. 먼저 관리자 인증을 완료하세요.');
    }
    try {
      final res = await http
          .put(
            Uri.parse('$_base/v1/app/config'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(cfg.toJson()),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final saved = RemoteAppConfig.fromJson(
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
        );
        return AdminPublishResult.success(saved);
      }
      if (res.statusCode == 401 || res.statusCode == 403) {
        return const AdminPublishResult.failure('권한이 없습니다(토큰 만료/무효). 재인증하세요.');
      }
      return AdminPublishResult.failure('배포 실패 (${res.statusCode})');
    } catch (e) {
      if (kDebugMode) debugPrint('AdminConfigApi.publish 실패: $e');
      return AdminPublishResult.failure('네트워크 오류: $e');
    }
  }
}

/// 배포 결과.
@immutable
class AdminPublishResult {
  const AdminPublishResult.success(this.config)
      : ok = true,
        message = '배포 완료';
  const AdminPublishResult.failure(this.message)
      : ok = false,
        config = null;

  final bool ok;
  final String message;
  final RemoteAppConfig? config;
}
