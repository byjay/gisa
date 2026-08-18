import 'package:flutter_test/flutter_test.dart';
import 'package:cert_study_tracker/services/ads_config.dart';
import 'package:cert_study_tracker/services/app_config.dart';
import 'package:cert_study_tracker/services/remote_config_service.dart';

/// 📣 광고 설정 회귀 테스트 (R60).
///
/// 광고는 "조용히 실패"하는 기능이다. 잘못된 ID 를 배포해도 예외가 나지 않고
/// 광고만 안 나오므로 아무도 눈치채지 못한다. 그래서 형식 판정과 기본값을
/// 테스트로 못박는다.
void main() {
  group('AdsConfig 기본값', () {
    test('기본은 꺼짐이다 — 관리자가 켜야 광고가 나간다', () {
      const c = AdsConfig.defaults();
      expect(c.enabled, isFalse);
    });

    test('기본 ID 는 구글 공식 테스트 ID 이며 usesTestIds 가 이를 감지한다', () {
      const c = AdsConfig.defaults();
      expect(c.androidAppId, AdsConfig.testAppId);
      expect(c.usesTestIds, isTrue,
          reason: '테스트 ID 를 감지하지 못하면 그대로 출시돼 수익이 0원이 된다');
    });

    test('문제풀이 화면 배너는 기본 꺼짐 — 집중을 깨면 이탈한다', () {
      const c = AdsConfig.defaults();
      expect(c.showBannerOnQuiz, isFalse);
    });
  });

  group('ID 형식 판정', () {
    test('구글 규격을 만족하는 ID 만 통과한다', () {
      expect(AdsConfig.isValidAppId('ca-app-pub-1234567890123456~9876543210'),
          isTrue);
      expect(AdsConfig.isValidUnitId('ca-app-pub-1234567890123456/9876543210'),
          isTrue);
    });

    test('구분자가 바뀌면 거부한다 (앱ID 는 ~, 단위ID 는 /)', () {
      // 실무에서 가장 흔한 실수다. 콘솔에서 복사하다 서로 뒤바꿔 넣는다.
      expect(AdsConfig.isValidAppId('ca-app-pub-1234567890123456/9876543210'),
          isFalse);
      expect(AdsConfig.isValidUnitId('ca-app-pub-1234567890123456~9876543210'),
          isFalse);
    });

    test('빈 값·자릿수 부족·접두사 오류를 거부한다', () {
      expect(AdsConfig.isValidUnitId(''), isFalse);
      expect(AdsConfig.isValidUnitId('ca-app-pub-123/456'), isFalse);
      expect(AdsConfig.isValidUnitId('pub-1234567890123456/9876543210'), isFalse);
      // 앞뒤 공백이 붙은 값도 거부해야 한다(붙여넣기 사고).
      expect(
          AdsConfig.isValidUnitId(' ca-app-pub-1234567890123456/9876543210'),
          isFalse);
    });

    test('실 ID 로 바꾸면 usesTestIds 가 false 가 된다', () {
      const real = AdsConfig(
        enabled: true,
        androidAppId: 'ca-app-pub-1234567890123456~9876543210',
        bannerUnitId: 'ca-app-pub-1234567890123456/1111111111',
        interstitialUnitId: 'ca-app-pub-1234567890123456/2222222222',
        rewardedUnitId: 'ca-app-pub-1234567890123456/3333333333',
        interstitialEveryNQuiz: 10,
        showBannerOnHome: true,
        showBannerOnQuiz: false,
        removeAdsForPremium: true,
      );
      expect(real.usesTestIds, isFalse);
    });

    test('하나라도 테스트 ID 가 섞이면 감지한다 (부분 교체 사고)', () {
      // 앱ID 만 실 ID 로 바꾸고 단위ID 를 안 바꾸는 실수가 실제로 잦다.
      const partial = AdsConfig(
        enabled: true,
        androidAppId: 'ca-app-pub-1234567890123456~9876543210',
        bannerUnitId: AdsConfig.testBanner, // 안 바꿈
        interstitialUnitId: 'ca-app-pub-1234567890123456/2222222222',
        rewardedUnitId: 'ca-app-pub-1234567890123456/3333333333',
        interstitialEveryNQuiz: 10,
        showBannerOnHome: true,
        showBannerOnQuiz: false,
        removeAdsForPremium: true,
      );
      expect(partial.usesTestIds, isTrue);
    });
  });

  group('원격설정 왕복 (관리자가 배포한 값이 학습앱에 그대로 도착하는가)', () {
    test('toJson → fromJson 왕복에서 9개 필드가 모두 보존된다', () {
      const c = AdsConfig(
        enabled: true,
        androidAppId: 'ca-app-pub-1234567890123456~9876543210',
        bannerUnitId: 'ca-app-pub-1234567890123456/1111111111',
        interstitialUnitId: 'ca-app-pub-1234567890123456/2222222222',
        rewardedUnitId: 'ca-app-pub-1234567890123456/3333333333',
        interstitialEveryNQuiz: 7,
        showBannerOnHome: false,
        showBannerOnQuiz: true,
        removeAdsForPremium: false,
      );
      final back = AdsConfig.fromJson(c.toJson());
      expect(back.enabled, c.enabled);
      expect(back.androidAppId, c.androidAppId);
      expect(back.bannerUnitId, c.bannerUnitId);
      expect(back.interstitialUnitId, c.interstitialUnitId);
      expect(back.rewardedUnitId, c.rewardedUnitId);
      expect(back.interstitialEveryNQuiz, c.interstitialEveryNQuiz);
      expect(back.showBannerOnHome, c.showBannerOnHome);
      expect(back.showBannerOnQuiz, c.showBannerOnQuiz);
      expect(back.removeAdsForPremium, c.removeAdsForPremium);
    });

    test('서버가 ads 키를 안 보내도 안전한 기본값으로 동작한다', () {
      // 구버전 서버 응답과 섞여도 크래시하지 않아야 한다.
      final c = AdsConfig.fromJson(const {});
      expect(c.enabled, isFalse);
      expect(c.androidAppId, AdsConfig.testAppId);
    });

    test('RemoteAppConfig 가 ads 를 왕복 보존한다', () {
      final cfg = RemoteAppConfig.fromJson({
        'version': 3,
        'ads': {'enabled': true, 'interstitialEveryNQuiz': 12},
      });
      expect(cfg.ads.enabled, isTrue);
      expect(cfg.ads.interstitialEveryNQuiz, 12);
      // toJson 에 ads 가 빠지면 관리자가 배포해도 값이 사라진다.
      expect(cfg.toJson()['ads'], isA<Map>());
      expect((cfg.toJson()['ads'] as Map)['enabled'], isTrue);
    });
  });

  group('관리자 전용 앱 분리', () {
    test('플래그를 주입하지 않은 빌드(=사용자 앱)는 isAdminApp 이 false 다', () {
      // 이 테스트는 dart-define 없이 실행되므로 사용자 앱과 동일한 조건이다.
      // 여기가 true 로 바뀌면 학습자에게 운영 메뉴가 노출된다.
      expect(AppConfig.isAdminApp, isFalse);
    });
  });
}
