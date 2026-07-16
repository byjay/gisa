import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

/// 💻 CBT 안내 항목 (Q-Net 시험정보에서 크롤링).
class CbtInfo {
  final String jmCd;
  final String certName;
  final bool cbtEnabled; // 필기 CBT(컴퓨터 기반) 시행 여부
  final String feeWritten; // 필기 수수료
  final String feePractical; // 실기 수수료
  final List<String> notes; // 안내 문구(원서접수 시간 등)
  final DateTime fetchedAt;

  const CbtInfo({
    required this.jmCd,
    required this.certName,
    required this.cbtEnabled,
    required this.feeWritten,
    required this.feePractical,
    required this.notes,
    required this.fetchedAt,
  });

  /// CBT 체험(Q-Net 공식 웹 체험) 링크.
  static const cbtTrialUrl =
      'https://www.q-net.or.kr/cst006.do?id=cst00601';

  /// 가답안(확정답안) 공개 게시판 링크.
  static const answerBoardUrl =
      'https://www.q-net.or.kr/crf021.do?id=crf02101&gSite=Q';
}

/// Q-Net CBT/수수료/안내 실시간 크롤링 서비스.
class CbtInfoService {
  CbtInfoService._();
  static final CbtInfoService instance = CbtInfoService._();

  static const _base = 'https://www.q-net.or.kr/crf005.do';
  static const _corsProxies = [
    'https://proxy.cors.sh/',
    'https://api.allorigins.win/raw?url=',
    'https://cors.eu.org/',
  ];

  final Map<String, CbtInfo> _cache = {};
  Map<String, CbtInfo>? _bundled;

  Future<CbtInfo?> fetch(
    String jmCd,
    String certName, {
    String seriesCd = '03',
    String? catalogId,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cache.containsKey(jmCd)) return _cache[jmCd];

    final url = '$_base?id=crf00503s02&gSite=Q&gId='
        '&jmCd=$jmCd&jmInfoDivCcd=B0&seriesCd=$seriesCd';
    final html = await _fetchWithFallback(url);
    if (html != null) {
      final info = _parse(jmCd, certName, html);
      _cache[jmCd] = info;
      return info;
    }

    // 실시간 실패 → 번들 asset 폴백
    if (catalogId != null) {
      final offline = await _loadBundled(catalogId, certName);
      if (offline != null) {
        _cache[jmCd] = offline;
        return offline;
      }
    }
    return _cache[jmCd];
  }

  Future<CbtInfo?> _loadBundled(String catalogId, String certName) async {
    try {
      _bundled ??= await _parseBundle(certName);
      return _bundled?[catalogId];
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, CbtInfo>> _parseBundle(String certNameHint) async {
    final raw = await rootBundle.loadString('assets/data/qnet_schedule.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final cbt = (json['cbt'] as Map<String, dynamic>?) ?? {};
    final out = <String, CbtInfo>{};
    cbt.forEach((cid, v) {
      final m = v as Map<String, dynamic>;
      out[cid] = CbtInfo(
        jmCd: cid,
        certName: certNameHint,
        cbtEnabled: (m['cbtEnabled'] as bool?) ?? false,
        feeWritten: (m['feeWritten'] as String?) ?? '-',
        feePractical: (m['feePractical'] as String?) ?? '-',
        notes: ((m['notes'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
        fetchedAt: DateTime.now(),
      );
    });
    return out;
  }

  CbtInfo _parse(String jmCd, String certName, String html) {
    // 수수료 파싱 (필기 / 실기)
    final fees = RegExp(r'([\d,]+)\s*원')
        .allMatches(html)
        .map((m) => m.group(1) ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
    final feeWritten = fees.isNotEmpty ? '${fees[0]}원' : '-';
    final feePractical = fees.length > 1 ? '${fees[1]}원' : '-';

    // 안내 문구(txtList dot li) 파싱
    final notes = <String>[];
    for (final m in RegExp(r'<li[^>]*>(.*?)</li>', dotAll: true)
        .allMatches(html)) {
      final t = _clean(m.group(1) ?? '');
      if (t.isNotEmpty && t.length < 120) notes.add(t);
      if (notes.length >= 6) break;
    }

    // CBT 시행 여부: 기사/산업기사 필기는 전면 CBT 시행.
    // 안내 문구/본문에 CBT 키워드가 있거나, 기사/산업기사면 true 로 판단.
    final cbtEnabled = html.contains('CBT') ||
        html.contains('컴퓨터') ||
        certName.contains('기사') ||
        certName.contains('산업기사');

    return CbtInfo(
      jmCd: jmCd,
      certName: certName,
      cbtEnabled: cbtEnabled,
      feeWritten: feeWritten,
      feePractical: feePractical,
      notes: notes,
      fetchedAt: DateTime.now(),
    );
  }

  String _clean(String raw) => raw
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  Future<String?> _fetchWithFallback(String url) async {
    final direct = await _tryGet(url);
    if (direct != null && direct.contains('시험')) return direct;
    if (kIsWeb || direct == null) {
      for (final proxy in _corsProxies) {
        final proxied = proxy.endsWith('=')
            ? proxy + Uri.encodeComponent(url)
            : proxy + url;
        final res = await _tryGet(proxied);
        if (res != null && res.contains('시험')) return res;
      }
    }
    return direct;
  }

  Future<String?> _tryGet(String url) async {
    try {
      final res = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
        'Accept': 'text/html,application/xhtml+xml',
        'x-cors-api-key': 'temp_qnet_cert_tracker',
      }).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        try {
          return utf8.decode(res.bodyBytes);
        } catch (_) {
          return res.body;
        }
      }
    } catch (_) {}
    return null;
  }

  void clearCache() => _cache.clear();
}
