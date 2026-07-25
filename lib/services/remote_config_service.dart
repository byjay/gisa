import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';

/// 📡 원격 앱 설정(Remote Config) 수신기 — 학습앱 측.
///
/// [무엇을 하나 — R59]
/// 관리자(운영자)가 관리자 콘솔에서 세팅해 서버에 배포한 값을,
/// 학습앱이 시작할 때 `/v1/app/config`에서 pull 하여 **자동 반영**한다.
/// 관리자가 "배포" 버튼만 누르면, 다음 실행 때(또는 refresh 시) 학습앱이
/// 관리자가 설정한 대로 세팅된다. (배민에서 사장님이 메뉴 바꾸면 고객앱에 반영되는 것과 동일)
///
/// [SSOT 경계 — 매우 중요]
///  - 여기서 받는 값은 **표현/기능 스위치**뿐이다: 기능 플래그, 공지, 최소버전, 활성트랙.
///  - 사용자별 **권한/구독/점수**는 여기서 판정하지 않는다(그건 서버의 entitlement/progress API).
///  - 서버가 미설정(hasApi==false)이면 안전 기본값(내장)을 쓴다 → 오프라인에서도 앱은 정상 동작.
///
/// [캐시 정책]
///  마지막으로 받은 설정 JSON을 로컬(shared_preferences)에 저장해,
///  오프라인 시작 시에도 직전 관리자 설정을 유지한다(표현값이므로 캐시 허용).
class RemoteConfigService extends ChangeNotifier {
  RemoteConfigService._();
  static final RemoteConfigService instance = RemoteConfigService._();

  static const _kCacheKey = 'remote_app_config_v1';

  RemoteAppConfig _config = RemoteAppConfig.defaults();
  bool _loaded = false;

  /// 현재 적용 중인 설정(항상 유효값 — 미로드/오프라인 시 기본값).
  RemoteAppConfig get config => _config;

  /// 최소 1회 이상 로드(캐시 or 서버)했는지.
  bool get isLoaded => _loaded;

  String get _base => AppConfig.apiBaseUrl;

  /// 앱 시작 시 호출: 캐시 먼저 반영 → 온라인이면 서버에서 갱신.
  Future<void> init() async {
    await _loadFromCache();
    _loaded = true;
    notifyListeners();
    // 서버가 설정돼 있으면 백그라운드로 최신값 pull(실패해도 캐시 유지).
    if (AppConfig.hasApi) {
      unawaited(refresh());
    }
  }

  /// 서버에서 최신 설정을 가져와 반영 + 캐시. 실패 시 false(기존값 유지).
  Future<bool> refresh() async {
    if (!AppConfig.hasApi) return false;
    try {
      final res = await http
          .get(Uri.parse('$_base/v1/app/config'))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return false;
      final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final incoming = RemoteAppConfig.fromJson(json);
      // 버전이 같거나 낮으면(변경 없음) 굳이 알림/저장 안 함.
      final changed = incoming.version != _config.version;
      _config = incoming;
      await _saveToCache(json);
      if (changed) notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('RemoteConfig refresh 실패: $e');
      return false;
    }
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCacheKey);
      if (raw != null && raw.isNotEmpty) {
        _config = RemoteAppConfig.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('RemoteConfig 캐시 로드 실패: $e');
    }
  }

  Future<void> _saveToCache(Map<String, dynamic> json) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCacheKey, jsonEncode(json));
    } catch (_) {}
  }
}

/// 원격 설정 스냅샷(불변). 서버 `defaultConfig()`와 스키마 1:1 대응.
@immutable
class RemoteAppConfig {
  const RemoteAppConfig({
    required this.version,
    required this.updatedAt,
    required this.features,
    required this.notice,
    required this.update,
    required this.activeTracks,
  });

  final int version;
  final int updatedAt;
  final RemoteFeatures features;
  final RemoteNotice notice;
  final RemoteUpdateGate update;
  final List<String> activeTracks;

  factory RemoteAppConfig.defaults() => const RemoteAppConfig(
        version: 0,
        updatedAt: 0,
        features: RemoteFeatures.defaults(),
        notice: RemoteNotice.empty(),
        update: RemoteUpdateGate.none(),
        activeTracks: <String>[],
      );

