import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🛡️ Gisaclub 슈퍼 관리자(운영자) 서비스.
///
/// [인증 방식 — Google 계정 로그인 + 이메일 일치]
/// PIN·하드코딩 비밀번호를 쓰지 않는다. 관리자 진입 시 **Google Sign-In**으로
/// 로그인하고, 로그인된 이메일이 "관리자 이메일"과 일치할 때만 관리자 모드가
/// 열린다. 관리자 구글 계정이 2단계 인증(휴대폰)으로 보호되므로, 공격자가
/// 4자리 PIN을 추측하는 것이 아니라 **실제 구글 자격증명 + 휴대폰**을 모두
/// 확보해야 하는 구조라 훨씬 안전하다.
///
/// [디컴파일 방어]
///  - 관리자 이메일을 소스에 평문으로 박지 않고 **SHA-256 해시**만 내장한다.
///    (누가 APK를 뜯어도 어떤 이메일이 관리자인지 바로 드러나지 않는다.)
///  - 운영 배포 시 `--dart-define=GISACLUB_ADMIN_EMAIL_HASH=<해시>` 로 교체 가능.
///
/// [한계 — 정직한 설명]
///  - 앱 내부의 이메일 비교(if email==admin)는 이론상 앱을 변조하면 우회 가능하다
///    (PIN보다 압도적으로 안전하지만 "완벽 차단"은 아님).
///  - 그래서 **서버 자원(타 사용자 데이터·관리자 크레딧) 접근은 서버가 최종
///    판정**한다: 관리자 구글 idToken을 Cloudflare `/v1/admin/login` 에 보내면
///    서버가 이메일을 검증하고 관리자 토큰을 발급한다(선택적 강화 경로).
///  - 즉 로컬 오버라이드 = "운영자 본인 기기의 UX 게이트", 서버 판정 = "진짜 권한".
class AdminService extends ChangeNotifier {
  AdminService._();
  static final AdminService instance = AdminService._();

  // ─────────────── 저장 키 ───────────────
  static const _kAdminSession = 'admin_session_v1'; // '1'이면 관리자 세션 활성
  static const _kAdminToken = 'admin_server_token_v1'; // 서버 발급 토큰(선택)
  static const _kAdminEmail = 'admin_email_v1'; // 로그인된 관리자 이메일(표시용)

  /// 🔐 관리자 이메일의 SHA-256 해시(소문자·trim 후 계산).
  /// 기본값은 "designssir@gmail.com" 의 SHA-256 이다.
  static const _defaultAdminEmailHash =
      'b530074caab8e9989e1a9cf22bb4ef46b3e385c49e229fc21a2f82221b176c0c';

  /// 빌드시 주입 가능한 관리자 이메일 해시(운영 배포판 교체용).
  static const _injectedAdminEmailHash = String.fromEnvironment(
    'GISACLUB_ADMIN_EMAIL_HASH',
    defaultValue: '',
  );

  bool _isAdmin = false;
  String? _serverToken;
  String _email = '';

  /// 현재 관리자 세션 활성 여부. 앱 전역에서 이 값으로 오버라이드를 결정한다.
  bool get isAdmin => _isAdmin;

  /// 서버 관리자 토큰(있으면 서버 API 호출에 사용).
  String? get serverToken => _serverToken;

  /// 로그인된 관리자 이메일(표시용).
  String get email => _email;

  /// 표시용 라벨.
  String get label => _email.isNotEmpty ? _email : '운영자';

  /// 실제 사용할 관리자 이메일 해시(주입값 우선).
  String get _effectiveEmailHash => _injectedAdminEmailHash.isNotEmpty
      ? _injectedAdminEmailHash
      : _defaultAdminEmailHash;

  /// 앱 시작 시 초기화 — 저장된 관리자 세션 복원.
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
  }

  /// 주어진 이메일이 관리자 이메일인지 확인(해시 비교).
  bool _isAdminEmail(String email) {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    final hash = sha256.convert(utf8.encode(normalized)).toString();
    return hash == _effectiveEmailHash;
  }

  /// 🔑 Google 계정으로 관리자 로그인.
  ///
  /// 반환값:
  ///   AdminLoginResult.success   — 관리자 이메일 일치, 세션 활성화됨
  ///   AdminLoginResult.notAdmin  — 로그인은 됐지만 관리자 이메일이 아님
  ///   AdminLoginResult.cancelled — 사용자가 로그인 취소
  ///   AdminLoginResult.error     — 오류(설정 누락 등)
  Future<AdminLoginResult> loginWithGoogle() async {
    try {
      final signIn = GoogleSignIn.instance;
      // v7: 사용 전 initialize() 필요(멱등). serverClientId 등은 기본 설정 사용.
      await signIn.initialize();

      GoogleSignInAccount account;
      try {
        account = await signIn.authenticate(scopeHint: const ['email']);
      } on GoogleSignInException catch (e) {
        if (e.code == GoogleSignInExceptionCode.canceled) {
          return AdminLoginResult.cancelled;
        }
        if (kDebugMode) debugPrint('GoogleSignIn 오류: ${e.code} ${e.description}');
        return AdminLoginResult.error;
      }

      final email = account.email;
      if (!_isAdminEmail(email)) {
        // 관리자 계정이 아니면 즉시 로그아웃(사용자 계정을 앱에 남기지 않음).
        await signIn.signOut();
        return AdminLoginResult.notAdmin;
      }

      await _activate(email: email);
      return AdminLoginResult.success;
    } catch (e) {
      if (kDebugMode) debugPrint('loginWithGoogle 실패: $e');
      return AdminLoginResult.error;
    }
  }

  /// 🌐 서버 발급 관리자 토큰으로 로그인(마켓 배포판 원격 관리 강화용, 선택).
  Future<void> loginWithServerToken(String token, {String email = ''}) async {
    _serverToken = token.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kAdminToken, _serverToken!);
    } catch (_) {}
    await _activate(email: email);
  }

  Future<void> _activate({required String email}) async {
    _isAdmin = true;
    _email = email;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kAdminSession, '1');
      await prefs.setString(_kAdminEmail, email);
    } catch (_) {}
    notifyListeners();
  }

  /// 관리자 로그아웃 — 세션·토큰 제거 + 구글 로그아웃(일반 사용자로 복귀).
  Future<void> logout() async {
    _isAdmin = false;
    _serverToken = null;
    _email = '';
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kAdminSession);
      await prefs.remove(_kAdminToken);
      await prefs.remove(_kAdminEmail);
    } catch (_) {}
    notifyListeners();
  }

  /// (도구) 임의 이메일의 관리자 해시 계산 — 관리자 이메일 교체 시 사용.
  static String emailHashOf(String email) =>
      sha256.convert(utf8.encode(email.trim().toLowerCase())).toString();
}

/// 관리자 Google 로그인 결과.
enum AdminLoginResult { success, notAdmin, cancelled, error }
