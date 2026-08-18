/// 🌐 Gisaclub 전역 설정 — 모든 서버 URL을 한 곳에서 관리한다.
///
/// [도메인 비종속 원칙]
/// 커스텀 도메인(gisa.club 등)을 아직 구매하지 않았으므로, 기본값은 Cloudflare가
/// 무료로 제공하는 `*.workers.dev` / `*.pages.dev` 주소를 사용한다.
/// URL을 코드 곳곳에 하드코딩하지 않고 **여기 한 곳 + 빌드시 --dart-define**으로만
/// 주입한다. 나중에 커스텀 도메인을 붙이면 이 파일이나 dart-define 값만 바꾸면 되고,
/// 애플리케이션 로직은 전혀 수정할 필요가 없다.
///
/// [주입 예시 — 실제 배포]
///   flutter build apk --release \
///     --dart-define=API_BASE_URL=`https://gisaclub-api.<sub>.workers.dev` \
///     --dart-define=WEB_BASE_URL=https://gisaclub-admin.pages.dev
///
///   커스텀 도메인 구매 후에는 값만 교체:
///     --dart-define=API_BASE_URL=https://api.gisa.club \
///     --dart-define=WEB_BASE_URL=https://admin.gisa.club
class AppConfig {
  AppConfig._();

  /// Worker API 베이스 URL.
  /// 미설정 시 빈 문자열 → 관리자/서버 기능이 "미설정" 안전 상태로 동작한다.
  ///
  /// ⚠️ 하위호환: 이전 빌드가 쓰던 `GISACLUB_API_BASE`도 계속 인식한다.
  static const String apiBaseUrl = _apiBaseUrl != ''
      ? _apiBaseUrl
      : _legacyApiBase;

  static const String _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static const String _legacyApiBase = String.fromEnvironment(
    'GISACLUB_API_BASE',
    defaultValue: '',
  );

  /// 웹(관리자 대시보드 Pages) 베이스 URL — 안내 문구·딥링크 표시용.
  static const String webBaseUrl = String.fromEnvironment(
    'WEB_BASE_URL',
    defaultValue: '',
  );

  /// 앱 자동 업데이트 매니페스트 URL.
  /// 별도 지정이 없으면 API 베이스의 `/v1/app/version`을 사용한다(도메인 비종속).
  static const String updateManifestUrl = _updateManifestUrl != ''
      ? _updateManifestUrl
      : _legacyUpdateManifest;

  static const String _updateManifestUrl = String.fromEnvironment(
    'UPDATE_MANIFEST_URL',
    defaultValue: '',
  );
  static const String _legacyUpdateManifest = String.fromEnvironment(
    'GISACLUB_UPDATE_MANIFEST',
    defaultValue: '',
  );

  /// API 베이스가 설정되어 있는지(서버 기능 사용 가능 여부).
  static bool get hasApi => apiBaseUrl.isNotEmpty;

  /// 🔐 이 빌드가 **관리자 전용 앱**인가 (R60).
  ///
  /// ## 왜 필요한가 — 실측된 문제
  /// 학습앱 설정화면(`lib/screens/settings_screen.dart`)에 "슈퍼 관리자 모드"
  /// 항목이 **모든 사용자에게** 그대로 보이고 있었다. 토큰이 없으면 기능은
  /// 막히지만, 일반 학습자에게 운영 메뉴가 보이는 것 자체가 문제다.
  ///   - 학습자는 자기와 무관한 메뉴를 보고 혼란스러워한다.
  ///   - 운영 화면의 존재와 구조가 그대로 노출된다(공격면 확대).
  ///
  /// ## 판정 방식
  /// `lib/main_admin.dart` 로 빌드할 때만 `IS_ADMIN_APP=true` 를 주입한다.
  /// **런타임 값이 아니라 컴파일 상수**이므로, 사용자 앱에서는 관리자 화면 코드가
  /// tree-shaking 으로 바이너리에서 아예 빠진다(런타임 스위치로는 불가능).
  ///
  ///   관리자 앱: flutter build apk --release --flavor admin \
  ///                -t lib/main_admin.dart --dart-define=IS_ADMIN_APP=true
  ///   사용자 앱: flutter build apk --release --flavor user -t lib/main.dart
  ///              (주입하지 않으므로 false)
  static const bool isAdminApp = bool.fromEnvironment(
    'IS_ADMIN_APP',
    defaultValue: false,
  );

  /// 자동업데이트 매니페스트 URL을 해석한다(명시값 → API베이스 파생 → 없음).
  static String resolveUpdateManifestUrl() {
    if (updateManifestUrl.isNotEmpty) return updateManifestUrl;
    if (apiBaseUrl.isNotEmpty) return '$apiBaseUrl/v1/app/version';
    return '';
  }
}
