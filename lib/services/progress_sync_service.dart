import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'admin_service.dart';
import 'app_config.dart';

/// 🔄 학습 진도·점수 서버 동기화 (SSOT 정책 · R58)
///
/// [정책 근거] docs/DATA_STORAGE_POLICY.md §4
/// 이 앱의 핵심 가치는 "오프라인 학습"이므로 진도/점수는 로컬에 write-through
/// 캐시한다. 다만 **서버(Cloudflare D1/KV)가 최종 SSOT**이며, 서버가 배포되면
/// 이 서비스가 로컬 변경분을 push하고 서버 스냅샷을 pull하여 병합한다.
/// **충돌 시 서버 값이 우선.**
///
/// [중요 — 판정 분리]
/// 진도/점수는 권한·구독·관리자 판정과 **완전히 무관**하다. 로컬 진도로 유료 기능을
/// 열거나 관리자로 승격하는 일은 절대 없다(그 판정은 EntitlementService/AdminService가
/// 서버 응답으로만 수행). 이 서비스는 "사용자 소유 학습 데이터"의 백업·기기간 동기만
/// 담당한다.
///
/// [안전 기본값]
/// 서버 미설정(API_BASE_URL 없음)이면 모든 메서드는 **no-op** 이고, 앱은 로컬
/// 캐시만으로 완전히 동작한다. `API_BASE_URL` 이 주입되고 Worker `/v1/progress`
/// 가 구현되면 코드 수정 없이 동기화가 활성화된다.
class ProgressSyncService {
  ProgressSyncService._();
  static final ProgressSyncService instance = ProgressSyncService._();

  bool _pushing = false;

  /// 서버 동기화가 가능한 상태인지(API 베이스 + 관리자/사용자 토큰).
  /// 현재는 인증 토큰이 있어야 사용자별 진도를 식별할 수 있다.
  bool get isEnabled =>
      AppConfig.hasApi && (AdminService.instance.serverToken?.isNotEmpty ?? false);

  String get _base => AppConfig.apiBaseUrl;
  String? get _token => AdminService.instance.serverToken;

  /// ⬇️ 서버 진도 스냅샷 조회(pull). 서버가 SSOT이므로 반환 맵을 로컬에 병합한다.
  /// 서버 미설정/미인증/오류 시 **null**(호출측은 로컬 캐시를 그대로 유지).
  Future<Map<String, dynamic>?> pull() async {
    if (!isEnabled) return null;
    try {
      final resp = await http
          .get(
            Uri.parse('$_base/v1/progress'),
            headers: {'Authorization': 'Bearer $_token'},
          )
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is Map<String, dynamic>) return data;
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('progress pull 실패(로컬 유지): $e');
      return null;
    }
  }

  /// ⬆️ 로컬 변경분 반영(push). 서버가 최종 병합·판정한다.
  /// 서버 미설정/미인증이면 no-op(true 아님, false 반환).
  Future<bool> push(Map<String, dynamic> snapshot) async {
    if (!isEnabled || _pushing) return false;
    _pushing = true;
    try {
      final resp = await http
          .post(
            Uri.parse('$_base/v1/progress'),
            headers: {
              'Authorization': 'Bearer $_token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(snapshot),
          )
          .timeout(const Duration(seconds: 12));
      return resp.statusCode == 200;
    } catch (e) {
      if (kDebugMode) debugPrint('progress push 실패(로컬 유지): $e');
      return false;
    } finally {
      _pushing = false;
    }
  }
}
