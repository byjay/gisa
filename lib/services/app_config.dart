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

  /// 자동업데이트 매니페스트 URL을 해석한다(명시값 → API베이스 파생 → 없음).
  static String resolveUpdateManifestUrl() {
    if (updateManifestUrl.isNotEmpty) return updateManifestUrl;
    if (apiBaseUrl.isNotEmpty) return '$apiBaseUrl/v1/app/version';
    return '';
  }
}
