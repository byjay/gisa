import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

/// 로그인 사용자 프로필 (로컬 저장용).
class UserProfile {
  final String id;
  final String name;
  final String email;
  final String? photoUrl;
  final String provider; // 'google' | 'local'

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

  factory UserProfile.fromMap(Map<dynamic, dynamic> m) => UserProfile(
    id: (m['id'] ?? '') as String,
    name: (m['name'] ?? '') as String,
    email: (m['email'] ?? '') as String,
    photoUrl: m['photoUrl'] as String?,
    provider: (m['provider'] ?? 'local') as String,
  );
}

/// 인증 서비스 — 현재는 준비(스캐폴딩) 단계.
///
/// 구글 로그인은 아직 실제 연동하지 않고, 향후 google_sign_in +
/// firebase_auth 를 붙일 수 있도록 인터페이스만 마련해 둔다.
/// 지금은 로컬에 프로필을 저장/불러오는 정도만 동작한다.
class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _boxName = 'auth';
  static const _profileKey = 'profile';

  Box? _box;
  UserProfile? _user;

  UserProfile? get currentUser => _user;
  bool get isLoggedIn => _user != null;

  /// 앱 시작 시 초기화 — 저장된 프로필 복원.
  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
    final raw = _box!.get(_profileKey);
    if (raw is Map) {
      _user = UserProfile.fromMap(raw);
    }
    notifyListeners();
  }

  /// 🚧 [준비 단계] 구글 로그인.
  ///
  /// TODO(google-login): google_sign_in / firebase_auth 연동.
  ///   1. pubspec.yaml 에 google_sign_in, firebase_auth 추가
  ///   2. Firebase 콘솔에서 Google 로그인 사용 설정 + SHA-1 등록
  ///   3. android/app/google-services.json 배치
  ///   4. 아래 로직을 실제 GoogleSignIn().signIn() 흐름으로 교체
  ///
  /// 지금은 미구현 상태이며, UI 에서 "준비 중" 안내를 띄우기 위해
  /// [GoogleSignInNotReady] 예외를 던진다.
  Future<UserProfile> signInWithGoogle() async {
    throw const GoogleSignInNotReady();
  }

  /// 로컬(게스트) 프로필 저장 — 로그인 전에도 학습 데이터를 쓸 수 있게.
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
    await _box?.put(_profileKey, profile.toMap());
    notifyListeners();
  }

  /// (내부용) 구글 프로필 확정 저장 — 연동 완료 후 사용.
  Future<void> setGoogleProfile(UserProfile profile) async {
    _user = profile;
    await _box?.put(_profileKey, profile.toMap());
    notifyListeners();
  }

  Future<void> signOut() async {
    _user = null;
    await _box?.delete(_profileKey);
    notifyListeners();
  }
}

/// 구글 로그인이 아직 준비되지 않았음을 나타내는 예외.
class GoogleSignInNotReady implements Exception {
  const GoogleSignInNotReady();
  @override
  String toString() => '구글 로그인은 준비 중입니다.';
}
