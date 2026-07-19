import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// 음성 대화 상태
enum VoiceState {
  idle, // 대기
  listening, // 마이크로 듣는 중
  processing, // AI 생각 중
  speaking, // 튜터가 말하는 중
}

/// 🎙️ 음성 입출력 통합 서비스 — speech_to_text(STT) + flutter_tts(TTS).
///
/// - Android: 기기 내장 Google 음성 인식(RecognitionService) 사용
/// - Web: 브라우저 Web Speech API(SpeechRecognition) 사용 (Chrome/Edge 지원)
/// - 핸즈프리 대화 루프: 듣기 → 자동 전송 → AI 응답 낭독 → 다시 듣기
class VoiceService {
  VoiceService._();
  static final instance = VoiceService._();

  final SpeechToText _stt = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _sttReady = false;
  bool _ttsReady = false;
  bool _available = false;
  String? _koLocaleId;

  /// 현재 상태 (UI 바인딩용)
  final ValueNotifier<VoiceState> state = ValueNotifier(VoiceState.idle);

  /// 실시간 부분 인식 텍스트 (듣는 중 자막)
  final ValueNotifier<String> partialText = ValueNotifier('');

  /// 마이크 입력 레벨 0.0~1.0 (파형 애니메이션용)
  final ValueNotifier<double> soundLevel = ValueNotifier(0.0);

  /// 마지막 오류 메시지
  String lastError = '';

  bool get isAvailable => _available;
  bool get isListening => _stt.isListening;

  // ── 초기화 ─────────────────────────────────────
  Future<bool> init() async {
    if (_sttReady) return _available;
    try {
      _available = await _stt.initialize(
        onError: _onSttError,
        onStatus: _onSttStatus,
        debugLogging: false,
      );
      if (_available) {
        // 한국어 로케일 탐색 (ko_KR / ko-KR / ko)
        try {
          final locales = await _stt.locales();
          for (final l in locales) {
            final id = l.localeId.toLowerCase();
            if (id.startsWith('ko')) {
              _koLocaleId = l.localeId;
              break;
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      lastError = e.toString();
      _available = false;
    }
    _sttReady = true;
    return _available;
  }

  Future<void> _prepareTts({double rate = 0.46, double pitch = 1.0}) async {
    if (!_ttsReady) {
      await _tts.setLanguage('ko-KR');
      // 대화 모드에서는 낭독 완료를 기다려야 다음 듣기로 넘어갈 수 있음
      await _tts.awaitSpeakCompletion(true);
      _ttsReady = true;
    }
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(pitch);
  }

  void _onSttError(SpeechRecognitionError e) {
    lastError = e.errorMsg;
    if (state.value == VoiceState.listening) {
      state.value = VoiceState.idle;
    }
  }

  void _onSttStatus(String status) {
    // status: listening / notListening / done
    if (status == 'done' || status == 'notListening') {
      if (state.value == VoiceState.listening) {
        // finalResult 콜백이 처리하므로 여기서는 idle 전환만 예약
      }
    }
  }

  // ── 듣기 (STT) ─────────────────────────────────
  /// 한 번 듣고 최종 인식 텍스트를 [onFinal]로 전달.
  /// 침묵 3초 또는 최대 30초에서 자동 종료.
  Future<bool> listen({
    required void Function(String text) onFinal,
    Duration listenFor = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    final ok = await init();
    if (!ok) return false;
    if (_stt.isListening) await _stt.stop();
    await _tts.stop();

    partialText.value = '';
    state.value = VoiceState.listening;

    void handleResult(SpeechRecognitionResult r) {
      partialText.value = r.recognizedWords;
      if (r.finalResult) {
        final text = r.recognizedWords.trim();
        state.value = VoiceState.idle;
        soundLevel.value = 0;
        if (text.isNotEmpty) onFinal(text);
      }
    }

    try {
      await _stt.listen(
        onResult: handleResult,
        listenOptions: SpeechListenOptions(
          localeId: _koLocaleId,
          listenFor: listenFor,
          pauseFor: pauseFor,
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
        ),
        onSoundLevelChange: (level) {
          // level: dB 스케일(-2~10 근사) → 0~1 정규화
          final v = ((level + 2) / 12).clamp(0.0, 1.0);
          soundLevel.value = v;
        },
      );
      return true;
    } catch (e) {
      lastError = e.toString();
      state.value = VoiceState.idle;
      return false;
    }
  }

  /// 듣기 중지 (현재까지 인식분은 finalResult로 전달됨)
  Future<void> stopListening() async {
    if (_stt.isListening) await _stt.stop();
    if (state.value == VoiceState.listening) state.value = VoiceState.idle;
    soundLevel.value = 0;
  }

  /// 듣기 취소 (인식분 폐기)
  Future<void> cancelListening() async {
    if (_stt.isListening) await _stt.cancel();
    partialText.value = '';
    state.value = VoiceState.idle;
    soundLevel.value = 0;
  }

  // ── 말하기 (TTS) ───────────────────────────────
  /// 텍스트 낭독 — 완료까지 대기. [onDone] 후 핸즈프리 루프에서 재청취 가능.
  Future<void> speak(
    String text, {
    double rate = 0.46,
    double pitch = 1.0,
  }) async {
    final clean = _cleanForSpeech(text);
    if (clean.isEmpty) return;
    await _prepareTts(rate: rate, pitch: pitch);
    await _tts.stop();
    state.value = VoiceState.speaking;
    try {
      await _tts.speak(clean); // awaitSpeakCompletion(true) → 완료까지 대기
    } finally {
      if (state.value == VoiceState.speaking) state.value = VoiceState.idle;
    }
  }

  Future<void> stopSpeaking() async {
    await _tts.stop();
    if (state.value == VoiceState.speaking) state.value = VoiceState.idle;
  }

  /// 모든 음성 활동 정지
  Future<void> stopAll() async {
    await cancelListening();
    await stopSpeaking();
    state.value = VoiceState.idle;
  }

  static String _cleanForSpeech(String text) {
    var s = text
        // 마크다운·수식 기호 제거
        .replaceAll(RegExp(r'[*#`_>【】\[\]|]'), '')
        .replaceAll(RegExp(r'\$+'), '')
        // 이모지 대부분 제거 (BMP 밖 서러게이트)
        .replaceAll(RegExp(r'[\u{1F000}-\u{1FFFF}]', unicode: true), '')
        .replaceAll(RegExp(r'[\u2600-\u27BF\uFE0F]'), '')
        // 단위·기호를 읽기 좋게
        .replaceAll('Ω', '옴')
        .replaceAll('μ', '마이크로')
        .replaceAll('²', '제곱')
        .replaceAll('³', '세제곱')
        .replaceAll('√', '루트')
        .replaceAll('≒', '약 ')
        .replaceAll('→', ', ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    // 너무 긴 답변은 앞부분 위주로 (약 600자)
    if (s.length > 620) {
      final cut = s.substring(0, 600);
      final lastDot = cut.lastIndexOf(RegExp(r'[.!?다요]'));
      s = lastDot > 300 ? cut.substring(0, lastDot + 1) : cut;
    }
    return s;
  }
}