  factory RemoteAppConfig.fromJson(Map<String, dynamic> j) => RemoteAppConfig(
        version: (j['version'] as num?)?.toInt() ?? 0,
        updatedAt: (j['updatedAt'] as num?)?.toInt() ?? 0,
        features: RemoteFeatures.fromJson(
          (j['features'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        notice: RemoteNotice.fromJson(
          (j['notice'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        update: RemoteUpdateGate.fromJson(
          (j['update'] as Map?)?.cast<String, dynamic>() ?? const {},
        ),
        activeTracks: ((j['activeTracks'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'version': version,
        'updatedAt': updatedAt,
        'features': features.toJson(),
        'notice': notice.toJson(),
        'update': update.toJson(),
        'activeTracks': activeTracks,
      };
}

@immutable
class RemoteFeatures {
  const RemoteFeatures({
    required this.aiTutorEnabled,
    required this.handwritingEnabled,
    required this.freeQuestionPercent,
    required this.promoBannerEnabled,
  });

  const RemoteFeatures.defaults()
      : aiTutorEnabled = true,
        handwritingEnabled = true,
        freeQuestionPercent = 10,
        promoBannerEnabled = false;

  final bool aiTutorEnabled;
  final bool handwritingEnabled;
  final int freeQuestionPercent;
  final bool promoBannerEnabled;

  factory RemoteFeatures.fromJson(Map<String, dynamic> j) => RemoteFeatures(
        aiTutorEnabled: j['aiTutorEnabled'] as bool? ?? true,
        handwritingEnabled: j['handwritingEnabled'] as bool? ?? true,
        freeQuestionPercent: (j['freeQuestionPercent'] as num?)?.toInt() ?? 10,
        promoBannerEnabled: j['promoBannerEnabled'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'aiTutorEnabled': aiTutorEnabled,
        'handwritingEnabled': handwritingEnabled,
        'freeQuestionPercent': freeQuestionPercent,
        'promoBannerEnabled': promoBannerEnabled,
      };

  RemoteFeatures copyWith({
    bool? aiTutorEnabled,
    bool? handwritingEnabled,
    int? freeQuestionPercent,
    bool? promoBannerEnabled,
  }) =>
      RemoteFeatures(
        aiTutorEnabled: aiTutorEnabled ?? this.aiTutorEnabled,
        handwritingEnabled: handwritingEnabled ?? this.handwritingEnabled,
        freeQuestionPercent: freeQuestionPercent ?? this.freeQuestionPercent,
        promoBannerEnabled: promoBannerEnabled ?? this.promoBannerEnabled,
      );
}

@immutable
class RemoteNotice {
  const RemoteNotice({
    required this.text,
    required this.level,
    required this.linkUrl,
  });

  const RemoteNotice.empty()
      : text = '',
        level = 'info',
        linkUrl = '';

  final String text;
  final String level; // info | warn | urgent
  final String linkUrl;

  bool get isVisible => text.trim().isNotEmpty;

  factory RemoteNotice.fromJson(Map<String, dynamic> j) => RemoteNotice(
        text: (j['text'] as String?) ?? '',
        level: (j['level'] as String?) ?? 'info',
        linkUrl: (j['linkUrl'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {
        'text': text,
        'level': level,
        'linkUrl': linkUrl,
      };

  RemoteNotice copyWith({String? text, String? level, String? linkUrl}) =>
      RemoteNotice(
        text: text ?? this.text,
        level: level ?? this.level,
        linkUrl: linkUrl ?? this.linkUrl,
      );
}

@immutable
class RemoteUpdateGate {
  const RemoteUpdateGate({
    required this.minSupportedBuild,
    required this.latestBuild,
    required this.latestVersion,
    required this.apkUrl,
    required this.forced,
  });

  const RemoteUpdateGate.none()
      : minSupportedBuild = 0,
        latestBuild = 0,
        latestVersion = '',
        apkUrl = '',
        forced = false;

  final int minSupportedBuild;
  final int latestBuild;
  final String latestVersion;
  final String apkUrl;
  final bool forced;

  /// 현재 빌드가 강제 업데이트 대상인지.
  bool requiresUpdate(int currentBuild) =>
      forced && minSupportedBuild > 0 && currentBuild < minSupportedBuild;

  factory RemoteUpdateGate.fromJson(Map<String, dynamic> j) => RemoteUpdateGate(
        minSupportedBuild: (j['minSupportedBuild'] as num?)?.toInt() ?? 0,
        latestBuild: (j['latestBuild'] as num?)?.toInt() ?? 0,
        latestVersion: (j['latestVersion'] as String?) ?? '',
        apkUrl: (j['apkUrl'] as String?) ?? '',
        forced: j['forced'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'minSupportedBuild': minSupportedBuild,
        'latestBuild': latestBuild,
        'latestVersion': latestVersion,
        'apkUrl': apkUrl,
        'forced': forced,
      };
}
