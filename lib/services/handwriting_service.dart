import 'package:flutter/foundation.dart';
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart'
    as mlkit;

/// ✍️→가 손글씨 인식 서비스 (패드/태블릿 학습용)
///
/// - Android: Google ML Kit Digital Ink Recognition (한국어 'ko' 모델)
///   최초 1회 모델 다운로드(약 20MB, Wi-Fi 권장) 후 완전 오프라인 인식.
/// - Web(미리보기): 플랫폼 채널 미지원 → 안내 메시지 폴백.
class HandwritingResult {
  final bool ok;
  final List<String> candidates;
  final String? error;
  const HandwritingResult({
    required this.ok,
    this.candidates = const [],
    this.error,
  });
}

class HandwritingService {
  HandwritingService._();
  static final HandwritingService instance = HandwritingService._();

  static const _lang = 'ko';
  mlkit.DigitalInkRecognizer? _recognizer;
  final _modelManager = kIsWeb
      ? null
      : mlkit.DigitalInkRecognizerModelManager();
  bool _modelReady = false;

  bool get supported => !kIsWeb;

  /// 한국어 잉크 모델 준비 (미설치 시 다운로드).
  Future<bool> ensureModel({void Function(String)? onStatus}) async {
    if (kIsWeb || _modelManager == null) return false;
    if (_modelReady) return true;
    try {
      final downloaded = await _modelManager.isModelDownloaded(_lang);
      if (!downloaded) {
        onStatus?.call('한국어 필기 모델 다운로드 중… (최초 1회)');
        final ok = await _modelManager.downloadModel(_lang);
        if (!ok) {
          onStatus?.call('모델 다운로드 실패 — 네트워크를 확인하세요');
          return false;
        }
      }
      _modelReady = true;
      return true;
    } catch (e) {
      onStatus?.call('모델 준비 실패: $e');
      return false;
    }
  }

  /// 스트로크(점 좌표+타임스탬프)를 텍스트 후보로 인식.
  /// [strokes]는 각 획의 (x, y, t[ms]) 목록.
  Future<HandwritingResult> recognize(
    List<List<({double x, double y, int t})>> strokes, {
    void Function(String)? onStatus,
  }) async {
    if (kIsWeb) {
      return const HandwritingResult(
        ok: false,
        error:
            '웹 미리보기에서는 필기 인식이 지원되지 않습니다.\n'
            'Android 앱(APK)에서 한국어 손글씨 인식이 동작합니다.',
      );
    }
    if (strokes.isEmpty) {
      return const HandwritingResult(ok: false, error: '먼저 글씨를 써 주세요.');
    }
    final ready = await ensureModel(onStatus: onStatus);
    if (!ready) {
      return const HandwritingResult(
        ok: false,
        error: '한국어 필기 모델을 준비하지 못했습니다. 네트워크 연결 후 다시 시도하세요.',
      );
    }
    try {
      _recognizer ??= mlkit.DigitalInkRecognizer(languageCode: _lang);
      final ink = mlkit.Ink()
        ..strokes = [
          for (final s in strokes)
            mlkit.Stroke()
              ..points = [
                for (final p in s) mlkit.StrokePoint(x: p.x, y: p.y, t: p.t),
              ],
        ];
      final candidates = await _recognizer!.recognize(ink);
      if (candidates.isEmpty) {
        return const HandwritingResult(
          ok: false,
          error: '인식된 글자가 없습니다. 조금 더 크게 써 보세요.',
        );
      }
      return HandwritingResult(
        ok: true,
        candidates: candidates.take(5).map((c) => c.text).toList(),
      );
    } catch (e) {
      return HandwritingResult(ok: false, error: '인식 오류: $e');
    }
  }

  Future<void> dispose() async {
    await _recognizer?.close();
    _recognizer = null;
  }
}
