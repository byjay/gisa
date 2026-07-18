import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'study_data.dart';

/// 튜터 응답 — 생각(추론) 과정 + 최종 답변
class TutorReply {
  final String thinking; // 모델의 사고 과정 (reasoning)
  final String answer; // 최종 답변
  TutorReply({required this.thinking, required this.answer});
}

/// 대화 턴 (튜터 채팅용)
class TutorTurn {
  final String role; // 'user' | 'assistant'
  final String content;
  TutorTurn(this.role, this.content);
  Map<String, String> toJson() => {'role': role, 'content': content};
}

/// Cerebras Inference API 서비스 — OpenAI 호환 chat completions
///
/// 모델: gpt-oss-120b (reasoning 지원 — 답변 전에 '생각'을 먼저 수행)
///   - reasoning_effort 파라미터로 사고 깊이 조절 (low/medium/high)
///   - 응답 message.reasoning 필드에 사고 과정이 담겨 옴
/// 보안 원칙: 앱에는 운영 키를 내장하지 않는다.
/// 사용자가 직접 발급한 키(BYOK)만 기기에 저장해 사용한다.
class CerebrasService {
  CerebrasService._();
  static final CerebrasService instance = CerebrasService._();

  static const _keyPref = 'cerebras_api_key';
  static const _endpoint = 'https://api.cerebras.ai/v1/chat/completions';
  static const _model = 'gpt-oss-120b';

  /// 🧪 AI 튜터 테스트 기간 — 이 기간 동안에만 API 키 설정과 AI 기능을 사용할 수 있다.
  /// 기간이 지나면 키 설정 UI가 잠기고, 저장된 키가 있어도 호출이 차단된다.
  static final DateTime testPeriodEnd = DateTime(2026, 12, 31, 23, 59, 59);

  /// 현재가 테스트 기간인지 여부
  static bool get isTestPeriod => DateTime.now().isBefore(testPeriodEnd);

  /// 테스트 종료일 표시용 문자열 (예: 2026.12.31)
  static String get testPeriodEndLabel =>
      '${testPeriodEnd.year}.${testPeriodEnd.month.toString().padLeft(2, '0')}.${testPeriodEnd.day.toString().padLeft(2, '0')}';

  String? _cachedKey;

  Future<String> getApiKey() async {
    if (_cachedKey != null) return _cachedKey!;
    final prefs = await SharedPreferences.getInstance();
    _cachedKey = (prefs.getString(_keyPref) ?? '').trim();
    return _cachedKey!;
  }

  Future<void> setApiKey(String key) async {
    final k = key.trim();
    _cachedKey = k;
    final prefs = await SharedPreferences.getInstance();
    if (k.isEmpty) {
      await prefs.remove(_keyPref);
    } else {
      await prefs.setString(_keyPref, k);
    }
  }

  Future<bool> hasKey() async => (await getApiKey()).isNotEmpty;

  /// AI 기능 사용 가능 여부 = 테스트 기간 + 키 설정 완료
  Future<bool> get aiAvailable async => isTestPeriod && await hasKey();

  /// 튜터 시스템 프롬프트 — 현재 종목 맞춤 + 사고 지시 + 페르소나 스타일
  String _systemPrompt({String? personaStyle}) {
    final t = StudyData.instance.track;
    final style = (personaStyle == null || personaStyle.isEmpty)
        ? '왕초보도 이해하는 쉬운 비유로 설명하세요. '
        : '캐릭터 지시(최우선 준수): $personaStyle ';
    return '당신 이름은 "볼트쌤"이며, 한국 "${t.name}" 자격증 시험 전문 과외 튜터입니다. '
        '담당 과목: ${t.subjects.join(", ")}. '
        '$style'
        '답변하기 전에 반드시 단계별로 깊이 생각하세요: '
        '(a) 질문의 핵심 파악 → (b) 관련 이론·공식 점검 → (c) 함정·예외 검토 → (d) 답 구성. '
        '역할: (1) 최신 시험 정보와 정확한 이론 안내, '
        '(2) 출제 포인트·함정·고득점 전략 짚기, '
        '(3) 공식은 명확히 표기하고 암기법(두문자·스토리·표 정리)을 제안, '
        '(4) 학습 계획 질문에도 구체적으로 답변. '
        '답변 규칙: 한국어, LaTeX 수식(\\[..\\]) 금지 — 일반 텍스트 수식 사용(예: Qc = P(tanθ1 - tanθ2)), '
        '마크다운 헤더(#) 대신 【제목】 형식, 핵심 위주. '
        '확실하지 않으면 솔직히 밝히세요.';
  }

