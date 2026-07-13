import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'study_data.dart';

/// 대화 메시지 (튜터 채팅용)
class ChatTurn {
  final String role; // 'user' | 'assistant'
  final String content;
  ChatTurn(this.role, this.content);
  Map<String, String> toJson() => {'role': role, 'content': content};
}

/// Kimi K2 (Moonshot AI) API 서비스 — OpenAI 호환 chat completions
///
/// 영상 3편(w7CLlkBtFbU / teGbJTJj6JM / biZxdqm3d5I) 및 공식 문서
/// (platform.kimi.ai)에서 확인한 연동 스펙:
///   - Base URL : https://api.moonshot.ai/v1
///   - Endpoint : POST /chat/completions
///   - Auth     : Authorization Bearer + MOONSHOT_API_KEY
///   - Model    : kimi-k2.6 (기본), 설정에서 교체 가능
///   - Format   : OpenAI chat completions (messages / temperature / max_tokens)
/// API 키는 사용자가 설정에서 직접 입력하며 기기에만 저장됩니다.
class KimiService {
  KimiService._();
  static final KimiService instance = KimiService._();

  static const _keyPref = 'kimi_api_key';
  static const _modelPref = 'kimi_model';
  static const _endpoint = 'https://api.moonshot.ai/v1/chat/completions';
  static const defaultModel = 'kimi-k2.6';

  String? _cachedKey;
  String? _cachedModel;

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

  Future<String> getModel() async {
    if (_cachedModel != null && _cachedModel!.isNotEmpty) return _cachedModel!;
    final prefs = await SharedPreferences.getInstance();
    _cachedModel = prefs.getString(_modelPref) ?? defaultModel;
    return _cachedModel!;
  }

  Future<void> setModel(String model) async {
    _cachedModel = model.trim().isEmpty ? defaultModel : model.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modelPref, _cachedModel!);
  }

  Future<bool> hasKey() async {
    final k = await getApiKey();
    return k != null && k.isNotEmpty;
  }

  /// 튜터 시스템 프롬프트 — 현재 종목에 맞춘 최신정보·학습가이드 역할
  String _systemPrompt() {
    final t = StudyData.instance.track;
    return '당신은 한국 "${t.name}" 자격증 시험 전문 AI 튜터입니다. '
        '담당 과목: ${t.subjects.join(", ")}. '
        '역할: (1) 학습자에게 항상 최신 시험 정보와 정확한 이론을 안내, '
        '(2) 개념을 왕초보도 이해하도록 쉬운 비유로 설명, '
        '(3) 시험 출제 포인트·함정·고득점 전략을 짚어주기, '
        '(4) 공식은 명확히 표기하고 암기법을 제안, '
        '(5) 과목 공부 순서·학습 계획 같은 학습가이드 질문에도 친절히 답변. '
        '답변 규칙: 한국어로, 마크다운 없이 읽기 쉽게, 핵심 위주 700자 이내. '
        '확실하지 않으면 솔직히 밝히고 최신 공식 정보 확인을 권하세요.';
  }

  /// 단발성 질문 (이론 검색 AI 검증용)
  Future<String> askTheory(String question, {String? context}) async {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': _systemPrompt()},
      if (context != null && context.isNotEmpty)
        {
          'role': 'user',
          'content': '참고 자료:\n$context\n\n위 자료를 참고하되 오류가 있으면 바로잡아 주세요.'
        },
      {'role': 'user', 'content': question},
    ];
    return _complete(messages, maxTokens: 1200, temperature: 0.3);
  }

  /// 대화형 튜터 (히스토리 포함)
  Future<String> chat(List<ChatTurn> history) async {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': _systemPrompt()},
      ...history.map((t) => t.toJson()),
    ];
    return _complete(messages, maxTokens: 1400, temperature: 0.6);
  }

  Future<String> _complete(
    List<Map<String, String>> messages, {
    required int maxTokens,
    required double temperature,
  }) async {
    final key = await getApiKey();
    if (key == null || key.isEmpty) {
      throw KimiException('API 키가 설정되지 않았습니다. 설정에서 Kimi(Moonshot) API 키를 입력해주세요.');
    }
    final model = await getModel();

    late final http.Response res;
    try {
      res = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $key',
            },
            body: jsonEncode({
              'model': model,
              'messages': messages,
              'max_tokens': maxTokens,
              'temperature': temperature,
            }),
          )
          .timeout(const Duration(seconds: 60));
    } catch (e) {
      if (kDebugMode) debugPrint('Kimi 요청 실패: $e');
      throw KimiException('네트워크 오류입니다. 연결 상태를 확인 후 다시 시도해주세요.');
    }

    switch (res.statusCode) {
      case 200:
        break;
      case 401:
        throw KimiException('API 키가 유효하지 않습니다. 키를 다시 확인해주세요.');
      case 404:
        throw KimiException('모델명이 올바르지 않습니다. 설정에서 모델(kimi-k2.6)을 확인해주세요.');
      case 429:
        throw KimiException('요청 한도 초과입니다. 잠시 후 다시 시도해주세요.');
      case 529:
        throw KimiException('서버가 혼잡합니다. 잠시 후 다시 시도해주세요.');
      default:
        throw KimiException('API 오류 (${res.statusCode}). 잠시 후 다시 시도해주세요.');
    }

    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final choices = body['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw KimiException('응답이 비어있습니다.');
    }
    final content =
        ((choices.first as Map)['message'] as Map?)?['content'] as String?;
    final text = content?.trim() ?? '';
    if (text.isEmpty) throw KimiException('응답이 비어있습니다.');
    return text;
  }
}

class KimiException implements Exception {
  final String message;
  KimiException(this.message);
  @override
  String toString() => message;
}
