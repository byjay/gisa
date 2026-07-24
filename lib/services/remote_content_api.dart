import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'entitlement_service.dart';

/// 🔐 서버(Cloudflare) 콘텐츠 API 클라이언트.
///
/// [보안 설계]
/// - 문제 본문은 서버가 세션·권한 검증 후에만 반환한다(view-only).
/// - **정답/해설은 채점(grade) 응답에서만** 받는다. 목록/본문에는 없다.
/// - 무료 사용자는 서버가 10%만 반환하며, 초과 요청은 402(PaymentRequired).
///
/// 이 클래스는 110MB 로컬 자산을 서버로 이전하는 마이그레이션의 앱 측
/// 진입점이다. 현재는 스켈레톤이며, 서버 배포 후 실제 데이터 소스로 전환한다.
class RemoteContentApi {
  RemoteContentApi._();
  static final RemoteContentApi instance = RemoteContentApi._();

  static const _base = String.fromEnvironment(
    'GISACLUB_API_BASE',
    defaultValue: 'https://api.gisaclub.com',
  );

  /// 현재 세션 토큰(로그인 후 AuthService가 주입). 없으면 게스트.
  String? _authToken;
  set authToken(String? t) => _authToken = t;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_authToken != null && _authToken!.isNotEmpty)
          'Authorization': 'Bearer $_authToken',
      };

  /// 문제 목록(메타만). 무료는 10%까지만 잠금 해제되어 반환된다.
  Future<RemoteQuestionPage> listQuestions(
    String track,
    String examId, {
    int page = 1,
  }) async {
    final res = await http
        .get(
          Uri.parse('$_base/v1/exams/$track/$examId/questions?page=$page'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw RemoteContentException.fromResponse(res);
    }
    return RemoteQuestionPage.fromJson(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }

  /// 단일 문제 본문(정답 제외). 잠긴 문항이면 402 → PremiumRequired 신호.
  Future<Map<String, dynamic>> getQuestion(String qid) async {
    final res = await http
        .get(
          Uri.parse('$_base/v1/questions/${Uri.encodeComponent(qid)}'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw RemoteContentException.fromResponse(res);
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  /// 채점 — 정답/해설은 여기서만 반환된다(제출 이후).
  Future<Map<String, dynamic>> grade(List<Map<String, int>> answers) async {
    final res = await http
        .post(
          Uri.parse('$_base/v1/quiz/grade'),
          headers: _headers,
          body: jsonEncode({'answers': answers}),
        )
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      throw RemoteContentException.fromResponse(res);
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  /// 결제 영수증을 서버에 전달해 구독을 활성화하고 최신 등급을 받는다.
  Future<void> verifyPurchase(String productId, String purchaseToken) async {
    final res = await http
        .post(
          Uri.parse('$_base/v1/billing/verify'),
          headers: _headers,
          body: jsonEncode({
            'productId': productId,
            'purchaseToken': purchaseToken,
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      throw RemoteContentException.fromResponse(res);
    }
    // 서버가 최신 tier/expiry를 반환 → EntitlementService 갱신.
    if (_authToken != null) {
      await EntitlementService.instance.refreshFromServer(authToken: _authToken);
    }
  }
}

class RemoteQuestionPage {
  RemoteQuestionPage({
    required this.total,
    required this.allowed,
    required this.premium,
    required this.items,
  });
  final int total;
  final int allowed;
  final bool premium;
  final List<RemoteQuestionMeta> items;

  factory RemoteQuestionPage.fromJson(Map<String, dynamic> j) =>
      RemoteQuestionPage(
        total: (j['total'] as num?)?.toInt() ?? 0,
        allowed: (j['allowed'] as num?)?.toInt() ?? 0,
        premium: j['premium'] == true,
        items: ((j['items'] as List?) ?? const [])
            .map((e) =>
                RemoteQuestionMeta.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class RemoteQuestionMeta {
  RemoteQuestionMeta({
    required this.qid,
    required this.subject,
    required this.topic,
    required this.difficulty,
    required this.freqScore,
    required this.hasImage,
    required this.locked,
  });
  final String qid;
  final String subject;
  final String topic;
  final int difficulty;
  final double freqScore;
  final bool hasImage;
  final bool locked;

  factory RemoteQuestionMeta.fromJson(Map<String, dynamic> j) =>
      RemoteQuestionMeta(
        qid: (j['qid'] as String?) ?? '',
        subject: (j['subject'] as String?) ?? '',
        topic: (j['topic'] as String?) ?? '기타',
        difficulty: (j['difficulty'] as num?)?.toInt() ?? 2,
        freqScore: (j['freqScore'] as num?)?.toDouble() ?? 0,
        hasImage: j['hasImage'] == true,
        locked: j['locked'] == true,
      );
}

class RemoteContentException implements Exception {
  RemoteContentException(this.statusCode, this.code, this.message);
  final int statusCode;
  final String code;
  final String message;

  /// 402 = 결제 필요(프리미엄 유도).
  bool get isPaymentRequired => statusCode == 402;

  factory RemoteContentException.fromResponse(http.Response res) {
    String code = 'error';
    String message = '요청을 처리할 수 없습니다. (${res.statusCode})';
    try {
      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      code = (j['error'] as String?) ?? code;
      message = (j['message'] as String?) ?? message;
    } catch (_) {}
    if (kDebugMode) debugPrint('RemoteContent 오류: $code $message');
    return RemoteContentException(res.statusCode, code, message);
  }

  @override
  String toString() => message;
}
