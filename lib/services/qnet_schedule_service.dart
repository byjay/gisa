import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'remote_content_api.dart';

/// 📅 Q-Net 회차 시험일정 (한 행 = 1 회차)
///
/// crf00503s02 페이지의 시험일정 표를 파싱한 결과.
/// 각 날짜는 "시작~끝" 범위일 수 있어 시작/끝을 함께 보관한다.
class QnetExamRound {
  final String label; // 예: 2026년 정기 기사 1회
  final DateRange? writtenReg; // 필기 원서접수
  final DateRange? writtenExam; // 필기 시험
  final DateTime? writtenResult; // 필기 합격발표
  final DateRange? practicalReg; // 실기 원서접수
  final DateRange? practicalExam; // 실기 시험
  final DateTime? finalResult; // 최종 합격발표

  const QnetExamRound({
    required this.label,
    this.writtenReg,
    this.writtenExam,
    this.writtenResult,
    this.practicalReg,
    this.practicalExam,
    this.finalResult,
  });

  Map<String, dynamic> toMap() => {
    'label': label,
    'writtenReg': writtenReg?.toMap(),
    'writtenExam': writtenExam?.toMap(),
    'writtenResult': writtenResult?.toIso8601String(),
    'practicalReg': practicalReg?.toMap(),
    'practicalExam': practicalExam?.toMap(),
    'finalResult': finalResult?.toIso8601String(),
  };

  factory QnetExamRound.fromMap(Map<dynamic, dynamic> m) => QnetExamRound(
    label: (m['label'] as String?) ?? '',
    writtenReg: DateRange.fromMap(m['writtenReg']),
    writtenExam: DateRange.fromMap(m['writtenExam']),
    writtenResult: _parse(m['writtenResult']),
    practicalReg: DateRange.fromMap(m['practicalReg']),
    practicalExam: DateRange.fromMap(m['practicalExam']),
    finalResult: _parse(m['finalResult']),
  );

  static DateTime? _parse(dynamic v) =>
      v is String && v.isNotEmpty ? DateTime.tryParse(v) : null;

  /// 회차의 대표 필기시험일(정렬/표시용). 없으면 원서접수 시작.
  DateTime? get anchorDate =>
      writtenExam?.start ?? writtenReg?.start ?? practicalExam?.start;
}

/// 날짜 범위 (시작~끝). 단일 날짜면 start==end.
class DateRange {
  final DateTime start;
  final DateTime end;
  const DateRange(this.start, this.end);

  bool get isSingleDay =>
      start.year == end.year &&
      start.month == end.month &&
      start.day == end.day;

  Map<String, dynamic> toMap() => {
    's': start.toIso8601String(),
    'e': end.toIso8601String(),
  };

  static DateRange? fromMap(dynamic m) {
    if (m is! Map) return null;
    final s = DateTime.tryParse((m['s'] as String?) ?? '');
    final e = DateTime.tryParse((m['e'] as String?) ?? '');
    if (s == null) return null;
    return DateRange(s, e ?? s);
  }
}

/// Q-Net 시험일정 실시간 크롤링 서비스.
///
/// 흐름:
///  1) crf00503s02 AJAX 페이지(HTML)를 요청
///  2) 웹(CORS)에서 실패하면 공개 CORS 프록시로 재시도
///  3) 시험일정 <table> 을 정규식으로 파싱하여 회차 목록 생성
class QnetScheduleService {
  QnetScheduleService._();
  static final QnetScheduleService instance = QnetScheduleService._();

  final Map<String, List<QnetExamRound>> _cache = {};

  /// 서버 카탈로그 캐시. catalogId -> rounds.
  Map<String, List<QnetExamRound>>? _bundled;
  DateTime? bundledFetchedAt;

