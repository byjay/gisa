import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

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

  static const _base = 'https://www.q-net.or.kr/crf005.do';

  /// 웹에서 CORS를 우회하기 위한 공개 프록시(폴백). 순서대로 시도.
  /// proxy.cors.sh 가 Q-Net(데이터센터 IP 차단 회피)에 가장 안정적.
  static const _corsProxies = [
    'https://proxy.cors.sh/',
    'https://api.allorigins.win/raw?url=',
    'https://cors.eu.org/',
  ];

  final Map<String, List<QnetExamRound>> _cache = {};

  /// 번들된 오프라인 일정(asset) 캐시. catalogId -> rounds.
  Map<String, List<QnetExamRound>>? _bundled;
  DateTime? bundledFetchedAt;

  /// jmCd 종목의 회차별 시험일정을 가져온다.
  ///
  /// 우선순위:
  ///  1) 메모리 캐시 (forceRefresh=false 일 때)
  ///  2) 실시간 크롤링 (네이티브=직접, 웹=CORS 프록시)
  ///  3) 번들된 asset JSON (브라우저에서 프록시가 막혀도 항상 표시)
  ///
  /// [catalogId] 를 주면 실시간 실패 시 해당 id 로 asset 폴백을 찾는다.
  Future<List<QnetExamRound>> fetchSchedule(
    String jmCd, {
    String seriesCd = '03',
    String? catalogId,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cache.containsKey(jmCd)) {
      return _cache[jmCd]!;
    }
    final url = Uri.parse(
      '$_base'
      '?id=crf00503s02&gSite=Q&gId='
      '&jmCd=$jmCd&jmInfoDivCcd=B0&seriesCd=$seriesCd',
    );

    final html = await _fetchWithFallback(url.toString());
    if (html != null) {
      final rounds = _parseScheduleTable(html);
      if (rounds.isNotEmpty) {
        _cache[jmCd] = rounds;
        return rounds;
      }
    }

    // 실시간 실패 → 번들 asset 폴백 (항상 무언가 표시하기 위함)
    if (catalogId != null) {
      final offline = await _loadBundled(catalogId);
      if (offline.isNotEmpty) {
        _cache[jmCd] = offline;
        return offline;
      }
    }
    // 마지막으로 이전 캐시라도 반환
    return _cache[jmCd] ?? const [];
  }

  /// 번들된 오프라인 일정에서 catalogId 회차 목록 로드.
  Future<List<QnetExamRound>> _loadBundled(String catalogId) async {
    try {
      _bundled ??= await _parseBundle();
      return _bundled?[catalogId] ?? const [];
    } catch (_) {
      return const [];
    }
  }

  /// assets/data/qnet_schedule.json 파싱.
  Future<Map<String, List<QnetExamRound>>> _parseBundle() async {
    final raw = await rootBundle.loadString('assets/data/qnet_schedule.json');
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

  /// 직접 요청 → 실패 시 CORS 프록시 순차 시도.
  Future<String?> _fetchWithFallback(String url) async {
    // 1) 직접 요청 (모바일/네이티브는 CORS 없음)
    final direct = await _tryGet(url);
    if (direct != null && direct.contains('시험일정')) return direct;

    // 2) 웹 CORS 폴백
    if (kIsWeb || direct == null) {
      for (final proxy in _corsProxies) {
        // ?url= 형태 프록시는 인코딩, path 뒤에 붙이는 프록시는 원본 URL 사용
        final proxied = proxy.endsWith('=')
            ? proxy + Uri.encodeComponent(url)
            : proxy + url;
        final res = await _tryGet(proxied);
        if (res != null && res.contains('시험일정')) return res;
      }
    }
    return direct;
  }

  Future<String?> _tryGet(String url) async {
    try {
      final res = await http
          .get(
            Uri.parse(url),
            headers: {
              'User-Agent':
                  'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
              'Accept': 'text/html,application/xhtml+xml',
              // proxy.cors.sh 브라우저 요청용 데모 키(공개)
              'x-cors-api-key': 'temp_qnet_cert_tracker',
            },
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        // Q-Net은 UTF-8. 프록시가 이미 문자열을 주지만 안전하게 디코딩.
        try {
          return utf8.decode(res.bodyBytes);
        } catch (_) {
          return res.body;
        }
      }
    } catch (_) {
      // 무시하고 폴백으로 넘어감
    }
    return null;
  }

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

  /// yyyy.MM.dd 형태의 날짜를 모두 추출.
  List<DateTime> _extractDates(String text) {
    final re = RegExp(r'(\d{4})\.(\d{1,2})\.(\d{1,2})');
    final out = <DateTime>[];
    for (final m in re.allMatches(text)) {
      final y = int.tryParse(m.group(1)!);
      final mo = int.tryParse(m.group(2)!);
      final d = int.tryParse(m.group(3)!);
      if (y != null && mo != null && d != null) {
        out.add(DateTime(y, mo, d));
      }
    }
    return out;
  }

  void clearCache() => _cache.clear();
}
