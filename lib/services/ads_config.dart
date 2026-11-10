import 'package:flutter/foundation.dart';

/// 📣 AdMob 설정 (R60) — 관리자 앱에서 설정하고 학습앱이 원격으로 받아 쓴다.
///
/// ## 왜 원격설정에 두는가
/// 광고 단위 ID 와 노출 정책(빈도·위치)은 **운영 중에 바뀐다**. 앱을 새로 빌드해
/// 스토어 심사를 다시 받는 대신, 관리자가 콘솔에서 바꾸면 즉시 반영되게 한다.
/// (R59 의 원격설정 파이프라인을 그대로 재사용한다.)
///
/// ## SSOT 경계 — 여기에 두지 않는 것
/// 권한·구독·점수는 원격설정에 넣지 않는다(R58 데이터저장정책). 광고는
/// "기능 스위치" 범주이므로 원격설정 대상이 맞다.
///
/// ## 테스트 ID 에 대하여 (중요)
/// 구글이 공개한 **공식 테스트 단위 ID** 를 기본값으로 둔다. 실 광고 ID 를
/// 코드에 하드코딩하지 않는 이유는, 개발 중 자기 광고를 클릭하면 계정이
/// 정지되기 때문이다. 실 ID 는 관리자 콘솔에서 넣는다.
/// 다만 **테스트 ID 인 채로 출시되는 것**도 사고이므로,
/// `tool/audit/verify_release_ready.sh` 가 릴리스 빌드 전에 이를 잡는다.
@immutable
class AdsConfig {
  const AdsConfig({
    required this.enabled,
    required this.androidAppId,
    required this.bannerUnitId,
    required this.interstitialUnitId,
    required this.rewardedUnitId,
    required this.interstitialEveryNQuiz,
    required this.showBannerOnHome,
    required this.showBannerOnQuiz,
    required this.removeAdsForPremium,
  });

  /// 구글 공식 테스트 단위 ID. 출처: developers.google.com/admob/android/test-ads
  /// 이 값이 릴리스에 남아있으면 실제 수익이 발생하지 않으므로 검사로 막는다.
  static const String testAppId = 'ca-app-pub-3940256099942544~3347511713';
  static const String testBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const String testInterstitial =
      'ca-app-pub-3940256099942544/1033173712';
  static const String testRewarded = 'ca-app-pub-3940256099942544/5224354917';

  const AdsConfig.defaults()
    : enabled = false, // 기본 꺼짐 — 관리자가 켜야 광고가 나간다
      androidAppId = testAppId,
      bannerUnitId = testBanner,
      interstitialUnitId = testInterstitial,
      rewardedUnitId = testRewarded,
      interstitialEveryNQuiz = 10,
      showBannerOnHome = true,
      showBannerOnQuiz = false,
      removeAdsForPremium = true;

  /// 광고 전체 on/off. 꺼져 있으면 SDK 초기화도 하지 않는다.
  final bool enabled;
  final String androidAppId;
  final String bannerUnitId;
  final String interstitialUnitId;
  final String rewardedUnitId;

  /// 퀴즈 N문항마다 전면광고 1회. 0 이면 전면광고를 쓰지 않는다.
  /// 너무 작으면 학습을 방해하므로 UI 에서 하한을 둔다.
  final int interstitialEveryNQuiz;
  final bool showBannerOnHome;

  /// 문제 푸는 화면의 배너는 집중을 깨므로 기본 꺼짐이다.
  final bool showBannerOnQuiz;
  final bool removeAdsForPremium;

  /// 지금 설정이 구글 테스트 ID 를 쓰고 있는가.
  /// 릴리스 검사와 관리자 콘솔 경고가 이 값을 함께 쓴다(판정 로직 단일화).
  bool get usesTestIds =>
      androidAppId == testAppId ||
      bannerUnitId == testBanner ||
      interstitialUnitId == testInterstitial ||
      rewardedUnitId == testRewarded;

  factory AdsConfig.fromJson(Map<String, dynamic> j) => AdsConfig(
    enabled: j['enabled'] as bool? ?? false,
    androidAppId: (j['androidAppId'] as String?) ?? testAppId,
    bannerUnitId: (j['bannerUnitId'] as String?) ?? testBanner,
    interstitialUnitId:
        (j['interstitialUnitId'] as String?) ?? testInterstitial,
    rewardedUnitId: (j['rewardedUnitId'] as String?) ?? testRewarded,
    interstitialEveryNQuiz:
        (j['interstitialEveryNQuiz'] as num?)?.toInt() ?? 10,
    showBannerOnHome: j['showBannerOnHome'] as bool? ?? true,
    showBannerOnQuiz: j['showBannerOnQuiz'] as bool? ?? false,
    removeAdsForPremium: j['removeAdsForPremium'] as bool? ?? true,
  );

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'androidAppId': androidAppId,
    'bannerUnitId': bannerUnitId,
    'interstitialUnitId': interstitialUnitId,
    'rewardedUnitId': rewardedUnitId,
    'interstitialEveryNQuiz': interstitialEveryNQuiz,
    'showBannerOnHome': showBannerOnHome,
    'showBannerOnQuiz': showBannerOnQuiz,
    'removeAdsForPremium': removeAdsForPremium,
  };

  AdsConfig copyWith({
    bool? enabled,
    String? androidAppId,
    String? bannerUnitId,
    String? interstitialUnitId,
    String? rewardedUnitId,
    int? interstitialEveryNQuiz,
    bool? showBannerOnHome,
    bool? showBannerOnQuiz,
    bool? removeAdsForPremium,
  }) => AdsConfig(
    enabled: enabled ?? this.enabled,
    androidAppId: androidAppId ?? this.androidAppId,
    bannerUnitId: bannerUnitId ?? this.bannerUnitId,
    interstitialUnitId: interstitialUnitId ?? this.interstitialUnitId,
    rewardedUnitId: rewardedUnitId ?? this.rewardedUnitId,
    interstitialEveryNQuiz:
        interstitialEveryNQuiz ?? this.interstitialEveryNQuiz,
    showBannerOnHome: showBannerOnHome ?? this.showBannerOnHome,
    showBannerOnQuiz: showBannerOnQuiz ?? this.showBannerOnQuiz,
    removeAdsForPremium: removeAdsForPremium ?? this.removeAdsForPremium,
  );

  /// 광고 단위 ID 형식 검사. 잘못된 ID 를 배포하면 광고가 조용히 안 나온다.
  /// 앱ID 는 `~`, 단위ID 는 `/` 구분자를 쓴다(구글 규격).
  static bool isValidAppId(String v) =>
      RegExp(r'^ca-app-pub-\d{16}~\d{10}$').hasMatch(v);

  static bool isValidUnitId(String v) =>
      RegExp(r'^ca-app-pub-\d{16}/\d{10}$').hasMatch(v);
}
