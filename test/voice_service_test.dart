import 'package:cert_study_tracker/services/voice_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// VoiceService는 STT/TTS 플랫폼 채널에 의존하므로 실제 음성 I/O는
/// 통합 테스트 영역이다. 여기서는 플랫폼 없이도 검증 가능한
/// (1) 상태 머신 초기 계약, (2) VoiceState enum 불변식을 지킨다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('싱글턴 인스턴스는 항상 동일 객체다', () {
    expect(identical(VoiceService.instance, VoiceService.instance), isTrue);
  });

  test('VoiceState는 idle/listening/processing/speaking 4단계를 갖는다', () {
    expect(VoiceState.values, hasLength(4));
    expect(VoiceState.values, contains(VoiceState.idle));
    expect(VoiceState.values, contains(VoiceState.listening));
    expect(VoiceState.values, contains(VoiceState.processing));
    expect(VoiceState.values, contains(VoiceState.speaking));
  });

  test('초기 상태 노출값은 안전한 기본값(idle/빈문자/무음)이다', () {
    final v = VoiceService.instance;
    expect(v.state.value, VoiceState.idle);
    expect(v.partialText.value, isEmpty);
    expect(v.soundLevel.value, 0.0);
    expect(v.lastError, isEmpty);
  });

  test('init 전에는 가용성이 false이고 듣고 있지 않다', () {
    final v = VoiceService.instance;
    // 플랫폼 미초기화 상태 — 안전한 기본값을 보장해야 UI가 크래시하지 않는다
    expect(v.isAvailable, isFalse);
    expect(v.isListening, isFalse);
  });
}
