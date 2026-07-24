import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// 🔄 Gisaclub 앱 자동 업데이트 서비스.
///
/// [동작 개요]
/// Cloudflare(또는 임의의 정적 호스팅)에 `version.json` 을 올려 두면,
/// 앱은 시작 시 백그라운드로 이 파일을 조회해 새 버전이 있는지 확인한다.
/// 새 버전이 발견되면 홈/설정 화면에 "업데이트" 배너·버튼이 노출되고,
/// 버튼 한 번으로:
///   - Android APK 직접배포: apkUrl 을 브라우저로 열어 다운로드→설치
///   - 스토어 배포판: storeUrl(Play/App Store) 로 이동
///
/// [version.json 스키마 예시]
/// {
///   "latest_version": "1.1.0",
///   "latest_build": 3,
///   "min_supported_build": 1,          // 이 미만이면 강제 업데이트
///   "apk_url": "https://cdn.gisaclub.com/releases/gisaclub-1.1.0.apk",
///   "store_url": "https://play.google.com/store/apps/details?id=com.certstudytracker.study",
///   "release_notes": "AI 튜터 속도 개선, 신규 종목 추가",
///   "force": false
/// }
///
/// [보안/안정성]
///  - 네트워크 실패·잘못된 JSON은 조용히 무시(앱 사용에 영향 없음).
///  - 버전 비교는 (build 정수) 우선, 없으면 semver 문자열 비교.
class AppUpdateService extends ChangeNotifier {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  /// 현재 앱 버전/빌드 — pubspec.yaml 의 version 과 일치시킨다.
  /// (package_info_plus 미도입 환경이므로 상수로 관리; 릴리스마다 갱신)
  static const String currentVersion = '1.0.0';
  static const int currentBuild = 1;

  /// version.json 위치. 배포 시 --dart-define 으로 교체 가능.
  static const String _versionManifestUrl = String.fromEnvironment(
    'GISACLUB_UPDATE_MANIFEST',
    defaultValue: 'https://cdn.gisaclub.com/app/version.json',
  );

  bool _checked = false;
  bool _updateAvailable = false;
  bool _forceUpdate = false;
  String _latestVersion = '';
  int _latestBuild = 0;
  String _apkUrl = '';
  String _storeUrl = '';
  String _releaseNotes = '';

  bool get checked => _checked;
  bool get updateAvailable => _updateAvailable;
  bool get forceUpdate => _forceUpdate;
  String get latestVersion => _latestVersion;
  String get releaseNotes => _releaseNotes;

  /// 앱 시작 시 백그라운드 확인.
  Future<void> init() async {
    await checkForUpdate();
  }

  /// 🔍 최신 버전 확인. 성공 시 상태 갱신 후 notify.
  Future<void> checkForUpdate() async {
    try {
      final res = await http
          .get(Uri.parse(_versionManifestUrl))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        _checked = true;
        notifyListeners();
        return;
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      _latestVersion = (body['latest_version'] as String?)?.trim() ?? '';
      _latestBuild = _asInt(body['latest_build']);
      final minBuild = _asInt(body['min_supported_build']);
      _apkUrl = (body['apk_url'] as String?)?.trim() ?? '';
      _storeUrl = (body['store_url'] as String?)?.trim() ?? '';
      _releaseNotes = (body['release_notes'] as String?)?.trim() ?? '';
      final explicitForce = body['force'] == true;

      _updateAvailable = _isNewer(_latestVersion, _latestBuild);
      _forceUpdate =
          explicitForce || (minBuild > 0 && currentBuild < minBuild);
      _checked = true;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('업데이트 확인 실패: $e');
      _checked = true;
      notifyListeners();
    }
  }

  /// 🚀 원버튼 업데이트 실행.
  /// 우선순위: 스토어 URL(정식 배포) → APK 직접 다운로드 URL.
  /// 성공하면 true.
  Future<bool> performUpdate() async {
    final target = _storeUrl.isNotEmpty ? _storeUrl : _apkUrl;
    if (target.isEmpty) return false;
    final uri = Uri.tryParse(target);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (kDebugMode) debugPrint('업데이트 실행 실패: $e');
      return false;
    }
  }

  bool _isNewer(String version, int build) {
    if (build > 0) return build > currentBuild;
    if (version.isEmpty) return false;
    return _compareSemver(version, currentVersion) > 0;
  }

  /// semver 문자열 비교: a>b → 1, a==b → 0, a<b → -1.
  int _compareSemver(String a, String b) {
    List<int> parse(String s) => s
        .split('.')
        .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
    final pa = parse(a);
    final pb = parse(b);
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x > y ? 1 : -1;
    }
    return 0;
  }

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    if (v is double) return v.toInt();
    return 0;
  }
}
