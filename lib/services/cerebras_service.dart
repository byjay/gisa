import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Cerebras AI API 서비스 — OpenAI 호환 chat completions
/// API 키는 사용자가 설정에서 직접 입력 (cloud.cerebras.ai에서 발급)
class CerebrasService {
  CerebrasService._();
  static final CerebrasService instance = CerebrasService._();

  static const _keyPref = 'cerebras_api_key';
  static const _endpoint = 'https://api.cerebras.ai/v1/chat/completions';
  static const _model = 'llama-3.3-70b';

  String? _cachedKey;

  Future<String?> getApiKey() async {
    if (_cachedKey != null && _cachedKey!.isNotEmpty) return _cachedKey;
    final prefs = await SharedPreferences.getInstance();
    _cachedKey = prefs.getString(_keyPref);
    return _cachedKey;
  }

  Future<void> setApiKey(String key) async {
    _cachedKey = key.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPref, _cachedKey!);
  }

  Future<bool> hasKey() async {
    final k = await getApiKey();
    return k != null && k.isNotEmpty;
  }

  /// 전기기사 이론 질문/검증 요청
  Future<String> askTheory(String question, {String? context}) async {
    final key = await getApiKey();
    if (key == null || key.isEmpty) {
      throw CerebrasException('API 키가 설정되지 않았습니다. 설정에서 Cerebras API 키를 입력해주세요.');
    }

    final messages = [
      {
        'role': 'system',
        'content': '당신은 한국 전기기사 필기·실기 시험 전문 튜터입니다. '
            '전자기학, 전력공학, 전기기기, 회로이론 및 제어공학, 전기설비기술기준(KEC) 전 과목에 정통합니다. '
            '답변 규칙: (1) 한국어로 간결하고 정확하게, (2) 공식은 명확히 표기, '
            '(3) 시험에 나오는 핵심 포인트와 함정을 짚어주기, (4) 가능하면 암기법도 제안, '
            '(5) 확실하지 않은 내용은 솔직하게 말하기. 답변은 500자 이내로 압축.'
      },
      if (context != null && context.isNotEmpty)
        {
          'role': 'user',
          'content': '참고 자료:\n$context\n\n위 자료를 참고하되, 오류가 있으면 바로잡아 주세요.'
        },
      {'role': 'user', 'content': question},
    ];

    final res = await http
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $key',
          },
          body: jsonEncode({
            'model': _model,
            'messages': messages,
            'max_tokens': 1200,
            'temperature': 0.3,
          }),
        )
        .timeout(const Duration(seconds: 45));

    if (res.statusCode == 401) {
      throw CerebrasException('API 키가 유효하지 않습니다. 키를 다시 확인해주세요.');
    }
    if (res.statusCode == 429) {
      throw CerebrasException('요청 한도 초과입니다. 잠시 후 다시 시도해주세요.');
    }
    if (res.statusCode != 200) {
      throw CerebrasException('API 오류 (${res.statusCode}). 잠시 후 다시 시도해주세요.');
    }

    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final choices = body['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw CerebrasException('응답이 비어있습니다.');
    }
    final content =
        ((choices.first as Map)['message'] as Map?)?['content'] as String?;
    return content?.trim() ?? '';
  }
}

class CerebrasException implements Exception {
  final String message;
  CerebrasException(this.message);
  @override
  String toString() => message;
}