  /// 대화형 튜터 — 생각(추론) + 답변을 함께 반환
  Future<TutorReply> chat(
    List<TutorTurn> history, {
    String effort = 'medium',
    String? personaStyle,
  }) async {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': _systemPrompt(personaStyle: personaStyle)},
      ...history.map((t) => t.toJson()),
    ];
    return _complete(
      messages,
      maxTokens: 2200,
      temperature: 0.5,
      effort: effort,
    );
  }

  /// 단발성 질문 (이론 검증용) — 답변 텍스트만 반환
  Future<String> askTheory(String question, {String? context}) async {
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': _systemPrompt()},
      if (context != null && context.isNotEmpty)
        {
          'role': 'user',
          'content': '참고 자료:\n$context\n\n위 자료를 참고하되, 오류가 있으면 바로잡아 주세요.',
        },
      {'role': 'user', 'content': question},
    ];
    final r = await _complete(
      messages,
      maxTokens: 1600,
      temperature: 0.3,
      effort: 'medium',
    );
    return r.answer;
  }

  Future<TutorReply> _complete(
    List<Map<String, String>> messages, {
    required int maxTokens,
    required double temperature,
    required String effort,
  }) async {
    if (!isTestPeriod) {
      throw CerebrasException(
        'AI 튜터 테스트 기간이 종료되었습니다. 로컬 강의·공식·암기법 검색을 이용해주세요.',
      );
    }
    final key = await getApiKey();
    if (key.isEmpty) {
      throw CerebrasException(
        'AI API 키가 설정되지 않았습니다. 설정 화면의 "AI 튜터 (테스트)" 카드에서 키를 등록해주세요.',
      );
    }

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
              'model': _model,
              'messages': messages,
              'max_tokens': maxTokens,
              'temperature': temperature,
              'reasoning_effort': effort, // 사고 깊이 (low/medium/high)
            }),
          )
          .timeout(const Duration(seconds: 90));
    } catch (e) {
      if (kDebugMode) debugPrint('Cerebras 요청 실패: $e');
      throw CerebrasException('네트워크 오류입니다. 연결 상태를 확인 후 다시 시도해주세요.');
    }

    switch (res.statusCode) {
      case 200:
        break;
      case 401:
        throw CerebrasException('API 키가 유효하지 않습니다. 설정에서 키를 확인해주세요.');
      case 429:
        throw CerebrasException('요청 한도 초과입니다. 잠시 후 다시 시도해주세요.');
      default:
        throw CerebrasException('API 오류 (${res.statusCode}). 잠시 후 다시 시도해주세요.');
    }

    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final choices = body['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw CerebrasException('응답이 비어있습니다.');
    }
    final msg = (choices.first as Map)['message'] as Map?;
    final answer = (msg?['content'] as String?)?.trim() ?? '';
    final thinking =
        ((msg?['reasoning'] ?? msg?['reasoning_content']) as String?)?.trim() ??
        '';
    if (answer.isEmpty) throw CerebrasException('응답이 비어있습니다.');
    return TutorReply(thinking: thinking, answer: answer);
  }
}

class CerebrasException implements Exception {
  final String message;
  CerebrasException(this.message);
  @override
  String toString() => message;
}
