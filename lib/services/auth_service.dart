import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:hive/hive.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'app_config.dart';
import 'cbt_info_service.dart';
import 'qnet_schedule_service.dart';
import 'remote_content_api.dart';
import 'study_data.dart';

void _clearSessionContentCaches() {
  StudyData.instance.clearSessionCache();
  CbtInfoService.instance.clearCache();
  QnetScheduleService.instance.clearCache();
  try {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  } catch (_) {
    // Flutter bindings are not created in a few service-only test contexts.
  }
}

/// 로그인 사용자 프로필.
class UserProfile {
  final String id;
  final String name;
  final String email;
  final String? photoUrl;
  final String provider;

  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    this.photoUrl,
    this.provider = 'local',
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'email': email,
    'photoUrl': photoUrl,
    'provider': provider,
  };

  factory UserProfile.fromMap(Map<dynamic, dynamic> map) => UserProfile(
    id: (map['id'] ?? '') as String,
    name: (map['name'] ?? '') as String,
    email: (map['email'] ?? '') as String,
    photoUrl: map['photoUrl'] as String?,
    provider: (map['provider'] ?? 'local') as String,
  );
}

/// 외부 로그인 토큰을 Worker에서 검증하고 API 세션을 저장한다.
class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _boxName = 'auth';
  static const _profileKey = 'profile';
  static const _tokenKey = 'api_session';
  static const _expiryKey = 'api_session_expiry';
  static const _secureStorage = FlutterSecureStorage();

  Box? _box;
  UserProfile? _user;
  String? _sessionToken;
  bool _googleInitialized = false;
  bool _kakaoInitialized = false;
  Future<void> Function(String? ownerId)? _dataOwnerChangeHandler;

  UserProfile? get currentUser => _user;
  bool get isLoggedIn => _user != null;
  String? get sessionToken => _sessionToken;
  bool get hasApiSession =>
      (_user?.provider == 'google' || _user?.provider == 'kakao') &&
      _sessionToken != null;
  String? get dataOwnerId => hasApiSession ? _user?.id : null;

  /// AppProvider binds account-scoped Hive boxes before the login state is shown.
  void setDataOwnerChangeHandler(
    Future<void> Function(String? ownerId) handler,
  ) {
    _dataOwnerChangeHandler = handler;
  }

  Future<void> _notifyDataOwnerChange() async {
    final handler = _dataOwnerChangeHandler;
    if (handler != null) await handler(dataOwnerId);
  }

  Future<void> init() async {
    try {
      await initializeKakao();
    } catch (_) {
      // Optional sign-in setup must never prevent the app from opening.
    }
    _box = await Hive.openBox(_boxName);
    final rawProfile = _box!.get(_profileKey);
    if (rawProfile is Map) _user = UserProfile.fromMap(rawProfile);

    if (_user?.provider == 'google' || _user?.provider == 'kakao') {
      final expiresAt = _box!.get(_expiryKey);
      final expiry = expiresAt is int ? expiresAt : 0;
      final storedToken = await _secureStorage.read(key: _tokenKey);
      if (expiry > DateTime.now().millisecondsSinceEpoch &&
          storedToken is String &&
          storedToken.isNotEmpty) {
        _sessionToken = storedToken;
        RemoteContentApi.instance.authToken = storedToken;
      } else {
        _user = null;
        _sessionToken = null;
        RemoteContentApi.instance.authToken = null;
        _clearSessionContentCaches();
        await _box!.delete(_profileKey);
        await _secureStorage.delete(key: _tokenKey);
        await _box!.delete(_expiryKey);
      }
    }
    notifyListeners();
  }

  /// Kakao SDK is initialized before the login screen can start OAuth.
  Future<void> initializeKakao() async {
    if (_kakaoInitialized) return;
    final appKey = kIsWeb
        ? AppConfig.kakaoJavaScriptAppKey
        : AppConfig.kakaoNativeAppKey;
    if (appKey.isEmpty) return;
    await KakaoSdk.init(
      nativeAppKey: kIsWeb ? null : appKey,
      javaScriptAppKey: kIsWeb ? appKey : null,
    );
    _kakaoInitialized = true;
  }

  /// Google 계정 로그인 후 ID token을 서버 세션으로 교환한다.
  Future<UserProfile> signInWithGoogle() async {
    _validateApiBaseUrl();
    if (AppConfig.googleOAuthClientId.isEmpty) {
      throw StateError('GOOGLE_OAUTH_CLIENT_ID 빌드 설정이 필요합니다.');
    }

    final google = GoogleSignIn.instance;
    if (!_googleInitialized) {
      await google.initialize(serverClientId: AppConfig.googleOAuthClientId);
      _googleInitialized = true;
    }
    final account = await google.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Google ID token을 가져오지 못했습니다. OAuth 설정을 확인해 주세요.');
    }

    final response = await http
        .post(
          Uri.parse('${AppConfig.apiBaseUrl}/v1/auth/google'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'idToken': idToken}),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw StateError(_messageFrom(response));
    }

    return _completeSignIn(response, provider: 'google', emailRequired: true);
  }

  /// Kakao Account OAuth를 거쳐 액세스 토큰을 서버에서 검증하고 세션을 받는다.
  /// Flutter SDK의 웹 로그인은 별도 JS OAuth 콜백이 필요하므로 Android/iOS만 노출한다.
  Future<UserProfile> signInWithKakao() async {
    if (kIsWeb) {
      throw StateError('카카오 계정 로그인은 현재 모바일 앱에서 사용할 수 있습니다.');
    }
    _validateApiBaseUrl();
    if (AppConfig.kakaoNativeAppKey.isEmpty) {
      throw StateError('KAKAO_NATIVE_APP_KEY 빌드 설정이 필요합니다.');
    }
    await initializeKakao();
    if (!_kakaoInitialized) {
      throw StateError('카카오 로그인 설정을 초기화하지 못했습니다.');
    }

    final kakaoToken = await UserApi.instance.loginWithKakaoAccount();
    final accessToken = kakaoToken.accessToken.trim();
    if (accessToken.isEmpty) {
      throw StateError('카카오 액세스 토큰을 가져오지 못했습니다.');
    }

    final response = await http
        .post(
          Uri.parse('${AppConfig.apiBaseUrl}/v1/auth/kakao'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'accessToken': accessToken}),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw StateError(_messageFrom(response));
    }
    return _completeSignIn(response, provider: 'kakao');
  }

  void _validateApiBaseUrl() {
    if (!AppConfig.hasApi) throw StateError('API_BASE_URL이 설정되지 않았습니다.');
    final apiUri = Uri.tryParse(AppConfig.apiBaseUrl);
    final localHttp =
        kDebugMode &&
        apiUri != null &&
        (apiUri.host == 'localhost' ||
            apiUri.host == '127.0.0.1' ||
            apiUri.host == '10.0.2.2');
    if (apiUri == null || (apiUri.scheme != 'https' && !localHttp)) {
      throw StateError('API_BASE_URL은 HTTPS 주소여야 합니다.');
    }
  }

  Future<UserProfile> _completeSignIn(
    http.Response response, {
    required String provider,
    bool emailRequired = false,
  }) async {
    final data =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final token = data['accessToken'] as String?;
    final expiresIn = (data['expiresIn'] as num?)?.toInt() ?? 0;
    final profileJson = data['profile'] as Map<String, dynamic>?;
    if (token == null ||
        token.isEmpty ||
        expiresIn <= 0 ||
        profileJson == null) {
      throw const FormatException('서버 로그인 응답 형식이 올바르지 않습니다.');
    }

    final profile = UserProfile(
      id: profileJson['id'] as String? ?? '',
      name: profileJson['name'] as String? ?? '학습자',
      email: profileJson['email'] as String? ?? '',
      photoUrl: profileJson['photoUrl'] as String?,
      provider: provider,
    );
    if (profile.id.isEmpty || (emailRequired && profile.email.isEmpty)) {
      throw const FormatException('서버 로그인 프로필이 불완전합니다.');
    }

    if (_user?.id != profile.id || _user?.provider != provider) {
      _clearSessionContentCaches();
    }
    _user = profile;
    _sessionToken = token;
    RemoteContentApi.instance.authToken = token;
    await _box?.put(_profileKey, profile.toMap());
    await _secureStorage.write(key: _tokenKey, value: token);
    await _box?.put(
      _expiryKey,
      DateTime.now().millisecondsSinceEpoch + expiresIn * 1000,
    );
    try {
      await _notifyDataOwnerChange();
    } finally {
      notifyListeners();
    }
    return profile;
  }

  String _messageFrom(http.Response response) {
    try {
      final json =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return (json['message'] as String?) ?? '로그인 실패 (${response.statusCode})';
    } catch (_) {
      return '로그인 실패 (${response.statusCode})';
    }
  }

  /// 로그인 전 로컬 프로필을 사용하는 기존 오프라인 모드.
  Future<void> saveLocalProfile({
    required String name,
    String email = '',
  }) async {
    final profile = UserProfile(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim().isEmpty ? '학습자' : name.trim(),
      email: email.trim(),
      provider: 'local',
    );
    _user = profile;
    _sessionToken = null;
    RemoteContentApi.instance.authToken = null;
    _clearSessionContentCaches();
    await _box?.put(_profileKey, profile.toMap());
    await _secureStorage.delete(key: _tokenKey);
    await _box?.delete(_expiryKey);
    try {
      await _notifyDataOwnerChange();
    } finally {
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    final provider = _user?.provider;
    final token = _sessionToken;
    _user = null;
    _sessionToken = null;
    RemoteContentApi.instance.authToken = null;
    _clearSessionContentCaches();
    await _box?.delete(_profileKey);
    await _secureStorage.delete(key: _tokenKey);
    await _box?.delete(_expiryKey);
    try {
      await _notifyDataOwnerChange();
    } finally {
      notifyListeners();
    }

    if (token != null && AppConfig.hasApi) {
      try {
        await http
            .post(
              Uri.parse('${AppConfig.apiBaseUrl}/v1/auth/logout'),
              headers: {'Authorization': 'Bearer $token'},
            )
            .timeout(const Duration(seconds: 8));
      } catch (_) {
        // 로컬 로그아웃은 서버 연결 실패와 무관하게 완료한다.
      }
    }
    if (provider == 'google' && _googleInitialized) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
    }
    if (provider == 'kakao' && _kakaoInitialized) {
      try {
        await UserApi.instance.logout();
      } catch (_) {}
    }
  }
}

/// 기존 설정 화면과의 소스 호환을 위한 예외 타입.
class GoogleSignInNotReady implements Exception {
  const GoogleSignInNotReady();
  @override
  String toString() => 'Google 로그인을 사용할 수 없습니다.';
}
