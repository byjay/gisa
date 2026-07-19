import 'package:flutter_tts/flutter_tts.dart';

/// 튜터 설명을 Android와 Web에서 읽어 주는 공용 스피커.
class TutorSpeechService {
  TutorSpeechService._();
  static final instance = TutorSpeechService._();

  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> _prepare({double rate = 0.46, double pitch = 1.0}) async {
    if (!_ready) {
      await _tts.setLanguage('ko-KR');
      await _tts.awaitSpeakCompletion(false);
      _ready = true;
    }
    await _tts.setPitch(pitch);
    await _tts.setSpeechRate(rate);
  }

  Future<void> speak(String text, {double rate = 0.46, double pitch = 1.0}) async {
    final clean = text
        .replaceAll(RegExp(r'[*#`_>【】]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (clean.isEmpty) return;
    await _prepare(rate: rate);
    await _tts.stop();
    await _tts.speak(clean);
  }

  Future<void> stop() => _tts.stop();
}
