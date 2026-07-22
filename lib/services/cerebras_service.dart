import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:http/http.dart' as http;
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

/// Cerebras Inference API 서비스 — OpenAI 호환 chat completions.
///
/// 개발 키는 소스 코드에 저장하지 않고, 로컬 실행 시 `--dart-define`으로만
/// 주입한다. 공개 배포 빌드에는 `ENABLE_DEV_AI=true` 및 키를 절대 전달하지 않는다.
class CerebrasService {
  CerebrasService._();
  static final CerebrasService instance = CerebrasService._();

  static const _endpoint = String.fromEnvironment(
    'CEREBRAS_API_ENDPOINT',
    defaultValue: 'https://api.cerebras.ai/v1/chat/completions',
  );
  static const _model = String.fromEnvironment(
    'CEREBRAS_MODEL',
    defaultValue: 'gpt-oss-120b',
  );
  static const _primaryDevKey = String.fromEnvironment('CEREBRAS_API_KEY');
  static const _backupDevKey = String.fromEnvironment(
    'CEREBRAS_API_BACKUP_KEY',
  );
  static const _developmentAiEnabled = bool.fromEnvironment('ENABLE_DEV_AI');

  /// 레거시 화면과의 호환용 상태값. 실제 사용 가능 여부는 [hasKey]로 판정한다.
  static bool get isTestPeriod => _developmentAiEnabled;
  static String get testPeriodEndLabel => '개발 모드';

  /// 개발 키는 빌드 옵션으로만 제공된다. 기본/백업 키를 모두 지원한다.
  Future<String> getApiKey() async {
    if (!_developmentAiEnabled) return '';
    if (_primaryDevKey.isNotEmpty) return _primaryDevKey;
    return _backupDevKey;
  }

  /// 이 앱은 키를 로컬 저장소나 소스에 기록하지 않는다.
  Future<void> setApiKey(String key) async {}

  Future<bool> hasKey() async => (await getApiKey()).isNotEmpty;

  Future<bool> get aiAvailable async => hasKey();

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
    final key = await getApiKey();
    if (key.isEmpty) {
      throw CerebrasException('개발용 AI 연결이 준비되지 않았습니다. 개발 실행 설정을 확인해주세요.');
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
        throw CerebrasException('AI 서버 인증 오류입니다. 잠시 후 다시 시도해주세요.');
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
