import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'app_config.dart';
import 'entitlement_service.dart';
import 'exam_track.dart';
import 'service_control_service.dart';

/// 🔐 서버(Cloudflare) 콘텐츠 API 클라이언트.
///
/// [보안 설계]
/// - 문제 본문은 서버가 세션·권한 검증 후에만 반환한다(view-only).
/// - **정답/해설은 채점(grade) 응답에서만** 받는다. 목록/본문에는 없다.
/// - 무료 사용자는 서버가 10%만 반환하며, 초과 요청은 402(PaymentRequired).
///
/// 학습 자료는 앱 패키지에 넣지 않고 이 인증 API에서만 가져온다.
class RemoteContentApi {
  RemoteContentApi._();
  static final RemoteContentApi instance = RemoteContentApi._();

  String get _base => AppConfig.apiBaseUrl;

  /// 현재 세션 토큰(로그인 후 AuthService가 주입). 없으면 게스트.
  String? _authToken;
  int _sessionGeneration = 0;
  int _requestGeneration = 0;
  set authToken(String? token) {
    if (_authToken == token) return;
    _authToken = token;
    _sessionGeneration++;
  }

  int get sessionGeneration => _sessionGeneration;

  void invalidateRequests() => _requestGeneration++;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_authToken != null && _authToken!.isNotEmpty)
      'Authorization': 'Bearer $_authToken',
  };

  RemoteContentException _sessionChanged() => RemoteContentException(
    401,
    'session_changed',
    '로그인 상태가 바뀌어 서버 자료를 폐기했습니다.',
  );

  Future<http.Response> _get(Uri uri, Duration timeout) async {
    final requestSessionGeneration = _sessionGeneration;
    final requestGeneration = _requestGeneration;
    final response = await http.get(uri, headers: _headers).timeout(timeout);
    if (_isServiceDisabled(response)) {
      _reportDisabled(response);
      return response;
    }
    if (requestSessionGeneration != _sessionGeneration) {
      throw _sessionChanged();
    }
    if (requestGeneration != _requestGeneration) throw _serviceChanged();
    return response;
  }

  Future<http.Response> _post(
    Uri uri,
    Duration timeout, {
    required String body,
  }) async {
    final requestSessionGeneration = _sessionGeneration;
    final requestGeneration = _requestGeneration;
    final response = await http
        .post(uri, headers: _headers, body: body)
        .timeout(timeout);
    if (_isServiceDisabled(response)) {
      _reportDisabled(response);
      return response;
    }
    if (requestSessionGeneration != _sessionGeneration) {
      throw _sessionChanged();
    }
    if (requestGeneration != _requestGeneration) throw _serviceChanged();
    return response;
  }

  bool _isServiceDisabled(http.Response response) {
    if (response.statusCode != 503) return false;
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      return body is Map<String, dynamic> &&
          body['error'] == 'service_disabled';
    } catch (_) {
      return false;
    }
  }

  void _reportDisabled(http.Response response) {
    invalidateRequests();
    var message = '서비스 점검 중입니다.';
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map<String, dynamic> && body['message'] is String) {
        message = body['message'] as String;
      }
    } catch (_) {}
    ServiceControlService.instance.reportDisabled(message);
  }

  RemoteContentException _serviceChanged() => RemoteContentException(
    503,
    'service_disabled',
    '서비스 상태가 바뀌어 서버 응답을 폐기했습니다.',
  );

  Future<List<ExamTrack>> getTrackCatalog() async {
    final res = await _get(
      Uri.parse('$_base/v1/tracks'),
      const Duration(seconds: 20),
    );
    if (res.statusCode != 200) throw RemoteContentException.fromResponse(res);
    final payload =
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    if ((payload['schemaVersion'] as num?)?.toInt() != 1 ||
        payload['tracks'] is! List) {
      throw const FormatException('서버 자격증 카탈로그 형식이 올바르지 않습니다.');
    }
    return (payload['tracks'] as List)
        .map(
          (item) => ExamTrack.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);
  }

  /// 자격증별 회차 색인(정답·해설 없음).
  Future<List<Map<String, dynamic>>> listExams(String track) async {
    final res = await _get(
      Uri.parse('$_base/v1/tracks/$track/exams'),
      const Duration(seconds: 20),
    );
    if (res.statusCode != 200) throw RemoteContentException.fromResponse(res);
    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return ((json['exams'] as List?) ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  /// 허용된 회차의 문제 본문을 한 번의 요청으로 받는다.
  Future<RemoteExamPaper> getExamPaper(String track, String examId) async {
    final res = await _get(
      Uri.parse('$_base/v1/exams/$track/$examId/paper'),
      const Duration(seconds: 30),
    );
    if (res.statusCode != 200) throw RemoteContentException.fromResponse(res);
    return RemoteExamPaper.fromJson(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }

  /// 종목별 학습 JSON 또는 이론 Markdown을 세션 인증 후 불러온다.
  Future<String> getStudyFile({
    required String group,
    required String track,
    required String filename,
  }) async {
    final path = [group, track, filename].map(Uri.encodeComponent).join('/');
    final res = await _get(
      Uri.parse('$_base/v1/study/$path'),
      const Duration(seconds: 20),
    );
    if (res.statusCode != 200) throw RemoteContentException.fromResponse(res);
    return utf8.decode(res.bodyBytes);
  }

  Uri questionImageUri(String track, String imagePath) {
    final encoded = imagePath.split('/').map(Uri.encodeComponent).join('/');
    return Uri.parse('$_base/v1/question-images/$track/$encoded');
  }

  Map<String, String> get imageHeaders => _headers;

  /// 문제 목록(메타만). 무료는 10%까지만 잠금 해제되어 반환된다.
  Future<RemoteQuestionPage> listQuestions(
    String track,
    String examId, {
    int page = 1,
  }) async {
    final res = await _get(
      Uri.parse('$_base/v1/exams/$track/$examId/questions?page=$page'),
      const Duration(seconds: 20),
    );
    if (res.statusCode != 200) {
      throw RemoteContentException.fromResponse(res);
    }
    return RemoteQuestionPage.fromJson(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }

  /// 단일 문제 본문(정답 제외). 잠긴 문항이면 402 → PremiumRequired 신호.
  Future<Map<String, dynamic>> getQuestion(String qid) async {
    final res = await _get(
      Uri.parse('$_base/v1/questions/${Uri.encodeComponent(qid)}'),
      const Duration(seconds: 20),
    );
    if (res.statusCode != 200) {
      throw RemoteContentException.fromResponse(res);
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  /// 채점 — 정답/해설은 여기서만 반환된다(제출 이후).
  Future<Map<String, dynamic>> grade(List<Map<String, dynamic>> answers) async {
    final res = await _post(
      Uri.parse('$_base/v1/quiz/grade'),
      const Duration(seconds: 30),
      body: jsonEncode({'answers': answers}),
    );
    if (res.statusCode != 200) {
      throw RemoteContentException.fromResponse(res);
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  /// 서버 배치 상한을 지키면서 회차 채점 결과를 하나로 합친다.
  Future<Map<String, dynamic>> gradeMany(
    List<Map<String, dynamic>> answers,
  ) async {
    final requestSessionGeneration = _sessionGeneration;
    final results = <dynamic>[];
    var correct = 0;
    for (var offset = 0; offset < answers.length; offset += 50) {
      if (requestSessionGeneration != _sessionGeneration) {
        throw _sessionChanged();
      }
      final end = (offset + 50 < answers.length) ? offset + 50 : answers.length;
      final page = await grade(answers.sublist(offset, end));
      if (requestSessionGeneration != _sessionGeneration) {
        throw _sessionChanged();
      }
      correct += (page['correct'] as num?)?.toInt() ?? 0;
      results.addAll((page['results'] as List?) ?? const []);
    }
    return {'total': results.length, 'correct': correct, 'results': results};
  }

  /// 결제 영수증을 서버에 전달해 구독을 활성화하고 최신 등급을 받는다.
  Future<void> verifyPurchase(String productId, String purchaseToken) async {
    final res = await _post(
      Uri.parse('$_base/v1/billing/verify'),
      const Duration(seconds: 30),
      body: jsonEncode({
        'productId': productId,
        'purchaseToken': purchaseToken,
      }),
    );
    if (res.statusCode != 200) {
      throw RemoteContentException.fromResponse(res);
    }
    // 서버가 최신 tier/expiry를 반환 → EntitlementService 갱신.
    if (_authToken != null) {
      await EntitlementService.instance.refreshFromServer(
        authToken: _authToken,
      );
    }
  }
}

class RemoteExamPaper {
  const RemoteExamPaper({
    required this.total,
    required this.allowed,
    required this.premium,
    required this.items,
  });
  final int total;
  final int allowed;
  final bool premium;
  final List<Map<String, dynamic>> items;

  factory RemoteExamPaper.fromJson(Map<String, dynamic> json) =>
      RemoteExamPaper(
        total: (json['total'] as num?)?.toInt() ?? 0,
        allowed: (json['allowed'] as num?)?.toInt() ?? 0,
        premium: json['premium'] == true,
        items: ((json['items'] as List?) ?? const [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList(),
      );
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
            .map((e) => RemoteQuestionMeta.fromJson(e as Map<String, dynamic>))
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
