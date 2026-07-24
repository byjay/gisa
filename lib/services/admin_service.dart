import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// 🛡️ Gisaclub 슈퍼 관리자(운영자) 서비스 — **서버 토큰 검증 방식(R57)**.
///
/// [아키텍처 전환의 배경]
/// 이전(R56)에는 앱 안에 Google Sign-In + 이메일 해시 비교 로직이 있었다.
/// 그러나 "앱 내부의 이메일 비교"는 APK를 변조·디컴파일하면 우회 가능한
/// **함정**이었다. R57에서는 판정 로직을 앱에서 완전히 제거하고,
/// **Cloudflare Access(Zero Trust)** 가 관리자 대시보드(admin.gisa.club)
/// 앞단에서 Google 로그인 게이트를 걸어 지정된 이메일만 통과시킨다.
///
/// [하이브리드 구조]
///  1) 관리자 **대시보드**   = admin.gisa.club (Cloudflare Access 뒤, 앱 밖)
///     → 여기서 Google 로그인 통과 시 Worker `/v1/admin/issue-app-token`이
///       **앱용 관리자 토큰**(서명된 짧은 토큰)을 발급한다.
///  2) 폰 앱 **무제한 모드** = 이 토큰을 앱에 등록(붙여넣기 or 딥링크)하면,
///     앱은 Worker `/v1/admin/verify`로 토큰을 검증받고(서버가 최종 판정),
///     검증 성공 시에만 로컬 오버라이드(_isAdmin=true)를 켠다.
///
/// [보안 요점 — 정직한 설명]
///  - 앱에는 "관리자 이메일"도 "PIN"도 없다. 오직 서버가 발급한 토큰만 신뢰한다.
///  - 토큰 검증은 서버가 수행하므로, 앱을 변조해도 서버 자원(타 사용자 데이터)
///    은 얻을 수 없다. 로컬 오버라이드는 "운영자 본인 기기의 UX 게이트"일 뿐,
///    실제 권한은 항상 서버가 토큰으로 판정한다.
///  - 오프라인/서버 미배포 상태에서는 관리자 모드가 열리지 않는다(안전 기본값).
class AdminService extends ChangeNotifier {
  AdminService._();
  static final AdminService instance = AdminService._();

  // ─────────────── 저장 키 ───────────────
  static const _kAdminSession = 'admin_session_v2'; // '1'이면 관리자 세션 활성
  static const _kAdminToken = 'admin_server_token_v2'; // 서버 발급 관리자 토큰
  static const _kAdminEmail = 'admin_email_v2'; // 검증 응답의 이메일(표시용)

  /// Worker API 베이스 URL (빌드시 주입).
  /// 예: --dart-define=GISACLUB_API_BASE=https://api.gisa.club
  static const _apiBase = String.fromEnvironment(
    'GISACLUB_API_BASE',
    defaultValue: '',
  );

  bool _isAdmin = false;
  String? _serverToken;
  String _email = '';
  bool _verifying = false;

  /// 현재 관리자 세션 활성 여부. 앱 전역에서 이 값으로 오버라이드를 결정한다.
  bool get isAdmin => _isAdmin;

  /// 서버 관리자 토큰(서버 API 호출의 Authorization 헤더에 사용).
  String? get serverToken => _serverToken;

  /// 검증된 관리자 이메일(표시용, 서버 응답 기반).
  String get email => _email;

  /// 표시용 라벨.
  String get label => _email.isNotEmpty ? _email : '운영자';

  /// 토큰 검증 진행 중 여부(UI 로딩 표시용).
  bool get isVerifying => _verifying;

  /// API 베이스가 설정되어 있는지(미설정이면 관리자 모드 사용 불가).
  bool get isConfigured => _apiBase.isNotEmpty;

  String get apiBase => _apiBase;

  /// 앱 시작 시 초기화 — 저장된 관리자 세션 복원 + (온라인이면) 토큰 재검증.
  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isAdmin = prefs.getString(_kAdminSession) == '1';
      _serverToken = prefs.getString(_kAdminToken);
      _email = prefs.getString(_kAdminEmail) ?? '';
    } catch (e) {
      if (kDebugMode) debugPrint('AdminService init 실패: $e');
      _isAdmin = false;
    }
    notifyListeners();

    // 저장된 토큰이 있으면 백그라운드로 재검증(만료·폐기 반영).
    final token = _serverToken;
    if (token != null && token.isNotEmpty && _apiBase.isNotEmpty) {
      // 실패해도 기존 세션은 유지(오프라인 관용). 성공 시 이메일 갱신.
      unawaited(_reverify(token));
    }
  }

  /// 🔑 관리자 토큰 등록 — admin.gisa.club 에서 발급받은 토큰을 검증하고 활성화.
  ///
  /// 반환값:
  ///   AdminAuthResult.success       — 토큰 검증 성공, 관리자 모드 활성화됨
  ///   AdminAuthResult.invalidToken  — 서버가 토큰을 거부(만료·위조 등)
  ///   AdminAuthResult.notConfigured — GISACLUB_API_BASE 미설정
  ///   AdminAuthResult.network       — 네트워크/서버 오류
  Future<AdminAuthResult> registerToken(String rawToken) async {
    final token = rawToken.trim();
    if (token.isEmpty) return AdminAuthResult.invalidToken;
    if (_apiBase.isEmpty) return AdminAuthResult.notConfigured;

    _verifying = true;
    notifyListeners();
    try {
      final resp = await http
          .get(
            Uri.parse('$_apiBase/v1/admin/verify'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 12));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final email = (data['email'] as String?)?.trim() ?? '';
        await _activate(token: token, email: email);
        return AdminAuthResult.success;
      }
      if (resp.statusCode == 401 || resp.statusCode == 403) {
        return AdminAuthResult.invalidToken;
      }
      return AdminAuthResult.network;
    } catch (e) {
      if (kDebugMode) debugPrint('registerToken 검증 실패: $e');
      return AdminAuthResult.network;
    } finally {
      _verifying = false;
      notifyListeners();
    }
  }

  /// 저장된 토큰 재검증(init 백그라운드용). 실패해도 기존 세션은 유지.
  Future<void> _reverify(String token) async {
    try {
      final resp = await http
          .get(
            Uri.parse('$_apiBase/v1/admin/verify'),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final email = (data['email'] as String?)?.trim() ?? _email;
        if (email != _email) {
          _email = email;
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(_kAdminEmail, email);
          } catch (_) {}
          notifyListeners();
        }
      } else if (resp.statusCode == 401 || resp.statusCode == 403) {
        // 서버가 토큰을 폐기 → 관리자 모드 해제.
        await logout();
      }
    } catch (_) {
      // 오프라인: 기존 세션 유지.
    }
  }

  Future<void> _activate({required String token, required String email}) async {
    _isAdmin = true;
    _serverToken = token;
    _email = email;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kAdminSession, '1');
      await prefs.setString(_kAdminToken, token);
      await prefs.setString(_kAdminEmail, email);
    } catch (_) {}
    notifyListeners();
  }

  /// 관리자 로그아웃 — 세션·토큰 제거(일반 사용자로 복귀).
  Future<void> logout() async {
    _isAdmin = false;
    _serverToken = null;
    _email = '';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kAdminSession);
      await prefs.remove(_kAdminToken);
      await prefs.remove(_kAdminEmail);
    } catch (_) {}
    notifyListeners();
  }
}

/// 관리자 토큰 등록/검증 결과.
enum AdminAuthResult { success, invalidToken, notConfigured, network }