  /// jmCd 종목의 회차별 시험일정을 가져온다.
  ///
  /// 우선순위:
  ///  1) 메모리 캐시 (forceRefresh=false 일 때)
  ///  2) 서버 R2의 자격증별 일정 카탈로그
  ///
  /// [catalogId] 를 주면 서버 일정 카탈로그에서 해당 종목 일정을 선택한다.
  Future<List<QnetExamRound>> fetchSchedule(
    String jmCd, {
    String seriesCd = '03',
    String? catalogId,
    bool forceRefresh = false,
  }) async {
    final sessionGeneration = RemoteContentApi.instance.sessionGeneration;
    if (!forceRefresh && _cache.containsKey(jmCd)) {
      return _cache[jmCd]!;
    }
    if (forceRefresh) _bundled = null;
    if (catalogId != null) {
      final rounds = await _loadBundled(catalogId);
      if (sessionGeneration != RemoteContentApi.instance.sessionGeneration) {
        return const [];
      }
      if (rounds.isNotEmpty) {
        _cache[jmCd] = rounds;
        return rounds;
      }
    }
    // 마지막으로 이전 캐시라도 반환
    return _cache[jmCd] ?? const [];
  }

  /// 서버에 보관한 일정에서 catalogId 회차 목록을 로드한다.
  Future<List<QnetExamRound>> _loadBundled(String catalogId) async {
    try {
      final sessionGeneration = RemoteContentApi.instance.sessionGeneration;
      final bundled = _bundled ?? await _parseBundle();
      if (sessionGeneration != RemoteContentApi.instance.sessionGeneration) {
        return const [];
      }
      _bundled = bundled;
      return _bundled?[catalogId] ?? const [];
    } catch (_) {
      return const [];
    }
  }

  /// 서버의 qnet_schedule.json 파싱.
  Future<Map<String, List<QnetExamRound>>> _parseBundle() async {
    final sessionGeneration = RemoteContentApi.instance.sessionGeneration;
    final raw = await RemoteContentApi.instance.getStudyFile(
      group: 'qnet',
      track: 'qnet',
      filename: 'qnet_schedule.json',
    );
    if (sessionGeneration != RemoteContentApi.instance.sessionGeneration) {
      return const {};
    }
    final json = jsonDecode(raw) as Map<String, dynamic>;
    bundledFetchedAt = DateTime.tryParse((json['fetchedAt'] as String?) ?? '');
    final schedules = (json['schedules'] as Map<String, dynamic>?) ?? {};
    final out = <String, List<QnetExamRound>>{};
    schedules.forEach((cid, list) {
      final rounds = <QnetExamRound>[];
      for (final item in (list as List)) {
        final m = item as Map<String, dynamic>;
        rounds.add(
          QnetExamRound(
            label: (m['label'] as String?) ?? '',
            writtenReg: _rangeFromJson(m['writtenReg']),
            writtenExam: _rangeFromJson(m['writtenExam']),
            writtenResult: _dateFromJson(m['writtenResult']),
            practicalReg: _rangeFromJson(m['practicalReg']),
            practicalExam: _rangeFromJson(m['practicalExam']),
            finalResult: _dateFromJson(m['finalResult']),
          ),
        );
      }
      out[cid] = rounds;
    });
    return out;
  }

  /// [y,m,d] 리스트 → DateTime
  DateTime? _dateFromJson(dynamic v) {
    if (v is List && v.length == 3) {
      return DateTime(v[0] as int, v[1] as int, v[2] as int);
    }
    return null;
  }

  /// {s:[y,m,d], e:[y,m,d]} → DateRange
  DateRange? _rangeFromJson(dynamic v) {
    if (v is! Map) return null;
    final s = _dateFromJson(v['s']);
    final e = _dateFromJson(v['e']);
    if (s == null) return null;
    return DateRange(s, e ?? s);
  }

  /// [P3-A/T5] 테스트 전용 공개 진입점. private 파서/연도검증 로직을
  /// 라이브러리 밖(test/)에서도 직접 호출해 회귀 테스트할 수 있게 한다.
  @visibleForTesting
  List<QnetExamRound> parseScheduleTableForTest(String html) =>
      _parseScheduleTable(html);

