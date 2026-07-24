import 'dart:convert';

import 'package:flutter/foundation.dart'
    show kDebugMode, kReleaseMode, debugPrint;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'study_data.dart';
import 'entitlement_service.dart';

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
  // 개발용 키(로컬 디버그 실행 시 --dart-define으로만 주입). 릴리스에는 주입 금지.
  static const _primaryDevKey = String.fromEnvironment('CEREBRAS_API_KEY');
  static const _backupDevKey = String.fromEnvironment(
    'CEREBRAS_API_BACKUP_KEY',
  );
  static const _developmentAiEnabled = bool.fromEnvironment('ENABLE_DEV_AI');

  /// 사용자가 설정에서 직접 입력한 API 키를 저장하는 로컬 키 이름.
  static const _prefsKeyUserApiKey = 'cerebras_user_api_key';

  /// 메모리 캐시(매번 SharedPreferences를 읽지 않도록).
  String? _cachedUserKey;
  bool _loadedUserKey = false;

  /// 디버그 실행에서 --dart-define으로 주입된 개발 키 사용 여부.
  static bool get _devAiActuallyEnabled =>
      _developmentAiEnabled && !kReleaseMode;

  /// AI 튜터 설정(키 입력 UI)을 항상 노출한다.
  ///
  /// 상용화 방식: 사용자가 본인 Cerebras 무료 키를 발급받아 입력하면
  /// 릴리스 빌드에서도 AI 튜터를 사용할 수 있다(BYOK). 개발자 키를 앱에
  /// 심지 않으므로 키 유출·비용 문제가 없다.
  static bool get isTestPeriod => true;
  static String get testPeriodEndLabel => '무료';

  /// 사용자 저장 키를 로컬에서 로드(1회 캐싱).
  Future<String> _loadUserKey() async {
    if (_loadedUserKey) return _cachedUserKey ?? '';
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedUserKey = prefs.getString(_prefsKeyUserApiKey)?.trim();
    } catch (_) {
      _cachedUserKey = null;
    }
    _loadedUserKey = true;
    return _cachedUserKey ?? '';
  }

  /// 실제 사용할 API 키를 반환한다.
  /// 우선순위: (1) 사용자가 설정에서 입력·저장한 키 → (2) 디버그 개발 키.
  Future<String> getApiKey() async {
    final userKey = await _loadUserKey();
    if (userKey.isNotEmpty) return userKey;
    if (_devAiActuallyEnabled) {
      if (_primaryDevKey.isNotEmpty) return _primaryDevKey;
      if (_backupDevKey.isNotEmpty) return _backupDevKey;
    }
    return '';
  }

  /// 사용자 API 키를 로컬(SharedPreferences)에 안전 저장한다.
  /// 빈 문자열을 넘기면 저장된 키를 삭제한다.
  Future<void> setApiKey(String key) async {
    final trimmed = key.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      if (trimmed.isEmpty) {
        await prefs.remove(_prefsKeyUserApiKey);
        _cachedUserKey = null;
      } else {
        await prefs.setString(_prefsKeyUserApiKey, trimmed);
        _cachedUserKey = trimmed;
      }
      _loadedUserKey = true;
    } catch (e) {
      if (kDebugMode) debugPrint('setApiKey 저장 실패: $e');
    }
  }

  /// 사용자가 키를 저장해 두었는지 여부(입력란 표시 상태용).
  Future<bool> hasUserKey() async => (await _loadUserKey()).isNotEmpty;

  Future<bool> hasKey() async => (await getApiKey()).isNotEmpty;

  Future<bool> get aiAvailable async => hasKey();

  /// 저장된 키가 실제로 유효한지 경량 요청으로 검증한다.
  /// 200이면 유효, 401/403이면 무효, 그 외(네트워크·429 등)는 낙관적으로 통과시킨다
  /// (일시적 오류로 정상 키를 무효 처리하지 않기 위함).
  Future<bool> validateKey() async {
    final key = await getApiKey();
    if (key.isEmpty) return false;
    try {
      final res = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $key',
            },
            body: jsonEncode({
              'model': _model,
              'messages': [
                {'role': 'user', 'content': 'ping'},
              ],
              'max_tokens': 1,
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 401 || res.statusCode == 403) return false;
      return true; // 200 또는 일시적 오류(429/5xx/네트워크)는 유효로 간주
    } catch (e) {
      if (kDebugMode) debugPrint('validateKey 네트워크 오류: $e');
      return true; // 네트워크 문제로 정상 키를 막지 않음
    }
  }

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
      throw CerebrasException(
        'AI 튜터 API 키가 없습니다. 설정 → "AI 튜터 API 키"에서 무료 Cerebras 키를 등록해주세요.',
      );
    }

    // ─────────── 💎 무료 티어 AI 30% 게이트 ───────────
    // 무료 사용자: 하루 사용 횟수 제한 + 답변 길이(토큰) 축약 + 추론 강도 low.
    // 프리미엄: 무제한 + 심화(high) 추론 + 긴 답변.
    final ent = EntitlementService.instance;
    if (!ent.isPremium) {
      final allowed = await ent.canUseAi();
      if (!allowed) {
        throw PremiumRequiredException(
          '오늘의 무료 AI 선생님 사용 횟수(${EntitlementService.kFreeAiDailyLimit}회)를 모두 사용했어요.\n'
          '프리미엄으로 업그레이드하면 볼트쌤을 하루 무제한으로, '
          '더 길고 깊은 풀이(심화 추론)로 만날 수 있어요.',
        );
      }
    }
    // 등급별로 토큰/추론 강도를 강제한다(무료는 상한선을 넘지 못한다).
    final effectiveMaxTokens =
        maxTokens > ent.aiMaxTokens() ? ent.aiMaxTokens() : maxTokens;
    final effectiveEffort = ent.aiReasoningEffort();

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
              'max_tokens': effectiveMaxTokens, // 무료는 짧게, 프리미엄은 길게
              'temperature': temperature,
              'reasoning_effort':
                  effectiveEffort, // 무료 low(축약) / 프리미엄 high(심화)
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
      case 403:
        throw CerebrasException(
          'API 키 인증에 실패했어요. 설정에서 API 키를 다시 확인해주세요.',
        );
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
    // 무료 티어 하루 사용 횟수 1회 차감(프리미엄은 내부에서 무시).
    await ent.recordAiUse();
    return TutorReply(thinking: thinking, answer: answer);
  }

  /// 현재 등급 기준 AI 사용 안내 문구(UI 배지용).
  Future<String> aiQuotaLabel() async {
    final ent = EntitlementService.instance;
    if (ent.isPremium) return '프리미엄 · AI 무제한 심화';
    final left = await ent.remainingAiUses();
    return '무료 · 오늘 남은 AI $left/${EntitlementService.kFreeAiDailyLimit}회';
  }
}

/// 무료 한도 초과 등, 프리미엄 업그레이드가 필요한 상황을 나타내는 예외.
/// UI는 이 예외를 잡아 페이월(openPremiumPaywall)로 안내한다.
class PremiumRequiredException implements Exception {
  PremiumRequiredException(this.message);
  final String message;
  @override
  String toString() => message;
}

class CerebrasException implements Exception {
  final String message;
  CerebrasException(this.message);
  @override
  String toString() => message;
}
