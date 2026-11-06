import 'dart:convert';
import 'remote_content_api.dart';

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
  static const cbtTrialUrl = 'https://www.q-net.or.kr/cst006.do?id=cst00601';

  /// 가답안(확정답안) 공개 게시판 링크.
  static const answerBoardUrl =
      'https://www.q-net.or.kr/crf021.do?id=crf02101&gSite=Q';
}

/// Q-Net CBT/수수료/안내 실시간 크롤링 서비스.
class CbtInfoService {
  CbtInfoService._();
  static final CbtInfoService instance = CbtInfoService._();

  final Map<String, CbtInfo> _cache = {};
  Map<String, CbtInfo>? _bundled;

  Future<CbtInfo?> fetch(
    String jmCd,
    String certName, {
    String seriesCd = '03',
    String? catalogId,
    bool forceRefresh = false,
  }) async {
    final sessionGeneration = RemoteContentApi.instance.sessionGeneration;
    if (!forceRefresh && _cache.containsKey(jmCd)) return _cache[jmCd];

    if (forceRefresh) _bundled = null;
    if (catalogId != null) {
      final serverInfo = await _loadBundled(catalogId, certName);
      if (sessionGeneration != RemoteContentApi.instance.sessionGeneration) {
        return null;
      }
      if (serverInfo != null) {
        _cache[jmCd] = serverInfo;
        return serverInfo;
      }
    }
    return _cache[jmCd];
  }

  Future<CbtInfo?> _loadBundled(String catalogId, String certName) async {
    try {
      final sessionGeneration = RemoteContentApi.instance.sessionGeneration;
      final bundled = _bundled ?? await _parseBundle(certName);
      if (sessionGeneration != RemoteContentApi.instance.sessionGeneration) {
        return null;
      }
      _bundled = bundled;
      return _bundled?[catalogId];
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, CbtInfo>> _parseBundle(String certNameHint) async {
    final raw = await RemoteContentApi.instance.getStudyFile(
      group: 'qnet',
      track: 'qnet',
      filename: 'qnet_schedule.json',
    );
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

  void clearCache() {
    _cache.clear();
    _bundled = null;
  }
}