  /// 시험일정 <table> 파싱.
  ///
  /// 표 구조(열 순서):
  ///  구분 | 필기원서접수 | 필기시험 | 필기합격발표 | 실기원서접수 | 실기시험 | 최종합격발표
  List<QnetExamRound> _parseScheduleTable(String html) {
    // "시험일정" 헤더 다음의 첫 <table> ~ </table> 만 추출
    final startIdx = html.indexOf('시험일정');
    if (startIdx < 0) return const [];
    final tableStart = html.indexOf('<table', startIdx);
    if (tableStart < 0) return const [];
    final tableEnd = html.indexOf('</table>', tableStart);
    if (tableEnd < 0) return const [];
    final table = html.substring(tableStart, tableEnd);

    final rows = RegExp(
      r'<tr[^>]*>(.*?)</tr>',
      dotAll: true,
    ).allMatches(table).map((m) => m.group(1) ?? '').toList();

    final result = <QnetExamRound>[];
    for (final row in rows) {
      // 헤더 행(th 포함) 건너뜀
      if (row.contains('<th')) continue;
      final cells = RegExp(
        r'<td[^>]*>(.*?)</td>',
        dotAll: true,
      ).allMatches(row).map((m) => _clean(m.group(1) ?? '')).toList();
      if (cells.length < 4) continue;

      final label = cells[0];
      if (label.isEmpty) continue;

      DateRange? range(int i) =>
          i < cells.length ? _parseRange(cells[i]) : null;
      DateTime? single(int i) =>
          i < cells.length ? _parseSingle(cells[i]) : null;

      result.add(
        QnetExamRound(
          label: label,
          writtenReg: range(1),
          writtenExam: range(2),
          writtenResult: single(3),
          practicalReg: range(4),
          practicalExam: range(5),
          finalResult: single(6),
        ),
      );
    }
    return result;
  }

  /// HTML 태그/공백 정리. 날짜 판별을 위해 원본 텍스트를 보존한다.
  String _clean(String raw) {
    var s = raw
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('~', ' ~ ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  /// "2026.01.12 ~ 2026.01.15" → DateRange
  /// 빈자리접수 등 부가 날짜는 무시하고 첫 두 날짜를 사용.
  DateRange? _parseRange(String text) {
    final dates = _extractDates(text);
    if (dates.isEmpty) return null;
    if (dates.length == 1) return DateRange(dates.first, dates.first);
    return DateRange(dates[0], dates[1]);
  }

  DateTime? _parseSingle(String text) {
    final dates = _extractDates(text);
    return dates.isEmpty ? null : dates.first;
  }

  /// [P1-A/S2] 크롤링 결과(3rd-party CORS 프록시 경유)는 신뢰할 수 없는
  /// 입력으로 취급한다. 파싱된 연도가 비합리적 범위(작년~2년 후)를 벗어나면
  /// 위조/오염된 데이터로 간주해 폐기한다 — 이 날짜들로 실제 기기 알림까지
  /// 예약되므로 최소한의 방어가 필요하다.
  bool _isPlausibleYear(int year) {
    final now = DateTime.now().year;
    return year >= now - 1 && year <= now + 2;
  }

  /// yyyy.MM.dd 형태의 날짜를 모두 추출. 비합리적 연도는 폐기한다.
  List<DateTime> _extractDates(String text) {
    final re = RegExp(r'(\d{4})\.(\d{1,2})\.(\d{1,2})');
    final out = <DateTime>[];
    for (final m in re.allMatches(text)) {
      final y = int.tryParse(m.group(1)!);
      final mo = int.tryParse(m.group(2)!);
      final d = int.tryParse(m.group(3)!);
      if (y != null && mo != null && d != null && _isPlausibleYear(y)) {
        out.add(DateTime(y, mo, d));
      }
    }
    return out;
  }

  void clearCache() {
    _cache.clear();
    _bundled = null;
    bundledFetchedAt = null;
  }
}
